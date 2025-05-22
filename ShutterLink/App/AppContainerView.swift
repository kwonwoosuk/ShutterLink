//
//  AppContainerView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/10/25.
//

import SwiftUI

struct AppContainerView: View {
    @EnvironmentObject private var authState: AuthState
    
    var body: some View {
        Group {
            if authState.isLoggedIn {
                MainTabView()
            } else {
                SignInView()
            }
        }
        .onAppear {
            // 앱 전체에서 기본 탭바 숨김 처리
            UITabBar.appearance().isHidden = true
        }
    }
}
