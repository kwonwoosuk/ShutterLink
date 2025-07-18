//
//  BannerRouter.swift
//  ShutterLink
//
//  Created by 권우석 on 7/18/25.
//

import Foundation

enum BannerRouter: APIRouter {
    case getMainBanners
    
    var path: String {
        switch self {
        case .getMainBanners:
            return APIConstants.Path.mainBanners
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getMainBanners:
            return .get
        }
    }
    
    var body: Data? {
        return nil
    }
    
    var authorizationType: AuthorizationType {
        return .sesacKey
    }
}
