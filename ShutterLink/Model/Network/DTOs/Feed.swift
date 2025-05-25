//
//  Feed.swift
//  ShutterLink
//
//  Created by 권우석 on 5/24/25.
//

import Foundation

// MARK: - 필터 목록 응답 모델
struct FilterListResponse: Decodable {
    let data: [FilterItem]
    let next_cursor: String
}

// MARK: - 좋아요 요청 모델
struct LikeRequest: Encodable {
    let like_status: Bool
}

// MARK: - 좋아요 응답 모델
struct LikeResponse: Decodable {
    let like_status: Bool
}

// MARK: - 카테고리 enum
enum FilterCategory: String, CaseIterable {
    case food = "푸드"
    case people = "인물"
    case landscape = "풍경"
    case night = "야경"
    case star = "별"
    
    var title: String {
        switch self {
        case .food: return "푸드"
        case .people: return "인물"
        case .landscape: return "풍경"
        case .night: return "야경"
        case .star: return "별"
        }
    }
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .people: return "person.2"
        case .landscape: return "photo"
        case .night: return "moon.stars"
        case .star: return "star"
        }
    }
}

// MARK: - 정렬 옵션 enum
enum FilterSortOption: String, CaseIterable {
    case popularity = "popularity"
    case purchase = "purchase"
    case latest = "latest"
    
    var title: String {
        switch self {
        case .popularity: return "인기순"
        case .purchase: return "구매순"
        case .latest: return "최신순"
        }
    }
}

// MARK: - 보기 모드 enum
enum FeedViewMode {
    case list
    case block
}
