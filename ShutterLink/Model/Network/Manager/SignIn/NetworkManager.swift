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
    private let authState: AuthState
    private var isRefreshing = false
    private var requestsToRetry: [(URLRequest, (Result<Data, Error>) -> Void)] = []
    
    private init(session: URLSession = .shared,
                 middleware: NetworkMiddleware = NetworkMiddleware(),
                 tokenManager: TokenManager = TokenManager.shared,
                 authState: AuthState = AuthState.shared) {
        self.session = session
        self.middleware = middleware
        self.tokenManager = tokenManager
        self.authState = authState
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
                if let json = try? JSONSerialization.jsonObject(with: data) {
                    print("📊 응답 JSON 구조: \(json)")
                }
            }
            
            let processedData = try middleware.handleResponse(data: data, response: response)
            return try JSONDecoder().decode(T.self, from: processedData)
        } catch let error as NetworkError {
            print("⚠️ 네트워크 에러: \(error.errorMessage)")
            print("⚠️ 원본 에러: \(error)")
            
            if case .invalidCredentials = error {
                print("🔑 인증 실패: 카카오 계정이 SLP 서버에 등록되어 있지 않을 수 있습니다")
            }
            
            // 401 또는 419 에러 시 토큰 갱신 시도
            if case .accessTokenExpired = error {
                return try await handleTokenRefresh(router: router, type: type)
            }
            if case .invalidAccessToken = error {
                print("🔄 401 에러 발생, 토큰 갱신 시도")
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
        guard !isRefreshing else {
            return try await withCheckedThrowingContinuation { continuation in
                do {
                    let request = try router.asURLRequest()
                    requestsToRetry.append((request, { result in
                        switch result {
                        case .success(let data):
                            do {
                                let decoded = try JSONDecoder().decode(T.self, from: data)
                                continuation.resume(returning: decoded)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        guard let refreshToken = tokenManager.refreshToken else {
            print("🔍 리프레시 토큰 없음, 로그아웃 처리")
            await MainActor.run {
                authState.logout()
                authState.showLoginModal = true
            }
            throw NetworkError.refreshTokenExpired
        }
        
        print("🔄 리프레시 토큰으로 갱신 시도: \(refreshToken)")
        let refreshRouter = AuthRouter.refreshToken(refreshToken: refreshToken)
        
        do {
            let tokenResponse = try await request(refreshRouter, type: TokenResponse.self)
            
            print("✅ 새 토큰 발급 성공: \(tokenResponse.accessToken)")
            tokenManager.saveTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken
            )
            
            await MainActor.run {
                authState.startTokenRefreshTimer()
            }
            
            let retryRequests = requestsToRetry
            requestsToRetry.removeAll()
            
            for (request, completion) in retryRequests {
                do {
                    let (data, response) = try await session.data(for: request)
                    let processedData = try middleware.handleResponse(data: data, response: response)
                    completion(.success(processedData))
                } catch {
                    completion(.failure(error))
                }
            }
            
            return try await request(router, type: type)
        } catch let error as NetworkError {
            if error == .refreshTokenExpired || error == .refreshTokenInvalid || error == .forbidden {
                print("🚫 리프레시 토큰 문제, 로그아웃 처리")
                await MainActor.run {
                    authState.logout()
                    authState.showLoginModal = true
                }
            } else {
                print("🔄 토큰 갱신 중 네트워크 에러: \(error.errorMessage)")
            }
            
            let retryRequests = requestsToRetry
            requestsToRetry.removeAll()
            
            for (_, completion) in retryRequests {
                completion(.failure(error))
            }
            
            throw error
        } catch {
            print("⚠️ 토큰 갱신 중 알 수 없는 에러: \(error)")
            
            let retryRequests = requestsToRetry
            requestsToRetry.removeAll()
            
            for (_, completion) in retryRequests {
                completion(.failure(error))
            }
            
            throw error
        }
    }
    
    func uploadImage(_ router: APIRouter, imageData: Data, fieldName: String) async throws -> Data {
        var urlRequest = try router.asURLRequest()
        middleware.prepare(request: &urlRequest, authorizationType: router.authorizationType)
        
        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: APIConstants.Header.contentType)
        
        var body = Data()
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body
        
        print("🌐 이미지 업로드 요청: \(urlRequest.url?.absoluteString ?? "")")
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            print("📨 API 응답: \(response)")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔢 상태 코드: \(httpResponse.statusCode)")
            }
            
            return try middleware.handleResponse(data: data, response: response)
        } catch let error as NetworkError {
            print("⚠️ 이미지 업로드 에러: \(error)")
            if case .accessTokenExpired = error {
                let _ = try await handleTokenRefresh(router: router, type: Data.self)
                return try await uploadImage(router, imageData: imageData, fieldName: fieldName)
            }
            if case .invalidAccessToken = error {
                print("🔄 401 에러 발생, 토큰 갱신 시도 (이미지 업로드)")
                let _ = try await handleTokenRefresh(router: router, type: Data.self)
                return try await uploadImage(router, imageData: imageData, fieldName: fieldName)
            }
            throw error
        } catch {
            print("⚠️ 이미지 업로드 알 수 없는 에러: \(error)")
            throw error
        }
    }
}

struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}
