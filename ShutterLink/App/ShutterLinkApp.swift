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
            // KakaoSDK 초기화
            KakaoSDK.initSDK(appKey: "6673881ea6a5986552bce8d37739b5e2")
            
            // 디바이스 토큰 및 알림 설정
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
                        // 카카오 로그인 콜백 처리
                        if AuthApi.isKakaoTalkLoginUrl(url) {
                            _ = AuthController.handleOpenUrl(url: url)
                        }
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
