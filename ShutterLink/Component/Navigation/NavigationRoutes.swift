//
//  NavigationRoutes.swift
//  ShutterLink
//
//  Created by 권우석 on 6/3/25.
//

import Foundation

// MARK: - Route 프로토콜
protocol Route: Hashable, Identifiable {
    var id: String { get }
}

// MARK: - 홈/피드 탭 라우트 (필터 관련)
enum FilterRoute: Route {
    case filterDetail(filterId: String)
    
    var id: String {
        switch self {
        case .filterDetail(let filterId):
            return "filterDetail_\(filterId)"
        }
    }
}

// MARK: - 검색 탭 라우트 (유저 관련)
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

// MARK: - 프로필 탭 라우트
enum ProfileRoute: Route {
    case editProfile
    
    var id: String {
        switch self {
        case .editProfile:
            return "editProfile"
        }
    }
}

// MARK: - 탭 식별자
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
