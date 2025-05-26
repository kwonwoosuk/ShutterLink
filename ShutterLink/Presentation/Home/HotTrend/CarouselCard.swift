//
//  CarouselCard.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import SwiftUI

struct CarouselCard: View {
    let filter: FilterItem
    let isCenter: Bool
    let scale: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onFilterTap: ((String) -> Void)?
    
    init(filter: FilterItem, isCenter: Bool, scale: CGFloat, cardWidth: CGFloat, cardHeight: CGFloat, onFilterTap: ((String) -> Void)? = nil) {
        self.filter = filter
        self.isCenter = isCenter
        self.scale = scale
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
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
        VStack(spacing: 12) {
            // 메인 이미지 영역
            ZStack {
                if let firstImagePath = filter.files.first {
                    AuthenticatedImageView(
                        imagePath: firstImagePath,
                        contentMode: .fill
                    ) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    }
                    .scaledToFill()
                    .frame(width: cardWidth, height: cardWidth)
                    .clipped()
                    .cornerRadius(20)
                    .overlay(
                        // 선택되지 않은 카드에 어두운 오버레이
                        Color.black.opacity(isCenter ? 0 : 0.5)
                    )
                    .overlay(
                        // 선택된 카드에 테두리 효과
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isCenter ? Color.white : Color.clear,
                                lineWidth: isCenter ? 2 : 0
                            )
                    )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: cardWidth, height: cardWidth)
                        .cornerRadius(20)
                }
                
                // 좋아요 카운트 (오른쪽 하단) - 표시만, 버튼 없음
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                            Text("\(filter.like_count)")
                                .font(.pretendard(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.7))
                        )
                        .padding(8)
                    }
                }
            }
            
            // 카드 정보 (선택된 카드만 표시)
            if isCenter {
                VStack(spacing: 4) {
                    Text(filter.title)
                        .font(.pretendard(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(filter.creator.nick)
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(width: cardWidth)
        .scaleEffect(scale)
        .opacity(isCenter ? 1.0 : 0.7)
        .shadow(radius: isCenter ? 10 : 3)
        .animation(.easeInOut(duration: 0.3), value: isCenter)
    }
}
