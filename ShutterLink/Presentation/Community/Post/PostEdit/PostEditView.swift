//
//  PostEditView.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import SwiftUI
import PhotosUI

struct PostEditView: View {
    let post: Post
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PostEditViewModel()
    
    @State private var selectedCategory: String
    @State private var title: String
    @State private var content: String
    @State private var currentImages: [String] = []
    @State private var newImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var showCategorySheet = false
    
    private let categories = ["핫스팟", "맛집", "일상", "여행", "취미", "기타"]
    private let maxImages = 5
    
    init(post: Post) {
        self.post = post
        self._selectedCategory = State(initialValue: post.category)
        self._title = State(initialValue: post.title)
        self._content = State(initialValue: post.content)
        self._currentImages = State(initialValue: post.files)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        categorySection
                        imageSection
                        titleSection
                        contentSection
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                
                if viewModel.isLoading {
                    loadingIndicator
                }
            }
            .navigationTitle("게시글 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
        }
        .sheet(isPresented: $showImagePicker) {
            PostEditImagePickerView(selectedImages: $newImages, maxSelection: maxRemainingImageSlots)
        }
        .sheet(isPresented: $showCategorySheet) {
            CategorySelectionSheet(
                categories: categories,
                selectedCategory: $selectedCategory,
                showSheet: $showCategorySheet
            )
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
        .onChange(of: viewModel.isUpdated) { isUpdated in
            if isUpdated {
                dismiss()
            }
        }
    }
}

// MARK: - View Components

extension PostEditView {
    
    private var categorySection: some View {
        CategorySectionView(
            selectedCategory: selectedCategory,
            onTap: { showCategorySheet = true }
        )
    }
    
    private var imageSection: some View {
        ImageSectionView(
            currentImages: $currentImages,
            newImages: $newImages,
            maxImages: maxImages,
            totalImageCount: totalImageCount,
            onAddImage: { showImagePicker = true }
        )
    }
    
    private var titleSection: some View {
        TitleSectionView(title: $title)
    }
    
    private var contentSection: some View {
        ContentSectionView(content: $content)
    }
    
    private var loadingIndicator: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("게시글을 수정하는 중...")
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.top, 12)
        }
        .padding(24)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("취소") {
                dismiss()
            }
            .foregroundColor(.white)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("수정") {
                updatePost()
            }
            .foregroundColor(canUpdatePost ? .blue : .gray)
            .fontWeight(.semibold)
            .disabled(!canUpdatePost || viewModel.isLoading)
        }
    }
}

// MARK: - Computed Properties & Methods

extension PostEditView {
    
    private var totalImageCount: Int {
        currentImages.count + newImages.count
    }
    
    private var maxRemainingImageSlots: Int {
        max(0, maxImages - currentImages.count)
    }
    
    private var canUpdatePost: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedCategory.isEmpty &&
        hasChanges
    }
    
    private var hasChanges: Bool {
        selectedCategory != post.category ||
        title.trimmingCharacters(in: .whitespacesAndNewlines) != post.title ||
        content.trimmingCharacters(in: .whitespacesAndNewlines) != post.content ||
        !newImages.isEmpty ||
        currentImages != post.files
    }
    
    private func updatePost() {
        Task {
            await viewModel.updatePost(
                postId: post.postId,
                category: selectedCategory,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                currentImagePaths: currentImages,
                newImages: newImages
            )
        }
    }
}

// MARK: - Category Section Component

struct CategorySectionView: View {
    let selectedCategory: String
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("카테고리")
                .font(.pretendard(size: 16, weight: .semiBold))
                .foregroundColor(.white)
            
