//
//  Post.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import Foundation
import CoreLocation

// MARK: - Domain Models

struct Post: Identifiable, Equatable, Hashable {
    let id: String
    let postId: String
    let category: String
    let title: String
    let content: String
    let geolocation: PostGeolocation
    let creator: PostCreator
    let files: [String]
    let isLike: Bool
    let likeCount: Int
    let comments: [PostComment]
    let createdAt: Date
    let updatedAt: Date
    
    static func == (lhs: Post, rhs: Post) -> Bool {
        return lhs.postId == rhs.postId &&
               lhs.isLike == rhs.isLike &&
               lhs.likeCount == rhs.likeCount &&
               lhs.comments.count == rhs.comments.count
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(postId)
    }
}

struct PostGeolocation: Codable, Equatable, Hashable {
    let longitude: Double
    let latitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct PostCreator: Codable, Equatable, Hashable {
    let userId: String
    let nick: String
    let name: String
    let introduction: String
    let profileImage: String?
    let hashTags: [String]
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nick, name, introduction, profileImage, hashTags
    }
    
    init(userId: String, nick: String, name: String, introduction: String, profileImage: String?, hashTags: [String]) {
        self.userId = userId
        self.nick = nick
        self.name = name
        self.introduction = introduction
        self.profileImage = profileImage
        self.hashTags = hashTags
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        userId = try container.decode(String.self, forKey: .userId)
        nick = try container.decode(String.self, forKey: .nick)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? nick
        introduction = try container.decodeIfPresent(String.self, forKey: .introduction) ?? ""
        profileImage = try container.decodeIfPresent(String.self, forKey: .profileImage)
        hashTags = try container.decodeIfPresent([String].self, forKey: .hashTags) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(userId, forKey: .userId)
        try container.encode(nick, forKey: .nick)
        try container.encode(name, forKey: .name)
        try container.encode(introduction, forKey: .introduction)
        try container.encodeIfPresent(profileImage, forKey: .profileImage)
        try container.encode(hashTags, forKey: .hashTags)
    }
}

struct PostComment: Identifiable, Equatable, Hashable {
    let id: String
    let commentId: String
    let content: String
    let createdAt: Date
    let creator: PostCreator
    let replies: [PostReply]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(commentId)
    }
}

struct PostReply: Identifiable, Equatable, Hashable {
    let id: String
    let commentId: String
    let content: String
    let createdAt: Date
    let creator: PostCreator
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(commentId)
    }
}

// MARK: - API Request Models

struct PostCreateRequest: Codable {
    let category: String
    let title: String
    let content: String
    let latitude: Double
    let longitude: Double
    let files: [String]
}

struct PostUpdateRequest: Codable {
    let category: String?
    let title: String?
    let content: String?
    let latitude: Double?
    let longitude: Double?
    let files: [String]?
}

struct PostGeolocationRequest {
    let category: String?
    let longitude: Double?
    let latitude: Double?
    let maxDistance: Int?
    let limit: Int
    let next: String?
    let orderBy: String
    
    init(category: String? = nil,
         longitude: Double? = nil,
         latitude: Double? = nil,
         maxDistance: Int? = nil,
         limit: Int = 5,
         next: String? = nil,
         orderBy: String = "createdAt") {
        self.category = category
        self.longitude = longitude
        self.latitude = latitude
        self.maxDistance = maxDistance
        self.limit = limit
        self.next = next
        self.orderBy = orderBy
    }
}

struct PostLikeRequest: Codable {
    let like_status: Bool
}

// MARK: - 댓글 관련 요청/응답 모델

struct CommentCreateRequest: Codable {
    let content: String
    let parent_comment_id: String?
    
    init(content: String, parentCommentId: String? = nil) {
        self.content = content
        self.parent_comment_id = parentCommentId
    }
}

struct CommentUpdateRequest: Codable {
    let content: String
}

struct CommentResponse: Codable {
    let commentId: String
    let content: String
    let createdAt: String
    let creator: PostCreator
    
    enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case content, createdAt, creator
    }
}

// MARK: - API Response Models

