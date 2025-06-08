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
    
    private init() {
        Task {
            await loadUserIfTokenExists()
        }
    }
    
    func loadUserIfTokenExists() async {
        print("🔍 사용자 토큰 확인 시작")
        
        // 토큰이 없으면 로그인 상태 해제
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
            // 먼저 토큰 갱신 시도
            try await refreshAccessToken()
            
            // 프로필 정보 로드
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
            print("✅ 사용자 로그인 상태 복원 성공")
            
        } catch let error as NetworkError {
            print("❌ 프로필 로드 에러: \(error)")
            
            switch error {
            case  .refreshTokenExpired, .forbidden:
                // 리프레시 토큰에 문제가 있는 경우 로그아웃 처리
                print("🚫 세션 만료 - 로그아웃 처리")
                await MainActor.run {
                    logout()
                }
            case .accessTokenExpired, .invalidAccessToken:
                // 액세스 토큰만 문제가 있는 경우 갱신 재시도 (1회만)
                print("🔄 액세스 토큰 문제 - 재시도")
                do {
                    try await refreshAccessToken()
                    // 재귀 호출 방지를 위해 프로필 정보만 다시 로드
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
                // 기타 네트워크 에러는 토큰이 유효할 수 있으므로 로딩만 해제
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
            
            // 403 오류(refreshTokenInvalid) 또는 리프레시 토큰 만료 시 로그아웃
            if error == .refreshTokenExpired || error == .forbidden {
                print("🚫 리프레시 토큰 만료 - 즉시 로그아웃")
                await MainActor.run {
                    // 중요: 여기서 logout()을 호출하면 isLoading도 false로 설정됨
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
                    // 에러 로깅만 하고 타이머는 계속 유지
                    // 리프레시 토큰 관련 에러는 refreshAccessToken 내에서 처리
                    print("토큰 갱신 타이머 에러: \(error)")
                }
            }
        }
        
        // 110초마다 실행(만료 10초 전 갱신)
        refreshTimer?.schedule(deadline: .now() + 110, repeating: 110)
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
        self.isLoading = false // 중요: 로그아웃 시 로딩 상태도 해제
        self.showLoginModal = false // 로그아웃 시 모달도 해제
        print("✅ 로그아웃 처리 완료")
    }
    
    func showLogin() {
        self.showLoginModal = true
    }
    
    func checkAndRefreshTokenIfNeeded() async {
        // 토큰이 곧 만료되거나 의심스러운 경우 갱신
        do {
            try await refreshAccessToken()
        } catch {
            if let networkError = error as? NetworkError, networkError != .refreshTokenExpired {
                // 리프레시 토큰이 만료되지 않은 다른 에러의 경우
                print("토큰 확인 중 에러 발생: \(error)")
            }
        }
    }
    
    // 강제 로그아웃 메서드 (디버깅용)
    func forceLogout() async {
        await MainActor.run {
            logout()
        }
    }
}
