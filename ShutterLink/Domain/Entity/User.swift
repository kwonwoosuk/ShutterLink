//
//  User.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation

struct User {
    let id: String
    let email: String
    let nickname: String
    let profileImageURL: String?
    
    init(id: String, email: String, nickname: String, profileImageURL: String? = nil) {
        self.id = id
        self.email = email
        self.nickname = nickname
        self.profileImageURL = profileImageURL
    }
    
    init(from loginResponse: LoginResponse) {
        self.id = loginResponse.user_id
        self.email = loginResponse.email
        self.nickname = loginResponse.nick
        self.profileImageURL = loginResponse.profileImage
    }
    
    init(from joinResponse: JoinResponse) {
        self.id = joinResponse.user_id
        self.email = joinResponse.email
        self.nickname = joinResponse.nick
        self.profileImageURL = nil
    }
}
