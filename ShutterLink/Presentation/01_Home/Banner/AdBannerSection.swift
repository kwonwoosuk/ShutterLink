//
//  AdBannerSection.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import SwiftUI

// 배너 섹션
struct AdBannerSection: View {
    @State private var currentIndex = 0
    @State private var showWebView = false
    @State private var selectedWebURL: URL?
    @State private var autoScrollTimer: Timer?
    
    let banners: [BannerItem]
    
    init(banners: [BannerItem]) {
        self.banners = banners
        print("🔵 AdBannerSection: 초기화됨 - 배너 개수: \(banners.count)")
        for (index, banner) in banners.enumerated() {
            print("   [\(index)] \(banner.title) - \(banner.subtitle ?? "subtitle 없음")")
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if !banners.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                        Button {
                            handleBannerTap(banner: banner)
                        } label: {
                            BannerCard(banner: banner)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 100)
                .padding(.horizontal, 20)
                .gesture(
                    DragGesture()
                        .onEnded { _ in
                            print("👆 AdBannerSection: 사용자 스와이프 감지")
                            restartAutoScrollAfterDelay()
                        }
                )
                
                BannerPageIndicator(
                    currentIndex: currentIndex,
                    totalCount: banners.count
                )
            } else {
                EmptyBannerView()
            }
        }
        .sheet(isPresented: $showWebView) {
            if let url = selectedWebURL {
                BridgeWebViewSheet(
                    url: url,
                    isPresented: $showWebView,
                    onDismiss: {
                        showWebView = false
                        selectedWebURL = nil
                        startAutoScroll()
                    }
                )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("⏰ AdBannerSection: onAppear 지연 후 자동 스크롤 시작")
                self.startAutoScroll()
            }
        }
        .onDisappear {
            stopAutoScroll()
        }
        .onChange(of: banners) { newBanners in
            print("🔄 AdBannerSection: 배너 데이터 변경됨 - \(newBanners.count)개")
            stopAutoScroll()
            if !newBanners.isEmpty {
                currentIndex = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("⏰ AdBannerSection: 지연 후 자동 스크롤 시작 - 배너 개수: \(newBanners.count)")
                    self.startAutoScroll()
                }
            }
        }
    }
    
    
    private func startAutoScroll() {
        let currentBannerCount = banners.count
        guard currentBannerCount > 1 else {
            print("🔄 AdBannerSection: 배너가 \(currentBannerCount)개여서 자동 스크롤 비활성화")
            return
        }
        
        stopAutoScroll()
        
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.7)) {
                currentIndex = (currentIndex + 1) % currentBannerCount
            }
        }
    }
    
    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
    
    private func restartAutoScrollAfterDelay() {
        stopAutoScroll()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            startAutoScroll()
        }
        
        print("⏰ AdBannerSection: 3초 후 자동 스크롤 재시작 예약")
    }
    
    private func handleBannerTap(banner: BannerItem) {
        print("🔵 AdBannerSection: 배너 탭됨 - \(banner.title)")
        print("🔵 Payload Type: \(banner.payload.type), Value: \(banner.payload.value)")
        
        stopAutoScroll()
        
        // payload type에 따른 처리
        switch banner.payload.type.uppercased() {
        case "WEBVIEW":
            openWebView(urlString: banner.payload.value)
        default:
            print("⚠️ AdBannerSection: 지원하지 않는 payload type - \(banner.payload.type)")
            startAutoScroll()
        }
    }
    
    private func openWebView(urlString: String) {
        guard !urlString.isEmpty else {
            print("❌ AdBannerSection: URL이 비어있습니다")
            startAutoScroll()
            return
        }
        
        let finalURL: URL?
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            finalURL = URL(string: urlString)
        } else {
            let baseURL = APIConstants.baseURL
            finalURL = URL(string: "\(baseURL)\(urlString)")
            print("🔍 AdBannerSection: 생성된 URL - \(baseURL)\(urlString)")
        }
        
        guard let url = finalURL else {
            print("❌ AdBannerSection: 유효하지 않은 URL - \(urlString)")
            startAutoScroll()
            return
        }
        
        print("🌐 AdBannerSection: 웹뷰 열기 - \(url.absoluteString)")
        selectedWebURL = url
        showWebView = true
    }
}

struct EmptyBannerView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 80)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.gray)
                    
                    Text("배너를 불러오는 중...")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            )
            .padding(.horizontal, 20)
    }
}
