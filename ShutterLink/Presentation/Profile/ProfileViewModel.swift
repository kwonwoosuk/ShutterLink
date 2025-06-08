//
//  ProfileViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI
import Combine

final class ProfileViewModel: ObservableObject {
    // 기존 프로퍼티들
    @Published var profile: ProfileResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedImage: UIImage?
    @Published var isImageUploading = false
    
    // 좋아요한 필터 관련 프로퍼티 추가
    @Published var likedFilters: [FilterItem] = []
    @Published var isLoadingLikedFilters = false
    @Published var hasMoreLikedFilters = true
    
    private let profileUseCase: ProfileUseCase
    private let filterUseCase: FilterUseCase // 추가
    private let authState: AuthState
    
    // 페이지네이션 상태
    private var likedFiltersNextCursor = ""
    private let likedFiltersPageLimit = 10
    
    // Task 관리용
    private var loadProfileTask: Task<Void, Never>?
    private var updateProfileTask: Task<Bool, Never>?
    private var uploadImageTask: Task<Bool, Never>?
    private var loadLikedFiltersTask: Task<Void, Never>? // 추가
    
    init(profileUseCase: ProfileUseCase = ProfileUseCaseImpl(),
         filterUseCase: FilterUseCase = FilterUseCaseImpl(), // 추가
         authState: AuthState = .shared) {
        self.profileUseCase = profileUseCase
        self.filterUseCase = filterUseCase // 추가
        self.authState = authState
    }
    
    // 기존 메서드들... (loadProfile, updateProfile, uploadProfileImage)
    
