//
//  MyPostsView.swift
//  ShutterLink
//
//  Created by 권우석 on 8/2/25.
//

import SwiftUI

struct MyPostsView: View {
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = MyPostsViewModel()
    @State private var selectedCategory = ""
    @State private var showDeleteAlert = false
    @State private var postToDelete: Post?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 카테고리 필터
                    categoryFilterSection
                    
                    // 게시글 목록
                    if viewModel.posts.isEmpty && !viewModel.isLoading {
                        emptyStateView
                    } else {
                        postsListSection
                    }
                }
            }
            .refreshable {
                await viewModel.refreshPostsAsync()
            }
            
            if viewModel.isLoading && viewModel.posts.isEmpty {
                loadingIndicator
            }
        }
        .navigationTitle("내 글 관리")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    router.popProfileRoute()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                }
            }
        }
        .onAppear {
            viewModel.loadMyPosts()
        }
        .alert("게시글 삭제", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                if let post = postToDelete {
                    viewModel.deletePost(postId: post.postId)
                }
            }
        } message: {
            Text("이 게시글을 정말 삭제하시겠습니까?")
        }
        .alert("오류", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("확인") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Category Filter Section
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                categoryButton("전체", category: "")
                categoryButton("핫스팟", category: "핫스팟")
                categoryButton("맛집", category: "맛집")
                categoryButton("일상", category: "일상")
                categoryButton("여행", category: "여행")
                categoryButton("취미", category: "취미")
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }
    
    private func categoryButton(_ title: String, category: String) -> some View {
        Button {
            selectedCategory = category
            viewModel.filterByCategory(category.isEmpty ? nil : category)
        } label: {
            Text(title)
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(selectedCategory == category ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selectedCategory == category ? Color.white : Color.gray90)
                )
        }
    }
    
    // MARK: - Posts List Section
    
    private var postsListSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.posts) { post in
                MyPostCard(
                    post: post,
                    onTap: {
                        router.pushToPostDetail(postId: post.postId)
                    },
                    onEdit: {
                        router.pushToEditPost(post: post)
                    },
                    onDelete: {
                        postToDelete = post
                        showDeleteAlert = true
                    }
                )
                .padding(.horizontal, 16)
                .onAppear {
                    // 무한 스크롤
                    if post.id == viewModel.posts.last?.id {
                        viewModel.loadMorePosts()
                    }
                }
            }
            
            // 더 로딩 중 인디케이터
            if viewModel.isLoadingMore {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    
                    Text("더 불러오는 중...")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 20)
            }
            
            // 하단 여백
            Color.clear.frame(height: 100)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.gray60)
            
            Text("작성한 게시글이 없습니다")
                .font(.pretendard(size: 18, weight: .semiBold))
                .foregroundColor(.white)
            
            Text("첫 번째 게시글을 작성해보세요!")
                .font(.pretendard(size: 14, weight: .regular))
                .foregroundColor(.gray60)
            
            Button {
                router.pushToCreatePost()
            } label: {
                Text("게시글 작성하기")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Loading Indicator
    
    private var loadingIndicator: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("게시글을 불러오는 중...")
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.top, 8)
        }
        .padding(20)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
    }
}

// MARK: - MyPostCard Component

struct MyPostCard: View {
    let post: Post
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 카테고리와 액션 버튼
            HStack {
                Text(post.category)
                    .font(.pretendard(size: 12, weight: .semiBold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                
                Spacer()
                
                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label("수정하기", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("삭제하기", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                        .frame(width: 24, height: 24)
                }
            }
            
            // 제목과 내용
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    onTap()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.title)
                            .font(.pretendard(size: 16, weight: .semiBold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        
                        Text(post.content)
                            .font(.pretendard(size: 14, weight: .regular))
                            .foregroundColor(.gray60)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 이미지 미리보기 (있는 경우)
            if !post.files.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(post.files.prefix(3).enumerated()), id: \.offset) { index, imagePath in
                            AuthenticatedImageView(
                                imagePath: imagePath,
                                contentMode: .fill,
                                targetSize: CGSize(width: 60, height: 60)
                            ) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.5)
                                    )
                            }
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(8)
                        }
                        
                        if post.files.count > 3 {
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.8))
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                
                                Text("+\(post.files.count - 3)")
                                    .font(.pretendard(size: 12, weight: .semiBold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            
            // 좋아요와 댓글 수
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                    Text("\(post.likeCount)")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.gray60)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .foregroundColor(.gray60)
                        .font(.system(size: 12))
                    Text("\(post.comments.count)")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.gray60)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MyPostsView()
            .environmentObject(NavigationRouter.shared)
    }
    .preferredColorScheme(.dark)
}
