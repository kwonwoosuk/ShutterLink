//
//  Profile.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import Foundation

// 프로필 응답 모델
struct ProfileResponse: Decodable ,Equatable {
    let user_id: String
    let email: String
    let nick: String
    let name: String?          // 옵셔널로 변경
    let introduction: String?  // 옵셔널로 변경
    var profileImage: String?
    let phoneNum: String?      // 옵셔널로 변경
    let hashTags: [String]
    
    enum CodingKeys: String, CodingKey {
            case user_id, email, nick, name, introduction, profileImage, phoneNum, hashTags
        }
    // 커스텀 초기화로 누락된 필드 처리
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 필수 필드
        user_id = try container.decode(String.self, forKey: .user_id)
        email = try container.decode(String.self, forKey: .email)
        nick = try container.decode(String.self, forKey: .nick)
        
        // 옵셔널 필드는 비어있는 경우 기본값 사용
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        introduction = try container.decodeIfPresent(String.self, forKey: .introduction) ?? ""
        profileImage = try container.decodeIfPresent(String.self, forKey: .profileImage)
        phoneNum = try container.decodeIfPresent(String.self, forKey: .phoneNum) ?? ""
        hashTags = try container.decodeIfPresent([String].self, forKey: .hashTags) ?? []
    }
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
