//
//  SignUpViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation
import Combine

final class SignUpViewModel: ObservableObject {
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
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var isSignUpComplete = false
    @Published var isEmailValid = false
    @Published var isEmailAvailable = false
    @Published var isPasswordValid = false
    @Published var isPasswordMatching = false
    @Published var isNicknameValid = false
    @Published var isNameValid = false
    
    private let authUseCase: AuthUseCase
    private let authState: AuthState
    private let fcmTokenManager = FCMTokenManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(authUseCase: AuthUseCase = AuthUseCaseImpl(), authState: AuthState = .shared) {
        self.authUseCase = authUseCase
        self.authState = authState
        
        setupValidation()
    }
    
    private func setupValidation() {
        // 이메일 유효성 검사
        $email
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .map { email in
                let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
                return emailPredicate.evaluate(with: email)
            }
            .assign(to: \.isEmailValid, on: self)
            .store(in: &cancellables)
        
        // 비밀번호 유효성 검사
        $password
            .map { $0.count >= 6 }
            .assign(to: \.isPasswordValid, on: self)
            .store(in: &cancellables)
        
        // 비밀번호 확인
        Publishers.CombineLatest($password, $confirmPassword)
            .map { password, confirmPassword in
                !password.isEmpty && password == confirmPassword
            }
            .assign(to: \.isPasswordMatching, on: self)
            .store(in: &cancellables)
        
        // 닉네임 유효성 검사
        $nickname
            .map { $0.count >= 2 }
            .assign(to: \.isNicknameValid, on: self)
            .store(in: &cancellables)
        
        // 이름 유효성 검사
        $name
            .map { $0.count >= 2 }
            .assign(to: \.isNameValid, on: self)
            .store(in: &cancellables)
    }
    
    func validateEmail() async {
        guard isEmailValid else { return }
        
        do {
            isEmailAvailable = try await authUseCase.validateEmail(email: email)
        } catch {
            isEmailAvailable = false
            handleError(error)
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
            // 실제 FCM 토큰 가져오기
            let deviceToken = getCurrentDeviceToken()
            
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
            await MainActor.run {
                isLoading = false
                isSignUpComplete = true
                authState.currentUser = user
                authState.isLoggedIn = true
            }
            
            // 회원가입 성공 후 FCM 토큰 동기화
            await fcmTokenManager.syncTokenWithServer()
        } catch {
            handleError(error)
        }
    }
    
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
    
    private var isFormValid: Bool {
        return isEmailValid && isEmailAvailable && isPasswordValid &&
               isPasswordMatching && isNicknameValid && isNameValid
    }
}
