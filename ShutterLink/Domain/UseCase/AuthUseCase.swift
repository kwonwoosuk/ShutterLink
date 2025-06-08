//
//  AuthUseCase.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation

protocol AuthUseCase {
    func validateEmail(email: String) async throws -> Bool
    func register(email: String, password: String, nickname: String, name: String, introduction: String, phoneNum: String, hashTags: [String], deviceToken: String) async throws -> User
    func login(email: String, password: String, deviceToken: String) async throws -> User
    func loginWithKakao(oauthToken: String, deviceToken: String) async throws -> User
    func loginWithApple(idToken: String, deviceToken: String, nickname: String?) async throws -> User

    func refreshToken() async throws -> TokenResponse
}

final class AuthUseCaseImpl: AuthUseCase {
    private let networkManager = NetworkManager.shared
    private let tokenManager = TokenManager.shared
    private let authState = AuthState.shared
    
    func validateEmail(email: String) async throws -> Bool {
        let router = AuthRouter.validateEmail(email: email)
        let response = try await networkManager.request(router, type: EmailValidationResponse.self)
        // "사용 가능한 이메일입니다." 메시지를 확인
        return response.message.contains("사용 가능한")
    }
    
    func register(email: String, password: String, nickname: String, name: String, introduction: String, phoneNum: String, hashTags: [String], deviceToken: String) async throws -> User {
        let joinRequest = JoinRequest(
            email: email,
            password: password,
            nick: nickname,
            name: name,
            introduction: introduction,
            phoneNum: phoneNum,
            hashTags: hashTags,
            deviceToken: deviceToken
        )
        
        let router = AuthRouter.join(user: joinRequest)
        let response = try await networkManager.request(router, type: JoinResponse.self)
        
        // 토큰 저장
        tokenManager.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
        
        // 사용자 모델 반환
        let user = User(from: response)
        return user
    }
    
    func login(email: String, password: String, deviceToken: String) async throws -> User {
        let router = AuthRouter.login(email: email, password: password, deviceToken: deviceToken)
        let response = try await networkManager.request(router, type: LoginResponse.self)
        
        // 토큰 저장
        tokenManager.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
        
        // 사용자 모델 반환
        let user = User(from: response)
        return user
    }
    
    func loginWithKakao(oauthToken: String, deviceToken: String) async throws -> User {
           let router = AuthRouter.kakaoLogin(oauthToken: oauthToken, deviceToken: deviceToken)
           let response = try await networkManager.request(router, type: LoginResponse.self)
           
           // 토큰 저장
           tokenManager.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
           
           // 사용자 모델 반환
           let user = User(from: response)
           return user
       }
    
    func loginWithApple(idToken: String, deviceToken: String, nickname: String?) async throws -> User {
        let router = AuthRouter.appleLogin(idToken: idToken, deviceToken: deviceToken, nickname: nickname)
        let response = try await networkManager.request(router, type: LoginResponse.self)
        
        // 토큰 저장
        tokenManager.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
        
        // 사용자 모델 반환
        let user = User(from: response)
        return user
    }
    
    func refreshToken() async throws -> TokenResponse {
        guard let refreshToken = tokenManager.refreshToken else {
            throw NetworkError.refreshTokenExpired
        }
        
        let router = AuthRouter.refreshToken(refreshToken: refreshToken)
        return try await networkManager.request(router, type: TokenResponse.self)
    }
}
