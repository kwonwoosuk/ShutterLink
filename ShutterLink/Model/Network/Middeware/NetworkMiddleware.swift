//
//  NetworkMiddleware.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation

class NetworkMiddleware {
    private let tokenManager: TokenManager
    
    init(tokenManager: TokenManager = TokenManager.shared) {
        self.tokenManager = tokenManager
    }
    
    func prepare(request: inout URLRequest, authorizationType: AuthorizationType) {
        switch authorizationType {
        case .none:
            break
            
        case .sesacKey:
            request.setValue(Key.ShutterLink.apiKey.rawValue, forHTTPHeaderField: APIConstants.Header.sesacKey)
            
        case .accessToken:
            if let token = tokenManager.accessToken {
                request.setValue(token, forHTTPHeaderField: APIConstants.Header.authorization)
            }
            request.setValue(Key.ShutterLink.apiKey.rawValue, forHTTPHeaderField: APIConstants.Header.sesacKey)
            
        case .refreshToken:
            if let token = tokenManager.refreshToken {
                request.setValue(token, forHTTPHeaderField: APIConstants.Header.refreshToken)
                
                // 중요: 액세스 토큰도 함께 전송 (자격 증명 확인용)
                if let accessToken = tokenManager.accessToken {
                    request.setValue(accessToken, forHTTPHeaderField: APIConstants.Header.authorization)
                }
            }
            request.setValue(Key.ShutterLink.apiKey.rawValue, forHTTPHeaderField: APIConstants.Header.sesacKey)
            
        case .both:
            if let token = tokenManager.accessToken {
                request.setValue(token, forHTTPHeaderField: APIConstants.Header.authorization)
            }
            request.setValue(Key.ShutterLink.apiKey.rawValue, forHTTPHeaderField: APIConstants.Header.sesacKey)
        }
    }
    
    func handleResponse(data: Data?, response: URLResponse?) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard let data = data else {
            throw NetworkError.emptyData
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 400:
            throw NetworkError.missingRequiredFields
        case 401:
            if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                if error.message.contains("계정") {
                    throw NetworkError.invalidCredentials
                } else {
                    throw NetworkError.invalidAccessToken
                }
            }
            throw NetworkError.invalidAccessToken
        case 403:
                // 리프레시 토큰 요청인지 확인
                if let url = (response as? HTTPURLResponse)?.url?.absoluteString,
                   url.contains("/auth/refresh") {
                    // 리프레시 토큰에 문제가 있는 경우 (user_id 조회 불가)
                    throw NetworkError.refreshTokenExpired
                } else {
                    throw NetworkError.forbidden
                }
        case 409:
            throw NetworkError.emailAlreadyExists
        case 418:
            throw NetworkError.refreshTokenExpired
        case 419:
            throw NetworkError.accessTokenExpired
        case 420:
            throw NetworkError.invalidSesacKey
        case 429:
            throw NetworkError.tooManyRequests
        case 444:
            throw NetworkError.invalidAPICall
        case 500...599:
            throw NetworkError.serverError
        default:
            throw NetworkError.invalidStatusCode(httpResponse.statusCode)
        }
    }
}

struct ErrorResponse: Decodable {
    let message: String
}
