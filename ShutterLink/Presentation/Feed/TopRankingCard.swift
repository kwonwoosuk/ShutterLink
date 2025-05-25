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
    let onLike: ((String, Bool) -> Void)?
    
    init(filter: FilterItem, rank: Int, onLike: ((String, Bool) -> Void)? = nil) {
        self.filter = filter
        self.rank = rank
        self.onLike = onLike
    }
    
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
                    
                    // 좋아요 버튼 (오른쪽 하단)
                    if let onLike = onLike {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button {
                                    onLike(filter.filter_id, !filter.is_liked)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: filter.is_liked ? "heart.fill" : "heart")
                                            .foregroundColor(filter.is_liked ? .red : .white)
                                            .font(.system(size: 16))
                                        Text("\(filter.like_count)")
                                            .font(.pretendard(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.7))
                                    )
                                }
                                .padding(.trailing, 20)
                                .padding(.bottom, 10)
                            }
                        }
                    }
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
    let onLike: ((String, Bool) -> Void)?
    
    init(filter: FilterItem, rank: Int, onLike: ((String, Bool) -> Void)? = nil) {
        self.filter = filter
        self.rank = rank
        self.onLike = onLike
    }
    
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
                    
                    // 좋아요 버튼 (미니 버전용)
                    if let onLike = onLike {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button {
                                    onLike(filter.filter_id, !filter.is_liked)
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: filter.is_liked ? "heart.fill" : "heart")
                                            .foregroundColor(filter.is_liked ? .red : .white.opacity(0.8))
                                            .font(.system(size: 12))
                                        Text("\(filter.like_count)")
                                            .font(.pretendard(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.6))
                                    )
                                }
                                .padding(.trailing, 15)
                                .padding(.bottom, 8)
                            }
                        }
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
