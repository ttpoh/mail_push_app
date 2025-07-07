import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate, AVSpeechSynthesizerDelegate {
    var flutterViewController: FlutterViewController?
    let synthesizer = AVSpeechSynthesizer()
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    var isTTSSpeaking = false
    var processedMessageIds = Set<String>()
    private var mailEventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // FlutterViewController 설정
        if let nav = window?.rootViewController as? UINavigationController,
           let flutterVC = nav.children.first as? FlutterViewController {
            flutterViewController = flutterVC
        } else if let flutterVC = window?.rootViewController as? FlutterViewController {
            flutterViewController = flutterVC
        } else {
            fatalError("루트 뷰 컨트롤러에서 FlutterViewController를 찾지 못했습니다.")
        }

        synthesizer.delegate = self

        // Firebase 초기화
        do {
            try FirebaseApp.configure()
            print("Firebase 초기화 성공")
        } catch {
            print("Firebase 초기화 실패: \(error)")
        }

        // 알림 설정
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        ) { granted, error in
            print(error == nil ? "알림 권한 요청 성공: \(granted)" : "알림 권한 요청 실패: \(error!)")
        }
        application.registerForRemoteNotifications()

        // MethodChannel 설정
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
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        let ttsChannel = FlutterMethodChannel(
            name: "com.secure.mail_push_app/tts",
            binaryMessenger: flutterViewController!.binaryMessenger
        )
        ttsChannel.setMethodCallHandler { call, result in
            if call.method == "speak",
               let args = call.arguments as? [String: Any],
               let text = args["text"] as? String {
                self.speak(text)
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        // EventChannel 설정
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
        var mailDataToSend: [String: Any]?
        if let mailDataString = userInfo["mailData"] as? String {
            do {
                if let mailData = try JSONSerialization.jsonObject(with: mailDataString.data(using: .utf8)!) as? [String: String] {
                    let subject = mailData["subject"] ?? ""
                    let body = mailData["body"] ?? ""
                    if subject.contains("긴급") || body.contains("긴급") {
                        ttsText = "緊急メールが届きました"
                    } else if subject.contains("미팅") || body.contains("미팅") {
                        ttsText = "ミーティングのメールが届きました"
                    }
                    mailDataToSend = ["messageId": messageId, "subject": subject, "body": body]
                }
            } catch {
                print("🔔 mailData JSON 파싱 실패: \(error)")
            }
        }

        // Flutter로 이벤트 전송
        if let data = mailDataToSend, let sink = eventSink {
            sink(data)
        }

        if let text = ttsText, !isTTSSpeaking {
            DispatchQueue.main.async {
                self.speak(text)
            }
        } else {
            print("🔔 TTS 메시지 없음 또는 이미 TTS 실행 중")
        }

        completionHandler(.newData)
    }

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
            completionHandler([.alert, .sound, .badge])
            return
        }

        processedMessageIds.insert(messageId)
        var ttsText: String?
        var mailDataToSend: [String: Any]?
        if let mailDataString = userInfo["mailData"] as? String {
            do {
                if let mailData = try JSONSerialization.jsonObject(with: mailDataString.data(using: .utf8)!) as? [String: String] {
                    let subject = mailData["subject"] ?? ""
                    let body = mailData["body"] ?? ""
                    if subject.contains("긴급") || body.contains("긴급") {
                        ttsText = "緊急メールが届きました"
                    } else if subject.contains("미팅") || body.contains("미팅") {
                        ttsText = "ミーティングのメール가届きました"
                    }
                    mailDataToSend = ["messageId": messageId, "subject": subject, "body": body]
                }
            } catch {
                print("🔔 포그라운드 mailData JSON 파싱 실패: \(error)")
            }
        }

        // Flutter로 이벤트 전송
        if let data = mailDataToSend, let sink = eventSink {
            sink(data)
        }

        if let text = ttsText, !isTTSSpeaking {
            DispatchQueue.main.async {
                self.speak(text)
            }
        } else {
            print("🔔 포그라운드 TTS 메시지 없음 또는 이미 TTS 실행 중")
        }

        completionHandler([.alert, .sound, .badge])
    }

    private func speak(_ text: String) {
        guard !isTTSSpeaking else {
            print("🔔 TTS 이미 실행 중, 중복 호출 방지")
            return
        }
        isTTSSpeaking = true

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            print("🔔 AVAudioSession 활성화 성공")
        } catch {
            print("🔔 AVAudioSession 설정 실패: \(error)")
            isTTSSpeaking = false
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.preUtteranceDelay = 0.5
        synthesizer.speak(utterance)
        print("🔔 TTS 시작: \(text)")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isTTSSpeaking = false
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            print("🔔 AVAudioSession 비활성화 성공")
        } catch {
            print("🔔 AVAudioSession 비활성화 실패: \(error)")
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

    // StreamHandler 클래스
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