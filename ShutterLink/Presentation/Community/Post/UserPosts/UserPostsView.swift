//
//  UserPostsView.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import SwiftUI

struct UserPostsView: View {
    let userId: String
    let userNick: String
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = UserPostsViewModel()
    @State private var selectedCategory = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 카테고리 필터
                categoryFilterSection
                
                // 게시글 목록
                if viewModel.posts.isEmpty && !viewModel.isLoading {
                    emptyStateSection
                } else {
                    postListSection
                }
            }
            
            if viewModel.isLoading && !viewModel.isLoadingMore {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("게시글을 불러오는 중...")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                .padding(20)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("\(userNick)님의 게시글")
                    .font(.hakgyoansim(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.refreshPosts()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .onAppear {
            viewModel.loadPosts(for: userId)
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
        .padding(.vertical, 12)
        .background(Color.black)
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
                        .fill(selectedCategory == category ? Color.white : Color.gray75)
                )
        }
    }
    
    // MARK: - Empty State Section
    
    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.gray60)
            
            VStack(spacing: 8) {
                Text("작성한 게시글이 없습니다")
                    .font(.pretendard(size: 18, weight: .semiBold))
                    .foregroundColor(.white)
                
                Text("\(userNick)님이 아직 게시글을 작성하지 않았습니다")
                    .font(.pretendard(size: 14, weight: .regular))
                    .foregroundColor(.gray60)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Post List Section
    
    private var postListSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.posts) { post in
                    PostCell(post: post) {
                        router.pushToPostDetail(postId: post.postId)
                    } onLikeTapped: { post in
                        Task {
                            await viewModel.toggleLike(post: post)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onAppear {
                        if post.id == viewModel.posts.last?.id {
                            viewModel.loadMorePosts()
                        }
                    }
                }
                
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
    }
}
