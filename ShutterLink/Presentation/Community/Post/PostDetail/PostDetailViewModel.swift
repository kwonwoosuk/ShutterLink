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
    
    // MARK: - Initialization
    
    init(postUseCase: PostUseCase = PostUseCaseImpl()) {
        self.postUseCase = postUseCase
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
                await MainActor.run {
                    updatePostLike(isLiked: !currentPost.isLike)
                }
                
                let newLikeStatus = try await postUseCase.toggleLike(
                    postId: currentPost.postId,
                    currentLikeStatus: currentPost.isLike
                )
                
                await MainActor.run {
                    updatePostLike(isLiked: newLikeStatus)
                }
                
                print("✅ PostDetailViewModel: 좋아요 상태 업데이트 완료 - \(newLikeStatus)")
                
            } catch {
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
    
    // MARK: - 댓글 관련 메서드
    
    func createComment(content: String, parentCommentId: String?) async throws -> PostComment {
        guard let currentPost = post else {
            throw NSError(domain: "PostDetailViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "게시글 정보가 없습니다."])
        }
        
        return try await postUseCase.createComment(
            postId: currentPost.postId,
            content: content,
            parentCommentId: parentCommentId
        )
    }
    
    func updateComment(commentId: String, content: String) async throws -> PostComment {
        guard let currentPost = post else {
            throw NSError(domain: "PostDetailViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "게시글 정보가 없습니다."])
        }
        
        return try await postUseCase.updateComment(
            postId: currentPost.postId,
            commentId: commentId,
            content: content
        )
    }
    
    func deleteComment(commentId: String) async throws {
        guard let currentPost = post else {
            throw NSError(domain: "PostDetailViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "게시글 정보가 없습니다."])
        }
        
        try await postUseCase.deleteComment(
            postId: currentPost.postId,
            commentId: commentId
        )
    }
    
    func setError(_ message: String) {
        errorMessage = message
    }
    
    // MARK: - Private Methods
    
    private func performLoadPostDetail(postId: String) async {
        print("📄 PostDetailViewModel: 게시글 상세 로드 시작 - \(postId)")
        
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
    
    
    private func cancelAllTasks() {
        loadTask?.cancel()
        likeTask?.cancel()
        deleteTask?.cancel()
    }
}
