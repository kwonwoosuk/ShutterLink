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
    @State private var isShowingBefore = false
    
    private let properties = FilterProperty.properties
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 메인 이미지 영역 (전체 화면 활용)
                editingImageSection
                
                // 하단 편집 컨트롤
                editingControlsSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            
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
                print("🎨 MakeEditView: 화면 표시됨")
                print("🎨 초기 Undo 가능: \(viewModel.canUndo), Redo 가능: \(viewModel.canRedo)")
            }
        }
        .compatibleOnChange(of: viewModel.canUndo) { newValue in
            print("🎨 MakeEditView: Undo 상태 변경 - \(newValue)")
        }
        .compatibleOnChange(of: viewModel.canRedo) { newValue in
            print("🎨 MakeEditView: Redo 상태 변경 - \(newValue)")
        }
        .compatibleOnChange(of: selectedPropertyIndex) { newIndex in
            print("🎨 MakeEditView: 선택된 속성 변경 - \(properties[newIndex].name)")
        }
    }
    
    // MARK: - 편집 이미지 섹션
    @ViewBuilder
    private var editingImageSection: some View {
        GeometryReader { geometry in
            ZStack {
                // 메인 이미지
                Group {
                    if isShowingBefore {
                        // Before: 원본 이미지
                        if let originalImage = viewModel.originalImage {
                            Image(uiImage: originalImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    } else {
                        // After: 편집된 이미지
                        if let filteredImage = viewModel.filteredImage {
                            Image(uiImage: filteredImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if let originalImage = viewModel.originalImage {
                            Image(uiImage: originalImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                
                // Before/After 상태 라벨 (좌측 상단)
                VStack {
                    HStack {
                        Text(isShowingBefore ? "BEFORE" : "AFTER")
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
                    .padding(20)
                    Spacer()
                }
                
                // 플로팅 버튼들 (항상 표시)
                VStack {
                    Spacer()
                    HStack {
                        // 좌측: Undo/Redo 버튼들
                        HStack(spacing: 12) {
                            Button {
                                viewModel.input.undo.send()
                            } label: {
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image("Undo")
                                            .overlay(viewModel.canUndo ? DesignSystem.Colors.Gray.gray15 : Color.gray.opacity(0.5))
                                            .mask(Image("Undo"))
                                            .font(.system(size: 18))
                                            .frame(width: 24, height: 24)
                                    )
                            }
                            .disabled(!viewModel.canUndo)
                            
                            Button {
                                viewModel.input.redo.send()
                            } label: {
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image("Redo")
                                            .overlay(viewModel.canRedo ? DesignSystem.Colors.Gray.gray15 : Color.gray.opacity(0.5))
                                            .mask(Image("Redo"))
                                            .font(.system(size: 18))
                                            .frame(width: 24, height: 24)
                                    )
                            }
                            .disabled(!viewModel.canRedo)
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        // 우측: Before/After 버튼
                        Button {
                            // 이 버튼은 onPressingChanged를 사용하므로 여기서는 빈 액션
                        } label: {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image("Compare")
                                        .overlay(DesignSystem.Colors.Gray.gray15)
                                        .mask(Image("Compare"))
                                        .font(.system(size: 18))
                                        .frame(width: 24, height: 24)
                                )
                        }
                        .onPressingChanged { isPressing in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isShowingBefore = isPressing
                            }
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.bottom, 40) // 하단 컨트롤과 겹치지 않도록 여유 공간
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isShowingBefore)
    }
    
    // MARK: - 편집 컨트롤 섹션
    @ViewBuilder
    private var editingControlsSection: some View {
        VStack(spacing: 0) {
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
                
                EnhancedFilterSlider(
                    property: property,
                    value: currentValue,
                    onValueChanged: { key, value in
                        viewModel.input.editProperty.send((key, value))
                    }
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            
            // 하단 컨트롤 버튼들
            HStack(spacing: 20) {
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
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.9))
                .ignoresSafeArea(.container, edges: .bottom)
        )
    }
    
    // MARK: - 속성 선택 탭바
    @ViewBuilder
    private var propertyTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(properties.enumerated()), id: \.offset) { index, property in
                    Button {
                        selectedPropertyIndex = index
                    } label: {
                        VStack(spacing: 6) {
                            // 아이콘
                            Image(property.iconName)
                                .overlay(selectedPropertyIndex == index ? DesignSystem.Colors.Brand.brightTurquoise : DesignSystem.Colors.Gray.gray15)
                                .mask(Image(property.iconName))
                                .font(.system(size: 16))
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(selectedPropertyIndex == index ? DesignSystem.Colors.Brand.brightTurquoise.opacity(0.2) : Color.gray.opacity(0.3))
                                )
                            
                            // 제목
                            Text(property.name)
                                .font(.pretendard(size: 10, weight: .medium))
                                .foregroundColor(selectedPropertyIndex == index ? DesignSystem.Colors.Brand.brightTurquoise : .white)
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
        .padding(.bottom, 12)
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

// MARK: - 향상된 필터 슬라이더
struct EnhancedFilterSlider: View {
    let property: FilterProperty
    @Binding var value: Double
    let onValueChanged: (String, Double) -> Void
    
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 12) {
            // 속성 이름과 현재 값
            HStack {
                Text(property.name)
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(formatValue(value))
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                    .monospacedDigit()
            }
            
            // 커스텀 슬라이더
            GeometryReader { geometry in
                let trackWidth = geometry.size.width
                let normalizedValue = (value - property.minValue) / (property.maxValue - property.minValue)
                let thumbPosition = trackWidth * CGFloat(normalizedValue)
                
                ZStack(alignment: .leading) {
                    // 배경 트랙
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    
                    // 진행 바
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignSystem.Colors.Brand.brightTurquoise)
                        .frame(width: thumbPosition, height: 8)
                    
                    // 슬라이더 썸
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                        .scaleEffect(isDragging ? 1.2 : 1.0)
                        .offset(x: thumbPosition - 10) // 썸 중앙 정렬
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    if !isDragging {
                                        isDragging = true
                                        print("🎛️ EnhancedFilterSlider: 드래그 시작 - \(property.name)")
                                    }
                                    
                                    let newPosition = max(0, min(trackWidth, gesture.location.x))
                                    let newNormalizedValue = newPosition / trackWidth
                                    let newValue = property.minValue + Double(newNormalizedValue) * (property.maxValue - property.minValue)
                                    
                                    // 스텝에 맞춰 값 조정
                                    let steppedValue = round(newValue / property.step) * property.step
                                    
                                    value = steppedValue
                                    onValueChanged(property.key, steppedValue)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    print("🎛️ EnhancedFilterSlider: 드래그 완료 - \(property.name): \(value)")
                                    // 드래그 완료 시에는 별도 처리 없음 (이미 onValueChanged에서 처리)
                                }
                        )
                }
            }
            .frame(height: 20)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
            
            // 범위 표시
            HStack {
                Text(formatValue(property.minValue))
                    .font(.pretendard(size: 11, weight: .regular))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(formatValue(property.maxValue))
                    .font(.pretendard(size: 11, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func formatValue(_ val: Double) -> String {
        if property.key == "temperature" {
            return String(format: "%.0fK", val)
        } else {
            return String(format: "%.2f", val)
        }
    }
}

// MARK: - onPressingChanged 제스처 확장
extension View {
    func onPressingChanged(_ action: @escaping (Bool) -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    action(true)
                }
                .onEnded { _ in
                    action(false)
                }
        )
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
