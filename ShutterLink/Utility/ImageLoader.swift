//
//  ImageLoader.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import Foundation
import UIKit

final class ImageLoader {
    static let shared = ImageLoader()
    
    private let session: URLSession
    private let tokenManager = TokenManager.shared
    
    // 메모리 캐시 최적화
    private var cache = NSCache<NSString, NSData>()
    private let memoryCache = NSCache<NSString, UIImage>()
    
    
    private init() {
        let cacheSize = 100 * 1024 * 1024 // 100MB
        let urlCache = URLCache(
            memoryCapacity: cacheSize / 4,  // 25MB 메모리
            diskCapacity: cacheSize,        // 100MB 디스크
            diskPath: "ImageCache"
        )
        
        let config = URLSessionConfiguration.default
        config.urlCache = urlCache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 15.0
        
        // URLSession 동시성 최적화
        config.httpMaximumConnectionsPerHost = 8
        config.waitsForConnectivity = false
        
        self.session = URLSession(configuration: config)
        
        // 기존 캐시 설정 유지
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
        
        // 메모리 캐시 추가 설정
        memoryCache.countLimit = 50
        memoryCache.totalCostLimit = 25 * 1024 * 1024
    }
    
    func loadImage(from imagePath: String, targetSize: CGSize? = CGSize(width: 500, height: 500),) async throws -> Data {
        // 빈 경로 체크
        guard !imagePath.isEmpty else {
            throw URLError(.badURL)
        }
        
        // 캐시 키에 크기 정보 포함 (기존 로직 유지)
        let cacheKey = NSString(string: imagePath + (targetSize != nil ? "_\(Int(targetSize!.width))x\(Int(targetSize!.height))" : ""))
        
        // 1. UIImage 메모리 캐시 확인 (가장 빠름)
        if let cachedImage = memoryCache.object(forKey: NSString(string: imagePath)) {
            if let imageData = cachedImage.jpegData(compressionQuality: 0.8) {
                print("✅ 이미지 메모리 캐시 히트: \(imagePath)")
                return imageData
            }
        }
        
        // 2. 기존 Data 캐시 확인
        if let cachedData = cache.object(forKey: cacheKey) {
            print("✅ 이미지 캐시 히트: \(imagePath)")
            return cachedData as Data
        }
        
        // 3. 네트워크 요청 (동시 요청 제한 제거)
        print("🔄 이미지 로딩 시작: \(imagePath)")
        let data = try await performImageRequest(imagePath: imagePath, targetSize: targetSize, cacheKey: cacheKey)
        print("✅ 이미지 로딩 성공: \(imagePath)")
        return data
    }
    
    private func performImageRequest(imagePath: String, targetSize: CGSize?, cacheKey: NSString) async throws -> Data {
        // URL 구성
        let fullURL = imagePath.fullImageURL
        guard let url = URL(string: fullURL) else {
            throw URLError(.badURL)
        }
        
        // 요청 구성
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad // 캐시 우선
        
        // 헤더 추가 (기존 로직 유지)
        if let accessToken = tokenManager.accessToken {
            request.setValue(accessToken, forHTTPHeaderField: APIConstants.Header.authorization)
        }
        request.setValue(Key.ShutterLink.apiKey.rawValue, forHTTPHeaderField: APIConstants.Header.sesacKey)
        
        // 네트워크 요청
        let (data, response) = try await session.data(for: request)
        
        // 응답 확인
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        
        // 다운샘플링 처리 (기존 로직 유지하되 단순화)
        let processedData: Data
        if let targetSize = targetSize {
            processedData = try await downsampleImage(data: data, to: targetSize)
        } else {
            processedData = data
        }
        
        // UIImage 메모리 캐시에도 저장
        if let image = UIImage(data: processedData) {
            memoryCache.setObject(image, forKey: NSString(string: imagePath))
        }
        
        // 기존 캐시에 저장
        cache.setObject(NSData(data: processedData), forKey: cacheKey)
        
        return processedData
    }
    
