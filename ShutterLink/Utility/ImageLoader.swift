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
    private var cache = NSCache<NSString, NSData>()
    
    // 동시 요청 제한을 위한 세마포어
    private let requestSemaphore = DispatchSemaphore(value: 6) // 최대 6개 동시 요청
    
    private init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15.0 // 15초 타임아웃
        config.timeoutIntervalForResource = 30.0 // 30초 리소스 타임아웃
        self.session = URLSession(configuration: config)
        
        // 캐시 설정
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 
    }
    
    func loadImage(from imagePath: String, targetSize: CGSize? = nil) async throws -> Data {
        // 빈 경로 체크
        guard !imagePath.isEmpty else {
            throw URLError(.badURL)
        }
        
        // 캐시 키에 크기 정보 포함
        let cacheKey = NSString(string: imagePath + (targetSize != nil ? "_\(Int(targetSize!.width))x\(Int(targetSize!.height))" : ""))
        
        // 캐시 확인
        if let cachedData = cache.object(forKey: cacheKey) {
            print("✅ 이미지 캐시 히트: \(imagePath)")
            return cachedData as Data
        }
        
        // 동시 요청 제한
        await requestSemaphore.waitAsync()
        defer { requestSemaphore.signal() }
        
        // 재시도 로직 (최대 3회) - 단순화
        var lastError: Error?
        for attempt in 1...3 {
            do {
                print("🔄 이미지 로딩 시도 \(attempt)/3: \(imagePath)")
                let data = try await performImageRequest(imagePath: imagePath, targetSize: targetSize, cacheKey: cacheKey)
                print("✅ 이미지 로딩 성공: \(imagePath)")
                return data
            } catch {
                lastError = error
                print("❌ 이미지 로딩 실패 \(attempt)/3: \(error)")
                
                // 마지막 시도가 아니면 잠시 대기 후 재시도
                if attempt < 3 {
                    // 간단한 백오프: 0.5초, 1초
                    let delay = Double(attempt) * 0.5
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? URLError(.unknown)
    }
    
    private func performImageRequest(imagePath: String, targetSize: CGSize?, cacheKey: NSString) async throws -> Data {
        // URL 구성
        let fullURL = imagePath.fullImageURL
        guard let url = URL(string: fullURL) else {
            throw URLError(.badURL)
        }
        
        // 요청 구성
        var request = URLRequest(url: url)
        
        // 헤더 추가 (미들웨어와 동일한 방식)
        if let accessToken = tokenManager.accessToken {
            request.setValue(accessToken, forHTTPHeaderField: APIConstants.Header.authorization)
        }
        request.setValue(Key.ShutterLink.apiKey.rawValue, forHTTPHeaderField: APIConstants.Header.sesacKey)
        
        // 네트워크 요청 (URLSession 직접 사용 - 이미지는 raw data)
        let (data, response) = try await session.data(for: request)
        
        // 응답 확인 (미들웨어의 검증 로직은 건너뛰고 기본적인 것만)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // 200-299 범위가 아니면 에러 (미들웨어에서 처리할 수 없으므로 기본 검증만)
        guard 200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        
        // 다운샘플링 처리
        let processedData: Data
        if let targetSize = targetSize {
            processedData = try await downsampleImage(data: data, to: targetSize)
        } else {
            processedData = data
        }
        
        // 캐시에 저장
        cache.setObject(NSData(data: processedData), forKey: cacheKey)
        
        return processedData
    }
    
    // MARK: - 다운샘플링 로직
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
    
    // MARK: - 캐시 관리
    func clearCache() {
        cache.removeAllObjects()
        print("🗑️ 이미지 캐시 클리어")
    }
    
    func getCacheSize() -> Int {
        return cache.totalCostLimit
    }
}

// MARK: - DispatchSemaphore async 지원
extension DispatchSemaphore {
    func waitAsync() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.wait()
                continuation.resume()
            }
        }
    }
}
