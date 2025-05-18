//
//  SignInViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation
import Combine

class SignInViewModel: ObservableObject {
    // Input
    @Published var email = ""
    @Published var password = ""
    
    // Output
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var isSignInComplete = false
    
    private let authUseCase: AuthUseCase
    private let authState: AuthState
    private let kakaoLoginManager = KakaoLoginManager.shared
    
    init(authUseCase: AuthUseCase = AuthUseCaseImpl(), authState: AuthState = .shared) {
        self.authUseCase = authUseCase
        self.authState = authState
    }
    
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
            // 실제 구현에서는 FCM 등에서 얻어온 디바이스 토큰
            let deviceToken = "sample_device_token"
            
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
            }
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }
    
    func signInWithKakao() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 카카오 로그인으로 oauthToken 얻기
            let oauthToken = try await KakaoLoginManager.shared.loginWithKakaoAccount()
            
            // SwiftUI 환경에서 생성한 deviceToken 사용
            guard let deviceToken = DeviceTokenManager.shared.getCurrentToken() else {
                throw NSError(domain: "DeviceTokenError", code: -1, userInfo: [NSLocalizedDescriptionKey: "디바이스 토큰을 생성할 수 없습니다."])
            }
            
            // 로그인 성공 시 알림 보내기
            DeviceTokenManager.shared.sendLocalNotification(
                title: "로그인 성공",
                body: "ShutterLink에 오신 것을 환영합니다!"
            )
            
            // SLP 서버로 카카오 로그인 요청
            let user = try await authUseCase.loginWithKakao(oauthToken: oauthToken, deviceToken: deviceToken)
            
            await MainActor.run {
                isLoading = false
                authState.currentUser = user
                authState.isLoggedIn = true
                isSignInComplete = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                if let networkError = error as? NetworkError {
                    errorMessage = networkError.errorMessage
                    print("❌ 카카오 로그인 에러: \(networkError.errorMessage)")
                } else {
                    errorMessage = error.localizedDescription
                    print("❌ 카카오 로그인에러러러러러: \(error)")
                }
            }
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
