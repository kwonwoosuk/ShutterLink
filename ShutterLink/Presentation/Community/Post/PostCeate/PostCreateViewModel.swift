//
//  PostCreateViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import SwiftUI
import Combine
import CoreLocation

final class PostCreateViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isCreated = false
    
    // MARK: - Private Properties
    
    private let postUseCase: PostUseCase
    private var createTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(postUseCase: PostUseCase = PostUseCaseImpl()) {
        self.postUseCase = postUseCase
    }
    
    deinit {
        createTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func createPost(category: String, title: String, content: String, images: [UIImage]) async {
        createTask?.cancel()
        
        createTask = Task {
            await performCreatePost(category: category, title: title, content: content, images: images)
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func performCreatePost(category: String, title: String, content: String, images: [UIImage]) async {
        print("📝 PostCreateViewModel: 게시글 작성 시작")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 1. 이미지가 있으면 먼저 업로드
            var imagePaths: [String] = []
            if !images.isEmpty {
                imagePaths = try await postUseCase.uploadPostImages(images)
            }
            
            // 2. 게시글 작성
            let post = try await postUseCase.createPost(
                category: category,
                title: title,
                content: content,
                location: nil,
                imagePaths: imagePaths
            )
            
            try Task.checkCancellation()
            
            await MainActor.run {
                isLoading = false
                isCreated = true
            }
            
            print("✅ PostCreateViewModel: 게시글 작성 완료 - \(post.postId)")
            
        } catch let error as PostError {
            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    print("❌ PostCreateViewModel: PostError - \(error.localizedDescription)")
                }
            }
            
        } catch let decodingError as DecodingError {
            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "서버 응답 처리 중 오류가 발생했습니다."
                    print("❌ PostCreateViewModel: DecodingError - \(decodingError)")
                    
                }
            }
            
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "게시글 작성에 실패했습니다."
                    print("❌ PostCreateViewModel: 게시글 작성 실패 - \(error)")
                }
            }
        }
    }
    
    func validateCategory(_ category: String) -> Bool {
        let validCategories = ["핫스팟", "여행", "맛집", "일상", "night", "landscape"]
        return validCategories.contains(category)
    }
    
    func validateTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 100
    }
    
    func validateContent(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 1000
    }
    
    func validateImages(_ images: [UIImage]) -> Bool {
        return images.count <= 5 // 최대 5개 이미지
    }
    
    func getValidationError(category: String, title: String, content: String, images: [UIImage]) -> String? {
        if !validateCategory(category) {
            return "올바른 카테고리를 선택해주세요."
        }
        
        if !validateTitle(title) {
            return "제목을 1-100자 이내로 입력해주세요."
        }
        
        if !validateContent(content) {
            return "내용을 1-1000자 이내로 입력해주세요."
        }
        
        if !validateImages(images) {
            return "이미지는 최대 5개까지 업로드할 수 있습니다."
        }
        
        return nil
    }
}
