//
//  NetworkRouter.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation

protocol APIRouter {
    var path: String { get }
    var method: HTTPMethod { get }
    var contentType: String { get }
    var body: Data? { get }
    var queryItems: [URLQueryItem]? { get }
    var authorizationType: AuthorizationType { get }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum AuthorizationType {
    case none
    case sesacKey
    case accessToken
    case refreshToken
    case both 
}

extension APIRouter {
    var baseURL: URL? {
        return URL(string: APIConstants.baseURL)
    }
    
    var contentType: String {
        return APIConstants.ContentType.json
    }
    
    var queryItems: [URLQueryItem]? {
        return nil
    }
    
    func asURLRequest() throws -> URLRequest {
        guard let baseURL = baseURL else {
            throw NetworkError.invalidURL
        }
        
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(contentType, forHTTPHeaderField: APIConstants.Header.contentType)
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
}
