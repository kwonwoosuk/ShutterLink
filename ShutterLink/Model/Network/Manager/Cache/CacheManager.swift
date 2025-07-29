//
//  CacheManager.swift
//  ShutterLink
//
//  Created by 권우석 on 7/30/25.
//

import Foundation
import UIKit

final class CacheManager: ObservableObject {
    static let shared = CacheManager()
    
    @Published var memoryCacheSize: Int64 = 0
    @Published var diskCacheSize: Int64 = 0
    
    private let imageLoader = ImageLoader.shared
    
    private init() {
        updateCacheSizes()
    }
    
    // MARK: - 캐시 크기 계산
    func updateCacheSizes() {
        calculateMemoryCacheSize()
        calculateDiskCacheSize()
    }
    
    private func calculateMemoryCacheSize() {
        // ImageLoader의 실제 메모리 캐시 크기 가져오기
        let cacheStats = imageLoader.getCacheStatistics()
        memoryCacheSize = Int64(cacheStats.memorySize)
    }
    
    private func calculateDiskCacheSize() {
        // ImageLoader의 실제 디스크 캐시 크기 가져오기
        let cacheStats = imageLoader.getCacheStatistics()
        diskCacheSize = Int64(cacheStats.diskSize)
    }
    
    // MARK: - 캐시 정리
    func clearMemoryCache() {
        imageLoader.clearMemoryCache()
        memoryCacheSize = 0
        print("🗑️ CacheManager: 메모리 캐시 정리 완료")
    }
    
    func clearDiskCache() {
        imageLoader.clearDiskCache()
        diskCacheSize = 0
        print("🗑️ CacheManager: 디스크 캐시 정리 완료")
    }
    
    func clearAllCache() {
        imageLoader.clearCache()
        memoryCacheSize = 0
        diskCacheSize = 0
        print("🗑️ CacheManager: 전체 캐시 정리 완료")
    }
    
    // MARK: - 캐시 사용률 계산
    func getMemoryCacheUsagePercentage() -> Double {
        let maxSize = getMaxMemoryCacheSize()
        guard maxSize > 0 else { return 0 }
        return Double(memoryCacheSize) / Double(maxSize) * 100
    }
    
    func getDiskCacheUsagePercentage() -> Double {
        let maxSize = getMaxDiskCacheSize()
        guard maxSize > 0 else { return 0 }
        return Double(diskCacheSize) / Double(maxSize) * 100
    }
    
    // MARK: - 크기 포맷팅
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - ImageLoader에서 실제 한도 가져오기
    func getMaxDiskCacheSize() -> Int64 {
        return Int64(imageLoader.getDiskCacheLimit())
    }
    
    func getMaxMemoryCacheSize() -> Int64 {
        return Int64(imageLoader.getMemoryCacheLimit())
    }
}
