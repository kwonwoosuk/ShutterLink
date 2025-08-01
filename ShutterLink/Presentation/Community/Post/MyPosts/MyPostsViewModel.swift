//
//  MyPostsViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 8/2/25.
//

import SwiftUI

final class MyPostsViewModel: ObservableObject {
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
    private var deleteTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(postUseCase: PostUseCase = PostUseCaseImpl()) {
        self.postUseCase = postUseCase
    }
    
    deinit {
        cancelAllTasks()
    }
    
    // MARK: - Public Methods
    
    func loadMyPosts() {
        guard let currentUserId = TokenManager.shared.getCurrentUserId() else {
            setError("로그인이 필요합니다.")
            return
        }
        
        cancelLoadTasks()
        
        loadTask = Task {
            await performLoadPosts(for: currentUserId, isRefresh: true)
        }
    }
    
    func refreshPosts() {
        resetPagination()
        loadMyPosts()
    }
    
    func refreshPostsAsync() async {
        guard let currentUserId = TokenManager.shared.getCurrentUserId() else {
            await MainActor.run {
                setError("로그인이 필요합니다.")
            }
            return
        }
        
        resetPagination()
        await performLoadPosts(for: currentUserId, isRefresh: true)
    }
    
    func loadMorePosts() {
        guard hasMorePosts, !isLoadingMore, !isLoading,
              let currentUserId = TokenManager.shared.getCurrentUserId() else { return }
        
        loadMoreTask = Task {
            await performLoadPosts(for: currentUserId, isRefresh: false)
        }
    }
    
    func filterByCategory(_ category: String?) {
        currentCategory = category
        resetPagination()
        loadMyPosts()
    }
    
    func deletePost(postId: String) {
        deleteTask?.cancel()
        
        deleteTask = Task {
            await performDeletePost(postId: postId)
        }
    }
    
    func setError(_ message: String) {
        errorMessage = message
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func performLoadPosts(for userId: String, isRefresh: Bool) async {
        print("📋 MyPostsViewModel: 내 게시글 로드 시작 - refresh: \(isRefresh)")
        
        await MainActor.run {
            if isRefresh {
                isLoading = true
            } else {
                isLoadingMore = true
            }
            errorMessage = nil
        }
        
        do {
            let result = try await postUseCase.getUserPosts(
                userId: userId,
                category: currentCategory,
                limit: pageLimit,
                next: isRefresh ? nil : nextCursor
            )
            
            try Task.checkCancellation()
            
            await MainActor.run {
                if isRefresh {
                    posts = result.posts
                    isLoading = false
                } else {
                    posts.append(contentsOf: result.posts)
                    isLoadingMore = false
                }
                
                nextCursor = result.nextCursor
                hasMorePosts = result.posts.count >= pageLimit && !result.posts.isEmpty && result.nextCursor != nil
            }
            
            print("✅ MyPostsViewModel: 내 게시글 로드 완료 - \(result.posts.count)개")
            
        } catch let error as PostError {
            if !Task.isCancelled {
                await MainActor.run {
                    if isRefresh {
                        isLoading = false
                    } else {
                        isLoadingMore = false
                    }
                    errorMessage = error.localizedDescription
                    print("❌ MyPostsViewModel: PostError - \(error.localizedDescription)")
                }
            }
            
        } catch let decodingError as DecodingError {
            if !Task.isCancelled {
                await MainActor.run {
                    if isRefresh {
                        isLoading = false
                    } else {
                        isLoadingMore = false
                    }
                    errorMessage = "데이터 처리 중 오류가 발생했습니다."
                    print("❌ MyPostsViewModel: DecodingError - \(decodingError)")
                }
            }
            
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    if isRefresh {
                        isLoading = false
                    } else {
                        isLoadingMore = false
                    }
                    errorMessage = "게시글을 불러오는데 실패했습니다."
                    print("❌ MyPostsViewModel: 게시글 로드 실패 - \(error)")
                }
            }
        }
    }
    
    private func performDeletePost(postId: String) async {
        print("🗑️ MyPostsViewModel: 게시글 삭제 시작 - \(postId)")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await postUseCase.deletePost(postId: postId)
            
            try Task.checkCancellation()
            
            await MainActor.run {
                // 삭제된 게시글을 목록에서 제거
                posts.removeAll { $0.postId == postId }
                isLoading = false
            }
            
            print("✅ MyPostsViewModel: 게시글 삭제 완료 - \(postId)")
            
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "게시글 삭제에 실패했습니다: \(error.localizedDescription)"
                }
                print("❌ MyPostsViewModel: 게시글 삭제 실패 - \(error)")
            }
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
        deleteTask?.cancel()
    }
}
