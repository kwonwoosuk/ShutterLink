//
//  PostEditViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import SwiftUI
import Combine
import CoreLocation

final class PostEditViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isUpdated = false
    
    // MARK: - Private Properties
    
    private let postUseCase: PostUseCase
    private var updateTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(postUseCase: PostUseCase = PostUseCaseImpl()) {
        self.postUseCase = postUseCase
    }
    
    deinit {
        updateTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func updatePost(
        postId: String,
        category: String,
        title: String,
        content: String,
        currentImagePaths: [String],
        newImages: [UIImage]
    ) async {
        updateTask?.cancel()
        
        updateTask = Task {
            await performUpdatePost(
                postId: postId,
                category: category,
                title: title,
                content: content,
                currentImagePaths: currentImagePaths,
                newImages: newImages
            )
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func performUpdatePost(
        postId: String,
        category: String,
        title: String,
        content: String,
        currentImagePaths: [String],
        newImages: [UIImage]
    ) async {
        print("✏️ PostEditViewModel: 게시글 수정 시작")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            var newImagePaths: [String] = []
            if !newImages.isEmpty {
                print("📸 PostEditViewModel: 새 이미지 업로드 중... (\(newImages.count)개)")
                newImagePaths = try await postUseCase.uploadPostImages(newImages)
                print("✅ PostEditViewModel: 새 이미지 업로드 완료")
            }
            
            let allImagePaths = currentImagePaths + newImagePaths
            
            print("✏️ PostEditViewModel: 게시글 데이터 수정 중...")
            let post = try await postUseCase.updatePost(
                postId: postId,
                category: category,
                title: title,
                content: content,
                location: nil, 
                imagePaths: allImagePaths
            )
            
            try Task.checkCancellation()
            
            await MainActor.run {
                isLoading = false
                isUpdated = true
            }
            
            print("✅ PostEditViewModel: 게시글 수정 완료 - \(post.postId)")
            
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "게시글 수정에 실패했습니다: \(error.localizedDescription)"
                }
                print("❌ PostEditViewModel: 게시글 수정 실패 - \(error)")
            }
        }
    }
}
