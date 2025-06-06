//
//  MakeViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 6/6/25.
//

import SwiftUI
import Combine
import UIKit
import CoreLocation
import Photos

class MakeViewModel: ObservableObject {
    struct Input {
        let selectImage = PassthroughSubject<Void, Never>()
        let editProperty = PassthroughSubject<(String, Double), Never>()
        let undo = PassthroughSubject<Void, Never>()
        let redo = PassthroughSubject<Void, Never>()
        let resetToOriginal = PassthroughSubject<Void, Never>()
        let saveFilter = PassthroughSubject<(String, String, Int, String), Never>() // title, category, price, description
        let completeEditing = PassthroughSubject<Void, Never>()
    }
    
    // MARK: - Published Properties
    @Published var originalImage: UIImage?
    @Published var filteredImage: UIImage?
    @Published var isShowingImagePicker = false
    @Published var editingState = EditingState.defaultState
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var hasEditedImage = false
    @Published var isPreviewingOriginal = false
    
    // Filter Info
    @Published var filterTitle = ""
    @Published var selectedCategory = "푸드"
    @Published var filterPrice: Int = 0
    @Published var filterDescription = ""
    
    // Photo Metadata
    @Published var photoMetadata: PhotoMetadataRequest?
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    private let filterProcessor = ImageFilterProcessor()
    private let filterUseCase: FilterUseCase
    
    // Undo/Redo 스택
    private var undoStack: [EditingState] = []
    private var redoStack: [EditingState] = []
    private let maxHistoryCount = 50
    
    // 중복 저장 방지
    private var isSaving = false
    
    // Tasks
    private var filterTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    
    let categories = ["푸드", "인물", "풍경", "별", "야경"]
    
    init(filterUseCase: FilterUseCase = FilterUseCaseImpl()) {
        self.filterUseCase = filterUseCase
        setupBindings()
    }
    
