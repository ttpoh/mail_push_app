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

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // FlutterViewController 참조
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

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        ) { granted, error in
            print(error == nil ? "알림 권한 요청 성공: \(granted)" : "알림 권한 요청 실패: \(error!)")
        }
        application.registerForRemoteNotifications()

        // MethodChannels 등록
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

    // MARK: - FCM 토큰 갱신 콜백
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("🔔 FCM registration token: \(token)")
        // 서버에 토큰 등록 로직 호출 필요 시 여기에 추가
    }

    // 백그라운드 silent push 수신
    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("🔔 백그라운드 푸시: \(userInfo)")

        // Background Task 시작
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "TTS") {
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        }

        // mailData 파싱 및 TTS 텍스트 선택
        var ttsText: String?
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
                }
            } catch {
                print("🔔 mailData JSON 파싱 실패: \(error)")
            }
        } else {
            print("🔔 mailData가 문자열 형식이 아님")
        }

        if let text = ttsText {
            DispatchQueue.main.async {
                self.speak(text)
            }
        } else {
            print("🔔 TTS 메시지 없음")
        }

        completionHandler(.newData)
    }

    // 공통 TTS 호출
    private func speak(_ text: String) {
        let session = AVAudioSession.sharedInstance()
        do {
            if #available(iOS 13.0, *) {
                try session.setCategory(.playback,
                                        mode: .spokenAudio,
                                        options: [.mixWithOthers])
            } else {
                try session.setCategory(.playback,
                                        options: [.mixWithOthers])
            }
            try session.setActive(true)
            print("🔔 AVAudioSession 활성화 성공")
        } catch {
            print("🔔 AVAudioSession 설정 실패: \(error)")
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.preUtteranceDelay = 1.5
        synthesizer.speak(utterance)
        print("🔔 TTS 시작: \(text)")
    }

    // MARK: AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                          didFinish utterance: AVSpeechUtterance) {
        // 오디오 세션 비활성화 & Background Task 종료
        do {
            try AVAudioSession.sharedInstance().setActive(false,
                options: .notifyOthersOnDeactivation)
            print("🔔 AVAudioSession 비활성화 성공")
        } catch {
            print("🔔 AVAudioSession 비활성화 실패: \(error)")
        }
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                          didStart utterance: AVSpeechUtterance) {
        print("🔔 TTS 음성 재생 시작")
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                          didCancel utterance: AVSpeechUtterance) {
        print("🔔 TTS 음성 재생 취소")
    }
}