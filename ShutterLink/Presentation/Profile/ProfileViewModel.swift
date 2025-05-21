//
//  ProfileViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI

class ProfileViewModel: ObservableObject {
    @Published var profile: ProfileResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedImage: UIImage?
    @Published var isImageUploading = false
    
    private let profileUseCase: ProfileUseCase
    private let authState: AuthState
    
    init(profileUseCase: ProfileUseCase = ProfileUseCaseImpl(), authState: AuthState = .shared) {
        self.profileUseCase = profileUseCase
        self.authState = authState
    }
    
    func loadProfile() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let profileResponse = try await profileUseCase.getMyProfile()
            
            await MainActor.run {
                self.profile = profileResponse
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "프로필을 불러오는데 실패했습니다: \(error.localizedDescription)"
            }
        }
    }
    
    func updateProfile(nick: String, name: String, introduction: String, phoneNum: String, hashTags: [String]) async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let request = ProfileUpdateRequest(
            nick: nick,
            name: name,
            introduction: introduction,
            phoneNum: phoneNum,
            profileImage: profile?.profileImage,
            hashTags: hashTags
        )
        
        do {
            let updatedProfile = try await profileUseCase.updateProfile(request: request)
            
            await MainActor.run {
                self.profile = updatedProfile
                self.isLoading = false
                
                // 사용자 정보 업데이트
                let user = User(
                    id: updatedProfile.user_id,
                    email: updatedProfile.email,
                    nickname: updatedProfile.nick,
                    profileImageURL: updatedProfile.profileImage
                )
                self.authState.currentUser = user
            }
            
            return true
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "프로필 업데이트에 실패했습니다: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func uploadProfileImage() async -> Bool {
        guard let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.7) else {
            await MainActor.run {
                errorMessage = "이미지 처리에 실패했습니다."
            }
            return false
        }
        
        // 1MB 제한 체크
        let oneMB = 1 * 1024 * 1024
        if imageData.count > oneMB {
            await MainActor.run {
                errorMessage = "이미지 크기는 1MB 이하여야 합니다."
            }
            return false
        }
        
        await MainActor.run {
            isImageUploading = true
            errorMessage = nil
        }
        
        do {
            let profileImagePath = try await profileUseCase.uploadProfileImage(imageData: imageData)
            
            await MainActor.run {
                isImageUploading = false
                
                // 사용자 정보 업데이트
                if let currentUser = self.authState.currentUser {
                    let updatedUser = User(
                        id: currentUser.id,
                        email: currentUser.email,
                        nickname: currentUser.nickname,
                        profileImageURL: profileImagePath
                    )
                    self.authState.currentUser = updatedUser
                }
            }
            
            return true
        } catch {
            await MainActor.run {
                isImageUploading = false
                errorMessage = "이미지 업로드에 실패했습니다: \(error.localizedDescription)"
            }
            return false
        }
    }
}
