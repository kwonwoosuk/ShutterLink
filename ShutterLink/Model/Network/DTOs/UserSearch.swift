//
//  UserSearch.swift
//  ShutterLink
//
//  Created by 권우석 on 6/2/25.
//

import Foundation

// MARK: - 유저 검색 응답 모델
struct UserSearchResponse: Decodable {
    let data: [UserInfo]
}

// MARK: - 유저 정보 모델 (서버 응답에 맞게 옵셔널 처리)
struct UserInfo: Decodable, Identifiable, Hashable {
    let user_id: String
    let nick: String
    let name: String?
    let introduction: String?
    let profileImage: String?
    let hashTags: [String]
    
    var id: String { user_id }
}

