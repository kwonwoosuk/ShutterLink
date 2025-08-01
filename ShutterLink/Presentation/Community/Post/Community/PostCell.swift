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
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            contentSection
            
            if !post.files.isEmpty {
                imageSection
            }
            
            actionSection
            
            if !post.comments.isEmpty {
                commentsPreviewSection
            }
        }
        .background(Color.black)
    }
}

// MARK: - View Components

extension PostCell {
    
    // MARK: - Header Section
    
    private var headerSection: some View {
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
                    .fill(Color.gray60)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    )
            }
            
            // 유저 정보와 카테고리
            VStack(alignment: .leading, spacing: 2) {
                Text(post.creator.nick)
                    .font(.pretendard(size: 14, weight: .semiBold))
                    .foregroundColor(.white)
                
                Text(post.category)
                    .font(.pretendard(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 제목
            Button {
                onTapped()
            } label: {
                Text(post.title)
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 내용
            if !post.content.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    let maxContentLines = showAllContent ? nil : 3
                    
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
    
    // MARK: - Image Section
    
    private var imageSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(post.files.enumerated()), id: \.offset) { index, imagePath in
                    AuthenticatedImageView(
                        imagePath: imagePath,
                        contentMode: .fill,
                        targetSize: CGSize(width: 300, height: 200)
                    ) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            )
                    }
                    .frame(width: 280, height: 200)
                    .clipped()
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Action Section
    
    private var actionSection: some View {
        HStack(spacing: 20) {
            // 좋아요 버튼
            Button {
                onLikeTapped(post)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: post.isLike ? "heart.fill" : "heart")
                        .foregroundColor(post.isLike ? .red : .white)
                        .font(.system(size: 18))
                        .animation(.easeInOut(duration: 0.2), value: post.isLike)
                    
                    Text("\(post.likeCount)")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 댓글 버튼
            Button {
                onTapped()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                    
                    Text("\(post.comments.count)")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
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
        .padding(.bottom, 12)
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
