//
//  PostUseCase.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import Foundation
import UIKit
import CoreLocation

// MARK: - Protocol

protocol PostUseCase {
    func uploadPostImages(_ images: [UIImage]) async throws -> [String]
    func createPost(category: String, title: String, content: String, location: CLLocationCoordinate2D?, imagePaths: [String]) async throws -> Post
    func getPostsGeolocation(category: String?, location: CLLocationCoordinate2D?, maxDistance: Int?, limit: Int, next: String?, orderBy: String) async throws -> (posts: [Post], nextCursor: String?)
    func searchPosts(title: String) async throws -> [Post]
    func getPostDetail(postId: String) async throws -> Post
    func updatePost(postId: String, category: String?, title: String?, content: String?, location: CLLocationCoordinate2D?, imagePaths: [String]?) async throws -> Post
    func deletePost(postId: String) async throws
    func toggleLike(postId: String, currentLikeStatus: Bool) async throws -> Bool
    func getUserPosts(userId: String, category: String?, limit: Int, next: String?) async throws -> (posts: [Post], nextCursor: String?)
    func getMyLikedPosts(category: String?, limit: Int, next: String?) async throws -> (posts: [Post], nextCursor: String?)

    func createComment(postId: String, content: String, parentCommentId: String?) async throws -> PostComment
    func updateComment(postId: String, commentId: String, content: String) async throws -> PostComment
    func deleteComment(postId: String, commentId: String) async throws
}

// MARK: - Implementation

final class PostUseCaseImpl: PostUseCase {
    private let repository: PostRepository
    
    init(repository: PostRepository = PostRepositoryImpl()) {
        self.repository = repository
    }
    
    func uploadPostImages(_ images: [UIImage]) async throws -> [String] {
        print("📸 PostUseCase: 이미지 압축 및 업로드 시작 - \(images.count)개")
        
        let imageData: [Data] = try images.map { image in
            guard let data = image.jpegData(compressionQuality: 0.9) else {
                throw PostError.imageCompressionFailed
            }
            return data
        }
        
        let imagePaths = try await repository.uploadPostFiles(imageData)
        print("✅ PostUseCase: 이미지 업로드 완료")
        return imagePaths
    }
    
    func createPost(category: String, title: String, content: String, location: CLLocationCoordinate2D?, imagePaths: [String]) async throws -> Post {
        print("📝 PostUseCase: 게시글 작성 시작")
        
        let defaultLatitude = 37.654215
        let defaultLongitude = 127.049914
        
        let request = PostCreateRequest(
            category: category,
            title: title,
            content: content,
            latitude: location?.latitude ?? defaultLatitude,
            longitude: location?.longitude ?? defaultLongitude,
            files: imagePaths
        )
        
        let post = try await repository.createPost(request)
        print("✅ PostUseCase: 게시글 작성 완료")
        return post
    }
    
    func getPostsGeolocation(category: String?, location: CLLocationCoordinate2D?, maxDistance: Int?, limit: Int, next: String?, orderBy: String) async throws -> (posts: [Post], nextCursor: String?) {
        print("📋 PostUseCase: 게시글 목록 조회 시작")
        
        let request = PostGeolocationRequest(
            category: category,
            longitude: location?.longitude,
            latitude: location?.latitude,
            maxDistance: maxDistance,
            limit: limit,
            next: next,
            orderBy: orderBy
        )
        
        let result = try await repository.getPostsGeolocation(request)
        print("✅ PostUseCase: 게시글 목록 조회 완료 - \(result.posts.count)개")
        return result
    }
    
    func searchPosts(title: String) async throws -> [Post] {
        print("🔍 PostUseCase: 게시글 검색 시작 - '\(title)'")
        
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PostError.emptySearchQuery
        }
        
