//
//  FilterRouter.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import Foundation

enum FilterRouter: APIRouter {
    case getTodayFilter
    case getHotTrendFilters
    case getFilters(next: String, limit: Int, category: String?, orderBy: String)
    case likeFilter(filterId: String, likeStatus: Bool)
    case getFilterDetail(filterId: String)
    
    var path: String {
        switch self {
        case .getTodayFilter:
            return APIConstants.Path.todayFilter
        case .getHotTrendFilters:
            return APIConstants.Path.hotTrendFilters
        case .getFilters:
            return APIConstants.Path.filters
        case .likeFilter(let filterId, _):
            return APIConstants.Path.filterLike(filterId)
        case .getFilterDetail(let filterId):
            return APIConstants.Path.filterDetail(filterId)
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getTodayFilter, .getHotTrendFilters, .getFilters, .getFilterDetail:
            return .get
        case .likeFilter:
            return .post
        }
    }
    
    var body: Data? {
        switch self {
        case .likeFilter(_, let likeStatus):
            let request = LikeRequest(like_status: likeStatus)
            return try? JSONEncoder().encode(request)
        default:
            return nil
        }
    }
    
    var queryItems: [URLQueryItem]? {
        switch self {
        case .getFilters(let next, let limit, let category, let orderBy):
            var items: [URLQueryItem] = []
            if !next.isEmpty {
                items.append(URLQueryItem(name: "next", value: next))
            }
            items.append(URLQueryItem(name: "limit", value: String(limit)))
            if let category = category, !category.isEmpty {
                items.append(URLQueryItem(name: "category", value: category))
            }
            items.append(URLQueryItem(name: "order_by", value: orderBy))
            return items
        default:
            return nil
        }
    }
    
    var authorizationType: AuthorizationType {
        return .accessToken
    }
}
