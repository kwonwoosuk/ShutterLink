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
    
    private func handleError(_ error: Error) {
        isLoading = false
        if let networkError = error as? NetworkError {
            errorMessage = networkError.errorMessage
        } else {
            errorMessage = error.localizedDescription
        }
    }
}
