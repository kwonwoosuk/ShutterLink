//
//  UserUseCase.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import Foundation

protocol UserUseCase {
    func getTodayAuthor() async throws -> TodayAuthorResponse
}

class UserUseCaseImpl: UserUseCase {
    private let networkManager = NetworkManager.shared
    
    func getTodayAuthor() async throws -> TodayAuthorResponse {
        let router = UserRouter.getTodayAuthor
        return try await networkManager.request(router, type: TodayAuthorResponse.self)
    }
}
