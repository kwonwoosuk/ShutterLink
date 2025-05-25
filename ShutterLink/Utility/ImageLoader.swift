//
//  ImageLoader.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import Foundation

class ImageLoader {
    static let shared = ImageLoader()
    
    private let session: URLSession
    private let tokenManager = TokenManager.shared
    private var cache = NSCache<NSString, NSData>()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
        
        // 캐시 설정
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func loadImage(from imagePath: String) async throws -> Data {
        // 캐시 확인
        let cacheKey = NSString(string: imagePath)
        if let cachedData = cache.object(forKey: cacheKey) {
            return cachedData as Data
        }
        
        // URL 구성
        let fullURL = imagePath.fullImageURL
        guard let url = URL(string: fullURL) else {
            throw URLError(.badURL)
        }
        
        // 요청 구성
        var request = URLRequest(url: url)
        
        // 헤더 추가
        if let accessToken = tokenManager.accessToken {
            request.setValue(accessToken, forHTTPHeaderField: APIConstants.Header.authorization)
        }
        request.setValue(Key.ShutterLink.apiKey.rawValue, forHTTPHeaderField: APIConstants.Header.sesacKey)
        
        // 네트워크 요청
        let (data, response) = try await session.data(for: request)
        
        // 응답 확인
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        
        // 캐시에 저장
        cache.setObject(NSData(data: data), forKey: cacheKey)
        
        return data
    }
}
