//
//  AuthState.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation
import SwiftUI

class AuthState: ObservableObject {
    static let shared = AuthState()
    
    @Published var isLoggedIn = false
    @Published var currentUser: User? = nil
    @Published var showLoginModal = false
    
    private let tokenManager = TokenManager.shared
    
    private init() {
        // 토큰이 존재하면 자동 로그인 상태로 설정
        if tokenManager.accessToken != nil {
            isLoggedIn = true
            // 사용자 정보는 나중에 프로필 API를 통해 불러올 수 있음
        }
    }
    
    func login(user: User, accessToken: String, refreshToken: String) {
        tokenManager.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
        self.currentUser = user
        self.isLoggedIn = true
    }
    
    func logout() {
        tokenManager.clearTokens()
        self.currentUser = nil
        self.isLoggedIn = false
    }
    
    func showLogin() {
        self.showLoginModal = true
    }
}
