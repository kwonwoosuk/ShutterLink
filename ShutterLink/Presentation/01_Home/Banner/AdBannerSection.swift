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
                    // 사용자가 직접 스와이프할 때 자동 스크롤 일시정지 후 재시작
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
                // 배너가 없을 때 표시할 기본 뷰
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
                        // 웹뷰가 닫힐 때 자동 스크롤 재시작
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
            // 배너 데이터가 변경되면 자동 스크롤 재시작
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
    
    // MARK: - 자동 스크롤 기능
    
    private func startAutoScroll() {
        let currentBannerCount = banners.count
        print("🎠 AdBannerSection: startAutoScroll 호출됨")
        print("   - 현재 banners.count: \(currentBannerCount)")
        print("   - 배너 배열: \(banners.map { $0.name })")
        
        guard currentBannerCount > 1 else {
            print("🔄 AdBannerSection: 배너가 \(currentBannerCount)개여서 자동 스크롤 비활성화")
            return
        }
        
        stopAutoScroll()
        
        print("🎠 AdBannerSection: 자동 스크롤 시작 - 2초 간격, \(currentBannerCount)개 배너")
        
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.7)) {
                currentIndex = (currentIndex + 1) % currentBannerCount
            }
            print("🎠 AdBannerSection: 자동 스크롤 - 현재 인덱스: \(currentIndex)/\(currentBannerCount-1)")
        }
    }
    
    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        print("🛑 AdBannerSection: 자동 스크롤 중지")
    }
    
    private func restartAutoScrollAfterDelay() {
        stopAutoScroll()
        
        // 3초 후 자동 스크롤 재시작 (사용자 조작 후 약간의 여유 시간)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            startAutoScroll()
        }
        
        print("⏰ AdBannerSection: 3초 후 자동 스크롤 재시작 예약")
    }
    
    private func handleBannerTap(banner: BannerItem) {
        print("🔵 AdBannerSection: 배너 탭됨 - \(banner.title)")
        print("🔵 Payload Type: \(banner.payload.type), Value: \(banner.payload.value)")
        
        // 배너 탭 시 자동 스크롤 잠시 중지
        stopAutoScroll()
        
        // payload type에 따른 처리
        switch banner.payload.type.uppercased() {
        case "WEBVIEW":
            openWebView(urlString: banner.payload.value)
        default:
            print("⚠️ AdBannerSection: 지원하지 않는 payload type - \(banner.payload.type)")
            // 지원하지 않는 타입인 경우 자동 스크롤 재시작
            startAutoScroll()
        }
    }
    
    private func openWebView(urlString: String) {
        guard !urlString.isEmpty else {
            print("❌ AdBannerSection: URL이 비어있습니다")
            startAutoScroll() // 실패 시 자동 스크롤 재시작
            return
        }
        
        let finalURL: URL?
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            finalURL = URL(string: urlString)
        } else {
            let baseURL = APIConstants.baseURL
            finalURL = URL(string: "\(baseURL)\(urlString)")  // 포트 중복 추가 제거
            print("🔍 AdBannerSection: 생성된 URL - \(baseURL)\(urlString)")
        }
        
        guard let url = finalURL else {
            print("❌ AdBannerSection: 유효하지 않은 URL - \(urlString)")
            startAutoScroll() // 실패 시 자동 스크롤 재시작
            return
        }
        
        print("🌐 AdBannerSection: 웹뷰 열기 - \(url.absoluteString)")
        selectedWebURL = url
        showWebView = true
        // 웹뷰가 열리면 자동 스크롤은 중지된 상태로 유지 (onDismiss에서 재시작)
    }
}

// MARK: - 빈 배너 뷰
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
