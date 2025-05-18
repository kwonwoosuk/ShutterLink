//
//  KakaoLoginManager.swift
//  ShutterLink
//
//  Created by 권우석 on 5/18/25.
//

import Foundation
import KakaoSDKUser
import KakaoSDKAuth
import KakaoSDKCommon

class KakaoLoginManager {
    static let shared = KakaoLoginManager()
    
    private let authUseCase: AuthUseCase
    private let authState: AuthState
    
    private init(authUseCase: AuthUseCase = AuthUseCaseImpl(), authState: AuthState = .shared) {
        self.authUseCase = authUseCase
        self.authState = authState
    }
    
    func handleKakaoLogin() async throws -> String {
        // 카카오톡 설치 여부 확인
        if UserApi.isKakaoTalkLoginAvailable() {
            // 카카오톡으로 로그인
            return try await loginWithKakaoTalk()
        } else {
            // 카카오 계정으로 로그인
            return try await loginWithKakaoAccount()
        }
    }
    
    private func loginWithKakaoTalk() async throws -> String {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            UserApi.shared.loginWithKakaoTalk { oauthToken, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let token = oauthToken?.accessToken else {
                    continuation.resume(throwing: NetworkError.customError("카카오 토큰을 가져올 수 없습니다."))
                    return
                }
                
                // 로그인 성공, 토큰 전달
                continuation.resume(returning: token)
            }
        }
    }
    
    func loginWithKakaoAccount() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            
            DispatchQueue.main.async {
                UserApi.shared.loginWithKakaoAccount { (oauthToken, error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let token = oauthToken?.accessToken else {
                        continuation.resume(throwing: NSError(domain: "KakaoLoginError", code: -1, userInfo: [NSLocalizedDescriptionKey: "토큰을 받아오지 못했습니다."]))
                        return
                    }
                    
                    continuation.resume(returning: token)
                }
            }
        }
        
    }
    
    func completeLogin(token: String) async throws {
        // 디바이스 토큰 (실제 구현에서는 FCM 등을 통해 얻음)
        let deviceToken = "sample_device_token"
        
        // 서버에 카카오 토큰 전달하여 로그인
        let user = try await authUseCase.loginWithKakao(oauthToken: token, deviceToken: deviceToken)
        
        // 로그인 상태 업데이트
        await MainActor.run {
            authState.currentUser = user
            authState.isLoggedIn = true
        }
    }
}
