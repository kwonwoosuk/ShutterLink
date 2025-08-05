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
    @StateObject private var filterStateManager = EditingStateManager()
    @StateObject private var imageProcessor = CoreImageProcessor()
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProperty: EditingStateProperty = .brightness
    @State private var showBeforeImage = false
    @State private var hasAppeared = false
    @State private var isDraggingSlider = false
    @State private var dragStartState: EditingState?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 상단 컨트롤 바 (항상 표시)
                topControlBar
                
                // 메인 이미지 영역
                imageSection
                
                // 하단 필터 컨트롤 바
                bottomControlBar
            }
            
            // 로딩 오버레이
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .navigationBarHidden(false)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
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
                .disabled(viewModel.isLoading)
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                setupInitialImage()
                print("🎨 MakeEditView: 화면 표시됨")
            }
        }
        .onChange(of: filterStateManager.currentState) { newState in
            updateImageWithState(newState)
        }
    }
    
    // MARK: - Views
    
    private var topControlBar: some View {
        HStack(spacing: 16) {
            // Undo 버튼
            Button {
                filterStateManager.undo()
            } label: {
                VStack(spacing: 4) {
                    Image("Undo")
                        .overlay(filterStateManager.canUndo ? DesignSystem.Colors.Gray.gray15 : Color.gray)
                        .mask(Image("Undo"))
                        .font(.system(size: 16))
                        .frame(width: 24, height: 24)
                    
                    Text("Undo")
                        .font(.pretendard(size: 10, weight: .medium))
                        .foregroundColor(filterStateManager.canUndo ? .white : .gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!filterStateManager.canUndo)
            
            // Redo 버튼
            Button {
                filterStateManager.redo()
            } label: {
                VStack(spacing: 4) {
                    Image("Redo")
                        .overlay(filterStateManager.canRedo ? DesignSystem.Colors.Gray.gray15 : Color.gray)
                        .mask(Image("Redo"))
                        .font(.system(size: 16))
                        .frame(width: 24, height: 24)
                    
                    Text("Redo")
                        .font(.pretendard(size: 10, weight: .medium))
                        .foregroundColor(filterStateManager.canRedo ? .white : .gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!filterStateManager.canRedo)
            
            Spacer()
            
            // Before/After 버튼
            Button {
                // 버튼을 누르고 있는 동안 Before 이미지 표시
            } label: {
                VStack(spacing: 4) {
                    Image("Compare")
                        .overlay(DesignSystem.Colors.Gray.gray15)
                        .mask(Image("Compare"))
                        .font(.system(size: 16))
                        .frame(width: 24, height: 24)
                    
                    Text("비교")
                        .font(.pretendard(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !showBeforeImage {
                            showBeforeImage = true
                        }
                    }
                    .onEnded { _ in
                        showBeforeImage = false
                    }
            )
            
            // 리셋 버튼
            Button {
                filterStateManager.resetToDefault()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    
                    Text("리셋")
                        .font(.pretendard(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.8))
        )
    }
    
    private var imageSection: some View {
        GeometryReader { geometry in
            // 안전한 imageSize 계산 - 최소값 보장
            let safeWidth = max(geometry.size.width - 40, 100)
            let safeHeight = max(geometry.size.height - 40, 100)
            let imageSize = max(min(safeWidth, safeHeight), 100) // 최소 100pt 보장
            
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Group {
                        if showBeforeImage, let originalImage = viewModel.originalImage {
                            // Before 이미지 (원본)
                            createImageView(
                                image: originalImage,
                                size: imageSize,
                                label: "Before"
                            )
                        } else if let filteredImage = viewModel.filteredImage {
                            // After 이미지 (편집된)
                            createImageView(
                                image: filteredImage,
                                size: imageSize,
                                label: "After"
                            )
                        } else {
                            // 플레이스홀더
                            createPlaceholderView(size: imageSize)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: showBeforeImage)
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
        .background(Color.black)
    }
    
    // MARK: - Helper Views for Image Section
    
    @ViewBuilder
    private func createImageView(image: UIImage, size: CGFloat, label: String) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .overlay(
                VStack {
                    HStack {
                        Text(label)
                            .font(.pretendard(size: 12, weight: .semiBold))
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
            )
    }
    
    @ViewBuilder
    private func createPlaceholderView(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("이미지를 선택하세요")
                        .font(.pretendard(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
            )
    }
    
    private var bottomControlBar: some View {
        VStack(spacing: 0) {
            // 필터 속성 아이콘 바
            VStack(spacing: 12) {
                HStack {
                    Text(selectedProperty.title)
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(formatValue(filterStateManager.currentState.getValue(for: selectedProperty.key), for: selectedProperty))
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                }
                
                optimizedSlider
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(EditingStateProperty.allCases, id: \.self) { property in
                        Button {
                            selectedProperty = property
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(selectedProperty == property ?
                                              DesignSystem.Colors.Brand.brightTurquoise :
                                              Color.gray.opacity(0.4))
                                        .frame(width: 56, height: 56)
                                    
                                    Image(property.iconName)
                                        .overlay(selectedProperty == property ? Color.black : DesignSystem.Colors.Gray.gray15)
                                        .mask(Image(property.iconName))
                                        .font(.system(size: 16))
                                        .frame(width: 28, height: 28)
                                }
                                
                                Text(property.title)
                                    .font(.pretendard(size: 11, weight: .medium))
                                    .foregroundColor(selectedProperty == property ?
                                                   DesignSystem.Colors.Brand.brightTurquoise : .gray)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .padding(.bottom, 60)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.9))
        )
    }
    
    // MARK: - 최적화된 슬라이더
    private var optimizedSlider: some View {
        GeometryReader { geometry in
            let range = selectedProperty.range
            let currentValue = filterStateManager.currentState.getValue(for: selectedProperty.key)
            let normalizedValue = (currentValue - range.lowerBound) / (range.upperBound - range.lowerBound)
            let trackWidth = max(geometry.size.width - 24, 0) // 음수 방지
            
            ZStack(alignment: .leading) {
                // 배경 트랙
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)
                
                // 진행 바
                if trackWidth > 0 {
                    Capsule()
                        .fill(DesignSystem.Colors.Brand.brightTurquoise)
                        .frame(width: trackWidth * CGFloat(max(0, min(1, normalizedValue))), height: 8)
                }
                
                // 슬라이더 썸
                if trackWidth > 0 {
                    Circle()
                        .fill(.white)
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .scaleEffect(isDraggingSlider ? 1.2 : 1.0)
                        .offset(x: trackWidth * CGFloat(max(0, min(1, normalizedValue))))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    // 드래그 시작 시 현재 상태 저장 (한 번만)
                                    if !isDraggingSlider {
                                        isDraggingSlider = true
                                        dragStartState = filterStateManager.currentState
                                        print("🎛️ 슬라이더 드래그 시작 - \(selectedProperty.title)")
                                    }
                                    
                                    let newPosition = max(0, min(trackWidth, gesture.location.x))
                                    let newNormalizedValue = trackWidth > 0 ? newPosition / trackWidth : 0
                                    let newValue = range.lowerBound + Double(newNormalizedValue) * (range.upperBound - range.lowerBound)
                                    
                                    // 실시간 업데이트 (스택에 저장하지 않음)
                                    var newState = filterStateManager.currentState
                                    newState.setValue(for: selectedProperty.key, value: newValue)
                                    filterStateManager.currentState = newState
                                }
                                .onEnded { _ in
                                    // 드래그 완료 시에만 undo 스택에 저장
                                    if let startState = dragStartState {
                                        filterStateManager.saveStateToUndoStack(startState)
                                        print("🎛️ 슬라이더 드래그 완료 - \(selectedProperty.title): \(currentValue)")
                                    }
                                    
                                    isDraggingSlider = false
                                    dragStartState = nil
                                }
                        )
                }
            }
        }
        .frame(height: 28)
        .animation(.easeInOut(duration: 0.2), value: isDraggingSlider)
    }
    
    private var loadingOverlay: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("이미지 처리 중...")
                .font(.pretendard(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Helper Methods
    
    private func formatValue(_ value: Double, for property: EditingStateProperty) -> String {
        switch property {
        case .temperature:
            return "\(Int(value))K"
        default:
            return String(format: "%.1f", value)
        }
    }
    
    private func setupInitialImage() {
        if let originalImage = originalImage {
            viewModel.handleImageSelection(originalImage)
            imageProcessor.setOriginalImage(originalImage)
            
            // 초기 상태 설정 - EditingState.defaultState 사용
            filterStateManager.currentState = EditingState.defaultState
            updateImageWithState(filterStateManager.currentState)
        }
    }
    
    private func updateImageWithState(_ state: EditingState) {
        guard let originalImage = viewModel.originalImage else { return }
        
        // 백그라운드에서 필터 적용s
        Task.detached(priority: .userInitiated) {
            let filteredImage = await self.imageProcessor.applyFilters(with: state)
            
            await MainActor.run {
                self.viewModel.filteredImage = filteredImage ?? originalImage
                self.viewModel.editingState = state
            }
        }
    }
    
    private func completeEditing() {
        guard let filteredImage = viewModel.filteredImage else {
            onComplete(nil, viewModel.editingState)
            return
        }
        
        // 5MB 제한 내에서 최적화된 이미지 생성
        Task {
            viewModel.isLoading = true
            
            let optimizedImage = await optimizeImageForUpload(filteredImage)
            
            await MainActor.run {
                viewModel.isLoading = false
                onComplete(optimizedImage, viewModel.editingState)
            }
        }
    }
    
    // MARK: - 이미지 업로드 최적화
    private func optimizeImageForUpload(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let maxFileSize: Int = 5 * 1024 * 1024 // 5MB
                
                // 1단계: 원본 이미지에서 시작
                var currentImage = image
                var compressionQuality: CGFloat = 0.9
                
                // 2단계: 압축률 조정으로 5MB 이하로 만들기
                while compressionQuality > 0.1 {
                    if let imageData = currentImage.jpegData(compressionQuality: compressionQuality),
                       imageData.count <= maxFileSize {
                        print("✅ 압축 완료 - 품질: \(Int(compressionQuality * 100))%, 크기: \(imageData.count / 1024)KB")
                        continuation.resume(returning: currentImage)
                        return
                    }
                    compressionQuality -= 0.1
                }
                
                // 3단계: 압축률로도 안되면 이미지 크기 축소
                let maxDimension: CGFloat = 2048
                if max(currentImage.size.width, currentImage.size.height) > maxDimension {
                    let scale = maxDimension / max(currentImage.size.width, currentImage.size.height)
                    let newSize = CGSize(
                        width: currentImage.size.width * scale,
                        height: currentImage.size.height * scale
                    )
                    
                    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                    currentImage.draw(in: CGRect(origin: .zero, size: newSize))
                    if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                        currentImage = resizedImage
                    }
                    UIGraphicsEndImageContext()
                    
                    // 4단계: 리사이즈된 이미지로 다시 압축 시도
                    compressionQuality = 0.8
                    while compressionQuality > 0.1 {
                        if let imageData = currentImage.jpegData(compressionQuality: compressionQuality),
                           imageData.count <= maxFileSize {
                            print("✅ 리사이즈 후 압축 완료 - 품질: \(Int(compressionQuality * 100))%, 크기: \(imageData.count / 1024)KB")
                            continuation.resume(returning: currentImage)
                            return
                        }
                        compressionQuality -= 0.1
                    }
                }
                
                // 최종: 최소 품질로라도 반환
                if let finalData = currentImage.jpegData(compressionQuality: 0.1) {
                    print("⚠️ 최소 품질로 압축 - 크기: \(finalData.count / 1024)KB")
                }
                continuation.resume(returning: currentImage)
            }
        }
    }
}

// MARK: - EditingState 속성 enum
enum EditingStateProperty: String, CaseIterable {
    case brightness = "brightness"
    case exposure = "exposure"
    case contrast = "contrast"
    case saturation = "saturation"
    case sharpness = "sharpness"
    case blur = "blur"
    case vignette = "vignette"
    case noiseReduction = "noiseReduction"
    case highlights = "highlights"
    case shadows = "shadows"
    case temperature = "temperature"
    case blackPoint = "blackPoint"
    
    var title: String {
        switch self {
        case .brightness: return "밝기"
        case .exposure: return "노출"
        case .contrast: return "대비"
        case .saturation: return "채도"
        case .sharpness: return "선명도"
        case .blur: return "블러"
        case .vignette: return "비네팅"
        case .noiseReduction: return "노이즈"
        case .highlights: return "하이라이트"
        case .shadows: return "섀도우"
        case .temperature: return "색온도"
        case .blackPoint: return "블랙포인트"
        }
    }
    
    var iconName: String {
        switch self {
        case .brightness: return "Brightness"
        case .exposure: return "Exposure"
        case .contrast: return "Contrast"
        case .saturation: return "Saturation"
        case .sharpness: return "Sharpness"
        case .blur: return "Blur"
        case .vignette: return "Vignette"
        case .noiseReduction: return "Noise"
        case .highlights: return "Highlights"
        case .shadows: return "Shadows"
        case .temperature: return "Temperature"
        case .blackPoint: return "BlackPoint"
        }
    }
    
    var range: ClosedRange<Double> {
        switch self {
        case .brightness, .exposure, .sharpness, .blur, .vignette, .noiseReduction, .highlights, .shadows, .blackPoint:
            return -1.0...1.0
        case .contrast, .saturation:
            return 0.0...2.0
        case .temperature:
            return 2000...10000
        }
    }
    
    var key: String {
        return self.rawValue
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
