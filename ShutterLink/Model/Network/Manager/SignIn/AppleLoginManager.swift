//
//  AppleLoginManager.swift
//  ShutterLink
//
//  Created by 권우석 on 5/18/25.
//

import Foundation
import AuthenticationServices
import SwiftUI

class AppleLoginManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleLoginManager()
    
    private let authUseCase: AuthUseCase
    private let authState: AuthState
    
    // 결과 콜백을 위한 continuation 객체
    private var loginContinuation: CheckedContinuation<String, Error>?
    
    // 닉네임 저장을 위한 변수
    private var nickname: String?
    
    private init(authUseCase: AuthUseCase = AuthUseCaseImpl(), authState: AuthState = .shared) {
        self.authUseCase = authUseCase
        self.authState = authState
        super.init()
    }
    
    func handleAppleLogin(nickname: String? = nil) async throws -> String {
        self.nickname = nickname
        let nonce = randomNonceString()
        return try await withCheckedThrowingContinuation { continuation in
            self.loginContinuation = continuation
            
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = nonce
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }
    
    func completeLogin(idToken: String, nickname: String? = nil) async throws {
        // 디바이스 토큰 가져오기
        guard let deviceToken = DeviceTokenManager.shared.getCurrentToken() else {
            throw NSError(domain: "DeviceTokenError", code: -1, userInfo: [NSLocalizedDescriptionKey: "디바이스 토큰을 생성할 수 없습니다."])
        }
        
        // 서버에 애플 토큰 전달하여 로그인
        let user = try await authUseCase.loginWithApple(idToken: idToken, deviceToken: deviceToken, nickname: nickname)
        
        // 로그인 성공 시 알림 보내기
        DeviceTokenManager.shared.sendLocalNotification(
            title: "로그인 성공",
            body: "ShutterLink에 오신 것을 환영합니다!"
        )
        
        // 로그인 상태 업데이트
        await MainActor.run {
            authState.currentUser = user
            authState.isLoggedIn = true
        }
    }
    
    // ASAuthorizationControllerDelegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
           let tokenData = appleIDCredential.identityToken,
           let idToken = String(data: tokenData, encoding: .utf8) {
            loginContinuation?.resume(returning: idToken)
            loginContinuation = nil
        } else {
            loginContinuation?.resume(throwing: NSError(domain: "AppleSignInError", code: -1, userInfo: [NSLocalizedDescriptionKey: "인증 정보를 가져오지 못했습니다."]))
            loginContinuation = nil
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        loginContinuation?.resume(throwing: error)
        loginContinuation = nil
    }
    
    // ASAuthorizationControllerPresentationContextProviding
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // iOS 15부터는 UIApplication 대신 해당 방식 사용
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene!.windows.first!
    }
    
    // MARK: - Helper Methods
    
    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            for random in randoms {
                if remainingLength == 0 {
                    break
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
}
