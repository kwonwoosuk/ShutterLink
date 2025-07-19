//
//  BannerCard.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import SwiftUI

struct BannerCard: View {
    let banner: BannerItem
    
    var body: some View {
        ZStack {
            // 배경 이미지
            if !banner.imageUrl.isEmpty {
                AuthenticatedImageView(
                    imagePath: banner.imageUrl,
                    contentMode: .fill
                ) {
                    // 로딩 플레이스홀더
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue,
                                    Color.blue.opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue,
                                Color.blue.opacity(0.7)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
         
        }
     
    }
}

struct BannerPageIndicator: View {
    let currentIndex: Int
    let totalCount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(
                        width: index == currentIndex ? 20 : 8,
                        height: 4
                    )
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Mock 데이터 구조체 (기존 mock객체 호환성을 위해 유지)
struct BannerMockData: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let imageColor: Color
}
