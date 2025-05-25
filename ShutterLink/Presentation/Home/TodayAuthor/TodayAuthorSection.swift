//
//  TodayAuthorSection.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import SwiftUI

// MARK: - 섹션 4: 오늘의 작가 소개 (왼쪽 정렬)
struct TodayAuthorSection: View {
    let authorData: TodayAuthorResponse?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 타이틀
            HStack {
                Text("오늘의 작가 소개")
                    .font(.hakgyoansim(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            if let authorData = authorData {
                VStack(alignment: .leading, spacing: 20) {
                    // 작가 프로필 섹션 (왼쪽 정렬)
                    HStack(alignment: .top, spacing: 16) {
                        // 프로필 이미지
                        if let profileImagePath = authorData.author.profileImage {
                            AuthenticatedImageView(
                                imagePath: profileImagePath,
                                contentMode: .fill
                            ) {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    )
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 32))
                                )
                        }
                        
                        // 작가 정보 (왼쪽 정렬)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(authorData.author.name)
                                .font(.pretendard(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(authorData.author.nick)
                                .font(.pretendard(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(authorData.author.introduction)
                                .font(.pretendard(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                            
                            // 해시태그 (왼쪽 정렬)
                            if !authorData.author.hashTags.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(authorData.author.hashTags.prefix(3), id: \.self) { tag in
                                        Text(tag)
                                            .font(.pretendard(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.black)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // 작가 상세 설명 (왼쪽 정렬)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("작가 소개")
                            .font(.pretendard(size: 16, weight: .semiBold))
                            .foregroundColor(.white)
                        
                        Text(authorData.author.description)
                            .font(.pretendard(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(nil)
                    }
                    .padding(.horizontal, 20)
                    
                    // 작가의 필터 작품들
                    if !authorData.filters.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("작가의 작품")
                                .font(.pretendard(size: 16, weight: .semiBold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(authorData.filters) { filter in
                                        AuthorFilterCard(filter: filter)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            } else {
                
                AuthorMockView()
            }
        }
    }
}



struct MockFilterCard: View {
    let index: Int
    private let mockTitles = ["자연 필터", "도시 필터", "빈티지 필터", "모던 필터"]
    private let mockColors: [Color] = [.green, .blue, .orange, .purple]
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(mockColors[index].opacity(0.6))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "camera.filters")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                )
            
            Text(mockTitles[index])
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

// MARK: - 작가 Mock 뷰 (데이터 로딩 실패 시)
struct AuthorMockView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Mock 작가 프로필
            VStack(spacing: 16) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 32))
                    )
                
                VStack(spacing: 8) {
                    Text("새싹 작가")
                        .font(.pretendard(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("SESAC CREATOR")
                        .font(.pretendard(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("자연의 아름다움을 담는 사진작가")
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                // Mock 해시태그
                HStack(spacing: 8) {
                    Text("#자연")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("#감성")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)
            
            // Mock 설명
            VStack(alignment: .leading, spacing: 12) {
                Text("작가 소개")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                
                Text("자연의 섬세한 아름다움을 포착하는 데 탁월한 감각을 지닌 사진작가입니다. 새싹이 돋아나는 계절의 생명력과 따뜻함을 렌즈에 담아내며, 보는 이들에게 감동을 전달합니다.")
                    .font(.pretendard(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 20)
            
            // Mock 필터 작품들
            VStack(alignment: .leading, spacing: 12) {
                Text("작가의 작품")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<4) { index in
                            MockFilterCard(index: index)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
