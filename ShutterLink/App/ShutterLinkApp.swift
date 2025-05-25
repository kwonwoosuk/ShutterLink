//
//  ShutterLinkApp.swift
//  ShutterLink
//
//  Created by 권우석 on 5/10/25.
//

import SwiftUI
import KakaoSDKCommon
import KakaoSDKAuth

@main
struct ShutterLinkApp: App {
    @StateObject private var notificationHandler = NotificationHandler.shared
    @StateObject private var authState = AuthState.shared
    
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
                    
                    // 로딩 중이 아닐 때만 처리
                    guard !authState.isLoading else {
                        print("⏳ 로딩 중이므로 토큰 확인 건너뛰기")
                        return
                    }
                    
                    if authState.isLoggedIn {
                        print("✅ 로그인 상태 - 토큰 갱신 타이머 시작 및 토큰 확인")
                        authState.startTokenRefreshTimer()
                        
                        // 앱이 백그라운드에서 오래 있었을 경우를 대비해 토큰 상태 확인
                        Task {
                            await authState.checkAndRefreshTokenIfNeeded()
                        }
                    } else if authState.tokenManager.refreshToken != nil {
                        print("🔑 토큰은 있지만 로그인 상태 아님 - 자동 로그인 시도")
                        
                        // 토큰은 있지만 로그인 상태가 아닌 경우 자동 로그인 시도
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
