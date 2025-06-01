//
//  ImageLoader.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import Foundation
import UIKit

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
        cache.totalCostLimit = 50 * 1024 * 1024 
    }
    
    func loadImage(from imagePath: String, targetSize: CGSize? = nil) async throws -> Data {
        // 캐시 키에 크기 정보 포함
        let cacheKey = NSString(string: imagePath + (targetSize != nil ? "_\(Int(targetSize!.width))x\(Int(targetSize!.height))" : ""))
        
        // 캐시 확인
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
                let maxDimension = max(targetSize.width, targetSize.height)
                let imageMaxDimension = max(pixelWidth, pixelHeight)
                
                if imageMaxDimension <= maxDimension {
                    // 다운샘플링 불필요
                    continuation.resume(returning: data)
                    return
                }
                
                // 다운샘플링 옵션 설정
                let downsampleOptions: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxDimension
                ]
                
                guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
                    continuation.resume(returning: data)
                    return
                }
                
                // UIImage로 변환 후 JPEG 데이터로 변환
                let uiImage = UIImage(cgImage: downsampledImage)
                guard let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
                    continuation.resume(returning: data)
                    return
                }
                
                continuation.resume(returning: jpegData)
            }
        }
    }
}
