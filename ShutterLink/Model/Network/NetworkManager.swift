//
//  NetworkManager.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let middleware: NetworkMiddleware
    private let tokenManager: TokenManager
    
    private var isRefreshing = false
    private var requestsToRetry: [(URLRequest, (Result<Data, Error>) -> Void)] = []
    
    private init(session: URLSession = .shared,
                middleware: NetworkMiddleware = NetworkMiddleware(),
                tokenManager: TokenManager = TokenManager.shared) {
        self.session = session
        self.middleware = middleware
        self.tokenManager = tokenManager
    }
    
    func request<T: Decodable>(_ router: APIRouter, type: T.Type) async throws -> T {
        var urlRequest = try router.asURLRequest()
        middleware.prepare(request: &urlRequest, authorizationType: router.authorizationType)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            let processedData = try middleware.handleResponse(data: data, response: response)
            return try JSONDecoder().decode(T.self, from: processedData)
        } catch let error as NetworkError {
            if case .accessTokenExpired = error {
                // Access Token이 만료된 경우 갱신 시도
                return try await handleTokenRefresh(router: router, type: type)
            }
            throw error
        } catch {
            throw NetworkError.unknownError
        }
    }
    
    private func handleTokenRefresh<T: Decodable>(router: APIRouter, type: T.Type) async throws -> T {
        guard let refreshToken = tokenManager.refreshToken else {
            throw NetworkError.refreshTokenExpired
        }
        
        // 토큰 갱신 요청
        let refreshRouter = AuthRouter.refreshToken(refreshToken: refreshToken)
        
        do {
            let tokenResponse = try await request(refreshRouter, type: TokenResponse.self)
            
            // 새 토큰 저장
            tokenManager.saveTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken
            )
            
            // 원래 요청 재시도
            return try await request(router, type: type)
        } catch {
            if case NetworkError.refreshTokenExpired = error {
                // 리프레시 토큰도 만료되었으면 로그아웃 처리
                tokenManager.clearTokens()
                AuthState.shared.isLoggedIn = false
                // 로그인 화면으로 리다이렉트 로직 (AuthState 통해 처리)
            }
            throw error
        }
    }
}

struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}
