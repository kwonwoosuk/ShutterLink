//
//  UserRouter.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import Foundation

enum UserRouter: APIRouter {
    case getTodayAuthor
    
    var path: String {
        switch self {
        case .getTodayAuthor:
            return "/v1/users/today-author"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getTodayAuthor:
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
