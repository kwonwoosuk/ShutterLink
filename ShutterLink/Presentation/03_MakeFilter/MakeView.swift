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
                    case .create:
                        // 필터 생성 화면
                        createFilterContent
                    case .editFilter(let originalImage):
                        MakeEditView(
                            originalImage: originalImage,
                            onComplete: { editedImage, editingState in
                                // 편집 완료 시 메인 화면으로 결과 전달
                                viewModel.filteredImage = editedImage
                                viewModel.editingState = editingState
                                viewModel.hasEditedImage = true
                                if viewModel.originalImage == nil {
                                    viewModel.originalImage = originalImage
                                }
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
                }
        }
        .onDisappear {
            
            print("🧹 MakeView: 화면 사라짐 - 이미지 초기화")
            clearAllImages()
        }
    }
    
    @ViewBuilder
    private var makeContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // 메인 타이틀과 설명
                VStack(spacing: 16) {
                    Text("새로운 필터를 만들어보세요")
                        .font(.hakgyoansim(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("사진을 선택하고 편집하여\n나만의 필터를 제작할 수 있습니다")
                        .font(.pretendard(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                // 필터 생성 버튼
                Button {
                    router.pushToCreateFilter()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                        
                        Text("새로운 필터 생성하기")
                            .font(.pretendard(size: 16, weight: .semiBold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DesignSystem.Colors.Brand.brightTurquoise)
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var createFilterContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // 필터명 입력 (카테고리 위로 이동)
                    filterNameSection
                    
                    // 카테고리 선택
                    categorySection
                    
                    // 대표 사진 등록 (카테고리 바로 밑)
                    photoRegistrationSection
                    
                    // 나머지 입력 필드들
                    remainingInputFieldsSection
                    
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
                        // 사진 선택 후 바로 편집 화면으로 이동
                        router.pushToEditFilter(with: image)
                    }
                }
            ))
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("필터 생성")
                    .font(.hakgyoansim(size: 18, weight: .bold))
                    .foregroundColor(.gray45)
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    router.popMakeRoute()
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
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                print("🔵 MakeView: 필터 생성 화면 표시")
            }
        }
        .onDisappear {
            // 🆕 추가 - 필터 생성 화면을 떠날 때도 이미지 초기화
            print("🧹 MakeView: 필터 생성 화면 사라짐 - 이미지 초기화")
            clearAllImages()
        }
    }
    
    // MARK: - 필터명 섹션
    @ViewBuilder
    private var filterNameSection: some View {
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
        .padding(.horizontal, 20)
    }
    @ViewBuilder
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("카테고리")
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.categories, id: \.self) { category in
                        Button {
                            viewModel.selectedCategory = category
                        } label: {
                            Text(category)
                                .font(.pretendard(size: 14, weight: .medium))
                                .foregroundColor(viewModel.selectedCategory == category ? .black : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(viewModel.selectedCategory == category ? DesignSystem.Colors.Brand.brightTurquoise : Color.gray.opacity(0.3))
                                )
                        }
                        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedCategory)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 대표 사진 등록 섹션 (편집된 이미지 표시 포함)
    @ViewBuilder
    private var photoRegistrationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("대표 사진 등록")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            Button {
                viewModel.input.selectImage.send()
            } label: {
                Group {
                    if let displayImage = viewModel.filteredImage ?? viewModel.originalImage {
                        // 편집된 이미지 또는 원본 이미지가 있는 경우
                        Image(uiImage: displayImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(DesignSystem.Colors.Brand.brightTurquoise, lineWidth: 2)
                            )
                            .overlay(
                                // 편집 상태 표시 및 버튼들
                                VStack {
                                    // 편집 상태 표시
                                    if viewModel.hasEditedImage {
                                        HStack {
                                            Text("편집됨")
                                                .font(.pretendard(size: 12, weight: .semiBold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(DesignSystem.Colors.Brand.brightTurquoise)
                                                )
                                            Spacer()
                                        }
                                        .padding(12)
                                    }
                                    
                                    Spacer()
                                    
                                    // 하단 버튼들
                                    HStack {
                                        Spacer()
                                        
                                        HStack(spacing: 12) {
                                            // 다시 선택하기 버튼
                                            Button {
                                                viewModel.input.selectImage.send()
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "camera.fill")
                                                        .font(.system(size: 12, weight: .medium))
                                                    Text("변경")
                                                        .font(.pretendard(size: 12, weight: .semiBold))
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.black.opacity(0.7))
                                                )
                                            }
                                            
                                            // 수정하기 버튼 (이미지가 있을 때만)
                                            if viewModel.originalImage != nil {
                                                Button {
                                                    router.pushToEditFilter(with: viewModel.originalImage)
                                                } label: {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "slider.horizontal.3")
                                                            .font(.system(size: 12, weight: .medium))
                                                        Text("편집")
                                                            .font(.pretendard(size: 12, weight: .semiBold))
                                                    }
                                                    .foregroundColor(.black)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        Capsule()
                                                            .fill(DesignSystem.Colors.Brand.brightTurquoise)
                                                    )
                                                }
                                            }
                                        }
                                        .padding(12)
                                    }
                                }
                            )
                    } else {
                        // 이미지가 선택되지 않은 경우
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
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 나머지 입력 필드들 섹션
    @ViewBuilder
    private var remainingInputFieldsSection: some View {
        VStack(spacing: 20) {
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
            
            // 필터 소개
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
    
    // MARK: - 필터 저장 액션
    private func saveFilter() {
        let trimmedTitle = viewModel.filterTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = viewModel.filterDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            viewModel.errorMessage = "필터명을 입력해주세요."
            return
        }
        
        guard viewModel.filterPrice > 0 else {
            viewModel.errorMessage = "올바른 가격을 입력해주세요."
            return
        }
        
        guard !trimmedDescription.isEmpty else {
            viewModel.errorMessage = "필터 소개를 입력해주세요."
            return
        }
        
        print("💾 MakeView: 필터 저장 데이터 확인")
        print("   제목: '\(trimmedTitle)'")
        print("   카테고리: '\(viewModel.selectedCategory)'")
        print("   가격: \(viewModel.filterPrice)")
        print("   소개: '\(trimmedDescription)'")
        print("   소개 길이: \(trimmedDescription.count)")
        
        viewModel.input.saveFilter.send((
            trimmedTitle,
            viewModel.selectedCategory,
            viewModel.filterPrice,
            trimmedDescription
        ))
    }
    
    // 🆕 추가 메서드 - 모든 이미지 초기화
    private func clearAllImages() {
        print("🧹 MakeView: 모든 이미지 데이터 초기화 시작")
        
        // ViewModel의 전체 데이터 초기화
        viewModel.clearAllData()
        
        print("✅ MakeView: 모든 이미지 데이터 초기화 완료")
    }
}

#Preview {
    NavigationStack {
        MakeView()
            .environmentObject(NavigationRouter.shared)
    }
    .preferredColorScheme(.dark)
}