        let posts = try await repository.searchPosts(title: title)
        print("✅ PostUseCase: 게시글 검색 완료 - \(posts.count)개")
        return posts
    }
    
    func getPostDetail(postId: String) async throws -> Post {
        print("📄 PostUseCase: 게시글 상세 조회 시작")
        
        let post = try await repository.getPostDetail(postId: postId)
        print("✅ PostUseCase: 게시글 상세 조회 완료")
        return post
    }
    
    func updatePost(postId: String, category: String?, title: String?, content: String?, location: CLLocationCoordinate2D?, imagePaths: [String]?) async throws -> Post {
        print("✏️ PostUseCase: 게시글 수정 시작")
        
        let request = PostUpdateRequest(
            category: category,
            title: title,
            content: content,
            latitude: location?.latitude,
            longitude: location?.longitude,
            files: imagePaths
        )
        
        let post = try await repository.updatePost(postId: postId, request: request)
        print("✅ PostUseCase: 게시글 수정 완료")
        return post
    }
    
    func deletePost(postId: String) async throws {
        print("🗑️ PostUseCase: 게시글 삭제 시작")
        
        try await repository.deletePost(postId: postId)
        print("✅ PostUseCase: 게시글 삭제 완료")
    }
    
    func toggleLike(postId: String, currentLikeStatus: Bool) async throws -> Bool {
        print("❤️ PostUseCase: 좋아요 토글 시작 - 현재: \(currentLikeStatus)")
        
        let newStatus = !currentLikeStatus
        let result = try await repository.likePost(postId: postId, likeStatus: newStatus)
        
        print("✅ PostUseCase: 좋아요 토글 완료 - 결과: \(result)")
        return result
    }
    
    func getUserPosts(userId: String, category: String?, limit: Int, next: String?) async throws -> (posts: [Post], nextCursor: String?) {
        print("👤 PostUseCase: 유저 게시글 조회 시작")
        
        let result = try await repository.getUserPosts(userId: userId, category: category, limit: limit, next: next)
        print("✅ PostUseCase: 유저 게시글 조회 완료 - \(result.posts.count)개")
        return result
    }
    
    func getMyLikedPosts(category: String?, limit: Int, next: String?) async throws -> (posts: [Post], nextCursor: String?) {
        print("💖 PostUseCase: 내가 좋아요한 게시글 조회 시작")
        
        let result = try await repository.getMyLikedPosts(category: category, limit: String(limit), next: next)
        print("✅ PostUseCase: 내가 좋아요한 게시글 조회 완료 - \(result.posts.count)개")
        return result
    }
    
    // 댓글
    
    func createComment(postId: String, content: String, parentCommentId: String?) async throws -> PostComment {
        print("💬 PostUseCase: 댓글 작성 시작")
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw PostError.emptyCommentContent
        }
        
        guard trimmedContent.count <= 500 else {
            throw PostError.commentTooLong
        }
        
        let comment = try await repository.createComment(postId: postId, content: trimmedContent, parentCommentId: parentCommentId)
        print("✅ PostUseCase: 댓글 작성 완료")
        return comment
    }
    
    func updateComment(postId: String, commentId: String, content: String) async throws -> PostComment {
        print("✏️ PostUseCase: 댓글 수정 시작")
        
        // 내용 검증
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw PostError.emptyCommentContent
        }
        
        guard trimmedContent.count <= 500 else {
            throw PostError.commentTooLong
        }
        
        let comment = try await repository.updateComment(postId: postId, commentId: commentId, content: trimmedContent)
        print("✅ PostUseCase: 댓글 수정 완료")
        return comment
    }
    
    func deleteComment(postId: String, commentId: String) async throws {
        print("🗑️ PostUseCase: 댓글 삭제 시작")
        
        try await repository.deleteComment(postId: postId, commentId: commentId)
        print("✅ PostUseCase: 댓글 삭제 완료")
    }
}
// MARK: - PostError enum for better error handling

enum PostError: Error, LocalizedError {
    case decodingFailed
    case imageCompressionFailed
    case emptySearchQuery
    case networkError(String)
    case unknownError
    case invalidLocation
    case categoryNotAllowed
    case emptyCommentContent
    case commentTooLong
    
    var errorDescription: String? {
        switch self {
        case .decodingFailed:
            return "응답 데이터를 처리하는데 실패했습니다."
        case .imageCompressionFailed:
            return "이미지 압축에 실패했습니다."
        case .emptySearchQuery:
            return "검색어를 입력해주세요."
        case .networkError(let message):
            return "네트워크 오류: \(message)"
        case .unknownError:
            return "알 수 없는 오류가 발생했습니다."
        case .invalidLocation:
            return "유효하지 않은 위치 정보입니다."
        case .categoryNotAllowed:
            return "사용할 수 없는 카테고리입니다. (. , ? * - @ 제외)"
        case .emptyCommentContent:
            return "댓글 내용을 입력해주세요."
        case .commentTooLong:
            return "댓글은 500자 이내로 입력해주세요."
        }
    }
}
