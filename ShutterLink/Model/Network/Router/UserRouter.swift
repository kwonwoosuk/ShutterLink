//
//  UserRouter.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import Foundation

enum UserRouter: APIRouter {
    case getTodayAuthor
    case searchUsers(nick: String)
    case getUserFilters(userId: String, category: String?, next: String, limit: Int)
    
    var path: String {
        switch self {
        case .getTodayAuthor:
            return APIConstants.Path.todayAuthor
        case .searchUsers:
            return APIConstants.Path.searchUsers
        case .getUserFilters(let userId, _, _, _):
            return APIConstants.Path.userFilters(userId)
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getTodayAuthor, .searchUsers, .getUserFilters:
            return .get
        }
    }
    
    var body: Data? {
        return nil
    }
    
    var queryItems: [URLQueryItem]? {
        switch self {
        case .searchUsers(let nick):
            return [URLQueryItem(name: "nick", value: nick)]
        case .getUserFilters(_, let category, let next, let limit):
            var items: [URLQueryItem] = []
            if let category = category, !category.isEmpty {
                items.append(URLQueryItem(name: "category", value: category))
            }
            if !next.isEmpty {
                items.append(URLQueryItem(name: "next", value: next))
            }
            items.append(URLQueryItem(name: "limit", value: String(limit)))
            return items
        default:
            return nil
        }
    }
    
    var authorizationType: AuthorizationType {
        return .accessToken
    }
}
