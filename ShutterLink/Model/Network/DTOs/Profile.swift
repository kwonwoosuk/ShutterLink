//
//  Profile.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import Foundation

// 프로필 응답 모델
struct ProfileResponse: Decodable {
    let user_id: String
    let email: String
    let nick: String
    let name: String
    let introduction: String
    let profileImage: String?
    let phoneNum: String
    let hashTags: [String]
}

// 프로필 수정 요청 모델
struct ProfileUpdateRequest: Encodable {
    let nick: String
    let name: String
    let introduction: String
    let phoneNum: String
    let profileImage: String?
    let hashTags: [String]
}

// 프로필 이미지 업로드 응답 모델
struct ProfileImageResponse: Decodable {
    let profileImage: String
}
