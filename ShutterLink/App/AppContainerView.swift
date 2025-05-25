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
        ZStack {
            Group {
                if authState.isLoggedIn {
                    MainTabView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    SignInView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authState.isLoggedIn)
            
            // 앱 초기 로딩 상태
            if authState.isLoading {
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 20) {
                            Image(systemName: "camera.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .foregroundColor(.white)
                            
                            Text("ShutterLink")
                                .font(.hakgyoansim(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                                .padding(.top, 10)
                        }
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: authState.isLoading)
            }
        }
        .onAppear {
            // 앱 전체에서 기본 탭바 숨김 처리
            UITabBar.appearance().isHidden = true
        }
    }
}
