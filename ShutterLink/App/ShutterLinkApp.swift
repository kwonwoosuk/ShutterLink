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
                .fullScreenCover(isPresented: $authState.showLoginModal) {
                    SignInView()
                }
                .onOpenURL { url in
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    if authState.isLoggedIn {
                        authState.startTokenRefreshTimer()
                        // 앱이 백그라운드에서 오래 있었을 경우를 대비해 토큰 상태 확인
                        Task {
                            await authState.checkAndRefreshTokenIfNeeded()
                        }
                    } else if authState.tokenManager.refreshToken != nil {
                        // 토큰은 있지만 로그인 상태가 아닌 경우 자동 로그인 시도
                        Task {
                            await authState.loadUserIfTokenExists()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    authState.stopTokenRefreshTimer()
                }
        }
    }
}

//struct HomeView: View {
//    @EnvironmentObject private var authState: AuthState
//
//    var body: some View {
//        NavigationStack {
//            VStack {
//                Text("환영합니다, \(authState.currentUser?.nickname ?? "사용자")님!")
//                    .font(.title)
//                    .padding()
//
//                Button("로그아웃") {
//                    authState.logout()
//                }
//                .padding()
//                .background(Color.red)
//                .foregroundColor(.white)
//                .cornerRadius(10)
//            }
//            .navigationTitle("ShutterLink")
//        }
//    }
//}
