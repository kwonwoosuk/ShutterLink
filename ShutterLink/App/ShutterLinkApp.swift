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

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 Firebase 등록 토큰: \(String(describing: fcmToken))")
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
    }
    
    private func handleFCMChatNotification(userInfo: [AnyHashable: Any], isBackground: Bool) {
        if let roomId = userInfo["room_id"] as? String {
            if CurrentChatRoomManager.shared.isCurrentChatRoom(roomId) {
                Task {
                    await UnreadMessageManager.shared.handleFCMNotification()
                    await MainActor.run {
                        let totalUnread = UnreadMessageManager.shared.totalUnreadCount
                        UIApplication.shared.applicationIconBadgeNumber = totalUnread
                    }
                    
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("FCMChatNotificationReceived"),
                            object: nil,
                            userInfo: ["roomId": roomId, "isCurrentRoom": true]
                        )
                    }
                }
                return
            }
            // 푸시받으면  앱 알림 갯수 뱃지 업데이트하는 메서드
            Task {
                await UnreadMessageManager.shared.handleFCMNotification()
                await MainActor.run {
                    let totalUnread = UnreadMessageManager.shared.totalUnreadCount
                    UIApplication.shared.applicationIconBadgeNumber = totalUnread
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("FCMChatNotificationReceived"),
                        object: nil,
                        userInfo: ["roomId": roomId, "isCurrentRoom": false]
                    )
                }
            }
        }
    }
    
    // MARK: - 채팅 푸시 알림 탭 처리
    
    private func handleChatPushNotificationTap(userInfo: [AnyHashable: Any]) {
        //          print("🔔 FCM userInfo 전체 구조:")
        //          for (key, value) in userInfo {
        //              print("  \(key): \(value) (타입: \(type(of: value)))")
        //          }
        
        guard let roomId = userInfo["room_id"] as? String else {
            return
        }
        
        print("🔔 채팅 푸시 알림 탭 - roomId: \(roomId)")
        NavigationRouter.shared.navigateToChatFromPush(roomId: roomId)
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
                options: authOptions
            ) { granted, error in
                if granted {
                    print("✅ 알림 권한 허용됨")
                } else {
                    print("❌ 알림 권한 거부됨")
                }
            }
        } else {
            let settings: UIUserNotificationSettings =
            UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        application.registerForRemoteNotifications()
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
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("📱 포그라운드에서 알림 수신: \(userInfo)")
        
        if let roomId = userInfo["room_id"] as? String,
           CurrentChatRoomManager.shared.isCurrentChatRoom(roomId) {
            print("🚫 현재 활성 채팅방 알림 - 포그라운드 알림 생략")
            
            handleFCMChatNotification(userInfo: userInfo, isBackground: false)
            completionHandler([])
            return
        }
        
        handleFCMChatNotification(userInfo: userInfo, isBackground: false)
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        handleChatPushNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
}

@main
struct ShutterLinkApp: App {
    @StateObject private var authState = AuthState.shared
    @StateObject private var fcmTokenManager = FCMTokenManager.shared
    @StateObject private var currentChatRoomManager = CurrentChatRoomManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        KakaoSDK.initSDK(appKey: "6673881ea6a5986552bce8d37739b5e2")
        
        // 알림 권한 요청
        DeviceTokenManager.shared.requestNotificationPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            AppContainerView()
                .environmentObject(authState)
                .environmentObject(fcmTokenManager)
                .environmentObject(currentChatRoomManager)
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
        guard !authState.isLoading else {
            print("⏳ 로딩 중이므로 토큰 확인 건너뛰기")
            return
        }
        fcmTokenManager.refreshFCMToken()
        
        if authState.isLoggedIn {
            print("✅ 로그인 상태 - 토큰 갱신 타이머 시작 및 토큰 확인")
            authState.startTokenRefreshTimer()
            
            Task {
                await fcmTokenManager.syncTokenWithServer()
            }
            
            Task {
                await authState.checkAndRefreshTokenIfNeeded()
            }
        } else if authState.tokenManager.refreshToken != nil {
            print("🔑 토큰은 있지만 로그인 상태 아님 - 자동 로그인 시도")
            
            // 토큰은 있지만 로그인 상태가 아닌 경우 자동 로그인 시도
            Task {
                await authState.loadUserIfTokenExists()
                if authState.isLoggedIn {
                    await fcmTokenManager.syncTokenWithServer()
                }
            }
        } else {
            print("❌ 토큰 없음 - 로그인 필요")
        }
    }
}
