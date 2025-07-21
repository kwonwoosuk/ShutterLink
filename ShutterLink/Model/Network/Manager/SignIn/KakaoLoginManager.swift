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

final class KakaoLoginManager {
    static let shared = KakaoLoginManager()
    
    private let authUseCase: AuthUseCase
    private let authState: AuthState
    private let fcmTokenManager = FCMTokenManager.shared
    
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
        // 실제 FCM 토큰 사용
        let deviceToken = getCurrentDeviceToken()
        
        // 서버에 카카오 토큰과 FCM 토큰 전달하여 로그인
        let user = try await authUseCase.loginWithKakao(oauthToken: token, deviceToken: deviceToken)
        
        // 로그인 상태 업데이트
        await MainActor.run {
            authState.currentUser = user
            authState.isLoggedIn = true
            authState.startTokenRefreshTimer()
        }
        
        // 로그인 성공 후 FCM 토큰 동기화
        await fcmTokenManager.syncTokenWithServer()
    }
    
    private func getCurrentDeviceToken() -> String {
        // FCM 토큰이 있으면 사용, 없으면 임시 토큰 사용
        if let fcmToken = fcmTokenManager.getCurrentFCMToken() {
            print("✅ 카카오 로그인에 FCM 토큰 사용: \(fcmToken)")
            return fcmToken
        } else {
            // FCM 토큰이 없는 경우 임시 토큰 사용
            let fallbackToken = "temp_device_token_\(UUID().uuidString)"
            print("⚠️ 카카오 로그인: FCM 토큰 없음, 임시 토큰 사용: \(fallbackToken)")
            
            // FCM 토큰 재요청
            fcmTokenManager.refreshFCMToken()
            
            return fallbackToken
        }
    }
}
