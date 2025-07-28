//
//  PostRepository.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import Foundation

// MARK: - Protocol

protocol PostRepository {
    func uploadPostFiles(_ images: [Data]) async throws -> [String]
    func createPost(_ request: PostCreateRequest) async throws -> Post
    func getPostsGeolocation(_ request: PostGeolocationRequest) async throws -> (posts: [Post], nextCursor: String?)
    func searchPosts(title: String) async throws -> [Post]
    func getPostDetail(postId: String) async throws -> Post
    func updatePost(postId: String, request: PostUpdateRequest) async throws -> Post
    func deletePost(postId: String) async throws
    func likePost(postId: String, likeStatus: Bool) async throws -> Bool
    func getUserPosts(userId: String, category: String?, limit: Int, next: String?) async throws -> (posts: [Post], nextCursor: String?)
    func getMyLikedPosts(category: String?, limit: String?, next: String?) async throws -> (posts: [Post], nextCursor: String?)
    
    func createComment(postId: String, content: String, parentCommentId: String?) async throws -> PostComment
    func updateComment(postId: String, commentId: String, content: String) async throws -> PostComment
    func deleteComment(postId: String, commentId: String) async throws
}

// MARK: - Implementation

final class PostRepositoryImpl: PostRepository {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
    func uploadPostFiles(_ images: [Data]) async throws -> [String] {
        print("🌐 PostRepository: 이미지 파일 업로드 시작 - \(images.count)개")
        
        let imageFields = images.enumerated().map { index, data in
            return (fieldName: "files", data: data, filename: "image_\(Date().timeIntervalSince1970)_\(index).jpg")
        }
        
        let router = PostRouter.uploadPostFiles(images)
        let data = try await networkManager.uploadMultipleImages(router, images: imageFields)
        
        let response = try JSONDecoder().decode(PostFilesResponse.self, from: data)
        print("✅ PostRepository: 이미지 업로드 성공 - \(response.files)")
        return response.files
    }
    
    func createPost(_ request: PostCreateRequest) async throws -> Post {
        print("🌐 PostRepository: 게시글 작성 시작")
        
        let router = PostRouter.createPost(request)
        
        do {
            let response = try await networkManager.request(router, type: PostDetailResponse.self)
            let post = response.toDomain()
            
            print("✅ PostRepository: 게시글 작성 성공 - \(post.postId)")
            return post
            
        } catch let DecodingError.typeMismatch(type, context) {
            print("❌ 타입 불일치 에러:")
            print("   예상 타입: \(type)")
            print("   경로: \(context.codingPath)")
            print("   설명: \(context.debugDescription)")
            throw PostError.decodingFailed
            
        } catch let DecodingError.keyNotFound(key, context) {
            print("❌ 키를 찾을 수 없음:")
            print("   누락된 키: \(key)")
            print("   경로: \(context.codingPath)")
            print("   설명: \(context.debugDescription)")
            throw PostError.decodingFailed
            
        } catch {
            print("❌ 알 수 없는 디코딩 에러: \(error)")
            throw PostError.decodingFailed
        }
    }
    
    func getPostsGeolocation(_ request: PostGeolocationRequest) async throws -> (posts: [Post], nextCursor: String?) {
        print("🌐 PostRepository: 게시글 목록 조회 시작")
        
        let router = PostRouter.getPostsGeolocation(request)
        
        do {
            let response = try await networkManager.request(router, type: PostListResponse.self)
            let posts = response.data.map { $0.toDomain() }
            
            print("✅ PostRepository: 게시글 목록 조회 성공 - \(posts.count)개")
            return (posts: posts, nextCursor: response.nextCursor)
            
        } catch let DecodingError.typeMismatch(type, context) {
            print("❌ 타입 불일치 에러:")
            print("   예상 타입: \(type)")
            print("   경로: \(context.codingPath)")
            print("   설명: \(context.debugDescription)")
            throw PostError.decodingFailed
            
        } catch let DecodingError.keyNotFound(key, context) {
            print("❌ 키를 찾을 수 없음:")
            print("   누락된 키: \(key)")
            print("   경로: \(context.codingPath)")
            throw PostError.decodingFailed
            
        } catch {
            print("❌ 알 수 없는 디코딩 에러: \(error)")
            throw PostError.decodingFailed
        }
    }
    
    func searchPosts(title: String) async throws -> [Post] {
        print("🌐 PostRepository: 게시글 검색 시작 - '\(title)'")
        
        let router = PostRouter.searchPosts(title: title)
        let response = try await networkManager.request(router, type: PostListResponse.self)
        let posts = response.data.map { $0.toDomain() }
        
        print("✅ PostRepository: 게시글 검색 성공 - \(posts.count)개")
        return posts
    }
    
