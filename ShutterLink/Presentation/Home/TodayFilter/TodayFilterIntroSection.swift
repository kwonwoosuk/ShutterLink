//
//  TodayFilterIntroSection.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import SwiftUI
// MARK: - 섹션 1: 오늘의 필터 소개 (필터 정보만)
struct TodayFilterIntroSection: View {
    let filter: TodayFilterResponse?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 타이틀
            HStack {
                Text("오늘의 필터")
                    .font(.hakgyoansim(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // 오늘의 필터 상세 정보
            if let filter = filter {
                VStack(alignment: .leading, spacing: 16) {
                    // 메인 이미지 - NavigationLink로 감싸기
                    if #available(iOS 16.0, *) {
                        NavigationLink(destination: FilterDetailView(filterId: filter.filter_id)) {
                            filterImageView(filter: filter)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        NavigationLink(destination: FilterDetailView(filterId: filter.filter_id)) {
                            filterImageView(filter: filter)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // 필터 상세 설명
                    VStack(alignment: .leading, spacing: 12) {
                        Text("필터 설명")
                            .font(.pretendard(size: 16, weight: .semiBold))
                            .foregroundColor(.white)
                        
                        Text(filter.description)
                            .font(.pretendard(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(nil)
                        
                        // 생성/수정일
                        HStack {
                            Text("생성일: \(formatDate(filter.createdAt))")
                                .font(.pretendard(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                            
                            Text("수정일: \(formatDate(filter.updatedAt))")
                                .font(.pretendard(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                // 로딩 상태
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 240)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
                    .padding(.horizontal, 20)
            }
        }
    }
    
    // 필터 이미지 뷰를 별도 메서드로 분리
    @ViewBuilder
    private func filterImageView(filter: TodayFilterResponse) -> some View {
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
                .frame(height: 240)
                .clipped()
            }
            
            // 그라데이션 오버레이
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.6)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            
            // 텍스트 콘텐츠
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(filter.title)
                            .font(.hakgyoansim(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(filter.introduction)
                            .font(.pretendard(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    // 탭 인디케이터
                    VStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("자세히 보기")
                            .font(.pretendard(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "yyyy.MM.dd"
            return formatter.string(from: date)
        }
        return dateString
    }
}