    func loadProfile() {
        // 기존 작업 취소
        loadProfileTask?.cancel()
        
        loadProfileTask = Task {
            print("🔵 ProfileViewModel: 프로필 로드 시작")
            
            // UI 상태 업데이트 (메인스레드)
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            do {
                // 네트워킹 작업 (백그라운드에서 실행)
                let profileResponse = try await profileUseCase.getMyProfile()
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                // UI 업데이트 (메인스레드에서 실행)
                await MainActor.run {
                    self.profile = profileResponse
                    self.isLoading = false
                }
                
                print("✅ ProfileViewModel: 프로필 로드 성공")
                print("🖼️ ProfileViewModel: 프로필 이미지 경로 - \(profileResponse.profileImage ?? "없음")")
                
                // 프로필 로드 성공 후 좋아요한 필터들도 로드
                loadLikedFilters()
                
            } catch is CancellationError {
                print("🔵 ProfileViewModel: 프로필 로드 작업 취소됨")
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                print("❌ ProfileViewModel: 프로필 로드 실패 - \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "프로필을 불러오는데 실패했습니다: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - 좋아요한 필터 로드
    func loadLikedFilters() {
        // 기존 작업 취소
        loadLikedFiltersTask?.cancel()
        
        loadLikedFiltersTask = Task {
            print("🔵 ProfileViewModel: 좋아요한 필터 로드 시작")
            
            // UI 상태 업데이트 (메인스레드)
            await MainActor.run {
                self.isLoadingLikedFilters = true
                self.likedFiltersNextCursor = ""
            }
            
            do {
                // 네트워킹 작업 (백그라운드에서 실행)
                let response = try await filterUseCase.getLikedFilters(
                    next: "",
                    limit: likedFiltersPageLimit,
                    category: nil
                )
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                print("✅ ProfileViewModel: 좋아요한 필터 로드 성공 - \(response.data.count)개 필터")
                
                // UI 업데이트 (메인스레드에서 실행)
                await MainActor.run {
                    self.likedFilters = response.data
                    self.hasMoreLikedFilters = response.next_cursor != "0"
                    self.isLoadingLikedFilters = false
                }
                self.likedFiltersNextCursor = response.next_cursor
                
            } catch is CancellationError {
                print("🔵 ProfileViewModel: 좋아요한 필터 로드 작업 취소됨")
                await MainActor.run {
                    self.isLoadingLikedFilters = false
                }
            } catch {
                print("❌ ProfileViewModel: 좋아요한 필터 로드 실패 - \(error)")
                await MainActor.run {
                    self.isLoadingLikedFilters = false
                    self.likedFilters = []
                }
            }
        }
    }
    
    // MARK: - 더 많은 좋아요한 필터 로드 (나중에 필요시 구현)
    func loadMoreLikedFilters() {
        guard !isLoadingLikedFilters && hasMoreLikedFilters && !likedFiltersNextCursor.isEmpty && likedFiltersNextCursor != "0" else {
            return
        }
        
        Task {
            await MainActor.run {
                self.isLoadingLikedFilters = true
            }
            
            do {
                let response = try await filterUseCase.getLikedFilters(
                    next: likedFiltersNextCursor,
                    limit: likedFiltersPageLimit,
                    category: nil
                )
                
                await MainActor.run {
                    self.likedFilters.append(contentsOf: response.data)
                    self.hasMoreLikedFilters = response.next_cursor != "0"
                    self.isLoadingLikedFilters = false
                }
                self.likedFiltersNextCursor = response.next_cursor
                
            } catch {
                await MainActor.run {
                    self.isLoadingLikedFilters = false
                }
            }
        }
    }
    
    // 기존 메서드들 (updateProfile, uploadProfileImage)...
    
    func updateProfile(nick: String, name: String, introduction: String, phoneNum: String, hashTags: [String]) -> Task<Bool, Never> {
        // 기존 작업 취소
        updateProfileTask?.cancel()
        
        updateProfileTask = Task {
            print("🔵 ProfileViewModel: 프로필 업데이트 시작")
            
            // UI 상태 업데이트 (메인스레드)
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            // 현재 프로필 이미지 경로 가져오기
            let currentProfileImage = await MainActor.run { self.profile?.profileImage }
            
            let request = ProfileUpdateRequest(
                nick: nick,
                name: name,
                introduction: introduction,
                phoneNum: phoneNum,
                profileImage: currentProfileImage,
                hashTags: hashTags
            )
            
            do {
                // 네트워킹 작업 (백그라운드에서 실행)
                let updatedProfile = try await profileUseCase.updateProfile(request: request)
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                // UI 업데이트 (메인스레드에서 실행)
                await MainActor.run {
                    self.profile = updatedProfile
                    self.isLoading = false
                }
                
                // 프로필 업데이트 성공 시 닉네임 저장 (백그라운드에서 실행 가능)
                UserDefaults.standard.set(nick, forKey: "lastUserNickname")
                print("✅ ProfileViewModel: 닉네임 업데이트 및 저장 완료 - \(nick)")
                
                // 사용자 정보 업데이트 (메인스레드에서 실행)
                await MainActor.run {
                    let user = User(
                        id: updatedProfile.user_id,
                        email: updatedProfile.email,
                        nickname: updatedProfile.nick,
                        profileImageURL: updatedProfile.profileImage
                    )
                    self.authState.currentUser = user
                }
                
                return true
                
            } catch is CancellationError {
                print("🔵 ProfileViewModel: 프로필 업데이트 작업 취소됨")
                await MainActor.run {
                    self.isLoading = false
                }
                return false
            } catch {
                print("❌ ProfileViewModel: 프로필 업데이트 실패 - \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "프로필 업데이트에 실패했습니다: \(error.localizedDescription)"
                }
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
            
            // 현재 선택된 이미지 가져오기
            let currentSelectedImage = await MainActor.run { self.selectedImage }
            
            guard let image = currentSelectedImage, let imageData = image.jpegData(compressionQuality: 0.7) else {
                await MainActor.run {
                    self.errorMessage = "이미지 처리에 실패했습니다."
                }
                return false
            }
            
            // 1MB 제한 체크 (백그라운드에서 실행 가능)
            let oneMB = 1 * 1024 * 1024
            if imageData.count > oneMB {
                await MainActor.run {
                    self.errorMessage = "이미지 크기는 1MB 이하여야 합니다."
                }
                return false
            }
            
            // UI 상태 업데이트 (메인스레드)
            await MainActor.run {
                self.isImageUploading = true
                self.errorMessage = nil
            }
            
            do {
                print("🔄 ProfileViewModel: 프로필 이미지 업로드 - 크기: \(imageData.count) 바이트")
                
                // 네트워킹 작업 (백그라운드에서 실행)
                let profileImagePath = try await profileUseCase.uploadProfileImage(imageData: imageData)
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                print("✅ ProfileViewModel: 프로필 이미지 업로드 성공 - \(profileImagePath)")
                
                // UI 업데이트 (메인스레드에서 실행)
                await MainActor.run {
                    self.isImageUploading = false
                    
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
                    
                    // profile 객체도 업데이트
                    if var updatedProfile = self.profile {
                        updatedProfile.profileImage = profileImagePath
                        self.profile = updatedProfile
                        print("✅ ProfileViewModel: 프로필 객체 이미지 경로 업데이트 - \(profileImagePath)")
                    }
                }
                
                return true
                
            } catch is CancellationError {
                print("🔵 ProfileViewModel: 이미지 업로드 작업 취소됨")
                await MainActor.run {
                    self.isImageUploading = false
                }
                return false
            } catch {
                print("❌ ProfileViewModel: 이미지 업로드 실패 - \(error)")
                await MainActor.run {
                    self.isImageUploading = false
                    self.errorMessage = "이미지 업로드에 실패했습니다: \(error.localizedDescription)"
                }
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
        loadLikedFiltersTask?.cancel() // 추가
    }
}
