//
//  TodayFilterIntroSection.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import SwiftUI

struct TodayFilterIntroSection: View {
    let filter: TodayFilterResponse?
    let geometry: GeometryProxy
    let onFilterTap: ((String) -> Void)?
    
    private let baseHeight: CGFloat = 450
    
    var body: some View {
        GeometryReader { headerGeometry in
            let frame = headerGeometry.frame(in: .named("scroll"))
            let offset = frame.minY
            let safeAreaTop = geometry.safeAreaInsets.top
            let totalHeaderHeight = baseHeight + safeAreaTop // SafeArea 포함 총 높이
            let height = getStretchHeight(offset: offset, totalHeight: totalHeaderHeight)
            let yOffset = getYOffset(offset: offset)
            
            ZStack {
                // 배경 이미지 - SafeArea까지 포함
                if let filter = filter, let firstImagePath = filter.files.first {
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
                    .frame(
                        width: geometry.size.width,
                        height: height
                    )
                    .clipped()
                    .offset(y: yOffset)
                } else {
                    // 로딩 상태
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(
                            width: geometry.size.width,
                            height: height
                        )
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                        .offset(y: yOffset)
                }
                
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.1),
                        Color.black.opacity(0.2),
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.6),
                        Color.black
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(
                    width: geometry.size.width,
                    height: height
                )
                .offset(y: yOffset)
                
                // 콘텐츠 영역 - SafeArea 아래쪽에 위치
                if let filter = filter {
                    VStack {
                        Spacer()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 12) {
                                // 오늘의 필터 소개 라벨
                                Text("오늘의 필터 소개")
                                    .font(.pretendard(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                // 필터 제목
                                Text(filter.title)
                                    .font(.hakgyoansim(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                
                                // 필터 부제목
                                Text(filter.introduction)
                                    .font(.hakgyoansim(size: 16, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                
                                // 필터 설명
                                Text(filter.description)
                                    .font(.pretendard(size: 13, weight: .regular))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(3)
                                    .lineSpacing(2)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .frame(height: height)
                    .offset(y: yOffset)
                    
                    // 우상단 사용해보기 버튼 - SafeArea 아래쪽에 위치
                    VStack {
                        HStack {
                            Spacer()
                            
                            Button {
                                onFilterTap?(filter.filter_id)
                            } label: {
                                Text("사용해보기")
                                    .font(.pretendard(size: 12, weight: .medium))
                                    .foregroundColor(.gray45)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(.gray60.opacity(0.6))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, safeAreaTop + 20) // SafeArea + 여유 공간
                        
                        Spacer()
                    }
                    .frame(height: height)
                    .offset(y: yOffset)
                }
            }
        }
        .frame(height: baseHeight + geometry.safeAreaInsets.top)
    }
    
    // Stretch 높이 계산 (아래로 당길 때만)
    private func getStretchHeight(offset: CGFloat, totalHeight: CGFloat) -> CGFloat {
        if offset > 0 {
            // 아래로 당길 때 (양수 offset) - 이미지 늘리기
            return totalHeight + offset
        } else {
            // 위로 스크롤할 때 - 기본 높이 유지
            return totalHeight
        }
    }
    
    // Y 오프셋 계산 (아래로 당길 때만)
    private func getYOffset(offset: CGFloat) -> CGFloat {
        if offset > 0 {
            // 아래로 당길 때 - 이미지를 위로 이동시켜 늘어나는 효과
            return -offset
        } else {
            // 위로 스크롤할 때 - 오프셋 없음
            return 0
        }
    }
}

