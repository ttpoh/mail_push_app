import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications
import AVFoundation

func extractDedupeKey(_ userInfo: [AnyHashable: Any]) -> String? {
    // 1) mailData 파싱 (top-level 또는 custom_data)
    var mailId: String?
    if let mailDataStr = (userInfo["mailData"] as? String)
        ?? ((userInfo["custom_data"] as? [String: Any])?["mailData"] as? String),
       let data = mailDataStr.data(using: .utf8),
       let md = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        mailId = (md["message_id"] as? String) ?? (md["messageId"] as? String)
    }

    // 2) 폴백: APNs/FCM의 메시지ID
    let fcmId = (userInfo["gcm.message_id"] as? String)
        ?? (userInfo["messageId"] as? String)
        ?? (userInfo["message_id"] as? String)

    // 3) ruleVersion
    let ver = (userInfo["ruleVersion"] as? String) ?? "v0"

    // 4) 채널은 **키에서 제외** (bg/alert 모두 동일 키)
    let keyBase = (mailId?.isEmpty == false) ? mailId! : (fcmId ?? "")
    guard !keyBase.isEmpty else { return nil }
    return "\(keyBase):\(ver)"
}


@main
@objc class AppDelegate: FlutterAppDelegate,
    MessagingDelegate,
    AVSpeechSynthesizerDelegate,
    AVAudioPlayerDelegate,
    FlutterStreamHandler { // ✅ EventChannel 스트림 핸들러 추가

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
    // 메모리 누적 방지: 시간 기반 윈도우 또는 크기 제한 추가
    private var processedMessageIds = NSCache<NSString, NSNumber>()
    private let maxCacheSize = 500
    private var cacheCount = 0

    var sirenPlayer: AVAudioPlayer?
    var isAlarmLoopRunning = false
    var currentTtsLang: String?
    var currentTtsText: String?
    var ttsQueuedNextSiren = false
    var alternatingLoop = false

    private var isInBackground: Bool { UIApplication.shared.applicationState != .active }

    // ✅ EventChannel sink 보관
    private var mailEventSink: FlutterEventSink?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

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
        ) { _,_ in }
        application.registerForRemoteNotifications()

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil
        )

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
            } else { result(FlutterMethodNotImplemented) }
        }

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
            } else { result(FlutterMethodNotImplemented) }
        }

        // ✅ EventChannel 등록 (Dart의 HomeScreen에서 이미 구독함)
        let mailEventChannel = FlutterEventChannel(
            name: "com.secure.mail_push_app/mail_event",
            binaryMessenger: flutterViewController!.binaryMessenger
        )
        mailEventChannel.setStreamHandler(self)

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

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

    override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("🔔 FCM token: \(token)")
    }

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

    // ✅ Dart로 이벤트를 던지는 헬퍼
    private func emitMailEvent(from userInfo: [AnyHashable: Any]) {
        guard let sink = mailEventSink else { return }

        // ruleMatched 체크
        let rm1 = (userInfo["ruleMatched"] as? String)?.lowercased() == "true"
        let rm2 = ((userInfo["custom_data"] as? [String: Any])?["ruleMatched"] as? String)?.lowercased() == "true"
        guard rm1 || rm2 else { return }

        // mailData 추출 (top-level 또는 custom_data 내부)
        let mailDataStrTop = userInfo["mailData"] as? String
        let mailDataStrNested = (userInfo["custom_data"] as? [String: Any])?["mailData"] as? String
        guard let mailStr = mailDataStrTop ?? mailDataStrNested,
              let mailData = mailStr.data(using: .utf8),
              let mailMap = (try? JSONSerialization.jsonObject(with: mailData)) as? [String: Any] else {
            return
        }

        // ✅ messageId: 메일 고유 ID 우선 → 서버 base_data의 messageId → 최후에 FCM ID
        let mailIdFromData = (mailMap["message_id"] as? String) ?? (mailMap["messageId"] as? String)
        let baseIdTop = userInfo["messageId"] as? String
        let baseIdNested = (userInfo["custom_data"] as? [String: Any])?["messageId"] as? String
        let baseId = baseIdTop ?? baseIdNested
        let fcmId = (userInfo["gcm.message_id"] as? String)
            ?? (userInfo["message_id"] as? String)

        let mid = mailIdFromData ?? baseId ?? fcmId ?? UUID().uuidString

        var payload: [String: Any] = [:]
        payload["messageId"] = mid                     // ✅ 항상 메일 ID로 고정
        payload["ruleMatched"] = "true"
        if let ra = userInfo["ruleAlarm"] { payload["ruleAlarm"] = ra }
        if let ea = userInfo["effectiveAlarm"] { payload["effectiveAlarm"] = ea }
        if let ch = userInfo["pushChannel"] { payload["pushChannel"] = ch }
        payload["mailData"] = mailMap

        sink(payload)
    }

    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let key = extractDedupeKey(userInfo) else {
            completionHandler(.noData)
            return
        }

        // 중복 체크
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

        // ✅ Dart로 이벤트 전달 (ruleMatched && mailData 있을 때만)
        emitMailEvent(from: userInfo)

        // BG 작업 시간 연장
        endBGTask()
        if isCritical {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "TTS_Loop") { [weak self] in
                self?.stopAlarmLoop()
                self?.endBGTask()
            }
            // 배경 작업 시간: 최대 30초 이용 가능하지만 조기 종료 방지
            DispatchQueue.main.asyncAfter(deadline: .now() + 28) { [weak self] in
                guard let self = self else { return }
                // TTS나 루프가 진행 중이면 조금 더 유지
                if !self.isTTSSpeaking && !self.isAlarmLoopRunning {
                    self.endBGTask()
                }
            }
        }

        // (1) BG 채널 처리
        if ch == "bg" {
            if isCritical && criticalUntil {
                startAlarmLoop(text: ttsText, lang: ttsLang, mode: "loop")
                completionHandler(.newData)
                return
            }
            if isCritical && !criticalUntil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.speak(ttsText, lang: ttsLang)
                }
                completionHandler(.newData)
                return
            }
            completionHandler(.noData)
            return
        }

        // (2) ALERT 채널 Fail-over
        if ch == "alert" {
            if isCritical && criticalUntil && !isAlarmLoopRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.startAlarmLoop(text: ttsText, lang: ttsLang, mode: "loop")
                }
                completionHandler(.newData)
                return
            }
            if isCritical && !criticalUntil && !isTTSSpeaking {
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

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // ✅ 포그라운드 배너 케이스에서도 Dart로 즉시 전달
        let userInfo = notification.request.content.userInfo

            // ✅ dedupe: willPresent에서도 동일키로 중복 차단
        if let key = extractDedupeKey(userInfo) {
            if isAlreadyProcessed(key) {
                // 이미 처리된 이벤트라면 Dart로 emit하지 않음
                if #available(iOS 14.0, *) {
                    completionHandler([ .banner, .list, .badge, .sound ])
                } else {
                    completionHandler([ .alert, .badge, .sound ])
                }
                return
            }
            markProcessed(key)
        }

        emitMailEvent(from: userInfo)

        if #available(iOS 14.0, *) {
            completionHandler([ .banner, .list, .badge, .sound ])
        } else {
            completionHandler([ .alert, .badge, .sound ])
        }
    }

    // ===== 루프 =====
    func startAlarmLoop(text: String, lang: String?, mode: String) {
        guard mode == "loop" else { return }

        // ✅ 새 루프 시작/갱신 시 항상 깨끗한 상태로
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isTTSSpeaking = false
        sirenPlayer?.stop()
        sirenPlayer = nil

        // 이미 루프 중이더라도 텍스트/언어 갱신은 허용
        if isAlarmLoopRunning {
            currentTtsLang = lang
            currentTtsText = text
            // 다음 사이렌 → TTS 순서가 보장되도록 토글 리셋
            alternatingLoop = true
            ttsQueuedNextSiren = false
            // 즉시 다음 사이클 시작
            DispatchQueue.main.async { [weak self] in self?.playSirenOnce() }
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
            self.playSirenOnce()
        }
    }

    private func speak(_ text: String, lang: String? = nil) {
         // ✅ 플래그 스티키 복구
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
            utter.volume = 1.0
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
            sirenPlayer?.volume = 1.0
            sirenPlayer?.numberOfLoops = 0
            sirenPlayer?.prepareToPlay()
            sirenPlayer?.play()
        } catch {
            stopAlarmLoop()
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard isAlarmLoopRunning, alternatingLoop else { return }
        if let text = currentTtsText {
            ttsQueuedNextSiren = true
            speak(text, lang: currentTtsLang)

            // ✅ 워치독: 1.5초 안에 실제 TTS가 시작 안되면 사이렌로 재진입
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                if self.isAlarmLoopRunning && !self.synthesizer.isSpeaking && self.ttsQueuedNextSiren {
                    // TTS가 못 올라갔다면 다시 시도 or 다음 사이렌으로 넘어가 루프 유지
                    self.ttsQueuedNextSiren = false
                    self.playSirenOnce()
                }
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isTTSSpeaking = false
        if isAlarmLoopRunning, alternatingLoop, ttsQueuedNextSiren {
            ttsQueuedNextSiren = false
            DispatchQueue.main.async { [weak self] in self?.playSirenOnce() }
            return
        }
        if !isAlarmLoopRunning {
            try? AVAudioSession.sharedInstance().setActive(false)
            endBGTask()
        }
    }

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

    private func pickTTS(from userInfo: [AnyHashable: Any]) -> (String, String?) {
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
