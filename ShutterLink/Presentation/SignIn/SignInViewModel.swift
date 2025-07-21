//
//  SignInViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation
import Combine

final class SignInViewModel: ObservableObject {
    // Input
    @Published var email = ""
    @Published var password = ""
    
    // Output
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var isSignInComplete = false
    
    private let authUseCase: AuthUseCase
    private let authState: AuthState
    private let fcmTokenManager = FCMTokenManager.shared
    private let kakaoLoginManager = KakaoLoginManager.shared
    private let appleLoginManager = AppleLoginManager.shared
    
    init(authUseCase: AuthUseCase = AuthUseCaseImpl(), authState: AuthState = .shared) {
        self.authUseCase = authUseCase
        self.authState = authState
    }
    
    // MARK: - 이메일 로그인
    func signIn() async {
        guard !email.isEmpty && !password.isEmpty else {
            await MainActor.run {
                errorMessage = "이메일과 비밀번호를 입력해주세요."
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 실제 FCM 토큰 사용
            let deviceToken = getCurrentDeviceToken()
            
            let user = try await authUseCase.login(
                email: email,
                password: password,
                deviceToken: deviceToken
            )
            
            await MainActor.run {
                isLoading = false
                isSignInComplete = true
                authState.currentUser = user
                authState.isLoggedIn = true
                authState.startTokenRefreshTimer()
            }
            
            // 로그인 성공 후 FCM 토큰 동기화
            await fcmTokenManager.syncTokenWithServer()
            
            // 로그인 성공 후 FCM 토큰 동기화
            await fcmTokenManager.syncTokenWithServer()
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }
    
    // MARK: - 카카오 로그인
    func signInWithKakao() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 카카오 로그인으로 oauthToken 얻기
            let oauthToken = try await kakaoLoginManager.loginWithKakaoAccount()
            
            // 실제 FCM 토큰 사용
            let deviceToken = getCurrentDeviceToken()
            
            // 서버에 카카오 토큰과 FCM 토큰 전달하여 로그인
            let user = try await authUseCase.loginWithKakao(
                oauthToken: oauthToken,
                deviceToken: deviceToken
            )
            
            // 로그인 성공 시 알림 보내기
            DeviceTokenManager.shared.sendLocalNotification(
                title: "로그인 성공",
                body: "ShutterLink에 오신 것을 환영합니다!"
            )
            
            await MainActor.run {
                isLoading = false
                isSignInComplete = true
                authState.currentUser = user
                authState.isLoggedIn = true
                authState.startTokenRefreshTimer()
            }
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }
    
    // MARK: - 애플 로그인
    func signInWithApple() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 이전에 저장된 닉네임이 있는지 확인
            let savedNickname = UserDefaults.standard.string(forKey: "lastUserNickname")
            
            // 닉네임 결정 로직
            let userNickname: String
            if let savedNick = savedNickname, !savedNick.isEmpty {
                // 이전에 설정한 닉네임 사용
                userNickname = savedNick
                print("🔄 저장된 닉네임으로 로그인: \(userNickname)")
            } else {
                // 첫 로그인 시 기본값 사용
                userNickname = "ShutterLink_User"
                print("✨ 기본 닉네임으로 로그인: \(userNickname)")
            }
            
            // 애플 로그인 진행
            let idToken = try await AppleLoginManager.shared.handleAppleLogin(nickname: userNickname)
            try await AppleLoginManager.shared.completeLogin(idToken: idToken, nickname: userNickname)
            
            await MainActor.run {
                isLoading = false
                isSignInComplete = true
            }
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func getCurrentDeviceToken() -> String {
        // FCM 토큰이 있으면 사용, 없으면 임시 토큰 사용
        if let fcmToken = fcmTokenManager.getCurrentFCMToken() {
            print("✅ FCM 토큰 사용: \(fcmToken)")
            return fcmToken
        } else {
            // FCM 토큰이 없는 경우 임시 토큰 사용
            let fallbackToken = "temp_device_token_\(UUID().uuidString)"
            print("⚠️ FCM 토큰 없음, 임시 토큰 사용: \(fallbackToken)")
            
            // FCM 토큰 재요청
            fcmTokenManager.refreshFCMToken()
            
            return fallbackToken
        }
    }
    
    private func handleError(_ error: Error) {
        isLoading = false
        
        if let networkError = error as? NetworkError {
            errorMessage = networkError.errorMessage
        } else {
            errorMessage = error.localizedDescription
        }
    }
}
