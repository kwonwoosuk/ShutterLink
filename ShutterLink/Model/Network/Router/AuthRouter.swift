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
    case kakaoLogin(oauthToken: String, deviceToken: String)
    case appleLogin(idToken: String, deviceToken: String, nickname: String?)
    
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
        case .kakaoLogin:
            return APIConstants.Path.kakaoLogin
        case .appleLogin:
            return APIConstants.Path.appleLogin
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .validateEmail, .join, .login:
            return .post
        case .refreshToken:
            return .get
        case .kakaoLogin:
            return .post
        case .appleLogin:
            return .post
            
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
            
        case .kakaoLogin(let oauthToken, let deviceToken):
            let params = [
                "oauthToken": oauthToken,
                "deviceToken": deviceToken
            ]
            print("📱 카카오 로그인 요청 파라미터:")
            print("oauthToken: \(oauthToken)")
            print("deviceToken: \(deviceToken)")
            return try? JSONEncoder().encode(params)
            
        case .appleLogin(let idToken, let deviceToken, let nickname):
            var params: [String: Any] = [
                "idToken": idToken,
                "deviceToken": deviceToken
            ]
            
            if let nickname = nickname {
                params["nick"] = nickname
            }
            
            print("📱 애플 로그인 요청 파라미터:")
            print("idToken: \(idToken)")
            print("deviceToken: \(deviceToken)")
            if let nickname = nickname {
                print("nickname: \(nickname)")
            }
            
            return try? JSONSerialization.data(withJSONObject: params)

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
        case .kakaoLogin:
            return .sesacKey
        case .appleLogin:
            return .sesacKey
        }
    }
}
