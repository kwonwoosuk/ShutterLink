//
//  PostRouter.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import Foundation

enum PostRouter: APIRouter {
    case uploadPostFiles([Data])
    case createPost(PostCreateRequest)
    case getPostsGeolocation(PostGeolocationRequest)
    case searchPosts(title: String)
    case getPostDetail(postId: String)
    case updatePost(postId: String, request: PostUpdateRequest)
    case deletePost(postId: String)
    case likePost(postId: String, likeStatus: Bool)
    case getUserPosts(userId: String, category: String?, limit: Int, next: String?)
    case getMyLikedPosts(category: String?, limit: String?, next: String?)
    
    case createComment(postId: String, request: CommentCreateRequest)
    case updateComment(postId: String, commentId: String, request: CommentUpdateRequest)
    case deleteComment(postId: String, commentId: String)
    
    var path: String {
        switch self {
        case .uploadPostFiles:
            return APIConstants.Path.postsFiles
        case .createPost, .getPostsGeolocation:
            return APIConstants.Path.posts
        case .searchPosts:
            return APIConstants.Path.postsSearch
        case .getPostDetail(let postId), .updatePost(let postId, _), .deletePost(let postId):
            return APIConstants.Path.postDetail(postId)
        case .likePost(let postId, _):
            return APIConstants.Path.postLike(postId)
        case .getUserPosts(let userId, _, _, _):
            return APIConstants.Path.userPosts(userId)
        case .getMyLikedPosts:
            return APIConstants.Path.postsLikesMe
        case .createComment(let postId, _):
            return APIConstants.Path.postComments(postId)
        case .updateComment(let postId, let commentId, _), .deleteComment(let postId, let commentId):
            return APIConstants.Path.postComment(postId, commentId)
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .uploadPostFiles, .createPost, .likePost, .createComment:
            return .post
        case .getPostsGeolocation, .searchPosts, .getPostDetail, .getUserPosts, .getMyLikedPosts:
            return .get
        case .updatePost, .updateComment:
            return .put
        case .deletePost, .deleteComment:
            return .delete
        }
    }
    
    var contentType: String {
        switch self {
        case .uploadPostFiles:
            return APIConstants.ContentType.multipartFormData
        default:
            return APIConstants.ContentType.json
        }
    }
    
    var body: Data? {
        switch self {
        case .createPost(let request):
            return try? JSONEncoder().encode(request)
        case .updatePost(_, let request):
            return try? JSONEncoder().encode(request)
        case .likePost(_, let likeStatus):
            let likeRequest = PostLikeRequest(like_status: likeStatus)
            return try? JSONEncoder().encode(likeRequest)
        case .createComment(_, let request):
            return try? JSONEncoder().encode(request)
        case .updateComment(_, _, let request):
            return try? JSONEncoder().encode(request)
        default:
            return nil
        }
    }
    
    var queryItems: [URLQueryItem]? {
        switch self {
        case .getPostsGeolocation(let request):
            var items: [URLQueryItem] = []
            
            if let category = request.category, !category.isEmpty {
                items.append(URLQueryItem(name: "category", value: category))
            }
            if let longitude = request.longitude {
                items.append(URLQueryItem(name: "longitude", value: String(longitude)))
            }
            if let latitude = request.latitude {
                items.append(URLQueryItem(name: "latitude", value: String(latitude)))
            }
            if let maxDistance = request.maxDistance {
                items.append(URLQueryItem(name: "maxDistance", value: String(maxDistance)))
            }
            items.append(URLQueryItem(name: "limit", value: String(request.limit)))
            if let next = request.next, !next.isEmpty {
                items.append(URLQueryItem(name: "next", value: next))
            }
            items.append(URLQueryItem(name: "order_by", value: request.orderBy))
            
            return items
            
        case .searchPosts(let title):
            return [URLQueryItem(name: "title", value: title)]
            
        case .getUserPosts(_, let category, let limit, let next):
            var items: [URLQueryItem] = []
            if let category = category, !category.isEmpty {
                items.append(URLQueryItem(name: "category", value: category))
            }
            items.append(URLQueryItem(name: "limit", value: String(limit)))
            if let next = next, !next.isEmpty {
                items.append(URLQueryItem(name: "next", value: next))
            }
            return items
            
        case .getMyLikedPosts(let category, let limit, let next):
            var items: [URLQueryItem] = []
            if let category = category, !category.isEmpty {
                items.append(URLQueryItem(name: "category", value: category))
            }
            if let limit = limit, !limit.isEmpty {
                items.append(URLQueryItem(name: "limit", value: limit))
            }
            if let next = next, !next.isEmpty {
                items.append(URLQueryItem(name: "next", value: next))
            }
            return items
            
        default:
            return nil
        }
    }
    
    var authorizationType: AuthorizationType {
        return .accessToken
    }
}
