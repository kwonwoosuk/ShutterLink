//
//  SignUpViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation
import SwiftUI
import Combine

class SignUpViewModel: ObservableObject {
    // Input
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var nickname = ""
    @Published var name = ""
    @Published var introduction = ""
    @Published var phoneNumber = ""
    @Published var hashtags = ""
    
    // Output
    @Published var isEmailValid = false
    @Published var isEmailAvailable = false
    @Published var isPasswordValid = false
    @Published var isPasswordMatching = false
    @Published var isNicknameValid = false
    @Published var isNameValid = false
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var isSignUpComplete = false
    
    private let authUseCase: AuthUseCase
    private let authState: AuthState
    private var cancellables = Set<AnyCancellable>()
    
    init(authUseCase: AuthUseCase = AuthUseCaseImpl(), authState: AuthState = .shared) {
        self.authUseCase = authUseCase
        self.authState = authState
        setupValidations()
    }
    
    private func setupValidations() {
        // 이메일 형식 검증
        $email
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .map { email in
                let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
                return emailPredicate.evaluate(with: email)
            }
            .assign(to: &$isEmailValid)
        
        // 비밀번호 유효성 검증 (8자 이상, 영문자, 숫자, 특수문자 포함)
        $password
            .dropFirst()
            .map { password in
                let passwordRegex = "^(?=.*[A-Za-z])(?=.*\\d)(?=.*[@$!%*#?&])[A-Za-z\\d@$!%*#?&]{8,}$"
                let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
                return passwordPredicate.evaluate(with: password)
            }
            .assign(to: &$isPasswordValid)
        
        // 비밀번호 일치 여부 검증
        Publishers.CombineLatest($password, $confirmPassword)
            .dropFirst()
            .map { password, confirmPassword in
                return !password.isEmpty && password == confirmPassword
            }
            .assign(to: &$isPasswordMatching)
        
        // 닉네임 유효성 검증 (비어있지 않은지)
        $nickname
            .dropFirst()
            .map { !$0.isEmpty }
            .assign(to: &$isNicknameValid)
        
        // 이름 유효성 검증 (비어있지 않은지)
        $name
            .dropFirst()
            .map { !$0.isEmpty }
            .assign(to: &$isNameValid)
    }
    
    func validateEmail() async {
        guard isEmailValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            isEmailAvailable = try await authUseCase.validateEmail(email: email)
            isLoading = false
        } catch {
            handleError(error)
        }
    }
    
    func signUp() async {
        guard isFormValid else {
            errorMessage = "모든 필수 항목을 올바르게 입력해주세요."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // 해시태그 처리
        let hashTagsList = hashtags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        
        do {
            // 기기 토큰은 실제 구현에서는 FCM 등을 통해 얻어옵니다.
            let deviceToken = "sample_device_token"
            
            let user = try await authUseCase.register(
                email: email,
                password: password,
                nickname: nickname,
                name: name,
                introduction: introduction,
                phoneNum: phoneNumber,
                hashTags: hashTagsList,
                deviceToken: deviceToken
            )
            
            // 회원가입 성공
            isLoading = false
            isSignUpComplete = true
            authState.currentUser = user
            authState.isLoggedIn = true
        } catch {
            handleError(error)
        }
    }
    
    private var isFormValid: Bool {
        return isEmailValid && isEmailAvailable && isPasswordValid &&
               isPasswordMatching && isNicknameValid && isNameValid
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
