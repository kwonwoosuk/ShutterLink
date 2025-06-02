//
//  UserDetailView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/2/25.
//

import SwiftUI

struct UserDetailView: View {
    let userId: String
    let userInfo: UserInfo?
    
    @StateObject private var viewModel = UserDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showUserFilters = false
    @State private var hasAppeared = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if let user = userInfo {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 프로필 헤더 섹션
                        UserProfileHeaderSection(user: user)
                            .padding(.top, 40)
                        
                        // 해시태그 섹션
                        if !user.hashTags.isEmpty {
                            UserHashTagsSection(hashTags: user.hashTags)
                                .padding(.top, 24)
                        }
                        
                        // 작가 소개 섹션
                        UserIntroductionSection(introduction: user.introduction)
                            .padding(.top, 32)
                        
                        // 이 작가 필터 보기 버튼
                        UserFiltersButton {
                            showUserFilters = true
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 60)
                    }
                }
            } else if viewModel.isLoading {
                LoadingIndicatorView()
            } else if let errorMessage = viewModel.errorMessage {
                ErrorStateView(errorMessage: errorMessage) {
                    // 재시도 로직
                }
            }
        }
        .navigationBarHidden(false)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 커스텀 백버튼
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.Gray.gray75)
                }
            }
            
            // 유저 닉네임 타이틀
            ToolbarItem(placement: .principal) {
                if let user = userInfo {
                    Text(user.nick)
                        .font(.hakgyoansim(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else {
                    Text("")
                        .font(.hakgyoansim(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showUserFilters) {
            UserFiltersView(userId: userId, userNick: userInfo?.nick ?? "")
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                // 필요 시 추가 데이터 로드
            }
        }
    }
}

// MARK: - 프로필 헤더 섹션
struct UserProfileHeaderSection: View {
    let user: UserInfo
    
    var body: some View {
        VStack(spacing: 20) {
            // 프로필 이미지
            if let profileImagePath = user.profileImage {
                AuthenticatedImageView(
                    imagePath: profileImagePath,
                    contentMode: .fill,
                    targetSize: CGSize(width: 120, height: 120)
                ) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 48))
                    )
            }
            
            // 유저 정보
            VStack(spacing: 8) {
                Text(user.nick)
                    .font(.hakgyoansim(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(user.name)
                    .font(.pretendard(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 해시태그 섹션
struct UserHashTagsSection: View {
    let hashTags: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(hashTags, id: \.self) { tag in
                        Text(tag)
                            .font(.pretendard(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - 작가 소개 섹션
struct UserIntroductionSection: View {
    let introduction: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("작가 소개")
                    .font(.pretendard(size: 18, weight: .semiBold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            Text("아름다운 자연을 담아내는 사진 작가")
                .font(.pretendard(size: 16, weight: .medium))
                .foregroundColor(.white)
                .italic()
                .multilineTextAlignment(.leading)
            
            Text(introduction.isEmpty ? "윤새싹은 자연의 섬세한 아름다움을 포착하는 데 탁월한 감각을 지닌 사진작가입니다. 새싹이 돋아나는 계절의 생명력과 따뜻함을 렌즈에 담아내며, 보는 이들에게 감동을 전달합니다." : introduction)
                .font(.pretendard(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 필터 보기 버튼
struct UserFiltersButton: View {
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Spacer()
                Text("이 작가 필터 보기")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.Brand.brightTurquoise)
            )
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    NavigationStack {
        UserDetailView(
            userId: "test_user_id",
            userInfo: UserInfo(
                user_id: "test_user_id",
                nick: "윤새싹",
                name: "SESAC YOON",
                introduction: "자연의 섬세함을 담아내는 감성 사진작가",
                profileImage: nil,
                hashTags: ["#자연", "#감성", "#미니멀"]
            )
        )
    }
}