    func getPostDetail(postId: String) async throws -> Post {
        print("🌐 PostRepository: 게시글 상세 조회 시작 - \(postId)")
        
        let router = PostRouter.getPostDetail(postId: postId)
        let response = try await networkManager.request(router, type: PostDetailResponse.self)
        let post = response.toDomain()
        
        print("✅ PostRepository: 게시글 상세 조회 성공")
        return post
    }
    
    func updatePost(postId: String, request: PostUpdateRequest) async throws -> Post {
        print("🌐 PostRepository: 게시글 수정 시작 - \(postId)")
        
        let router = PostRouter.updatePost(postId: postId, request: request)
        let response = try await networkManager.request(router, type: PostDetailResponse.self)
        let post = response.toDomain()
        
        print("✅ PostRepository: 게시글 수정 성공")
        return post
    }
    
    func deletePost(postId: String) async throws {
        print("🌐 PostRepository: 게시글 삭제 시작 - \(postId)")
        
        let router = PostRouter.deletePost(postId: postId)
        _ = try await networkManager.request(router, type: EmptyResponse.self)
        
        print("✅ PostRepository: 게시글 삭제 성공")
    }
    
    func likePost(postId: String, likeStatus: Bool) async throws -> Bool {
        print("🌐 PostRepository: 게시글 좋아요 \(likeStatus ? "추가" : "취소") - \(postId)")
        
        let router = PostRouter.likePost(postId: postId, likeStatus: likeStatus)
        let response = try await networkManager.request(router, type: PostLikeResponse.self)
        
        print("✅ PostRepository: 게시글 좋아요 처리 성공 - \(response.likeStatus)")
        return response.likeStatus
    }
    
    func getUserPosts(userId: String, category: String?, limit: Int, next: String?) async throws -> (posts: [Post], nextCursor: String?) {
        print("🌐 PostRepository: 유저 게시글 조회 시작 - \(userId)")
        
        let router = PostRouter.getUserPosts(userId: userId, category: category, limit: limit, next: next)
        let response = try await networkManager.request(router, type: PostListResponse.self)
        let posts = response.data.map { $0.toDomain() }
        
        print("✅ PostRepository: 유저 게시글 조회 성공 - \(posts.count)개")
        return (posts: posts, nextCursor: response.nextCursor)
    }
    
    func getMyLikedPosts(category: String?, limit: String?, next: String?) async throws -> (posts: [Post], nextCursor: String?) {
        print("🌐 PostRepository: 내가 좋아요한 게시글 조회 시작")
        
        let router = PostRouter.getMyLikedPosts(category: category, limit: limit, next: next)
        let response = try await networkManager.request(router, type: PostListResponse.self)
        let posts = response.data.map { $0.toDomain() }
        
        print("✅ PostRepository: 내가 좋아요한 게시글 조회 성공 - \(posts.count)개")
        return (posts: posts, nextCursor: response.nextCursor)
    }
    
    // 댓글
    func createComment(postId: String, content: String, parentCommentId: String?) async throws -> PostComment {
        print("🌐 PostRepository: 댓글 작성 시작 - postId: \(postId)")
        
        let request = CommentCreateRequest(content: content, parentCommentId: parentCommentId)
        let router = PostRouter.createComment(postId: postId, request: request)
        let response = try await networkManager.request(router, type: CommentResponse.self)
        let comment = response.toDomainComment()
        
        print("✅ PostRepository: 댓글 작성 성공 - commentId: \(comment.commentId)")
        return comment
    }
    
    func updateComment(postId: String, commentId: String, content: String) async throws -> PostComment {
        print("🌐 PostRepository: 댓글 수정 시작 - commentId: \(commentId)")
        
        let request = CommentUpdateRequest(content: content)
        let router = PostRouter.updateComment(postId: postId, commentId: commentId, request: request)
        let response = try await networkManager.request(router, type: CommentResponse.self)
        let comment = response.toDomainComment()
        
        print("✅ PostRepository: 댓글 수정 성공")
        return comment
    }
    
    func deleteComment(postId: String, commentId: String) async throws {
        print("🌐 PostRepository: 댓글 삭제 시작 - commentId: \(commentId)")
        
        let router = PostRouter.deleteComment(postId: postId, commentId: commentId)
        _ = try await networkManager.request(router, type: EmptyResponse.self)
        
        print("✅ PostRepository: 댓글 삭제 성공")
    }
}
