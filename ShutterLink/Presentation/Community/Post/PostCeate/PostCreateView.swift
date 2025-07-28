//
//  PostCreateView.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import SwiftUI
import PhotosUI

struct PostCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PostCreateViewModel()
    
    @State private var selectedCategory = "핫스팟"
    @State private var title = ""
    @State private var content = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var showCategorySheet = false
    
    private let categories = ["핫스팟", "맛집", "일상", "여행", "취미", "기타"]
    private let maxImages = 5
    
    var body: some View {
        NavigationView {
            ZStack {
                // 다크 테마 배경
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 카테고리 선택
                        categorySection
                        
                        // 이미지 선택
                        imageSection
                        
                        // 제목 입력
                        titleSection
                        
                        // 내용 입력
                        contentSection
                        
                        // 위치 정보 (선택사항)
                        locationSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                
                // 로딩 인디케이터
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        
                        Text("게시글을 작성하는 중...")
                            .font(.pretendard(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.top, 12)
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                }
            }
            .navigationTitle("새 게시글")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("게시") {
                        createPost()
                    }
                    .foregroundColor(canCreatePost ? .blue : .gray)
                    .fontWeight(.semibold)
                    .disabled(!canCreatePost || viewModel.isLoading)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(selectedImages: $selectedImages, maxSelection: maxImages)
        }
        .sheet(isPresented: $showCategorySheet) {
            categorySelectionSheet
        }
        .alert("오류", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("확인") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .onChange(of: viewModel.isCreated) { isCreated in
            if isCreated {
                dismiss()
            }
        }
    }
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("카테고리")
                .font(.pretendard(size: 16, weight: .semiBold))
                .foregroundColor(.white)
            
            Button {
                showCategorySheet = true
            } label: {
                HStack {
                    Text(selectedCategory)
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(DesignSystem.Colors.Gray.gray90)
                .cornerRadius(10)
            }
        }
    }
    
    private var categorySelectionSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                ForEach(categories, id: \.self) { category in
                    categoryRowButton(category)
                    
                    if category != categories.last {
                        Divider()
                            .background(DesignSystem.Colors.Gray.gray75)
                    }
                }
                
                Spacer()
            }
            .background(Color.black)
            .navigationTitle("카테고리 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        showCategorySheet = false
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func categoryRowButton(_ category: String) -> some View {
        Button {
            selectedCategory = category
            showCategorySheet = false
        } label: {
            HStack {
                Text(category)
                    .font(.pretendard(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                if selectedCategory == category {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Image Section
    
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("사진")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                
                Text("(\(selectedImages.count)/\(maxImages))")
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // 이미지 추가 버튼
                    Button {
                        showImagePicker = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .foregroundColor(.gray)
                                .font(.system(size: 24))
                            
                            Text("사진 추가")
                                .font(.pretendard(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 80, height: 80)
                        .background(DesignSystem.Colors.Gray.gray90)
                        .cornerRadius(10)
                    }
                    .disabled(selectedImages.count >= maxImages)
                    
                    // 선택된 이미지들
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(10)
                            
                            // 삭제 버튼
                            Button {
                                selectedImages.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .background(Color.white.clipShape(Circle()))
                                    .font(.system(size: 18))
                            }
                            .offset(x: 8, y: -8)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("제목")
                .font(.pretendard(size: 16, weight: .semiBold))
                .foregroundColor(.white)
            
            TextField("제목을 입력하세요", text: $title)
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(DesignSystem.Colors.Gray.gray90)
                .cornerRadius(10)
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내용")
                .font(.pretendard(size: 16, weight: .semiBold))
                .foregroundColor(.white)
            
            TextEditor(text: $content)
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .background(DesignSystem.Colors.Gray.gray90)
                .cornerRadius(10)
                .frame(minHeight: 120)
                .overlay(
                    // Placeholder
                    Group {
                        if content.isEmpty {
                            VStack {
                                HStack {
                                    Text("내용을 입력하세요...")
                                        .font(.pretendard(size: 14, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.Gray.gray60)
                                        .padding(.leading, 20)
                                        .padding(.top, 20)
                                    Spacer()
                                }
                                Spacer()
                            }
                        }
                    }
                )
        }
    }
    
    // MARK: - Location Section
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("위치")
                .font(.pretendard(size: 16, weight: .semiBold))
                .foregroundColor(.white)
            
            Button {
            } label: {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    
                    Text("위치 추가 (선택사항)")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(DesignSystem.Colors.Gray.gray90)
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canCreatePost: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedCategory.isEmpty
    }
    
    // MARK: - Methods
    
    private func createPost() {
        Task {
            await viewModel.createPost(
                category: selectedCategory,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                images: selectedImages
            )
        }
    }
}

// MARK: - Multi-Image Picker

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    let maxSelection: Int
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = maxSelection
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            Task {
                var images: [UIImage] = []
                
                for result in results {
                    if let image = await loadImage(from: result) {
                        images.append(image)
                    }
                }
                
                await MainActor.run {
                    parent.selectedImages = images
                }
            }
        }
        
        private func loadImage(from result: PHPickerResult) async -> UIImage? {
            return await withCheckedContinuation { continuation in
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                    continuation.resume(returning: image as? UIImage)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PostCreateView()
}