struct PostResponse: Codable {
    let postId: String
    let category: String
    let title: String
    let content: String
    let geolocation: PostGeolocation
    let creator: PostCreator
    let files: [String]
    let isLike: Bool
    let likeCount: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case category, title, content, geolocation, creator, files
        case isLike = "is_like"
        case likeCount = "like_count"
        case createdAt, updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        do {
            postId = try container.decode(String.self, forKey: .postId)
            category = try container.decode(String.self, forKey: .category)
            title = try container.decode(String.self, forKey: .title)
            content = try container.decode(String.self, forKey: .content)
            geolocation = try container.decode(PostGeolocation.self, forKey: .geolocation)
            creator = try container.decode(PostCreator.self, forKey: .creator)
            files = try container.decode([String].self, forKey: .files)
            createdAt = try container.decode(String.self, forKey: .createdAt)
            updatedAt = try container.decode(String.self, forKey: .updatedAt)
            
            if let boolValue = try? container.decode(Bool.self, forKey: .isLike) {
                isLike = boolValue
            } else if let intValue = try? container.decode(Int.self, forKey: .isLike) {
                isLike = intValue != 0
            } else {
                isLike = false
            }
            
            if let intValue = try? container.decode(Int.self, forKey: .likeCount) {
                likeCount = intValue
            } else {
                likeCount = 0
            }
            
        } catch {
            print("❌ PostResponse 디코딩 실패: \(error)")
            print("📊 문제가 된 필드: \(error.localizedDescription)")
            throw error
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(postId, forKey: .postId)
        try container.encode(category, forKey: .category)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(geolocation, forKey: .geolocation)
        try container.encode(creator, forKey: .creator)
        try container.encode(files, forKey: .files)
        try container.encode(isLike, forKey: .isLike)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Post Detail Response

struct PostDetailResponse: Codable {
    let postId: String
    let category: String
    let title: String
    let content: String
    let geolocation: PostGeolocation
    let creator: PostCreator
    let files: [String]
    let isLike: Bool
    let likeCount: Int
    let comments: [PostCommentResponse]?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case category, title, content, geolocation, creator, files
        case isLike = "is_like"
        case likeCount = "like_count"
        case comments, createdAt, updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        postId = try container.decode(String.self, forKey: .postId)
        category = try container.decode(String.self, forKey: .category)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        geolocation = try container.decode(PostGeolocation.self, forKey: .geolocation)
        creator = try container.decode(PostCreator.self, forKey: .creator)
        files = try container.decode([String].self, forKey: .files)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        
        if let boolValue = try? container.decode(Bool.self, forKey: .isLike) {
            isLike = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isLike) {
            isLike = intValue != 0
        } else {
            isLike = false
        }
        
        if let intValue = try? container.decode(Int.self, forKey: .likeCount) {
            likeCount = intValue
        } else {
            likeCount = 0
        }
        
        comments = try container.decodeIfPresent([PostCommentResponse].self, forKey: .comments)
    }
}

extension PostDetailResponse {
    func toDomain() -> Post {
        let dateFormatter = ISO8601DateFormatter()
        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: updatedAt) ?? Date()
        
        let domainComments: [PostComment] = comments?.compactMap { comment in
            let commentDate = dateFormatter.date(from: comment.createdAt) ?? Date()
            let domainReplies: [PostReply] = comment.replies.compactMap { reply in
                let replyDate = dateFormatter.date(from: reply.createdAt) ?? Date()
                return PostReply(
                    id: reply.commentId,
                    commentId: reply.commentId,
                    content: reply.content,
                    createdAt: replyDate,
                    creator: reply.creator
                )
            }
            return PostComment(
                id: comment.commentId,
                commentId: comment.commentId,
                content: comment.content,
                createdAt: commentDate,
                creator: comment.creator,
                replies: domainReplies
            )
        } ?? []
        
        return Post(
            id: postId,
            postId: postId,
            category: category,
            title: title,
            content: content,
            geolocation: geolocation,
            creator: creator,
            files: files,
            isLike: isLike,
            likeCount: likeCount,
            comments: domainComments,
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}

struct PostCommentResponse: Codable {
    let commentId: String
    let content: String
    let createdAt: String
    let creator: PostCreator
    let replies: [PostReplyResponse]
    
    enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case content, createdAt, creator, replies
    }
}

struct PostReplyResponse: Codable {
    let commentId: String
    let content: String
    let createdAt: String
    let creator: PostCreator
    
    enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case content, createdAt, creator
    }
}

struct PostListResponse: Codable {
    let data: [PostResponse]
    let nextCursor: String?
    
    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        data = try container.decode([PostResponse].self, forKey: .data)
        if let stringCursor = try? container.decode(String.self, forKey: .nextCursor) {
            nextCursor = (stringCursor == "0" || stringCursor.isEmpty) ? nil : stringCursor
        } else if let intCursor = try? container.decode(Int.self, forKey: .nextCursor) {
            nextCursor = (intCursor == 0) ? nil : String(intCursor)
        } else {
            nextCursor = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(data, forKey: .data)
        try container.encodeIfPresent(nextCursor, forKey: .nextCursor)
    }
}

struct PostFilesResponse: Codable {
    let files: [String]
}

struct PostLikeResponse: Codable {
    let likeStatus: Bool
    
    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
    }
}

// MARK: - Extensions

extension PostResponse {
    func toDomain() -> Post {
        let dateFormatter = ISO8601DateFormatter()
        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: updatedAt) ?? Date()
        
        // 게시글 목록에서는 댓글 정보가 포함되지 않으므로 빈 배열로 설정
        let domainComments: [PostComment] = []
        
        return Post(
            id: postId,
            postId: postId,
            category: category,
            title: title,
            content: content,
            geolocation: geolocation,
            creator: creator,
            files: files,
            isLike: isLike,
            likeCount: likeCount,
            comments: domainComments,
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}

extension CommentResponse {
    func toDomainComment() -> PostComment {
        let dateFormatter = ISO8601DateFormatter()
        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        
        return PostComment(
            id: commentId,
            commentId: commentId,
            content: content,
            createdAt: createdDate,
            creator: creator,
            replies: [] // 새로 생성된 댓글은 대댓글이 없음
        )
    }
}
