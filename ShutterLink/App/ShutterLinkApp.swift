//
//  ShutterLinkApp.swift
//  ShutterLink
//
//  Created by 권우석 on 5/10/25.
//

import SwiftUI
import KakaoSDKCommon
import KakaoSDKAuth
import FirebaseCore
import FirebaseMessaging
import iamport_ios

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 Firebase 등록 토큰: \(String(describing: fcmToken))")
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        Iamport.shared.receivedURL(url)
        return true
    }
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Firebase 초기화
        FirebaseApp.configure()
        
        // 알림 권한 요청
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions
            ) { granted, error in
                if granted {
                    print("✅ 알림 권한 허용됨")
                } else {
                    print("❌ 알림 권한 거부됨: \(error?.localizedDescription ?? "unknown")")
                }
            }
        } else {
            let settings: UIUserNotificationSettings =
            UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        // APNS 등록 (먼저 실행되어야 함)
        application.registerForRemoteNotifications()
        
        // 메시지 대리자 설정
        Messaging.messaging().delegate = self
        
        
        return true
    }
    
    // APNS 토큰 등록 성공
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("✅ APNS 토큰 등록 성공")
        
        // APNS 토큰을 FCM에 설정
        Messaging.messaging().apnsToken = deviceToken
        
        // APNS 토큰 설정 후 FCM 토큰 요청
        FCMTokenManager.shared.requestFCMTokenAfterAPNS()
    }
    
    // APNS 토큰 등록 실패
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNS 토큰 등록 실패: \(error)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // 포그라운드에서 알림 표시
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // 알림 탭 처리
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 알림 탭됨: \(userInfo)")
        completionHandler()
    }
}

@main
struct ShutterLinkApp: App {
    @StateObject private var notificationHandler = NotificationHandler.shared
    @StateObject private var authState = AuthState.shared
    @StateObject private var fcmTokenManager = FCMTokenManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        // 카카오 SDK 초기화
        KakaoSDK.initSDK(appKey: "6673881ea6a5986552bce8d37739b5e2")
        
        // 알림 권한 요청
        DeviceTokenManager.shared.requestNotificationPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            AppContainerView()
                .environmentObject(authState)
                .environmentObject(notificationHandler)
                .environmentObject(fcmTokenManager)
                .onOpenURL { url in
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    print("📱 앱이 foreground로 전환됨")
                    handleAppForeground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    print("📱 앱이 background로 전환됨")
                    authState.stopTokenRefreshTimer()
                }
        }
    }
    
    private func handleAppForeground() {
        // 로딩 중이 아닐 때만 처리
        guard !authState.isLoading else {
            print("⏳ 로딩 중이므로 토큰 확인 건너뛰기")
            return
        }
        
        // FCM 토큰 갱신
        fcmTokenManager.refreshFCMToken()
        
        if authState.isLoggedIn {
            print("✅ 로그인 상태 - 토큰 갱신 타이머 시작 및 토큰 확인")
            authState.startTokenRefreshTimer()
            
            // FCM 토큰을 서버와 동기화
            Task {
                await fcmTokenManager.syncTokenWithServer()
            }
            
            // 앱이 백그라운드에서 오래 있었을 경우를 대비해 토큰 상태 확인
            Task {
                await authState.checkAndRefreshTokenIfNeeded()
            }
        } else if authState.tokenManager.refreshToken != nil {
            print("🔑 토큰은 있지만 로그인 상태 아님 - 자동 로그인 시도")
            
            // 토큰은 있지만 로그인 상태가 아닌 경우 자동 로그인 시도
            Task {
                await authState.loadUserIfTokenExists()
                
                // 자동 로그인 성공 후 FCM 토큰 동기화
                if authState.isLoggedIn {
                    await fcmTokenManager.syncTokenWithServer()
                }
            }
        } else {
            print("❌ 토큰 없음 - 로그인 필요")
        }
    }
}
