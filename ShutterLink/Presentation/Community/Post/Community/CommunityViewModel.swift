//
//  CommunityViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import SwiftUI
import Combine

final class CommunityViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMorePosts = true
    
    // MARK: - Private Properties
    
    private let postUseCase: PostUseCase
    private var currentCategory: String?
    private var currentOrderBy: String = "createdAt"
    private var nextCursor: String?
    private let pageLimit = 10
    private var cancellables = Set<AnyCancellable>()
    
    private var loadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var likeTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(postUseCase: PostUseCase = PostUseCaseImpl()) {
        self.postUseCase = postUseCase
    
        NotificationCenter.default.publisher(for: .postLikeUpdated)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let postId = userInfo["postId"] as? String,
                   let isLiked = userInfo["isLiked"] as? Bool,
                   let likeCount = userInfo["likeCount"] as? Int {
                    self?.updatePostLikeFromNotification(postId: postId, isLiked: isLiked, likeCount: likeCount)
                }
            }
            .store(in: &cancellables)
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
    
    func refreshPostsAsync() async {
        resetPagination()
        await performLoadPosts(isRefresh: true)
    }
    
    func loadMorePosts() {
        guard hasMorePosts, !isLoadingMore, !isLoading else { return }
        
        loadMoreTask = Task {
            await performLoadPosts(isRefresh: false)
        }
    }
    
    func filterByCategory(_ category: String?, orderBy: String? = nil) {
        currentCategory = category
        if let orderBy = orderBy {
            currentOrderBy = orderBy
        }
        resetPagination()
        loadPosts()
    }
    
    func updateSortOrder(_ orderBy: String) {
        currentOrderBy = orderBy
        resetPagination()
        loadPosts()
    }
    
    func searchPosts(query: String) async throws -> [Post] {
        return try await postUseCase.searchPosts(title: query)
    }
    
    func toggleLike(post: Post) async {
        likeTask?.cancel()
        
        likeTask = Task {
            do {
                // 즉시 UI 업데이트 (optimistic update)
                await MainActor.run {
                    updatePostLike(postId: post.postId, isLiked: !post.isLike)
                }
                
                let newLikeStatus = try await postUseCase.toggleLike(
                    postId: post.postId,
                    currentLikeStatus: post.isLike
                )
                
                await MainActor.run {
                    updatePostLike(postId: post.postId, isLiked: newLikeStatus)
                    
                    // 다른 화면과 동기화를 위한 노티피케이션 발송
                    if let updatedPost = posts.first(where: { $0.postId == post.postId }) {
                        NotificationCenter.default.post(
                            name: .postLikeUpdated,
                            object: nil,
                            userInfo: [
                                "postId": post.postId,
                                "isLiked": updatedPost.isLike,
                                "likeCount": updatedPost.likeCount
                            ]
                        )
                    }
                }
                
                print("✅ CommunityViewModel: 좋아요 상태 업데이트 완료 - \(newLikeStatus)")
                
            } catch {
                // 실패시 원래 상태로 롤백
                await MainActor.run {
                    updatePostLike(postId: post.postId, isLiked: post.isLike)
                    setError("좋아요 처리에 실패했습니다: \(error.localizedDescription)")
                }
                print("❌ CommunityViewModel: 좋아요 처리 실패 - \(error)")
            }
        }
    }
    
    func scrollToTop() {
        print("📜 CommunityViewModel: 스크롤 투 탑 요청")
    }
    
    func setError(_ message: String) {
        errorMessage = message
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func performLoadPosts(isRefresh: Bool) async {
        print("📋 CommunityViewModel: 게시글 로드 시작 - refresh: \(isRefresh)")
        
        await MainActor.run {
            if isRefresh {
                isLoading = true
            } else {
                isLoadingMore = true
            }
            errorMessage = nil
        }
        
        do {
            // 위치 기반 검색을 제거하고 기본 게시글 가져오기 사용
            let result = try await postUseCase.getPostsGeolocation(
                category: currentCategory,
                location: nil,
                maxDistance: nil, // 위치 기반 검색 제거
                limit: pageLimit,
                next: isRefresh ? nil : nextCursor,
                orderBy: currentOrderBy
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
            
            print("✅ CommunityViewModel: 게시글 로드 완료 - \(result.posts.count)개")
            
        } catch let error as PostError {
            if !Task.isCancelled {
                await MainActor.run {
                    if isRefresh {
                        isLoading = false
                    } else {
                        isLoadingMore = false
                    }
                    errorMessage = error.localizedDescription
                    print("❌ CommunityViewModel: PostError - \(error.localizedDescription)")
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
                    print("❌ CommunityViewModel: DecodingError - \(decodingError)")
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
                    print("❌ CommunityViewModel: 게시글 로드 실패 - \(error)")
                }
            }
        }
    }
    
    private func updatePostLike(postId: String, isLiked: Bool) {
        guard let index = posts.firstIndex(where: { $0.postId == postId }) else { return }
        
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
    
    private func updatePostLikeFromNotification(postId: String, isLiked: Bool, likeCount: Int) {
        guard let index = posts.firstIndex(where: { $0.postId == postId }) else { return }
        
        let currentPost = posts[index]
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
            likeCount: likeCount,
            comments: currentPost.comments,
            createdAt: currentPost.createdAt,
            updatedAt: currentPost.updatedAt
        )
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

// MARK: - Notification Extension

extension Notification.Name {
    static let postLikeUpdated = Notification.Name("postLikeUpdated")
}
