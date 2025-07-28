//
//  MyLikedPostsViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import SwiftUI

final class MyLikedPostsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMorePosts = true
    
    // MARK: - Private Properties
    
    private let postUseCase: PostUseCase
    private var currentCategory: String?
    private var nextCursor: String?
    private let pageLimit = 10
    
    private var loadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var likeTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(postUseCase: PostUseCase = PostUseCaseImpl()) {
        self.postUseCase = postUseCase
    }
    
    deinit {
        cancelAllTasks()
    }
    
    // MARK: - Public Methods
    
    func loadPosts() {
        cancelLoadTasks()
        
        loadTask = Task {
            await performLoadPosts(isRefresh: true)
        }
    }
    
    func refreshPosts() {
        resetPagination()
        loadPosts()
    }
    
    func loadMorePosts() {
        guard hasMorePosts, !isLoadingMore, !isLoading else { return }
        
        loadMoreTask = Task {
            await performLoadPosts(isRefresh: false)
        }
    }
    
    func filterByCategory(_ category: String?) {
        currentCategory = category
        resetPagination()
        loadPosts()
    }
    
    func toggleLike(post: Post) async {
        likeTask?.cancel()
        
        likeTask = Task {
            do {
                await MainActor.run {
                    updatePostLike(postId: post.postId, isLiked: !post.isLike)
                }
                
                let newLikeStatus = try await postUseCase.toggleLike(
                    postId: post.postId,
                    currentLikeStatus: post.isLike
                )
                
                await MainActor.run {
                    updatePostLike(postId: post.postId, isLiked: newLikeStatus)
                    
                    if !newLikeStatus {
                        posts.removeAll { $0.postId == post.postId }
                    }
                }
                
            } catch {
                await MainActor.run {
                    updatePostLike(postId: post.postId, isLiked: post.isLike)
                    setError("좋아요 처리에 실패했습니다: \(error.localizedDescription)")
                }
                print("❌ MyLikedPostsViewModel: 좋아요 처리 실패 - \(error)")
            }
        }
    }
    
    func setError(_ message: String) {
        errorMessage = message
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func performLoadPosts(isRefresh: Bool) async {
        
        await MainActor.run {
            if isRefresh {
                isLoading = true
            } else {
                isLoadingMore = true
            }
            errorMessage = nil
        }
        
        do {
            let result = try await postUseCase.getMyLikedPosts(
                category: currentCategory,
                limit: pageLimit,
                next: isRefresh ? nil : nextCursor
            )
            
            try Task.checkCancellation()
            
            await MainActor.run {
                if isRefresh {
                    posts = result.posts
                } else {
                    posts.append(contentsOf: result.posts)
                }
                
                nextCursor = result.nextCursor
                hasMorePosts = result.nextCursor != "0" && result.nextCursor != nil
                
                isLoading = false
                isLoadingMore = false
            }
            
            print("✅ MyLikedPostsViewModel: 좋아요한 게시글 로드 완료 - \(result.posts.count)개, hasMore: \(hasMorePosts)")
            
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                    isLoadingMore = false
                    errorMessage = "좋아요한 게시글을 불러오는데 실패했습니다: \(error.localizedDescription)"
                }
                print("❌ MyLikedPostsViewModel: 좋아요한 게시글 로드 실패 - \(error)")
            }
        }
    }
    
    private func updatePostLike(postId: String, isLiked: Bool) {
        if let index = posts.firstIndex(where: { $0.postId == postId }) {
            let currentPost = posts[index]
            let likeCountDelta = isLiked ? 1 : -1
            let newLikeCount = max(0, currentPost.likeCount + likeCountDelta)
            
            posts[index] = Post(
                id: currentPost.id,
                postId: currentPost.postId,
                category: currentPost.category,
                title: currentPost.title,
                content: currentPost.content,
                geolocation: currentPost.geolocation,
                creator: currentPost.creator,
                files: currentPost.files,
                isLike: isLiked,
                likeCount: newLikeCount,
                comments: currentPost.comments,
                createdAt: currentPost.createdAt,
                updatedAt: currentPost.updatedAt
            )
        }
    }
    
    private func resetPagination() {
        nextCursor = nil
        hasMorePosts = true
    }
    
    private func cancelLoadTasks() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
    }
    
    private func cancelAllTasks() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        likeTask?.cancel()
    }
}
