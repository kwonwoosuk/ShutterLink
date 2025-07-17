//
//  Auth.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation

// 회원가입 요청 DTO
struct JoinRequest: Encodable {
    let email: String
    let password: String
    let nick: String
    let name: String
    let introduction: String
    let phoneNum: String
    let hashTags: [String]
    let deviceToken: String
}

// 회원가입 응답 DTO
struct JoinResponse: Decodable {
    let user_id: String
    let email: String
    let nick: String
    let accessToken: String
    let refreshToken: String
}

// 로그인 응답 DTO
struct LoginResponse: Decodable {
    let user_id: String
    let email: String
    let nick: String
    let profileImage: String?
    let accessToken: String
    let refreshToken: String
}

// 이메일 검증 응답 DTO
struct EmailValidationResponse: Decodable {
    let message: String
}
