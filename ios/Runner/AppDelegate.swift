import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications
import AVFoundation

func extractDedupeKey(_ userInfo: [AnyHashable: Any]) -> String? {
    var mailId: String?
    if let mailDataStr = (userInfo["mailData"] as? String)
        ?? ((userInfo["custom_data"] as? [String: Any])?["mailData"] as? String),
       let data = mailDataStr.data(using: .utf8),
       let md = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        mailId = (md["message_id"] as? String) ?? (md["messageId"] as? String)
    }

    let fcmId = (userInfo["gcm.message_id"] as? String)
        ?? (userInfo["messageId"] as? String)
        ?? (userInfo["message_id"] as? String)

    let ver = (userInfo["ruleVersion"] as? String) ?? "v0"
    let keyBase = (mailId?.isEmpty == false) ? mailId! : (fcmId ?? "")
    guard !keyBase.isEmpty else { return nil }
    return "\(keyBase):\(ver)"
}

@main
@objc class AppDelegate: FlutterAppDelegate,
    MessagingDelegate,
    AVSpeechSynthesizerDelegate,
    AVAudioPlayerDelegate,
    FlutterStreamHandler
{
    var flutterViewController: FlutterViewController?
    let synthesizer = AVSpeechSynthesizer()

    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private func endBGTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    var isTTSSpeaking = false
    private var processedMessageIds = NSCache<NSString, NSNumber>()
    private let maxCacheSize = 500
    private var cacheCount = 0

    var sirenPlayer: AVAudioPlayer?
    var isAlarmLoopRunning = false
    var currentTtsLang: String?
    var currentTtsText: String?
    var ttsQueuedNextSiren = false
    var alternatingLoop = false
    private var mailEventSink: FlutterEventSink?

    // [RULE_SOUND] 추가 – UNTIL/CRITICAL에서 사용할 사운드 이름 저장
    var loopSoundName: String?

    // [RULE_SOUND] 서버에서 내려준 sound 추출
    private func pickSoundName(from userInfo: [AnyHashable: Any]) -> String? {
        if let s = userInfo["sound"] as? String { return s }
        if let cd = userInfo["custom_data"] as? [String: Any],
           let s = cd["sound"] as? String { return s }
        return nil
    }

        // MARK: - App lifecycle & channels
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        // FlutterVC 회수
        if let nav = window?.rootViewController as? UINavigationController,
           let flutterVC = nav.children.first as? FlutterViewController {
            flutterViewController = flutterVC
        } else if let flutterVC = window?.rootViewController as? FlutterViewController {
            flutterViewController = flutterVC
        } else {
            fatalError("FlutterViewController not found")
        }

        synthesizer.delegate = self
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        ) { _, _ in }
        application.registerForRemoteNotifications()

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil
        )

        // TTS 채널
        let ttsChannel = FlutterMethodChannel(
            name: "com.secure.mail_push_app/tts",
            binaryMessenger: flutterViewController!.binaryMessenger
        )
        ttsChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            if call.method == "speak",
               let args = call.arguments as? [String: Any],
               let text = args["text"] as? String {
                let lang = args["lang"] as? String
                self.speak(text, lang: lang)
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        // Loop 채널
        let alarmLoopChannel = FlutterMethodChannel(
            name: "com.secure.mail_push_app/alarm_loop",
            binaryMessenger: flutterViewController!.binaryMessenger
        )
        alarmLoopChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "start":
                let args = call.arguments as? [String: Any]
                let text = (args?["text"] as? String) ?? "An emergency email has arrived"
                let lang = (args?["lang"] as? String)
                let mode = (args?["mode"] as? String) ?? "once"
                self.startAlarmLoop(text: text, lang: lang, mode: mode)
                result(nil)
            case "stop":
                self.stopAlarmLoop { result(nil) }
            case "status":
                result(self.isAlarmLoopRunning)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Sync 채널
        let syncChannel = FlutterMethodChannel(
            name: "com.secure.mail_push_app/sync",
            binaryMessenger: flutterViewController!.binaryMessenger
        )
        syncChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            if call.method == "syncMessageId",
               let args = call.arguments as? [String: Any],
               let id = args["id"] as? String {
                self.markProcessed(id)
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        // EventChannel (메일 이벤트 → Dart)
        let mailEventChannel = FlutterEventChannel(
            name: "com.secure.mail_push_app/mail_event",
            binaryMessenger: flutterViewController!.binaryMessenger
        )
        mailEventChannel.setStreamHandler(self)

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - FCM
    override func application(_ application: UIApplication,
                              didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("🔔 FCM token: \(token)")
    }

    // MARK: - Foreground banner
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        // dedupe
        if let key = extractDedupeKey(userInfo) {
            if isAlreadyProcessed(key) {
                if #available(iOS 14.0, *) {
                    completionHandler([.banner, .list, .badge, .sound])
                } else {
                    completionHandler([.alert, .badge, .sound])
                }
                return
            }
            markProcessed(key)
        }

        // [RULE_SOUND] 규칙 사운드 저장
        if let s = pickSoundName(from: userInfo), !s.isEmpty, s != "default" {
            loopSoundName = s
        }

        // Dart로 이벤트 전달
        emitMailEvent(from: userInfo)

        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }

    // MARK: - Background/Remote push
    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let key = extractDedupeKey(userInfo) else {
            completionHandler(.noData)
            return
        }
        if isAlreadyProcessed(key) {
            completionHandler(.noData)
            return
        }
        markProcessed(key)

        func asBool(_ v: Any?) -> Bool {
            switch v {
            case let b as Bool: return b
            case let s as String: return s.lowercased() == "true"
            default: return false
            }
        }

        let isCritical = asBool(userInfo["isCritical"] ?? (userInfo["custom_data"] as? [String: Any])?["isCritical"])
        let criticalUntil = asBool(userInfo["criticalUntil"] ?? (userInfo["custom_data"] as? [String: Any])?["criticalUntil"])
        let ch = (userInfo["pushChannel"] as? String) ?? "alert"
        let (ttsText, ttsLang) = pickTTS(from: userInfo)

        // [RULE_SOUND] 규칙 사운드 저장 (CRITICAL/UNTIL 모두 사용)
        if let s = pickSoundName(from: userInfo), !s.isEmpty, s != "default" {
            loopSoundName = s
        } else {
            loopSoundName = nil
        }

        // Dart로 이벤트 전달
        emitMailEvent(from: userInfo)

        // BG 작업 시간 확보 (critical일 때)
        if isCritical {
            endBGTask()
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "TTS_Loop") { [weak self] in
                self?.stopAlarmLoop()
                self?.endBGTask()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 28) { [weak self] in
                guard let self = self else { return }
                if !self.isTTSSpeaking && !self.isAlarmLoopRunning {
                    self.endBGTask()
                }
            }
        }

        // (1) BG 채널
        if ch == "bg" {
            if isCritical && criticalUntil {
                // UNTIL 루프 시작 → 규칙 사운드 사용
                startAlarmLoop(text: ttsText, lang: ttsLang, mode: "loop")
                completionHandler(.newData)
                return
            }
            if isCritical && !criticalUntil {
                // CRITICAL 1회: 규칙 사운드 재생 + TTS 한번
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.playRuleSoundOnceOrDefault()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.speak(ttsText, lang: ttsLang)
                }
                completionHandler(.newData)
                return
            }
            completionHandler(.noData)
            return
        }

        // (2) ALERT 채널 (fail-over)
        if ch == "alert" {
            if isCritical && criticalUntil && !isAlarmLoopRunning {
                // UNTIL: 루프 시작 (규칙 사운드 사용)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.startAlarmLoop(text: ttsText, lang: ttsLang, mode: "loop")
                }
                completionHandler(.newData)
                return
            }
            if isCritical && !criticalUntil && !isTTSSpeaking {
                // CRITICAL 1회: 규칙 사운드 재생 + TTS
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.playRuleSoundOnceOrDefault()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.speak(ttsText, lang: ttsLang)
                }
                completionHandler(.newData)
                return
            }
            completionHandler(.noData)
            return
        }

        completionHandler(.noData)
    }

        // MARK: - Interruptions
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        if type == .ended, !isTTSSpeaking, let text = currentTtsText, !isAlarmLoopRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.speak(text, lang: self?.currentTtsLang)
            }
        }
    }

    // MARK: - Event → Dart
    private func emitMailEvent(from userInfo: [AnyHashable: Any]) {
        guard let sink = mailEventSink else { return }
        let rm1 = (userInfo["ruleMatched"] as? String)?.lowercased() == "true"
        let rm2 = ((userInfo["custom_data"] as? [String: Any])?["ruleMatched"] as? String)?.lowercased() == "true"
        guard rm1 || rm2 else { return }

        let mailDataStrTop = userInfo["mailData"] as? String
        let mailDataStrNested = (userInfo["custom_data"] as? [String: Any])?["mailData"] as? String
        guard let mailStr = mailDataStrTop ?? mailDataStrNested,
              let mailData = mailStr.data(using: .utf8),
              let mailMap = (try? JSONSerialization.jsonObject(with: mailData)) as? [String: Any] else {
            return
        }

        let mailIdFromData = (mailMap["message_id"] as? String) ?? (mailMap["messageId"] as? String)
        let baseIdTop = userInfo["messageId"] as? String
        let baseIdNested = (userInfo["custom_data"] as? [String: Any])?["messageId"] as? String
        let baseId = baseIdTop ?? baseIdNested
        let fcmId = (userInfo["gcm.message_id"] as? String)
            ?? (userInfo["message_id"] as? String)

        let mid = mailIdFromData ?? baseId ?? fcmId ?? UUID().uuidString

        var payload: [String: Any] = [:]
        payload["messageId"] = mid
        payload["ruleMatched"] = "true"
        if let ra = userInfo["ruleAlarm"] { payload["ruleAlarm"] = ra }
        if let ea = userInfo["effectiveAlarm"] { payload["effectiveAlarm"] = ea }
        if let ch = userInfo["pushChannel"] { payload["pushChannel"] = ch }
        payload["mailData"] = mailMap

        sink(payload)
    }

    // MARK: - Dedupe helpers
    private func markProcessed(_ key: String) {
        processedMessageIds.setObject(NSNumber(value: true), forKey: key as NSString)
        cacheCount += 1
        if cacheCount > maxCacheSize {
            processedMessageIds.removeAllObjects()
            cacheCount = 0
        }
    }

    private func isAlreadyProcessed(_ key: String) -> Bool {
        return processedMessageIds.object(forKey: key as NSString) != nil
    }

    // MARK: - TTS
    private func speak(_ text: String, lang: String? = nil) {
        if isTTSSpeaking && !synthesizer.isSpeaking {
            isTTSSpeaking = false
        }
        guard !isTTSSpeaking else { return }
        isTTSSpeaking = true
        let session = AVAudioSession.sharedInstance()
        func activateAndSpeak() throws {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let utter = AVSpeechUtterance(string: text)
            if let code = (lang ?? currentTtsLang), let v = AVSpeechSynthesisVoice(language: code) {
                utter.voice = v
            }
            utter.rate = 0.5
            utter.preUtteranceDelay = 0.2
            utter.volume = 0.7 //tts volume
            synthesizer.speak(utter)
        }
        do { try activateAndSpeak() }
        catch {
            isTTSSpeaking = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self else { return }
                if self.isTTSSpeaking && !self.synthesizer.isSpeaking { self.isTTSSpeaking = false }
                self.isTTSSpeaking = true
                do { try activateAndSpeak() } catch {
                    self.isTTSSpeaking = false
                    try? session.setActive(false, options: .notifyOthersOnDeactivation)
                    if !self.isAlarmLoopRunning { self.endBGTask() }
                }
            }
        }
    }

    // MARK: - Rule sound playback
    // [RULE_SOUND] 규칙 사운드를 1회 재생 (없으면 siren/기본으로 폴백)
    private func playRuleSoundOnceOrDefault() {
        // 규칙 사운드가 지정된 경우 mp3/caf 우선순위로 탐색
        if let base = loopSoundName, !base.isEmpty {
            if let url = Bundle.main.url(forResource: base, withExtension: "mp3") {
                play(url: url); return
            }
            if let url = Bundle.main.url(forResource: base, withExtension: "caf") {
                play(url: url); return
            }
        }
        // 폴백: siren
        playSirenOnce()
    }

    // 기존 siren 재생 (폴백)
    private func playSirenOnce() {
        if let url = Bundle.main.url(forResource: "siren", withExtension: "caf") {
            play(url: url); return
        }
        if let url = Bundle.main.url(forResource: "siren", withExtension: "mp3") {
            play(url: url); return
        }
        stopAlarmLoop()
    }

    private func play(url: URL) {
        do {
            sirenPlayer = try AVAudioPlayer(contentsOf: url)
            sirenPlayer?.delegate = self
            sirenPlayer?.volume = 0.5
            sirenPlayer?.numberOfLoops = 0
            sirenPlayer?.prepareToPlay()
            sirenPlayer?.play()
        } catch {
            stopAlarmLoop()
        }
    }

    // MARK: - Loop (UNTIL)
    func startAlarmLoop(text: String, lang: String?, mode: String) {
        guard mode == "loop" else { return }

        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isTTSSpeaking = false
        sirenPlayer?.stop()
        sirenPlayer = nil

        if isAlarmLoopRunning {
            currentTtsLang = lang
            currentTtsText = text
            alternatingLoop = true
            ttsQueuedNextSiren = false
            DispatchQueue.main.async { [weak self] in self?.playRuleSoundOnceOrDefault() }  // [RULE_SOUND]
            return
        }
        isAlarmLoopRunning = true
        alternatingLoop = true
        ttsQueuedNextSiren = false
        currentTtsLang = lang
        currentTtsText = text

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try session.setActive(true)
            } catch {
                self.isAlarmLoopRunning = false
                self.alternatingLoop = false
                return
            }
            // 첫 사이클: 규칙 사운드 → TTS → 규칙 사운드 ...
            self.playRuleSoundOnceOrDefault()  // [RULE_SOUND]
        }
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard isAlarmLoopRunning, alternatingLoop else { return }
        if let text = currentTtsText {
            ttsQueuedNextSiren = true
            speak(text, lang: currentTtsLang)

            // 워치독: 1.5초 내 TTS 시작 못하면 다시 규칙 사운드
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                if self.isAlarmLoopRunning && !self.synthesizer.isSpeaking && self.ttsQueuedNextSiren {
                    self.ttsQueuedNextSiren = false
                    self.playRuleSoundOnceOrDefault()  // [RULE_SOUND]
                }
            }
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isTTSSpeaking = false
        if isAlarmLoopRunning, alternatingLoop, ttsQueuedNextSiren {
            ttsQueuedNextSiren = false
            DispatchQueue.main.async { [weak self] in self?.playRuleSoundOnceOrDefault() } // [RULE_SOUND]
            return
        }
        if !isAlarmLoopRunning {
            try? AVAudioSession.sharedInstance().setActive(false)
            endBGTask()
        }
    }

    // MARK: - Stop
    func stopAlarmLoop(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            self.isAlarmLoopRunning = false
            self.alternatingLoop = false
            self.ttsQueuedNextSiren = false
            self.sirenPlayer?.stop(); self.sirenPlayer = nil
            self.currentTtsLang = nil; self.currentTtsText = nil
            try? AVAudioSession.sharedInstance().setActive(false)
            self.endBGTask()
            completion?()
        }
    }

    // MARK: - TTS 텍스트 선택 (기존 유지)
    // 기존 pickTTS 교체
    private func pickTTS(from userInfo: [AnyHashable: Any]) -> (String, String?) {
        // 1) 서버 payload 최우선
        if let t = userInfo["tts"] as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (t, nil)   // 언어는 iOS가 자동선택(또는 필요 시 규칙 확장으로 lang도 내려줄 수 있음)
        }
        if let cd = userInfo["custom_data"] as? [String: Any],
        let t = cd["tts"] as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (t, nil)
        }

        // 2) 없으면 기존 휴리스틱
        var text = "緊急メールが届きました"
        var lang: String? = "ja-JP"
        if let mailDataString = userInfo["mailData"] as? String,
        let data = mailDataString.data(using: .utf8),
        let md = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let subject = (md["subject"] as? String) ?? ""
            let body = (md["body"] as? String) ?? ""
            if subject.contains("미팅") || body.contains("미팅") {
                text = "ミーティングのメールが届きました"
                lang = "ja-JP"
            }
        }
        return (text, lang)
    }


    // MARK: - FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        mailEventSink = events
        return nil
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        mailEventSink = nil
        return nil
    }
}


