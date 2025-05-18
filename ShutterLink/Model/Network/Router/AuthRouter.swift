//
//  AuthRouter.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation

enum AuthRouter: APIRouter {
    case validateEmail(email: String)
    case join(user: JoinRequest)
    case login(email: String, password: String, deviceToken: String)
    case refreshToken(refreshToken: String)
    
    var path: String {
        switch self {
        case .validateEmail:
            return APIConstants.Path.emailValidation
        case .join:
            return APIConstants.Path.join
        case .login:
            return APIConstants.Path.login
        case .refreshToken:
            return APIConstants.Path.refresh
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .validateEmail, .join, .login:
            return .post
        case .refreshToken:
            return .get
        }
    }
    
    var body: Data? {
        switch self {
        case .validateEmail(let email):
            let params = ["email": email]
            return try? JSONEncoder().encode(params)
            
        case .join(let user):
            return try? JSONEncoder().encode(user)
            
        case .login(let email, let password, let deviceToken):
            let params = [
                "email": email,
                "password": password,
                "deviceToken": deviceToken
            ]
            return try? JSONEncoder().encode(params)
            
        case .refreshToken:
            return nil
        }
    }
    
    var authorizationType: AuthorizationType {
        switch self {
        case .validateEmail, .join:
            return .sesacKey
        case .login:
            return .sesacKey
        case .refreshToken:
            return .refreshToken
        }
    }
}
