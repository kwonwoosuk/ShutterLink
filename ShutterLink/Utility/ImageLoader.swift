//
//  ImageLoader.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import Foundation
import UIKit

class ImageProcessor {
    
    /// 이미지 데이터를 지정된 크기로 다운샘플링
    static func downsample(imageData: Data, to targetSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let maxDimensionInPixels = max(targetSize.width, targetSize.height) * scale
        
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        
        // 다운샘플링 옵션 설정
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            
            return UIImage(data: imageData)
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    /// 메모리에서 이미지 압축 해제
    static func decompressImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return image
        }
        
        let rect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        context.draw(cgImage, in: rect)
        
        guard let decompressedImage = context.makeImage() else {
            return image
        }
        
        return UIImage(cgImage: decompressedImage)
    }
}


class ImageLoader {
    static let shared = ImageLoader()
    
    private let session: URLSession
    private let tokenManager = TokenManager.shared
    private var cache = NSCache<NSString, NSData>()
    private let imageLoadQueue = DispatchQueue(label: "com.shutterlink.imageload", qos: .utility, attributes: .concurrent)
    
    // 동시 다운로드 제한
    private let concurrentDownloadLimit = 3
    private let downloadSemaphore: DispatchSemaphore
    
    private init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
        self.session = URLSession(configuration: config)
        
        // 메모리 캐시 설정 (더 보수적으로)
        cache.countLimit = 50 // 50개 이미지만 캐시
        cache.totalCostLimit = 20 * 1024 * 1024 // 20MB로 줄임
        
        downloadSemaphore = DispatchSemaphore(value: concurrentDownloadLimit)
        
        // 메모리 경고 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // 앱 백그라운드 진입 시 캐시 정리
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cleanupCache),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadImage(from imagePath: String) async throws -> Data {
        // 동시 다운로드 제한
        downloadSemaphore.wait()
        defer { downloadSemaphore.signal() }
        
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
        request.cachePolicy = .returnCacheDataElseLoad
        
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
        
        // 캐시에 저장 (백그라운드에서)
        Task.detached(priority: .utility) { [weak self] in
            self?.cache.setObject(NSData(data: data), forKey: cacheKey, cost: data.count)
        }
        
        return data
    }
    
    @objc private func handleMemoryWarning() {
        print("🚨 메모리 경고 - 이미지 캐시 정리")
        cache.removeAllObjects()
        
        // URL 캐시도 정리
        session.configuration.urlCache?.removeAllCachedResponses()
    }
    
    @objc private func cleanupCache() {
        print("🧹 백그라운드 진입 - 캐시 정리")
        
        // 캐시 크기를 절반으로 줄임
        let currentCount = cache.countLimit
        let currentCost = cache.totalCostLimit
        
        cache.countLimit = currentCount / 2
        cache.totalCostLimit = currentCost / 2
        
        // 일정 시간 후 원래 크기로 복원
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.cache.countLimit = currentCount
            self?.cache.totalCostLimit = currentCost
        }
    }
    
    /// 수동 캐시 정리
    func clearCache() {
        cache.removeAllObjects()
        session.configuration.urlCache?.removeAllCachedResponses()
    }
    
    /// 특정 이미지 캐시 제거
    func removeFromCache(imagePath: String) {
        let cacheKey = NSString(string: imagePath)
        cache.removeObject(forKey: cacheKey)
    }
}