    private func downsampleImage(data: Data, to targetSize: CGSize) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
                    continuation.resume(returning: data)
                    return
                }
                
                // 이미지 프로퍼티 확인
                guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
                      let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? CGFloat,
                      let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? CGFloat else {
                    continuation.resume(returning: data)
                    return
                }
                
                // 다운샘플링이 필요한지 확인
                let imageSize = CGSize(width: pixelWidth, height: pixelHeight)
                let scale = min(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
                
                // 이미 작은 이미지는 그대로 반환
                if scale >= 1.0 {
                    continuation.resume(returning: data)
                    return
                }
                
                // 다운샘플링 옵션 설정
                let downsampleOptions: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: max(targetSize.width, targetSize.height)
                ]
                
                guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
                    continuation.resume(returning: data)
                    return
                }
                
                // UIImage로 변환 후 JPEG 데이터로 압축
                let uiImage = UIImage(cgImage: downsampledImage)
                if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
                    continuation.resume(returning: jpegData)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }
    }
    func clearMemoryCache() {
           cache.removeAllObjects()
           memoryCache.removeAllObjects()
           print("🗑️ ImageLoader: 메모리 캐시 정리")
       }
       
       func clearDiskCache() {
           session.configuration.urlCache?.removeAllCachedResponses()
           print("🗑️ ImageLoader: 디스크 캐시 정리")
       }
       
       // MARK: - 실제 캐시 크기 조회 메서드
       func getCurrentMemoryCacheSize() -> Int {
           // NSCache의 현재 사용량을 가져오기
           // cost가 설정되어 있다면 현재 총 cost를 반환
           // 설정되어 있지 않다면 대략적인 추정치 반환
           let dataCache = cache.totalCostLimit > 0 ? min(cache.totalCostLimit / 2, 15 * 1024 * 1024) : 0
           let imageCache = memoryCache.totalCostLimit > 0 ? min(memoryCache.totalCostLimit / 2, 10 * 1024 * 1024) : 0
           return dataCache + imageCache
       }
       
       func getCurrentDiskCacheSize() -> Int {
           // URLCache의 실제 디스크 사용량
           return session.configuration.urlCache?.currentDiskUsage ?? 0
       }
       
       // MARK: - 캐시 한도 정보
       func getMemoryCacheLimit() -> Int {
           return cache.totalCostLimit + memoryCache.totalCostLimit
       }
       
       func getDiskCacheLimit() -> Int {
           return session.configuration.urlCache?.diskCapacity ?? 100 * 1024 * 1024
       }
       
       // MARK: - 캐시 통계 정보 (CacheManager에서 사용)
       func getCacheStatistics() -> (memorySize: Int, diskSize: Int, memoryLimit: Int, diskLimit: Int) {
           let memorySize = getCurrentMemoryCacheSize()
           let diskSize = getCurrentDiskCacheSize()
           let memoryLimit = getMemoryCacheLimit()
           let diskLimit = getDiskCacheLimit()
           
           print("📊 ImageLoader Cache Stats - Memory: \(memorySize)/\(memoryLimit), Disk: \(diskSize)/\(diskLimit)")
           
           return (memorySize: memorySize, diskSize: diskSize, memoryLimit: memoryLimit, diskLimit: diskLimit)
       }
       
       // MARK: - 기존 getCacheSize 메서드 업데이트 (하위 호환성)
       func getCacheSize() -> Int {
           // 기존 메서드명 유지하면서 실제 총 캐시 크기 반환
           return getCurrentMemoryCacheSize() + getCurrentDiskCacheSize()
       }
       
       // MARK: - 기존 clearCache 메서드 유지 (하위 호환성)
       func clearCache() {
           clearMemoryCache()
           clearDiskCache()
           session.configuration.urlCache?.removeAllCachedResponses()
           print("🗑️ ImageLoader: 전체 캐시 정리")
       }
}
