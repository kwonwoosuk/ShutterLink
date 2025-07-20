//
//  AppContainerView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/10/25.
//

import SwiftUI

struct AppContainerView: View {
    @EnvironmentObject private var authState: AuthState
    @StateObject private var router = NavigationRouter.shared
    @State private var hasInitialized = false
    
    var body: some View {
        ZStack {
            Group {
                if authState.isLoggedIn && hasInitialized {
                    MainTabView()
                        .environmentObject(router)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else if !authState.isLoading && hasInitialized {
                    SignInView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authState.isLoggedIn)
            
            if authState.isLoading || !hasInitialized {
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
                            
                            Text("자동 로그인 중 입니다...")
                                .font(.hakgyoansim(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                                .padding(.top, 10)
                            
                            
                            #if DEBUG
                            if hasInitialized {
                                Button("강제 로그아웃") {
                                    Task {
                                        await authState.forceLogout()
                                    }
                                }
                                .foregroundColor(.red)
                                .padding(.top, 20)
                            }
                            #endif
                        }
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: authState.isLoading)
            }
        }
        .onAppear {
            UITabBar.appearance().isHidden = true
            
            setupNavigationBarAppearance()
            
            if !hasInitialized {
                hasInitialized = true
            }
        }
        .task {
            // 앱 시작 시 한 번만 토큰 확인
            if !hasInitialized {
                await authState.loadUserIfTokenExists()
                hasInitialized = true
            }
        }
        
        .onChange(of: authState.isLoggedIn) { newValue in
            print("🔄 로그인 상태 변경: \(newValue)")
        }
        .onChange(of: authState.isLoading) { newValue in
            print("🔄 로딩 상태 변경: \(newValue)")
        }
    }
    
    private func setupNavigationBarAppearance() {
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        navBarAppearance.shadowColor = UIColor.black.withAlphaComponent(0.3)
        
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        navBarAppearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
    
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        
    }
}
