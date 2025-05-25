//
//  ProfileViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profile: ProfileResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedImage: UIImage?
    @Published var isImageUploading = false
    
    private let profileUseCase: ProfileUseCase
    private let authState: AuthState
    
    // Task 관리용
    private var loadProfileTask: Task<Void, Never>?
    private var updateProfileTask: Task<Bool, Never>?
    private var uploadImageTask: Task<Bool, Never>?
    
    init(profileUseCase: ProfileUseCase = ProfileUseCaseImpl(), authState: AuthState = .shared) {
        self.profileUseCase = profileUseCase
        self.authState = authState
    }
    
    func loadProfile() {
        // 기존 작업 취소
        loadProfileTask?.cancel()
        
        loadProfileTask = Task {
            print("🔵 ProfileViewModel: 프로필 로드 시작")
            
            // UI 상태 업데이트 (메인스레드)
            isLoading = true
            errorMessage = nil
            
            do {
                // 네트워크 작업 (백그라운드)
                let profileResponse = try await Task.detached { [profileUseCase] in
                    return try await profileUseCase.getMyProfile()
                }.value
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                // UI 업데이트 (메인스레드에서 실행됨 - @MainActor 클래스이므로)
                profile = profileResponse
                isLoading = false
                
                print("✅ ProfileViewModel: 프로필 로드 성공")
                print("🖼️ ProfileViewModel: 프로필 이미지 경로 - \(profileResponse.profileImage ?? "없음")")
                
            } catch is CancellationError {
                print("🔵 ProfileViewModel: 프로필 로드 작업 취소됨")
                isLoading = false
            } catch {
                print("❌ ProfileViewModel: 프로필 로드 실패 - \(error)")
                isLoading = false
                errorMessage = "프로필을 불러오는데 실패했습니다: \(error.localizedDescription)"
            }
        }
    }
    
    func updateProfile(nick: String, name: String, introduction: String, phoneNum: String, hashTags: [String]) -> Task<Bool, Never> {
        // 기존 작업 취소
        updateProfileTask?.cancel()
        
        updateProfileTask = Task {
            print("🔵 ProfileViewModel: 프로필 업데이트 시작")
            
            // UI 상태 업데이트 (메인스레드)
            isLoading = true
            errorMessage = nil
            
            let request = ProfileUpdateRequest(
                nick: nick,
                name: name,
                introduction: introduction,
                phoneNum: phoneNum,
                profileImage: profile?.profileImage,
                hashTags: hashTags
            )
            
            do {
                // 네트워크 작업 (백그라운드)
                let updatedProfile = try await Task.detached { [profileUseCase] in
                    return try await profileUseCase.updateProfile(request: request)
                }.value
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                // UI 업데이트 (메인스레드에서 실행됨 - @MainActor 클래스이므로)
                profile = updatedProfile
                isLoading = false
                
                // 프로필 업데이트 성공 시 닉네임 저장
                UserDefaults.standard.set(nick, forKey: "lastUserNickname")
                print("✅ ProfileViewModel: 닉네임 업데이트 및 저장 완료 - \(nick)")
                
                // 사용자 정보 업데이트
                let user = User(
                    id: updatedProfile.user_id,
                    email: updatedProfile.email,
                    nickname: updatedProfile.nick,
                    profileImageURL: updatedProfile.profileImage
                )
                authState.currentUser = user
                
                return true
                
            } catch is CancellationError {
                print("🔵 ProfileViewModel: 프로필 업데이트 작업 취소됨")
                isLoading = false
                return false
            } catch {
                print("❌ ProfileViewModel: 프로필 업데이트 실패 - \(error)")
                isLoading = false
                errorMessage = "프로필 업데이트에 실패했습니다: \(error.localizedDescription)"
                return false
            }
        }
        
        return updateProfileTask!
    }
    
    func uploadProfileImage() -> Task<Bool, Never> {
        // 기존 작업 취소
        uploadImageTask?.cancel()
        
        uploadImageTask = Task {
            print("🔵 ProfileViewModel: 프로필 이미지 업로드 시작")
            
            guard let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.7) else {
                errorMessage = "이미지 처리에 실패했습니다."
                return false
            }
            
            // 1MB 제한 체크
            let oneMB = 1 * 1024 * 1024
            if imageData.count > oneMB {
                errorMessage = "이미지 크기는 1MB 이하여야 합니다."
                return false
            }
            
            // UI 상태 업데이트 (메인스레드)
            isImageUploading = true
            errorMessage = nil
            
            do {
                print("🔄 ProfileViewModel: 프로필 이미지 업로드 - 크기: \(imageData.count) 바이트")
                
                // 네트워크 작업 (백그라운드)
                let profileImagePath = try await Task.detached { [profileUseCase] in
                    return try await profileUseCase.uploadProfileImage(imageData: imageData)
                }.value
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                print("✅ ProfileViewModel: 프로필 이미지 업로드 성공 - \(profileImagePath)")
                
                // UI 업데이트 (메인스레드에서 실행됨 - @MainActor 클래스이므로)
                isImageUploading = false
                
                // 사용자 정보 업데이트
                if let currentUser = authState.currentUser {
                    let updatedUser = User(
                        id: currentUser.id,
                        email: currentUser.email,
                        nickname: currentUser.nickname,
                        profileImageURL: profileImagePath
                    )
                    authState.currentUser = updatedUser
                }
                
                // profile 객체도 업데이트
                if var updatedProfile = profile {
                    updatedProfile.profileImage = profileImagePath
                    profile = updatedProfile
                    print("✅ ProfileViewModel: 프로필 객체 이미지 경로 업데이트 - \(profileImagePath)")
                }
                
                return true
                
            } catch is CancellationError {
                print("🔵 ProfileViewModel: 이미지 업로드 작업 취소됨")
                isImageUploading = false
                return false
            } catch {
                print("❌ ProfileViewModel: 이미지 업로드 실패 - \(error)")
                isImageUploading = false
                errorMessage = "이미지 업로드에 실패했습니다: \(error.localizedDescription)"
                return false
            }
        }
        
        return uploadImageTask!
    }
    
    // MARK: - Cleanup
    deinit {
        loadProfileTask?.cancel()
        updateProfileTask?.cancel()
        uploadImageTask?.cancel()
    }
}
