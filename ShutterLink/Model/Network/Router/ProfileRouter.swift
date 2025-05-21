//
//  ProfileRouter.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import Foundation

enum ProfileRouter: APIRouter {
    case getMyProfile
    case updateProfile(ProfileUpdateRequest)
    case uploadProfileImage(imageData: Data)
    
    var path: String {
        switch self {
        case .getMyProfile:
            return "/v1/users/me/profile"
        case .updateProfile:
            return "/v1/users/me/profile"
        case .uploadProfileImage:
            return "/v1/users/profile/image"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getMyProfile:
            return .get
        case .updateProfile:
            return .put
        case .uploadProfileImage:
            return .post
        }
    }
    
    var contentType: String {
        switch self {
        case .uploadProfileImage:
            return "multipart/form-data"
        default:
            return APIConstants.ContentType.json
        }
    }
    
    var body: Data? {
        switch self {
        case .getMyProfile:
            return nil
        case .updateProfile(let request):
            return try? JSONEncoder().encode(request)
        case .uploadProfileImage:
            return nil  // multipart/form-data는 별도 처리
        }
    }
    
    var authorizationType: AuthorizationType {
        return .accessToken
    }
}
