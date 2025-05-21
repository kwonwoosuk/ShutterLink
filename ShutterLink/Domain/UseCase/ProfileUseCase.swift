//
//  ProfileUseCase.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import Foundation

protocol ProfileUseCase {
    func getMyProfile() async throws -> ProfileResponse
    func updateProfile(request: ProfileUpdateRequest) async throws -> ProfileResponse
    func uploadProfileImage(imageData: Data) async throws -> String
}

class ProfileUseCaseImpl: ProfileUseCase {
    private let networkManager = NetworkManager.shared
    
    func getMyProfile() async throws -> ProfileResponse {
        let router = ProfileRouter.getMyProfile
        return try await networkManager.request(router, type: ProfileResponse.self)
    }
    
    func updateProfile(request: ProfileUpdateRequest) async throws -> ProfileResponse {
        let router = ProfileRouter.updateProfile(request)
        return try await networkManager.request(router, type: ProfileResponse.self)
    }
    
    func uploadProfileImage(imageData: Data) async throws -> String {
        let router = ProfileRouter.uploadProfileImage(imageData: imageData)
        let response = try await networkManager.uploadImage(router, imageData: imageData, fieldName: "profile")
        let imageResponse = try JSONDecoder().decode(ProfileImageResponse.self, from: response)
        return imageResponse.profileImage
    }
}
