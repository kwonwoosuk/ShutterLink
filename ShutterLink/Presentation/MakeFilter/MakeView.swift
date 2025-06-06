//
//  MakeView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/6/25.
//

import SwiftUI
import PhotosUI

struct MakeView: View {
    @StateObject private var viewModel = MakeViewModel()
    @EnvironmentObject private var router: NavigationRouter
    @State private var hasAppeared = false
    
    var body: some View {
        NavigationStack(path: $router.makePath) {
            makeContent
                .navigationDestination(for: MakeRoute.self) { route in
                    switch route {
                    case .editFilter(let originalImage):
                        MakeEditView(
                            originalImage: originalImage,
                            onComplete: { editedImage, editingState in
                                // 편집 완료 시 메인 화면으로 결과 전달
                                viewModel.filteredImage = editedImage
                                viewModel.editingState = editingState
                                viewModel.hasEditedImage = true
                                router.popMakeRoute()
                            }
                        )
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("MAKE")
                            .font(.hakgyoansim(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            // 뒤로 가기 (피드나 다른 탭으로)
                            router.selectTab(.feed)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // 편집된 이미지가 있고 저장 가능한 상태일 때만 저장 버튼 표시
                    if viewModel.hasEditedImage && viewModel.canSaveFilter {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                saveFilter()
                            } label: {
                                if viewModel.isUploading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image("Save")
                                        .overlay(DesignSystem.Colors.Gray.gray15)
                                        .mask(Image("Save"))
                                        .font(.system(size: 16))
                                        .frame(width: 24, height: 24)
                                }
                            }
                            .disabled(viewModel.isUploading)
                        }
                    }
                }
        }
    }
    
    @ViewBuilder
    private var makeContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    if viewModel.hasOriginalImage {
                        // 편집된 이미지가 있는 상태
                        editedImageSection
                    } else {
                        // 초기 상태 (이미지 없음)
                        initialStateSection
                    }
                    
                    // 공통 입력 필드들
                    inputFieldsSection
                    
                    // 카테고리 선택 아래에 사진 등록 (이미지가 없을 때만)
                    if !viewModel.hasOriginalImage {
                        addPhotoSection
                    }
                    
                    // 편집된 이미지가 있을 때만 EXIF 정보 표시
                    if viewModel.hasEditedImage, let metadata = viewModel.photoMetadata {
                        ExifInfoSection(metadata: metadata)
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 100)
                }
                .dismissKeyboardOnScroll()
                .padding(.top, 20)
            }
            
            // 토스트 메시지들
            if let successMessage = viewModel.successMessage {
                VStack {
                    ToastMessage(message: successMessage, isSuccess: true)
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .zIndex(1000)
            }
            
            if let errorMessage = viewModel.errorMessage {
                VStack {
                    ToastMessage(message: errorMessage, isSuccess: false)
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .zIndex(1000)
            }
        }
        .sheet(isPresented: $viewModel.isShowingImagePicker) {
            ImagePicker(image: Binding(
                get: { nil },
                set: { image in
                    if let image = image {
                        viewModel.handleImageSelection(image)
                    }
                }
            ))
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                print("🔵 MakeView: 화면 표시")
            }
        }
    }
    
    // MARK: - 편집된 이미지 섹션
    @ViewBuilder
    private var editedImageSection: some View {
        VStack(spacing: 16) {
            // 대표 사진 미리보기
            if let filteredImage = viewModel.filteredImage {
                Image(uiImage: filteredImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // 수정하기 버튼
            Button {
                router.pushToEditFilter(with: viewModel.originalImage)
            } label: {
                Text("수정하기")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DesignSystem.Colors.Brand.brightTurquoise)
                    )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 초기 상태 섹션
    @ViewBuilder
    private var initialStateSection: some View {
        VStack(spacing: 16) {
            Text("새로운 필터를 만들어보세요")
                .font(.hakgyoansim(size: 20, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("사진을 선택하고 편집하여\n나만의 필터를 제작할 수 있습니다")
                .font(.pretendard(size: 14, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
    }
    
    // MARK: - 입력 필드들 섹션
    @ViewBuilder
    private var inputFieldsSection: some View {
        VStack(spacing: 20) {
            // 필터명 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("필터명")
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                TextField("필터명을 입력하세요", text: $viewModel.filterTitle)
                    .font(.pretendard(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                    )
            }
            
            // 카테고리 선택
            CategorySelector(
                selectedCategory: $viewModel.selectedCategory,
                categories: viewModel.categories
            )
            
            // 판매 가격 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("판매 가격")
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                HStack {
                    TextField("가격", value: $viewModel.filterPrice, format: .number)
                        .font(.pretendard(size: 16, weight: .regular))
                        .foregroundColor(.white)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.15))
                        )
                    
                    Text("원")
                        .font(.pretendard(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            
            // 필터 소개 (항상 표시)
            VStack(alignment: .leading, spacing: 8) {
                Text("필터 소개")
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                TextField("필터에 대한 설명을 입력하세요", text: $viewModel.filterDescription, axis: .vertical)
                    .font(.pretendard(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .lineLimit(3...6)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 사진 등록 섹션 (카테고리 선택 아래)
    @ViewBuilder
    private var addPhotoSection: some View {
        VStack(spacing: 16) {
            Text("대표 사진 등록")
                .font(.pretendard(size: 16, weight: .semiBold))
                .foregroundColor(.white)
            
            Button {
                viewModel.input.selectImage.send()
            } label: {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 12) {
                            Circle()
                                .fill(DesignSystem.Colors.Brand.brightTurquoise)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.black)
                                )
                            
                            Text("사진 선택하기")
                                .font(.pretendard(size: 16, weight: .semiBold))
                                .foregroundColor(.white)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
                    )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 필터 저장 액션
    private func saveFilter() {
        guard !viewModel.filterTitle.isEmpty else {
            viewModel.errorMessage = "필터명을 입력해주세요."
            return
        }
        
        guard viewModel.filterPrice > 0 else {
            viewModel.errorMessage = "올바른 가격을 입력해주세요."
            return
        }
        
        guard !viewModel.filterDescription.isEmpty else {
            viewModel.errorMessage = "필터 소개를 입력해주세요."
            return
        }
        
        guard viewModel.hasEditedImage else {
            viewModel.errorMessage = "편집된 이미지가 필요합니다."
            return
        }
        
        print("💾 MakeView: 필터 저장 시작 - 제목: \(viewModel.filterTitle), 설명: \(viewModel.filterDescription)")
        
        viewModel.input.saveFilter.send((
            viewModel.filterTitle,
            viewModel.selectedCategory,
            viewModel.filterPrice,
            viewModel.filterDescription
        ))
    }
}

#Preview {
    NavigationStack {
        MakeView()
            .environmentObject(NavigationRouter.shared)
    }
    .preferredColorScheme(.dark)
}
