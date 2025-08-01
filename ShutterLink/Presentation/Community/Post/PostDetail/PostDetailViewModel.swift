//
//  PostDetailViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import SwiftUI
import Combine

final class PostDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var post: Post?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isDeleted = false
    
    // MARK: - Private Properties
    
    private let postUseCase: PostUseCase
    private var loadTask: Task<Void, Never>?
    private var likeTask: Task<Void, Never>?
    private var deleteTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(postUseCase: PostUseCase = PostUseCaseImpl()) {
        self.postUseCase = postUseCase
        
        // 좋아요 동기화를 위한 NotificationCenter 구독
        NotificationCenter.default.publisher(for: .postLikeUpdated)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let postId = userInfo["postId"] as? String,
                   let isLiked = userInfo["isLiked"] as? Bool,
                   let likeCount = userInfo["likeCount"] as? Int,
                   self?.post?.postId == postId {
                    self?.updatePostLikeFromNotification(isLiked: isLiked, likeCount: likeCount)
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancelAllTasks()
    }
    
    // MARK: - Public Methods
    
    func loadPostDetail(postId: String) {
        loadTask?.cancel()
        
        loadTask = Task {
            await performLoadPostDetail(postId: postId)
        }
    }
    
    func toggleLike() async {
        guard let currentPost = post else { return }
        
        likeTask?.cancel()
        
        likeTask = Task {
            do {
                // 즉시 UI 업데이트 (optimistic update)
                await MainActor.run {
                    updatePostLike(isLiked: !currentPost.isLike)
                }
                
                let newLikeStatus = try await postUseCase.toggleLike(
                    postId: currentPost.postId,
                    currentLikeStatus: currentPost.isLike
                )
                
                await MainActor.run {
                    updatePostLike(isLiked: newLikeStatus)
                    
                    // 다른 화면과 동기화를 위한 노티피케이션 발송
                    if let updatedPost = post {
                        NotificationCenter.default.post(
                            name: .postLikeUpdated,
                            object: nil,
                            userInfo: [
                                "postId": currentPost.postId,
                                "isLiked": updatedPost.isLike,
                                "likeCount": updatedPost.likeCount
                            ]
                        )
                    }
                }
                
                print("✅ PostDetailViewModel: 좋아요 상태 업데이트 완료 - \(newLikeStatus)")
                
            } catch {
                // 실패시 원래 상태로 롤백
                await MainActor.run {
                    updatePostLike(isLiked: currentPost.isLike)
                    setError("좋아요 처리에 실패했습니다: \(error.localizedDescription)")
                }
                print("❌ PostDetailViewModel: 좋아요 처리 실패 - \(error)")
            }
        }
    }
    
    func deletePost() {
        guard let currentPost = post else { return }
        
        deleteTask?.cancel()
        
        deleteTask = Task {
            await performDeletePost(postId: currentPost.postId)
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func setError(_ message: String) {
        errorMessage = message
    }
    
    // MARK: - 댓글 관련 메서드
    
    func createComment(content: String, parentCommentId: String?) async throws -> PostComment {
        guard let currentPost = post else {
            throw NSError(domain: "PostDetailViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "게시글 정보가 없습니다."])
        }
        
        do {
            let response = try await postUseCase.createComment(
                postId: currentPost.postId,
                content: content,
                parentCommentId: parentCommentId
            )
            
            print("✅ PostDetailViewModel: 댓글 작성 성공")
            
            // API 응답 그대로 사용 (createdAt을 String으로 유지)
            let newComment = PostComment(
                id: response.commentId,
                commentId: response.commentId,
                content: response.content,
                createdAt: response.createdAt, // String 타입 그대로 사용
                creator: response.creator,
                replies: []
            )
            
            return newComment
            
        } catch {
            print("❌ PostDetailViewModel: 댓글 작성 실패 - \(error)")
            throw error
        }
    }
    
    func updateComment(commentId: String, content: String) async throws -> PostComment {
        guard let currentPost = post else {
            throw NSError(domain: "PostDetailViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "게시글 정보가 없습니다."])
        }
        
        do {
            let response = try await postUseCase.updateComment(
                postId: currentPost.postId,
                commentId: commentId,
                content: content
            )
            
            print("✅ PostDetailViewModel: 댓글 수정 성공")
            
            
            var existingReplies: [PostReply] = []
            if let existingComment = currentPost.comments.first(where: { $0.commentId == commentId }) {
                existingReplies = existingComment.replies
            }
            
            // API 응답 그대로 사용하되, 기존 replies 보존
            let updatedComment = PostComment(
                id: response.commentId,
                commentId: response.commentId,
                content: response.content,
                createdAt: response.createdAt, // String 타입 그대로 사용
                creator: response.creator,
                replies: existingReplies // 기존 replies 보존
            )
            
            return updatedComment
            
        } catch {
            print("❌ PostDetailViewModel: 댓글 수정 실패 - \(error)")
            throw error
        }
    }
    
    func deleteComment(commentId: String) async throws {
        guard let currentPost = post else {
            throw NSError(domain: "PostDetailViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "게시글 정보가 없습니다."])
        }
        
        do {
            // 댓글 삭제 API 호출
            try await postUseCase.deleteComment(
                postId: currentPost.postId,
                commentId: commentId
            )
            
            print("✅ PostDetailViewModel: 댓글 삭제 성공 - \(commentId)")
            
        } catch {
            print("❌ PostDetailViewModel: 댓글 삭제 실패 - \(error)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func performLoadPostDetail(postId: String) async {
        print("📋 PostDetailViewModel: 게시글 상세 로드 시작 - \(postId)")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let postDetail = try await postUseCase.getPostDetail(postId: postId)
            
            try Task.checkCancellation()
            
            await MainActor.run {
                post = postDetail
                isLoading = false
            }
            
            print("✅ PostDetailViewModel: 게시글 상세 로드 완료")
            
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "게시글을 불러오는데 실패했습니다: \(error.localizedDescription)"
                }
                print("❌ PostDetailViewModel: 게시글 상세 로드 실패 - \(error)")
            }
        }
    }
    
    private func performDeletePost(postId: String) async {
        print("🗑️ PostDetailViewModel: 게시글 삭제 시작 - \(postId)")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await postUseCase.deletePost(postId: postId)
            
            try Task.checkCancellation()
            
            await MainActor.run {
                isLoading = false
                isDeleted = true
            }
            
            print("✅ PostDetailViewModel: 게시글 삭제 완료")
            
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "게시글 삭제에 실패했습니다: \(error.localizedDescription)"
                }
                print("❌ PostDetailViewModel: 게시글 삭제 실패 - \(error)")
            }
        }
    }
    
    private func updatePostLike(isLiked: Bool) {
        guard let currentPost = post else { return }
        
        let likeCountDelta = isLiked ? 1 : -1
        let newLikeCount = max(0, currentPost.likeCount + likeCountDelta)
        
        post = Post(
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
    
    private func updatePostLikeFromNotification(isLiked: Bool, likeCount: Int) {
        guard let currentPost = post else { return }
        
        post = Post(
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
    
    private func cancelAllTasks() {
        loadTask?.cancel()
        likeTask?.cancel()
        deleteTask?.cancel()
    }
}
