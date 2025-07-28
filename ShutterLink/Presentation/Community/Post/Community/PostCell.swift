//
//  PostCell.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import SwiftUI

struct PostCell: View {
    let post: Post
    let onTapped: () -> Void
    let onLikeTapped: (Post) -> Void
    
    @State private var showAllContent = false
    @State private var isLikeAnimating = false
    
    private let maxContentLines = 3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 사용자 헤더
            userHeaderSection
            
            // 이미지 섹션
            if !post.files.isEmpty {
                imageSection
            }
            
            // 액션 버튼들 (좋아요, 댓글, 공유)
            actionButtonsSection
            
            // 좋아요 수
            if post.likeCount > 0 {
                likeCountSection
            }
            
            // 게시글 내용
            contentSection
            
            // 댓글 미리보기
            if !post.comments.isEmpty {
                commentsPreviewSection
            }
            
            // 게시 시간
            timeSection
        }
        .background(Color.black)
        .onTapGesture {
            onTapped()
        }
    }
    
    // MARK: - User Header Section
    
    private var userHeaderSection: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            if let profileImagePath = post.creator.profileImage, !profileImagePath.isEmpty {
                AuthenticatedImageView(
                    imagePath: profileImagePath,
                    contentMode: .fill,
                    targetSize: CGSize(width: 40, height: 40)
                ) {
                    Circle()
                        .fill(Color.gray75)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.6)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray75)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    )
            }
            
            // 사용자 정보
            VStack(alignment: .leading, spacing: 2) {
                Text(post.creator.nick)
                    .font(.pretendard(size: 14, weight: .semiBold))
                    .foregroundColor(.white)
                
                if !post.category.isEmpty {
                    Text(post.category)
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // 더보기 버튼
            Button {
                // 메뉴 액션 (신고, 차단 등)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Image Section
    
    private var imageSection: some View {
        TabView {
            ForEach(Array(post.files.enumerated()), id: \.offset) { index, imagePath in
                AuthenticatedImageView(
                    imagePath: imagePath,
                    contentMode: .fill,
                    targetSize: CGSize(width: UIScreen.main.bounds.width, height: 400)
                ) {
                    Rectangle()
                        .fill(Color.gray75)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                .frame(height: 400)
                .clipped()
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: post.files.count > 1 ? .automatic : .never))
        .frame(height: 400)
        .background(Color.gray90)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            // 좋아요 버튼
            Button {
                onLikeTapped(post)
                withAnimation(.easeInOut(duration: 0.1)) {
                    isLikeAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isLikeAnimating = false
                }
            } label: {
                Image(systemName: post.isLike ? "heart.fill" : "heart")
                    .foregroundColor(post.isLike ? .red : .white)
                    .font(.system(size: 24, weight: .medium))
                    .scaleEffect(isLikeAnimating ? 1.2 : 1.0)
            }
            
            // 댓글 버튼
            Button {
                onTapped() // 상세 화면으로 이동
            } label: {
                Image(systemName: "message")
                    .foregroundColor(.white)
                    .font(.system(size: 24, weight: .medium))
            }
            
            // 공유 버튼
            Button {
                // 공유 기능
            } label: {
                Image(systemName: "paperplane")
                    .foregroundColor(.white)
                    .font(.system(size: 24, weight: .medium))
            }
            
            Spacer()
            
            // 북마크 버튼
            Button {
                // 북마크 기능
            } label: {
                Image(systemName: "bookmark")
                    .foregroundColor(.white)
                    .font(.system(size: 24, weight: .medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Like Count Section
    
    private var likeCountSection: some View {
        HStack {
            Text("좋아요 \(post.likeCount)개")
                .font(.pretendard(size: 14, weight: .semiBold))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 제목
            if !post.title.isEmpty {
                Text(post.title)
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            
            // 내용
            if !post.content.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text(post.content)
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.white)
                        .lineLimit(showAllContent ? nil : maxContentLines)
                        .multilineTextAlignment(.leading)
                    
                    // 더보기/간략히 버튼
                    if post.content.count > 100 { // 임계값 기준으로 표시
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllContent.toggle()
                            }
                        } label: {
                            Text(showAllContent ? "간략히" : "더 보기")
                                .font(.pretendard(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
    
    // MARK: - Comments Preview Section
    
    private var commentsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 댓글 개수
            Button {
                onTapped()
            } label: {
                Text("댓글 \(post.comments.count)개 모두 보기")
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            // 최신 댓글 1-2개 미리보기
            ForEach(Array(post.comments.prefix(2))) { comment in
                HStack(alignment: .top, spacing: 8) {
                    Text(comment.creator.nick)
                        .font(.pretendard(size: 14, weight: .semiBold))
                        .foregroundColor(.white)
                    
                    Text(comment.content)
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
    
    // MARK: - Time Section
    
    private var timeSection: some View {
        HStack {
            Text(post.createdAt.timeAgoDisplay())
                .font(.pretendard(size: 12, weight: .regular))
                .foregroundColor(.gray60)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Extensions

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        LazyVStack {
            ForEach(0..<3, id: \.self) { _ in
                PostCell(
                    post: Post(
                        id: "sample",
                        postId: "sample",
                        category: "핫스팟",
                        title: "사진 찍기 좋은 새싹동 스팟",
                        content: "새싹카페 – 창밖 뷰 미쳤어요. 창가 자리 추천 !! 저녁 되면 조명 켜지는데 감성 폭발",
                        geolocation: PostGeolocation(longitude: 127.049914, latitude: 37.654215),
                        creator: PostCreator(
                            userId: "user1",
                            nick: "김새싹",
                            name: "김새싹",
                            introduction: "프로필 소개입니다.",
                            profileImage: nil,
                            hashTags: ["#맑음"]
                        ),
                        files: [],
                        isLike: false,
                        likeCount: 12,
                        comments: [],
                        createdAt: Date(),
                        updatedAt: Date()
                    ),
                    onTapped: {},
                    onLikeTapped: { _ in }
                )
            }
        }
    }
    .background(Color.black)
}
