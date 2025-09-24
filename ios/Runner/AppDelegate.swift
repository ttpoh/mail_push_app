import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    var flutterViewController: FlutterViewController?
    let synthesizer = AVSpeechSynthesizer()
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    var isTTSSpeaking = false
    var processedMessageIds = Set<String>()
    private var mailEventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    // Alarm / TTS
    var sirenPlayer: AVAudioPlayer?
    var ttsTimer: Timer?                           // (교대 재생으로 더 이상 사용하지 않지만, stop에서 안전 해제용으로 남김)
    var isAlarmLoopRunning = false
    var currentTtsLang: String?
    var currentTtsText: String?

    // ✅ 교대 재생 상태
    var alternatingLoop = false
    var ttsQueuedNextSiren = false

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
            fatalError("루트 뷰 컨트롤러에서 FlutterViewController를 찾지 못했습니다.")
        }

        synthesizer.delegate = self

        do {
            try FirebaseApp.configure()
            print("Firebase 초기화 성공")
        } catch {
            print("Firebase 초기화 실패: \(error)")
        }

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        ) { granted, error in
            print(error == nil ? "알림 권한 요청 성공: \(granted)" : "알림 권한 요청 실패: \(error!)")
            if !granted {
                DispatchQueue.main.async {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
            }
        }
        application.registerForRemoteNotifications()

        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)

        // 권한 채널
        let criticalChannel = FlutterMethodChannel(
            name: "com.secure.mail_push_app/critical_alerts",
            binaryMessenger: flutterViewController!.binaryMessenger
        )
        criticalChannel.setMethodCallHandler { call, result in
            if call.method == "requestCriticalAlertPermission" {
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge, .criticalAlert]
                ) { granted, error in
                    result(error == nil ? granted : false)
                    if !granted {
                        DispatchQueue.main.async {
                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                        }
                    }
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        // (선택) TTS 단일 호출 채널
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

        // 알람 루프 제어 채널
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
                print("🧪 alarm_loop.start(text:\(text), lang:\(lang ?? "nil"), mode:\(mode))")
                self.startAlarmLoop(text: text, lang: lang, mode: mode)
                result(nil)
            case "stop":
                print("🧪 alarm_loop.stop()")
                self.stopAlarmLoop()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Dart→iOS 중복 방지 동기화 채널
        let syncChannel = FlutterMethodChannel(
            name: "com.secure.mail_push_app/sync",
            binaryMessenger: flutterViewController!.binaryMessenger
        )
        syncChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            if call.method == "syncMessageId",
               let args = call.arguments as? [String: Any],
               let id = args["id"] as? String {
                self.processedMessageIds.insert(id)
                print("🔔 Synced messageId: \(id)")
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        // EventChannel: iOS→Flutter
        mailEventChannel = FlutterEventChannel(
            name: "com.secure.mail_push_app/mail_events",
            binaryMessenger: flutterViewController!.binaryMessenger
        )
        mailEventChannel?.setStreamHandler(StreamHandler(delegate: self))

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("🔔 FCM registration token: \(token)")
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

    // 공통: mailData에서 이벤트 payload 구성
    private func buildMailEvent(messageId: String, mailData: [String: String]) -> [String: Any] {
        let subject = mailData["subject"] ?? ""
        let body = mailData["body"] ?? ""
        let sender = mailData["sender"] ?? ""
        let emailAddress = mailData["email_address"] ?? ""
        let receivedAt = mailData["received_at"] ?? ISO8601DateFormatter().string(from: Date())
        return [
            "messageId": messageId,
            "subject": subject,
            "body": body,
            "sender": sender,
            "email_address": emailAddress,
            "received_at": receivedAt
        ]
    }

    // 백그라운드/사일런트 푸시
    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("🔔 백그라운드 푸시: \(userInfo)")
        guard let messageId = userInfo["gcm.message_id"] as? String,
              !processedMessageIds.contains(messageId) else {
            print("🔔 이미 처리된 백그라운드 메시지: \(userInfo["gcm.message_id"] ?? "")")
            completionHandler(.noData)
            return
        }

        guard application.applicationState != .active else {
            print("🔔 포그라운드 상태: 백그라운드 푸시 처리 생략")
            completionHandler(.noData)
            return
        }

        processedMessageIds.insert(messageId)
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "TTS") {
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        }

        var ttsText: String?
        var ttsLang: String?
        var mailDataToSend: [String: Any]?
        var criticalUntil = false
        var isCritical = false

        if let critical = userInfo["isCritical"] as? String {
            isCritical = (critical.lowercased() == "true")
        }
        if let until = userInfo["criticalUntil"] as? String {
            criticalUntil = (until.lowercased() == "true")
        }
        print("🧪 flags(bg): isCritical=\(isCritical), until=\(criticalUntil)")

        if let mailDataString = userInfo["mailData"] as? String,
           let md = try? JSONSerialization.jsonObject(with: Data(mailDataString.utf8)) as? [String: String] {
            let subject = md["subject"] ?? ""
            let body = md["body"] ?? ""
            if subject.contains("미팅") || body.contains("미팅") {
                ttsText = "ミーティングのメールが届きました"
                ttsLang = "ja-JP"
            } else {
                ttsText = "緊急メールが届きました"
                ttsLang = "ja-JP"
            }
            mailDataToSend = buildMailEvent(messageId: messageId, mailData: md)
        }

        if let data = mailDataToSend, let sink = eventSink {
            sink(data)
        }

        // 🔑 loop일 때만 로컬 사이렌/tts 실행
        if isCritical && criticalUntil {
            let mode = "loop"
            startAlarmLoop(text: ttsText ?? "緊急メールが届きました", lang: ttsLang, mode: mode)
        }

        completionHandler(.newData)
    }

    // 포그라운드 수신
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("🔔 포그라운드 알림 수신: \(notification.request.identifier)")
        guard let userInfo = notification.request.content.userInfo as? [String: Any],
              let messageId = userInfo["gcm.message_id"] as? String,
              !processedMessageIds.contains(messageId) else {
            print("🔔 이미 처리된 포그라운드 메시지: \(notification.request.identifier)")
            // ✅ 포그라운드에서도 APNs 사운드가 들리도록 .sound 포함
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .list, .badge, .sound])
            } else {
                completionHandler([.alert, .badge, .sound])
            }
            return
        }

        processedMessageIds.insert(messageId)

        var ttsText: String?
        var ttsLang: String?
        var mailDataToSend: [String: Any]?
        var criticalUntil = false
        var isCritical = false

        if let critical = userInfo["isCritical"] as? String {
            isCritical = (critical.lowercased() == "true")
        }
        if let until = userInfo["criticalUntil"] as? String {
            criticalUntil = (until.lowercased() == "true")
        }
        print("🧪 flags(fg): isCritical=\(isCritical), until=\(criticalUntil)")

        if let mailDataString = userInfo["mailData"] as? String,
           let md = try? JSONSerialization.jsonObject(with: Data(mailDataString.utf8)) as? [String: String] {
            let subject = md["subject"] ?? ""
            let body = md["body"] ?? ""
            if subject.contains("미팅") || body.contains("미팅") {
                ttsText = "ミーティングのメールが届きました"
                ttsLang = "ja-JP"
            } else {
                ttsText = "緊急メールが届きました"
                ttsLang = "ja-JP"
            }
            mailDataToSend = buildMailEvent(messageId: messageId, mailData: md)
        }

        if let data = mailDataToSend, let sink = eventSink {
            sink(data)
        }

        // 🔑 loop일 때만 로컬 사이렌/tts 실행 (once는 APNs가 사운드 처리)
        if isCritical && criticalUntil {
            let mode = "loop"
            startAlarmLoop(text: ttsText ?? "緊急メールが届きました", lang: ttsLang, mode: mode)
        }

        // ✅ 포그라운드 사운드 허용
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }

    // MARK: - 알람 루프 (loop 전용, 교대 재생)
    func startAlarmLoop(text: String, lang: String?, mode: String) {
        // 🔐 하이브리드: loop만 로컬 처리, once는 APNs 사운드
        guard mode == "loop" else {
            print("🔕 skip local loop: mode=\(mode)")
            return
        }

        if isAlarmLoopRunning {
            print("🚫 Alarm loop already running")
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
                try session.setCategory(.playAndRecord,
                                        mode: .default,
                                        options: [.defaultToSpeaker, .duckOthers, .allowBluetooth, .allowBluetoothA2DP])
                try session.setActive(true)
                print("🔔 AVAudioSession 활성화")
            } catch {
                print("🔔 AVAudioSession 실패: \(error)")
                self.isAlarmLoopRunning = false
                self.alternatingLoop = false
                return
            }

            // ✅ 교대 재생: 첫 사이렌 1회 시작
            self.playSirenOnce()
        }
    }

    // ✅ 사이렌을 "딱 1회"만 재생
    private func playSirenOnce() {
        let assetPath = FlutterDartProject.lookupKey(forAsset: "assets/sounds/siren.mp3")
        guard let url = Bundle.main.url(forResource: assetPath, withExtension: nil) else {
            print("🔔 사이렌 파일 없음: \(assetPath)")
            stopAlarmLoop()
            return
        }
        do {
            sirenPlayer = try AVAudioPlayer(contentsOf: url)
            sirenPlayer?.delegate = self
            sirenPlayer?.volume = 1.0
            sirenPlayer?.prepareToPlay()
            sirenPlayer?.numberOfLoops = 0          // ✅ 1회
            sirenPlayer?.play()
            print("🔔 사이렌 1회 재생 시작")
        } catch {
            print("🔔 사이렌 재생 실패: \(error)")
            stopAlarmLoop()
        }
    }

    // 🔊 AVAudioPlayerDelegate — 사이렌 1회 종료 → TTS 1회
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard isAlarmLoopRunning, alternatingLoop else { return }
        // 사이렌이 끝났으니 TTS로 전환
        if let text = currentTtsText {
            ttsQueuedNextSiren = true
            speak(text, lang: currentTtsLang)
        }
    }

    func stopAlarmLoop() {
        isAlarmLoopRunning = false
        alternatingLoop = false
        ttsQueuedNextSiren = false

        ttsTimer?.invalidate(); ttsTimer = nil
        sirenPlayer?.stop(); sirenPlayer = nil

        // 현재 진행 중인 TTS가 있어도 루프는 종료 상태로 전환
        // (didFinish에서 alternatingLoop=false 덕분에 다음 사이렌은 재개되지 않음)
        currentTtsLang = nil
        currentTtsText = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false)
            print("🔔 AVAudioSession 비활성화")
        } catch {
            print("🔔 AVAudioSession 비활성화 실패: \(error)")
        }
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        print("🔔 알람 루프 정지")
    }

    // MARK: - TTS
    private func speak(_ text: String, lang: String? = nil) {
        guard !isTTSSpeaking else {
            print("🔔 TTS 이미 실행 중, 중복 호출 방지")
            return
        }
        isTTSSpeaking = true

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker, .duckOthers, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
            print("🔔 AVAudioSession 활성화 성공")
        } catch {
            print("🔔 AVAudioSession 설정 실패: \(error)")
            isTTSSpeaking = false
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        let langToUse = lang ?? currentTtsLang
        if let code = langToUse, let v = AVSpeechSynthesisVoice(language: code) {
            utterance.voice = v
        }
        utterance.rate = 0.5
        utterance.preUtteranceDelay = 0.2
        utterance.volume = 1.0

        synthesizer.speak(utterance)
        print("🔔 TTS 시작: \(text) (\(langToUse ?? "system-default"))")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isTTSSpeaking = false

        // ✅ 교대 재생: TTS가 끝나면 다시 사이렌 1회
        if isAlarmLoopRunning, alternatingLoop, ttsQueuedNextSiren {
            ttsQueuedNextSiren = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.playSirenOnce()
            }
            return
        }

        // 루프 중이 아니면 세션 내려 주기
        if !isAlarmLoopRunning {
            do {
                try AVAudioSession.sharedInstance().setActive(false)
                print("🔔 AVAudioSession 비활성화 (TTS 완료)")
            } catch {
                print("🔔 AVAudioSession 비활성화 실패: \(error)")
            }
        }
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔔 TTS 음성 재생 시작")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🔔 TTS 음성 재생 취소")
        isTTSSpeaking = false
    }

    class StreamHandler: NSObject, FlutterStreamHandler {
        weak var delegate: AppDelegate?

        init(delegate: AppDelegate) {
            self.delegate = delegate
        }

        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            delegate?.eventSink = events
            return nil
        }

        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            delegate?.eventSink = nil
            return nil
        }
    }
}
