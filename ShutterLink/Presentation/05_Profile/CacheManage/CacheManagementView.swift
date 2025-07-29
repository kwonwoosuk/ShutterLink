//
//  CacheManagementView.swift
//  ShutterLink
//
//  Created by 권우석 on 7/30/25.
//

import SwiftUI

struct CacheManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cacheManager = CacheManager.shared
    @State private var showClearAlert = false
    @State private var clearType: ClearType = .all
    
    enum ClearType {
        case memory, disk, all
        
        var title: String {
            switch self {
            case .memory: return "메모리 캐시"
            case .disk: return "디스크 캐시"
            case .all: return "전체 캐시"
            }
        }
        
        var message: String {
            switch self {
            case .memory: return "메모리 캐시를 정리하시겠습니까?"
            case .disk: return "디스크 캐시를 정리하시겠습니까?"
            case .all: return "모든 캐시를 정리하시겠습니까?"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                cacheOverviewSection
                memoryCacheSection
                diskCacheSection
                clearAllSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            cacheManager.updateCacheSizes()
        }
        .alert("캐시 정리", isPresented: $showClearAlert) {
            alertButtons
        } message: {
            Text(clearType.message)
        }
    }
}

// MARK: - View Components

extension CacheManagementView {
    
    @ViewBuilder
    private var cacheOverviewSection: some View {
        VStack(spacing: 16) {
            totalCacheUsageView
        }
    }
    
    @ViewBuilder
    private var totalCacheUsageView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("총 사용량")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.Gray.gray60)
                
                Spacer()
                
                let totalUsed = cacheManager.memoryCacheSize + cacheManager.diskCacheSize
                let totalMax = cacheManager.getMaxMemoryCacheSize() + cacheManager.getMaxDiskCacheSize()
                
                Text("\(cacheManager.formatBytes(totalUsed)) / \(cacheManager.formatBytes(totalMax))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            let totalUsage = Double(cacheManager.memoryCacheSize + cacheManager.diskCacheSize) / Double(cacheManager.getMaxMemoryCacheSize() + cacheManager.getMaxDiskCacheSize()) * 100
            
            ProgressView(value: totalUsage, total: 100)
                .progressViewStyle(CustomProgressStyle(
                    backgroundColor: DesignSystem.Colors.Gray.gray30,
                    foregroundColor: totalUsage > 80 ? .red : totalUsage > 60 ? .orange : DesignSystem.Colors.Brand.brightTurquoise
                ))
        }
        .padding(16)
        .background(Color.black)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var memoryCacheSection: some View {
        cacheSection(
            title: "메모리 캐시",
            subtitle: "앱 실행 중 임시로 저장된 이미지",
            currentSize: cacheManager.memoryCacheSize,
            maxSize: cacheManager.getMaxMemoryCacheSize(),
            usage: cacheManager.getMemoryCacheUsagePercentage(),
            clearAction: {
                clearType = .memory
                showClearAlert = true
            }
        )
    }
    
    @ViewBuilder
    private var diskCacheSection: some View {
        cacheSection(
            title: "디스크 캐시",
            subtitle: "기기에 저장된 이미지 캐시",
            currentSize: cacheManager.diskCacheSize,
            maxSize: cacheManager.getMaxDiskCacheSize(),
            usage: cacheManager.getDiskCacheUsagePercentage(),
            clearAction: {
                clearType = .disk
                showClearAlert = true
            }
        )
    }
    
    @ViewBuilder
    private var clearAllSection: some View {
        VStack(spacing: 16) {
            Button {
                clearType = .all
                showClearAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                    
                    Text("전체 캐시 정리")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.8))
                .cornerRadius(10)
            }
            
            Text("캐시를 정리하면 이미지 로딩 시간이 증가할 수 있습니다.")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.Gray.gray45)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func cacheSection(
        title: String,
        subtitle: String,
        currentSize: Int64,
        maxSize: Int64,
        usage: Double,
        clearAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.Gray.gray45)
                }
                
                Spacer()
                
                Button("정리", action: clearAction)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(DesignSystem.Colors.Brand.brightTurquoise.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("사용량")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.Gray.gray60)
                    
                    Spacer()
                    
                    Text("\(cacheManager.formatBytes(currentSize)) / \(cacheManager.formatBytes(maxSize))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                
                ProgressView(value: usage, total: 100)
                    .progressViewStyle(CustomProgressStyle(
                        backgroundColor: DesignSystem.Colors.Gray.gray30,
                        foregroundColor: usage > 80 ? .red : usage > 60 ? .orange : DesignSystem.Colors.Brand.brightTurquoise
                    ))
                
                HStack {
                    Text("\(String(format: "%.1f", usage))% 사용 중")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.Gray.gray45)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color.black)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Toolbar & Alert

extension CacheManagementView {
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        
        ToolbarItem(placement: .principal) {
            Text("디스크 캐시 관리")
                .font(.hakgyoansim(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    @ViewBuilder
    private var alertButtons: some View {
        Button("취소", role: .cancel) { }
        
        Button("정리", role: .destructive) {
            performCacheClear()
        }
    }
    
    private func performCacheClear() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch clearType {
            case .memory:
                cacheManager.clearMemoryCache()
            case .disk:
                cacheManager.clearDiskCache()
            case .all:
                cacheManager.clearAllCache()
            }
        }
        
        // 잠시 후 캐시 크기 업데이트
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            cacheManager.updateCacheSizes()
        }
    }
}

// MARK: - Custom Progress Style

struct CustomProgressStyle: ProgressViewStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(backgroundColor)
                .frame(height: 8)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(foregroundColor)
                .frame(width: CGFloat(configuration.fractionCompleted ?? 0) * UIScreen.main.bounds.width * 0.8, height: 8)
        }
    }
}
