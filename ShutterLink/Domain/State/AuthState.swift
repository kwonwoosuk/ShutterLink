//
//  AuthState.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation
import SwiftUI

final class AuthState: ObservableObject {
    static let shared = AuthState()
    
    @Published var isLoggedIn = false
    @Published var currentUser: User? = nil
    @Published var showLoginModal = false
    @Published var isLoading = false
    
    let tokenManager = TokenManager.shared
    private var refreshTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.shutterlink.tokenRefresh", qos: .background)
    
    init() {
        Task {
            await loadUserIfTokenExists()
        }
    }
    
    func loadUserIfTokenExists() async {
        guard tokenManager.refreshToken != nil else {
            print("❌ 리프레시 토큰 없음 - 로그인 상태 해제")
            await MainActor.run {
                self.isLoading = false
                self.isLoggedIn = false
                self.showLoginModal = false
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await refreshAccessToken()
            
            let profileUseCase = ProfileUseCaseImpl()
            let profileResponse = try await profileUseCase.getMyProfile()
            
            let user = User(
                id: profileResponse.user_id,
                email: profileResponse.email,
                nickname: profileResponse.nick,
                profileImageURL: profileResponse.profileImage
            )
            
            await MainActor.run {
                self.currentUser = user
                self.isLoggedIn = true
                self.isLoading = false
                self.showLoginModal = false
                self.startTokenRefreshTimer()
            }
            
        } catch let error as NetworkError {
            
            switch error {
            case  .refreshTokenExpired, .forbidden:
                print("🚫 세션 만료 - 로그아웃 처리")
                await MainActor.run {
                    logout()
                }
            case .accessTokenExpired, .invalidAccessToken:

                print("🔄 액세스 토큰 문제 - 재시도")
                do {
                    try await refreshAccessToken()
                    let profileUseCase = ProfileUseCaseImpl()
                    let profileResponse = try await profileUseCase.getMyProfile()
                    
                    let user = User(
                        id: profileResponse.user_id,
                        email: profileResponse.email,
                        nickname: profileResponse.nick,
                        profileImageURL: profileResponse.profileImage
                    )
                    
                    await MainActor.run {
                        self.currentUser = user
                        self.isLoggedIn = true
                        self.isLoading = false
                        self.showLoginModal = false
                        self.startTokenRefreshTimer()
                    }
                    print("✅ 재시도 후 로그인 성공")
                } catch {
                    print("❌ 재시도 실패 - 로그아웃 처리")
                    await MainActor.run {
                        logout()
                    }
                }
            default:
                print("⚠️ 네트워크 에러 - 로딩 해제")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            print("❌ 알 수 없는 에러: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func refreshAccessToken() async throws {
        guard let refreshToken = tokenManager.refreshToken else {
            throw NetworkError.refreshTokenExpired
        }
        
        do {
            let authUseCase = AuthUseCaseImpl()
            let tokenResponse = try await authUseCase.refreshToken()
            await MainActor.run {
                self.tokenManager.saveTokens(
                    accessToken: tokenResponse.accessToken,
                    refreshToken: tokenResponse.refreshToken
                )
            }
            print("✅ 토큰 갱신 성공")
        } catch let error as NetworkError {
            print("❌ 토큰 갱신 에러: \(error)")
            
            if error == .refreshTokenExpired || error == .forbidden {
                print("🚫 리프레시 토큰 만료 - 즉시 로그아웃")
                await MainActor.run {
                    self.logout()
                }
            }
            throw error
        }
    }
    
    func startTokenRefreshTimer() {
        stopTokenRefreshTimer()
        
        refreshTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        refreshTimer?.setEventHandler { [weak self] in
            Task {
                do {
                    try await self?.refreshAccessToken()
                } catch {
                    print("토큰 갱신 타이머 에러: \(error)")
                }
            }
        }
        
        refreshTimer?.schedule(deadline: .now() + 50, repeating: 50)
        refreshTimer?.resume()
    }
    
    func stopTokenRefreshTimer() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }
    
    func login(user: User, accessToken: String, refreshToken: String) {
        tokenManager.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
        self.currentUser = user
        self.isLoggedIn = true
        self.isLoading = false
        self.showLoginModal = false
        startTokenRefreshTimer()
    }
    
    func logout() {
        print("🚫 로그아웃 처리 시작")
        stopTokenRefreshTimer()
        tokenManager.clearTokens()
        self.currentUser = nil
        self.isLoggedIn = false
        self.isLoading = false
        self.showLoginModal = false
        print("✅ 로그아웃 처리 완료")
    }
    
    func showLogin() {
        self.showLoginModal = true
    }
    
    func checkAndRefreshTokenIfNeeded() async {
        do {
            try await refreshAccessToken()
        } catch {
            if let networkError = error as? NetworkError, networkError != .refreshTokenExpired {
                print("토큰 확인 중 에러 발생: \(error)")
            }
        }
    }
    
    func forceLogout() async {
        await MainActor.run {
            logout()
        }
    }
}
