//
//  CommunityViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import SwiftUI
import Combine
import CoreLocation

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
    private var currentDistance: Int = 300 // 기본 300미터
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
    
    func filterByCategory(_ category: String?, distance: Int? = nil, orderBy: String? = nil) {
        currentCategory = category
        // 현재는 위치 기반 검색을 사용하지 않으므로 distance는 무시
        // if let distance = distance {
        //     currentDistance = distance
        // }
        if let orderBy = orderBy {
            currentOrderBy = orderBy
        }
        resetPagination()
        loadPosts()
    }
    
    func updateDistance(_ distance: Int) {
        // 현재는 위치 기반 검색을 사용하지 않으므로 distance 업데이트 무시
        // currentDistance = distance
        // resetPagination()
        // loadPosts()
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
                await MainActor.run {
                    updatePostLike(postId: post.postId, isLiked: !post.isLike)
                }
                
                let newLikeStatus = try await postUseCase.toggleLike(
                    postId: post.postId,
                    currentLikeStatus: post.isLike
                )
                
                await MainActor.run {
                    updatePostLike(postId: post.postId, isLiked: newLikeStatus)
                }
                
                print("✅ CommunityViewModel: 좋아요 상태 업데이트 완료 - \(newLikeStatus)")
                
            } catch {
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
            // 위치 기반 검색이 아닌 경우 maxDistance를 nil로 설정
            let maxDistance: Int? = nil // 위치 기반이 아닐 때는 maxDistance 제외
            
            let result = try await postUseCase.getPostsGeolocation(
                category: currentCategory,
                location: nil, // 기본 위치 사용
                maxDistance: maxDistance, // 위치 기반이 아니므로 nil
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
        
        let updatedPost = Post(
            id: currentPost.id,
            postId: currentPost.postId,
            category: currentPost.category,
            title: currentPost.title,
            content: currentPost.content,
            geolocation: currentPost.geolocation,
            creator: currentPost.creator,
            files: currentPost.files,
            isLike: isLiked,
            likeCount: max(0, currentPost.likeCount + likeCountDelta),
            comments: currentPost.comments,
            createdAt: currentPost.createdAt,
            updatedAt: currentPost.updatedAt
        )
        
        posts[index] = updatedPost
    }
    
    private func resetPagination() {
        nextCursor = nil
        hasMorePosts = true
    }
    
    private func cancelAllTasks() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        likeTask?.cancel()
    }
    
    private func cancelLoadTasks() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
    }
    
//    private func logDecodingError(_ error: DecodingError) {
//        switch error {
//        case .typeMismatch(let type, let context):
//            print("🔍 타입 불일치:")
//            print("   예상 타입: \(type)")
//            print("   경로: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
//            print("   설명: \(context.debugDescription)")
//            
//        case .keyNotFound(let key, let context):
//            print("🔍 키 누락:")
//            print("   누락된 키: \(key.stringValue)")
//            print("   경로: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
//            
//        case .valueNotFound(let type, let context):
//            print("🔍 값 누락:")
//            print("   타입: \(type)")
//            print("   경로: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
//            
//        case .dataCorrupted(let context):
//            print("🔍 데이터 손상:")
//            print("   경로: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
//            print("   설명: \(context.debugDescription)")
//            
//        @unknown default:
//            print("🔍 알 수 없는 디코딩 에러: \(error)")
//        }
//    }
}
