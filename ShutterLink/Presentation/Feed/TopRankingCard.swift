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
    let onFilterTap: ((String) -> Void)?
    
    init(filter: FilterItem, rank: Int, onFilterTap: ((String) -> Void)? = nil) {
        self.filter = filter
        self.rank = rank
        self.onFilterTap = onFilterTap
    }
    
    var body: some View {
        cardContent
            .onTapGesture {
                onFilterTap?(filter.filter_id)
            }
    }
    
    @ViewBuilder
    private var cardContent: some View {
        ZStack {
            // 세로로 긴 타원형 배경 - 스크린샷과 동일한 스타일
            Capsule()
                .fill(Color.black.opacity(0.85))
                .frame(width: 240, height: 360)
                .overlay(
                    Capsule()
                        .stroke(DesignSystem.Colors.Brand.brightTurquoise, lineWidth: 3)
                )
            
            VStack(spacing: 0) {
                // 상단 원형 이미지
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 180, height: 180)
                    
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
                        .frame(width: 180, height: 180)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.system(size: 40))
                    }
                    
                    // 원형 테두리 - 스크린샷과 동일한 turquoise 색상
                    Circle()
                        .stroke(DesignSystem.Colors.Brand.brightTurquoise, lineWidth: 3)
                        .frame(width: 180, height: 180)
                }
                .padding(.top, 30)
                
                Spacer()
                
                // 하단 텍스트 정보 - 스크린샷과 동일한 레이아웃
                VStack(spacing: 8) {
                    Text(filter.creator.nick)
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(filter.title)
                        .font(.hakgyoansim(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                    
                    Text("#\(filter.category ?? "인물")")
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 20)
                
                // 순위 표시 - 스크린샷과 동일한 스타일
                Text("\(rank)")
                    .font(.hakgyoansim(size: 24, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                    .padding(.bottom, 20)
            }
        }
    }
}

// 미니 버전 (좌우 페이지 미리보기용) - 스크린샷 스타일 적용
struct MiniVerticalOvalCard: View {
    let filter: FilterItem
    let rank: Int
    let onFilterTap: ((String) -> Void)?
    
    init(filter: FilterItem, rank: Int, onFilterTap: ((String) -> Void)? = nil) {
        self.filter = filter
        self.rank = rank
        self.onFilterTap = onFilterTap
    }
    
    var body: some View {
        miniCardContent
            .onTapGesture {
                onFilterTap?(filter.filter_id)
            }
    }
    
    @ViewBuilder
    private var miniCardContent: some View {
        ZStack {
            // 세로로 긴 타원형 배경 - 비활성화 스타일
            Capsule()
                .fill(Color.black.opacity(0.6))
                .frame(width: 200, height: 280)
                .overlay(
                    Capsule()
                        .stroke(Color.clear, lineWidth: 0) // 테두리 없음
                )
            
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
                    
                    // 원형 테두리 - 비활성화 상태
                    Circle()
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        .frame(width: 140, height: 140)
                }
                .padding(.top, 25)
                
                Spacer()
                
                // 하단 텍스트 정보 - 비활성화 스타일
                VStack(spacing: 6) {
                    Text(filter.creator.nick)
                        .font(.pretendard(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(filter.title)
                        .font(.hakgyoansim(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                    
                    Text("#\(filter.category ?? "인물")")
                        .font(.pretendard(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 16)
                
                // 순위 표시 - 비활성화 스타일
                Text("\(rank)")
                    .font(.hakgyoansim(size: 16, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise.opacity(0.7))
                    .padding(.bottom, 12)
            }
        }
        .opacity(0.7) // 전체적으로 어두운 효과
    }
}
