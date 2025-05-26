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
    
    var body: some View {
        // NavigationLink로 전체 카드 감싸기
        if #available(iOS 16.0, *) {
            NavigationLink(destination: FilterDetailView(filterId: filter.filter_id)) {
                cardContent
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            NavigationLink(destination: FilterDetailView(filterId: filter.filter_id)) {
                cardContent
            }
            .buttonStyle(PlainButtonStyle())
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
                
                // 좋아요 카운트 (오른쪽 하단)
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
                
                // 중앙 카드에 탭 인디케이터 추가
                if isCenter {
                    VStack {
                        Spacer()
                        HStack {
                            VStack {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("보기")
                                    .font(.pretendard(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                            )
                            .padding(.leading, 8)
                            .padding(.bottom, 8)
                            
                            Spacer()
                        }
                        
                        Spacer()
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
