//
//  MakeEditView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/6/25.
//

import SwiftUI

struct MakeEditView: View {
    let originalImage: UIImage?
    let onComplete: (UIImage?, EditingState) -> Void
    
    @StateObject private var viewModel = MakeViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPropertyIndex = 0
    @State private var hasAppeared = false
    
    private let properties = FilterProperty.properties
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 편집 이미지 영역
                editingImageSection
                
                // 하단 편집 컨트롤
                editingControlsSection
            }
            
            // 플로팅 편집 버튼들 (Undo/Redo, Before/After)
            EditingControlButtons(
                canUndo: viewModel.canUndo,
                canRedo: viewModel.canRedo,
                onUndo: {
                    viewModel.input.undo.send()
                },
                onRedo: {
                    viewModel.input.redo.send()
                },
                onBeforeAfterStart: {
                    viewModel.startPreviewingOriginal()
                },
                onBeforeAfterEnd: {
                    viewModel.stopPreviewingOriginal()
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("EDIT")
                    .font(.hakgyoansim(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    completeEditing()
                } label: {
                    Text("완료")
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                setupInitialImage()
            }
        }
    }
    
    // MARK: - 편집 이미지 섹션
    @ViewBuilder
    private var editingImageSection: some View {
        GeometryReader { geometry in
            let imageSize = geometry.size.width
            
            ZStack {
                // 현재 편집 중인 이미지 또는 원본 이미지 (Before/After 상태에 따라)
                if viewModel.isPreviewingOriginal {
                    // Before: 원본 이미지
                    if let originalImage = viewModel.originalImage {
                        Image(uiImage: originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: imageSize, height: imageSize)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else {
                    // After: 편집된 이미지
                    if let filteredImage = viewModel.filteredImage {
                        Image(uiImage: filteredImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: imageSize, height: imageSize)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                
                // Before/After 상태 라벨
                if viewModel.isPreviewingOriginal {
                    VStack {
                        HStack {
                            Text("BEFORE")
                                .font(.pretendard(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.7))
                                )
                            Spacer()
                        }
                        .padding(16)
                        Spacer()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isPreviewingOriginal)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - 편집 컨트롤 섹션
    @ViewBuilder
    private var editingControlsSection: some View {
        VStack(spacing: 16) {
            // 속성 선택 탭바
            propertyTabBar
            
            // 선택된 속성의 슬라이더
            if selectedPropertyIndex < properties.count {
                let property = properties[selectedPropertyIndex]
                let currentValue = Binding(
                    get: { viewModel.editingState.getValue(for: property.key) },
                    set: { newValue in
                        viewModel.input.editProperty.send((property.key, newValue))
                    }
                )
                
                FilterPropertySlider(
                    property: property,
                    value: currentValue,
                    onValueChanged: { key, value in
                        viewModel.input.editProperty.send((key, value))
                    }
                )
                .padding(.horizontal, 20)
            }
            
            // 리셋 버튼
            Button {
                viewModel.input.resetToOriginal.send()
            } label: {
                Text("리셋")
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                    )
            }
        }
        .padding(.bottom, 40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.8))
                .ignoresSafeArea(.container, edges: .bottom)
        )
    }
    
    // MARK: - 속성 선택 탭바
    @ViewBuilder
    private var propertyTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(Array(properties.enumerated()), id: \.offset) { index, property in
                    Button {
                        selectedPropertyIndex = index
                    } label: {
                        VStack(spacing: 8) {
                            Image(property.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(selectedPropertyIndex == index ? DesignSystem.Colors.Brand.brightTurquoise : .white)
                            
                            Text(property.name)
                                .font(.pretendard(size: 10, weight: .medium))
                                .foregroundColor(selectedPropertyIndex == index ? DesignSystem.Colors.Brand.brightTurquoise : .white)
                        }
                        .frame(width: 60)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
    }
    
    // MARK: - 초기 이미지 설정
    private func setupInitialImage() {
        if let originalImage = originalImage {
            viewModel.handleImageSelection(originalImage)
        }
    }
    
    // MARK: - 편집 완료
    private func completeEditing() {
        viewModel.input.completeEditing.send()
        onComplete(viewModel.filteredImage, viewModel.editingState)
    }
}

#Preview {
    NavigationStack {
        MakeEditView(
            originalImage: nil,
            onComplete: { _, _ in }
        )
    }
    .preferredColorScheme(.dark)
}
