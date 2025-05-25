//
//  TopRankingCard.swift
//  ShutterLink
//
//  Created by 권우석 on 5/24/25.
//

import SwiftUI

struct VerticalOvalCard: View {
    let filter: FilterItem
    let rank: Int
    
    var body: some View {
        ZStack {
            // 세로로 긴 타원형 배경
            Capsule()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 260, height: 360)
                .overlay(
                    Capsule()
                        .stroke(DesignSystem.Colors.Brand.brightTurquoise, lineWidth: 3)
                )
            
            VStack(spacing: 0) {
                // 상단 원형 이미지
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                    
                    if let firstImagePath = filter.files.first {
                        AuthenticatedImageView(
                            imagePath: firstImagePath,
                            contentMode: .fill
                        ) {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                )
                        }
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.system(size: 40))
                    }
                    
                    // 원형 테두리
                    Circle()
                        .stroke(DesignSystem.Colors.Brand.brightTurquoise, lineWidth: 3)
                        .frame(width: 200, height: 200)
                }
                .padding(.top, 30)
                
                Spacer()
                
                // 하단 텍스트 정보
                VStack(spacing: 8) {
                    Text(filter.creator.nick)
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(filter.title)
                        .font(.pretendard(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                    
                    Text("#\(filter.category ?? "인물")")
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 20)
                
                // 순위 표시
                Text("\(rank)")
                    .font(.pretendard(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                    .padding(.bottom, 15)
            }
        }
    }
}

// 미니 버전 (좌우 페이지 미리보기용)
struct MiniVerticalOvalCard: View {
    let filter: FilterItem
    let rank: Int
    
    var body: some View {
        ZStack {
            // 세로로 긴 타원형 배경
            Capsule()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 200, height: 280)
            
            VStack(spacing: 0) {
                // 상단 원형 이미지
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 140, height: 140)
                    
                    if let firstImagePath = filter.files.first {
                        AuthenticatedImageView(
                            imagePath: firstImagePath,
                            contentMode: .fill
                        ) {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                    }
                }
                .padding(.top, 25)
                
                Spacer()
                
                // 하단 텍스트 정보
                VStack(spacing: 6) {
                    Text(filter.creator.nick)
                        .font(.pretendard(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(filter.title)
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                    
                    Text("#\(filter.category ?? "인물")")
                        .font(.pretendard(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 16)
                
                // 순위 표시
                Text("\(rank)")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise.opacity(0.7))
                    .padding(.bottom, 12)
            }
        }
        .opacity(0.6)
    }
}
