//
//  NavigationRoutes.swift
//  ShutterLink
//
//  Created by 권우석 on 6/3/25.
//

import Foundation
import UIKit

protocol Route: Hashable, Identifiable {
    var id: String { get }
}

enum FilterRoute: Route {
    case filterDetail(filterId: String)
    case userDetail(userId: String, userInfo: CreatorInfo)
    
    var id: String {
        switch self {
        case .filterDetail(let filterId):
            return "filterDetail_\(filterId)"
        case .userDetail(let userId, _):
            return "userDetail_\(userId)"
        }
    }
}

enum UserRoute: Route {
    case userDetail(userId: String, userInfo: UserInfo?)
    case userFilters(userId: String, userNick: String)
    
    var id: String {
        switch self {
        case .userDetail(let userId, _):
            return "userDetail_\(userId)"
        case .userFilters(let userId, _):
            return "userFilters_\(userId)"
        }
    }
}

enum ProfileRoute: Route {
    case editProfile
    case likedFilters
    case filterDetail(filterId: String)
    case chatRoomList
    case chatView(roomId: String, participantInfo: Users)
    case filterManagement
    case cacheManagement
    case community
    case postDetail(postId: String)
    case createPost
    case editPost(post: Post)
    case myLikedPosts
    case userPosts(userId: String, userNick: String)
    
    var id: String {
        switch self {
        case .editProfile:
            return "editProfile"
        case .likedFilters:
            return "likedFilters"
        case .filterDetail(let filterId):
            return "filterDetail_\(filterId)"
        case .chatRoomList:
            return "chatRoomList"
        case .chatView(let roomId, _):
            return "chatView_\(roomId)"
        case .filterManagement:
            return "filterManagement"
        case .cacheManagement:
            return "cacheManagement"
        case .community:
            return "community"
        case .postDetail(let postId):
            return "postDetail_\(postId)"
        case .createPost:
            return "createPost"
        case .editPost(let post):
            return "editPost_\(post.postId)"
        case .myLikedPosts:
            return "myLikedPosts"
        case .userPosts(let userId, _):
            return "userPosts_\(userId)"
        }
    }
}

enum MakeRoute: Route {
    case create
    case editFilter(originalImage: UIImage?)
    
    var id: String {
        switch self {
        case .create:
            return "create"
        case .editFilter:
            return "editFilter"
        }
    }
}

enum CommunityRoute: Route {
    case postDetail(postId: String)
    case createPost
    case editPost(post: Post)
    case myLikedPosts
    case userPosts(userId: String, userNick: String)
    
    var id: String {
        switch self {
        case .postDetail(let postId):
            return "postDetail_\(postId)"
        case .createPost:
            return "createPost"
        case .editPost(let post):
            return "editPost_\(post.postId)"
        case .myLikedPosts:
            return "myLikedPosts"
        case .userPosts(let userId, _):
            return "userPosts_\(userId)"
        }
    }
}

enum Tab: Int, CaseIterable {
    case home = 0
    case feed = 1
    case filter = 2
    case search = 3
    case profile = 4
    
    var title: String {
        switch self {
        case .home: return "HOME"
        case .feed: return "FEED"
        case .filter: return "FILTER"
        case .search: return "SEARCH"
        case .profile: return "PROFILE"
        }
    }
}
