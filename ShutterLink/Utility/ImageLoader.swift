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
    
    // 성능 최적화를 위한 추가 설정
    private let imageQueue = DispatchQueue(label: "com.shutterlink.imageLoader", qos: .utility)
    private var activeTasks: [String: Task<Data, Error>] = [:]
    private let taskLock = NSLock()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,   // 50MB 메모리 캐시
            diskCapacity: 200 * 1024 * 1024,    // 200MB 디스크 캐시
            diskPath: "shutterlink_images"
        )
        // 동시 연결 수 제한으로 성능 향상
        config.httpMaximumConnectionsPerHost = 4
        self.session = URLSession(configuration: config)
        
        // 캐시 설정 최적화
        cache.countLimit = 200          // 최대 200개 이미지
        cache.totalCostLimit = 100 * 1024 * 1024  // 100MB
    }
    
    func loadImage(from imagePath: String) async throws -> Data {
        // 중복 요청 방지
        taskLock.lock()
        if let existingTask = activeTasks[imagePath] {
            taskLock.unlock()
            return try await existingTask.value
        }
        
        // 새 태스크 생성
        let task = Task<Data, Error> {
            defer {
                taskLock.lock()
                activeTasks.removeValue(forKey: imagePath)
                taskLock.unlock()
            }
            
            return try await loadImageInternal(from: imagePath)
        }
        
        activeTasks[imagePath] = task
        taskLock.unlock()
        
        return try await task.value
    }
    
    private func loadImageInternal(from imagePath: String) async throws -> Data {
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
        request.timeoutInterval = 10.0  // 타임아웃 단축
        
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
        
        // 캐시에 저장 (비용을 파일 크기로 설정)
        cache.setObject(NSData(data: data), forKey: cacheKey, cost: data.count)
        
        return data
    }
    
    // 메모리 압박 시 캐시 정리
    func clearCache() {
        cache.removeAllObjects()
    }
    
    // 특정 이미지 캐시 제거
    func removeFromCache(imagePath: String) {
        let cacheKey = NSString(string: imagePath)
        cache.removeObject(forKey: cacheKey)
    }
    
    deinit {
        taskLock.lock()
        activeTasks.values.forEach { $0.cancel() }
        activeTasks.removeAll()
        taskLock.unlock()
    }
}
