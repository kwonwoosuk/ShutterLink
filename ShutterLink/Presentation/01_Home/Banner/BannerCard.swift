//
//  BannerCard.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import SwiftUI

struct BannerCard: View {
    let banner: BannerMockData
    
    var body: some View {
        ZStack {
            // 배경 그라데이션
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            banner.imageColor,
                            banner.imageColor.opacity(0.7)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: banner.imageColor.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // 텍스트 콘텐츠
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(banner.subtitle)
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(banner.title)
                        .font(.pretendard(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                
                Spacer()
                
                
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(height: 80) // 100에서 80으로 줄임
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

struct BannerMockData: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let imageColor: Color
}
