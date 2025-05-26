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
        case .getMyProfile, .updateProfile:
            return APIConstants.Path.myProfile
        case .uploadProfileImage:
            return APIConstants.Path.profileImage
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
            return APIConstants.ContentType.multipartFormData
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
            return nil
        }
    }
    
    var authorizationType: AuthorizationType {
        return .accessToken
    }
}