    private func setupBindings() {
        // 이미지 선택
        input.selectImage
            .sink { [weak self] in
                self?.isShowingImagePicker = true
            }
            .store(in: &cancellables)
        
        // 속성 편집
        input.editProperty
            .debounce(for: 0.1, scheduler: RunLoop.main)
            .sink { [weak self] key, value in
                self?.updateEditingProperty(key: key, value: value)
            }
            .store(in: &cancellables)
        
        // Undo
        input.undo
            .sink { [weak self] in
                self?.performUndo()
            }
            .store(in: &cancellables)
        
        // Redo
        input.redo
            .sink { [weak self] in
                self?.performRedo()
            }
            .store(in: &cancellables)
        
        // 원본으로 리셋
        input.resetToOriginal
            .sink { [weak self] in
                self?.resetToOriginal()
            }
            .store(in: &cancellables)
        
        // 필터 저장
        input.saveFilter
            .sink { [weak self] title, category, price, description in
                self?.saveFilter(title: title, category: category, price: price, description: description)
            }
            .store(in: &cancellables)
        
        // 편집 완료
        input.completeEditing
            .sink { [weak self] in
                self?.completeEditing()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Image Selection
    func handleImageSelection(_ image: UIImage) {
        originalImage = image
        filteredImage = image
        filterProcessor.setOriginalImage(image)
        extractPhotoMetadata(from: image)
        resetEditingState()
        print("✅ MakeViewModel: 이미지 선택 완료")
    }
    
    // MARK: - Editing State Management
    private func updateEditingProperty(key: String, value: Double) {
        // 히스토리에 현재 상태 저장
        saveToUndoStack()
        
        // 새 값 적용
        editingState.setValue(for: key, value: value)
        
        // 실시간 필터 적용
        applyFiltersInRealTime()
    }
    
    private func applyFiltersInRealTime() {
        filterTask?.cancel()
        
        filterTask = Task { @MainActor in
            guard let original = originalImage else { return }
            
            let filtered = filterProcessor.applyFilters(with: editingState)
            self.filteredImage = filtered ?? original
            self.hasEditedImage = !editingState.isDefault
        }
    }
    
    private func saveToUndoStack() {
        undoStack.append(editingState)
        redoStack.removeAll()
        
        // 히스토리 크기 제한
        if undoStack.count > maxHistoryCount {
            undoStack.removeFirst()
        }
    }
    
    private func performUndo() {
        guard !undoStack.isEmpty else { return }
        
        redoStack.append(editingState)
        editingState = undoStack.removeLast()
        applyFiltersInRealTime()
        
        print("🔄 MakeViewModel: Undo 실행")
    }
    
    private func performRedo() {
        guard !redoStack.isEmpty else { return }
        
        undoStack.append(editingState)
        editingState = redoStack.removeLast()
        applyFiltersInRealTime()
        
        print("🔄 MakeViewModel: Redo 실행")
    }
    
    private func resetToOriginal() {
        saveToUndoStack()
        editingState = EditingState.defaultState
        filteredImage = originalImage
        hasEditedImage = false
        
        print("🔄 MakeViewModel: 원본으로 리셋")
    }
    
    private func resetEditingState() {
        editingState = EditingState.defaultState
        undoStack.removeAll()
        redoStack.removeAll()
        hasEditedImage = false
    }
    
    // MARK: - Before/After Preview
    func startPreviewingOriginal() {
        isPreviewingOriginal = true
    }
    
    func stopPreviewingOriginal() {
        isPreviewingOriginal = false
    }
    
    // MARK: - Photo Metadata Extraction
    private func extractPhotoMetadata(from image: UIImage) {
        // 기본 메타데이터 설정
        let imageSize = image.size
        let scale = image.scale
        let pixelWidth = Int(imageSize.width * scale)
        let pixelHeight = Int(imageSize.height * scale)
        
        // 이미지 데이터 크기 계산
        let imageData = image.jpegData(compressionQuality: 1.0) ?? Data()
        let fileSize = imageData.count
        
        photoMetadata = PhotoMetadataRequest(
            camera: "Unknown Camera",
            lensInfo: "Unknown Lens",
            focalLength: nil,
            aperture: nil,
            iso: nil,
            shutterSpeed: nil,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            fileSize: fileSize,
            format: "JPEG",
            dateTimeOriginal: ISO8601DateFormatter().string(from: Date()),
            latitude: nil,
            longitude: nil
        )
        
        print("📱 MakeViewModel: 메타데이터 추출 완료")
    }
    
    // MARK: - Filter Saving
    private func saveFilter(title: String, category: String, price: Int, description: String) {
        guard !isSaving else {
            print("⚠️ MakeViewModel: 이미 저장 중")
            return
        }
        
        guard let originalImage = originalImage,
              let filteredImage = filteredImage else {
            errorMessage = "이미지를 선택해주세요."
            return
        }
        
        guard !title.isEmpty else {
            errorMessage = "필터명을 입력해주세요."
            return
        }
        
        isSaving = true
        saveTask?.cancel()
        
        saveTask = Task {
            await MainActor.run {
                self.isUploading = true
                self.errorMessage = nil
            }
            
            do {
                // 1. 이미지 데이터 준비
                guard let originalData = originalImage.jpegData(compressionQuality: 0.8, maxSizeInBytes: 2 * 1024 * 1024),
                      let filteredData = filteredImage.jpegData(compressionQuality: 0.8, maxSizeInBytes: 2 * 1024 * 1024) else {
                    throw NetworkError.customError("이미지 처리에 실패했습니다.")
                }
                
                print("🔵 MakeViewModel: 파일 업로드 시작")
                
                // 2. 파일 업로드
                let uploadedFiles = try await uploadFilterFiles(
                    originalData: originalData,
                    filteredData: filteredData
                )
                
                // 3. 필터 생성 요청
                let filterRequest = FilterCreateRequest(
                    category: category,
                    title: title,
                    price: price,
                    description: description,
                    files: uploadedFiles,
                    photoMetadata: photoMetadata,
                    filterValues: editingState.toFilterValuesRequest()
                )
                
                print("🔵 MakeViewModel: 필터 생성 시작")
                
                let createdFilter = try await filterUseCase.createFilter(request: filterRequest)
                
                await MainActor.run {
                    self.isUploading = false
                    self.isSaving = false
                    self.successMessage = "필터가 성공적으로 저장되었습니다!"
                    
                    // 폼 리셋
                    self.resetForm()
                }
                
                // 3초 후 성공 메시지 제거
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.successMessage = nil
                }
                
                print("✅ MakeViewModel: 필터 저장 완료")
                
            } catch is CancellationError {
                print("🔵 MakeViewModel: 저장 작업 취소됨")
                await MainActor.run {
                    self.isUploading = false
                    self.isSaving = false
                }
            } catch {
                print("❌ MakeViewModel: 필터 저장 실패 - \(error)")
                await MainActor.run {
                    self.isUploading = false
                    self.isSaving = false
                    
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.errorMessage
                    } else {
                        self.errorMessage = "필터 저장에 실패했습니다."
                    }
                }
                
                // 에러 메시지를 5초 후 자동으로 제거
                Task {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    await MainActor.run {
                        if self.errorMessage != nil {
                            self.errorMessage = nil
                        }
                    }
                }
            }
        }
    }
    
    private func uploadFilterFiles(originalData: Data, filteredData: Data) async throws -> [String] {
        // NetworkManager에서 multipart 업로드 처리 필요
        // 임시로 필터 생성 UseCase에 추가하거나, 별도 메서드 구현
        return try await filterUseCase.uploadFilterFiles(originalData: originalData, filteredData: filteredData)
    }
    
    private func completeEditing() {
        hasEditedImage = editingState != EditingState.defaultState
        print("✅ MakeViewModel: 편집 완료")
    }
    
    private func resetForm() {
        filterTitle = ""
        selectedCategory = "푸드"
        filterPrice = 0
        filterDescription = ""
        originalImage = nil
        filteredImage = nil
        hasEditedImage = false
        resetEditingState()
    }
    
    // MARK: - Computed Properties
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    var hasOriginalImage: Bool {
        originalImage != nil
    }
    
    var canSaveFilter: Bool {
        hasOriginalImage && !filterTitle.isEmpty && !isSaving
    }
    
    deinit {
        filterTask?.cancel()
        saveTask?.cancel()
        cancellables.removeAll()
    }
}

// MARK: - EditingState Extension
private extension EditingState {
    var isDefault: Bool {
        return self == EditingState.defaultState
    }
}
