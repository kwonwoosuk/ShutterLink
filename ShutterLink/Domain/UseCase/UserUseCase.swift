//
//  UserUseCase.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import Foundation

protocol UserUseCase {
    func getTodayAuthor() async throws -> TodayAuthorResponse
    func searchUsers(nick: String) async throws -> UserSearchResponse
    func getUserFilters(userId: String, category: String?, next: String, limit: Int) async throws -> FilterListResponse
}

class UserUseCaseImpl: UserUseCase {
    private let networkManager = NetworkManager.shared
    
    func getTodayAuthor() async throws -> TodayAuthorResponse {
        let router = UserRouter.getTodayAuthor
        return try await networkManager.request(router, type: TodayAuthorResponse.self)
    }
    
    func searchUsers(nick: String) async throws -> UserSearchResponse {
        let router = UserRouter.searchUsers(nick: nick)
        return try await networkManager.request(router, type: UserSearchResponse.self)
    }
    
    func getUserFilters(userId: String, category: String?, next: String, limit: Int) async throws -> FilterListResponse {
        let router = UserRouter.getUserFilters(userId: userId, category: category, next: next, limit: limit)
        return try await networkManager.request(router, type: FilterListResponse.self)
    }
}
