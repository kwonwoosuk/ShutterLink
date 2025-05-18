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
        
        print("🌐 API 요청: \(urlRequest.url?.absoluteString ?? "")")
        print("🧠 요청 헤더: \(urlRequest.allHTTPHeaderFields ?? [:])")
        if let body = urlRequest.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("📦 요청 바디: \(bodyString)")
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            print("📨 API 응답: \(response)")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔢 상태 코드: \(httpResponse.statusCode)")
            }
            
            if let dataString = String(data: data, encoding: .utf8) {
                print("📄 응답 데이터: \(dataString)")
                // 추가 - 세부 응답 구조 확인
                if let json = try? JSONSerialization.jsonObject(with: data) {
                    print("📊 응답 JSON 구조: \(json)")
                }
            }
            
            let processedData = try middleware.handleResponse(data: data, response: response)
            return try JSONDecoder().decode(T.self, from: processedData)
        } catch let error as NetworkError {
            print("⚠️ 네트워크 에러: \(error.errorMessage)")
            print("⚠️ 원본 에러: \(error)")
            
            // 추가 에러 정보
            if case .invalidCredentials = error {
                print("🔑 인증 실패: 카카오 계정이 SLP 서버에 등록되어 있지 않을 수 있습니다")
            }
            
            if case .accessTokenExpired = error {
                return try await handleTokenRefresh(router: router, type: type)
            }
            throw error
        } catch {
            print("❓ 알 수 없는 에러: \(error.localizedDescription)")
            print("❓ 원본 에러 객체: \(error)")
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