            Button(action: onTap) {
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
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - Category Selection Sheet

struct CategorySelectionSheet: View {
    let categories: [String]
    @Binding var selectedCategory: String
    @Binding var showSheet: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ForEach(categories, id: \.self) { category in
                    CategoryRowView(
                        category: category,
                        isSelected: selectedCategory == category,
                        onSelect: {
                            selectedCategory = category
                            showSheet = false
                        }
                    )
                    
                    if category != categories.last {
                        Divider()
                            .background(Color.gray.opacity(0.5))
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
                        showSheet = false
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Category Row Component

struct CategoryRowView: View {
    let category: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(category)
                    .font(.pretendard(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Image Section Component

struct ImageSectionView: View {
    @Binding var currentImages: [String]
    @Binding var newImages: [UIImage]
    let maxImages: Int
    let totalImageCount: Int
    let onAddImage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            imageScrollView
        }
    }
    
    private var sectionHeader: some View {
        HStack {
            Text("사진")
                .font(.pretendard(size: 16, weight: .semiBold))
                .foregroundColor(.white)
            
            Text("(\(totalImageCount)/\(maxImages))")
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    private var imageScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if totalImageCount < maxImages {
                    addImageButton
                }
                
                currentImagesView
                newImagesView
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var addImageButton: some View {
        Button(action: onAddImage) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundColor(.gray)
                    .font(.system(size: 24))
                
                Text("사진 추가")
                    .font(.pretendard(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(width: 80, height: 80)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
    }
    
    private var currentImagesView: some View {
        ForEach(Array(currentImages.enumerated()), id: \.offset) { index, imagePath in
            CurrentImageItemView(
                imagePath: imagePath,
                onDelete: {
                    currentImages.remove(at: index)
                }
            )
        }
    }
    
    private var newImagesView: some View {
        ForEach(Array(newImages.enumerated()), id: \.offset) { index, image in
            NewImageItemView(
                image: image,
                onDelete: {
                    newImages.remove(at: index)
                }
            )
        }
    }
}

// MARK: - Image Item Components

struct CurrentImageItemView: View {
    let imagePath: String
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            AuthenticatedImageView(
                imagePath: imagePath,
                contentMode: .fill,
                targetSize: CGSize(width: 80, height: 80)
            ) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.6)
                    )
            }
            .frame(width: 80, height: 80)
            .clipped()
            .cornerRadius(10)
            
            DeleteButton(onDelete: onDelete)
        }
    }
}

struct NewImageItemView: View {
    let image: UIImage
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(10)
            
            DeleteButton(onDelete: onDelete)
        }
    }
}

struct DeleteButton: View {
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .background(Color.white.clipShape(Circle()))
                .font(.system(size: 18))
        }
        .offset(x: 8, y: -8)
    }
}

// MARK: - Title Section Component

struct TitleSectionView: View {
    @Binding var title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("제목")
                .font(.pretendard(size: 16, weight: .semiBold))
                .foregroundColor(.white)
            
            TextField("제목을 입력하세요", text: $title)
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
        }
    }
}

// MARK: - Content Section Component

struct ContentSectionView: View {
    @Binding var content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내용")
                .font(.pretendard(size: 16, weight: .semiBold))
                .foregroundColor(.white)
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $content)
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .frame(minHeight: 120)
                
                if content.isEmpty {
                    Text("내용을 입력하세요...")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.gray60)
                        .padding(.leading, 20)
                        .padding(.top, 20)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

// MARK: - Post Edit Image Picker

struct PostEditImagePickerView: UIViewControllerRepresentable {
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
        let parent: PostEditImagePickerView
        
        init(_ parent: PostEditImagePickerView) {
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
    PostEditView(
        post: Post(
            id: "sample",
            postId: "sample",
            category: "핫스팟",
            title: "샘플 제목",
            content: "샘플 내용",
            geolocation: PostGeolocation(longitude: 127.049914, latitude: 37.654215),
            creator: PostCreator(
                userId: "user1",
                nick: "김새싹",
                name: "김새싹",
                introduction: "프로필 소개입니다.",
                profileImage: nil,
                hashTags: ["#맑음"]
            ),
            files: [],
            isLike: false,
            likeCount: 12,
            comments: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}
