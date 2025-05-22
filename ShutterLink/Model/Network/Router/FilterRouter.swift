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
    
    var path: String {
        switch self {
        case .getTodayFilter:
            return "/v1/filters/today-filter"
        case .getHotTrendFilters:
            return "/v1/filters/hot-trend"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getTodayFilter, .getHotTrendFilters:
            return .get
        }
    }
    
    var body: Data? {
        return nil
    }
    
    var authorizationType: AuthorizationType {
        return .accessToken
    }
}
