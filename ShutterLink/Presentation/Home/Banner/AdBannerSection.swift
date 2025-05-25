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
    
    private let bannerData = [
        BannerMockData(id: 1, title: "새싹을 담은 필터", subtitle: "자연 시장", imageColor: .green),
        BannerMockData(id: 2, title: "도시의 감성", subtitle: "도시 필터", imageColor: .blue),
        BannerMockData(id: 3, title: "따뜻한 햇살", subtitle: "빈티지 필터", imageColor: .orange),
        BannerMockData(id: 4, title: "차가운 밤", subtitle: "블루 필터", imageColor: .indigo)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $currentIndex) {
                ForEach(Array(bannerData.enumerated()), id: \.element.id) { index, banner in
                    Button {
                        handleBannerTap(banner: banner)
                    } label: {
                        TabViewBannerCard(banner: banner)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 120)
            .padding(.horizontal, 20)
            
            BannerPageIndicator(
                currentIndex: currentIndex,
                totalCount: bannerData.count
            )
        }
    }
    
    private func handleBannerTap(banner: BannerMockData) {
        print("배너 탭됨: \(banner.title)")
        // 여기에 배너 탭 시 액션 구현
        // 상세 화면 표시
    }
}
