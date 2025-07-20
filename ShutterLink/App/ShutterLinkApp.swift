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
        print("FireBase 등록 토큰 \(String(describing: fcmToken))")
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        Iamport.shared.receivedURL(url)
        return true
    }
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { _, _ in }
            )
        } else {
            let settings: UIUserNotificationSettings =
            UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        // APNs 등록
        application.registerForRemoteNotifications()
        //메세지 대리자 설정
        Messaging.messaging().delegate = self
        //현재 등록된 토큰 가져오기
        Messaging.messaging().token() { token , error in
            if let error = error {
                print("Error fetching FCM registration token: \(error)")
            } else if let token = token {
                print("FCM registration token: \(token)")
            }
            
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

@main
struct ShutterLinkApp: App {
    @StateObject private var notificationHandler = NotificationHandler.shared
    @StateObject private var authState = AuthState.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        KakaoSDK.initSDK(appKey: "6673881ea6a5986552bce8d37739b5e2")
        let _ = DeviceTokenManager.shared.getCurrentToken()
        DeviceTokenManager.shared.requestNotificationPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            AppContainerView()
                .environmentObject(authState)
                .environmentObject(notificationHandler)
                .onOpenURL { url in
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    print("📱 앱이 foreground로 전환됨")
                    
                    guard !authState.isLoading else {
                        print("⏳ 로딩 중이므로 토큰 확인 건너뛰기")
                        return
                    }
                    
                    if authState.isLoggedIn {
                        print("✅ 로그인 상태 - 토큰 갱신 타이머 시작 및 토큰 확인")
                        authState.startTokenRefreshTimer()
                        
                        Task {
                            await authState.checkAndRefreshTokenIfNeeded()
                        }
                    } else if authState.tokenManager.refreshToken != nil {
                        print("🔑 토큰은 있지만 로그인 상태 아님 - 자동 로그인 시도")
                        
                        Task {
                            await authState.loadUserIfTokenExists()
                        }
                    } else {
                        print("❌ 토큰 없음 - 로그인 필요")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    print("📱 앱이 background로 전환됨")
                    authState.stopTokenRefreshTimer()
                }
        }
    }
}
