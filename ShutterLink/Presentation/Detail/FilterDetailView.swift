//
//  FilterDetailView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/26/25.
//

import SwiftUI

struct FilterDetailView: View {
    let filterId: String
    @StateObject private var viewModel = FilterDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var hasAppeared = false
    @State private var showChatOuterView = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if let filterDetail = viewModel.filterDetail {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 이미지 비교 섹션 (사진 아래 디바이더 포함)
                        InteractiveBeforeAfterView(
                            imagePath: filterDetail.files.first ?? "",
                            filterValues: filterDetail.filterValues
                        )
                        .frame(height: 400)
                        .padding(.top, 40)
                        
                        // 필터 정보와 통계
                        FilterInfoWithStatsSection(filterDetail: filterDetail)
                        
                        // 사진 메타데이터 섹션 (위치 정보 포함)
                        PhotoMetadataWithLocationSection(metadata: filterDetail.photoMetadata)
                        
                        // 필터 프리셋 섹션 (결제 상태에 따라 다르게 표시)
                        FilterPresetsSection(
                            filterValues: filterDetail.filterValues,
                            isPurchased: filterDetail.is_downloaded
                        )
                        
                        // 결제/다운로드 버튼 - 결제 처리 로직 연결
                        PurchaseDownloadButton(
                            price: filterDetail.price,
                            isPurchased: filterDetail.is_downloaded,
                            isPurchasing: viewModel.isPurchasing, // 결제 중 상태 추가
                            onPurchase: {
                                // 결제 처리 로직 - ViewModel에 신호 전달
                                print("🔵 FilterDetailView: 결제 버튼 탭 - \(filterId)")
                                viewModel.input.purchaseFilter.send(filterId)
                            }
                        )
                        
                        // 크리에이터 프로필 섹션 (채팅 버튼 포함)
                        CreatorProfileWithChatSection(
                            creator: filterDetail.creator,
                            onChatTap: {
                                showChatOuterView = true
                            }
                        )
                        
                        // 하단 여백
                        Color.clear.frame(height: 100)
                    }
                }
            } else if viewModel.isLoading {
                LoadingIndicatorView()
            } else if let errorMessage = viewModel.errorMessage {
                ErrorStateView(errorMessage: errorMessage) {
                    viewModel.input.loadFilterDetail.send(filterId)
                }
            }
            
            // 성공/에러 메시지 토스트 (상단에 표시)
            if let errorMessage = viewModel.errorMessage, !viewModel.isLoading {
                VStack {
                    ToastMessageView(
                        message: errorMessage,
                        isSuccess: errorMessage.contains("완료")
                    )
                    .padding(.top, 10) // 네비게이션 바 아래에 표시
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .zIndex(1000) // 다른 뷰들 위에 표시
            }
        }
        .navigationBarHidden(false)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 커스텀 백버튼
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.Gray.gray75)
                }
            }
            
            // 커스텀 타이틀
            ToolbarItem(placement: .principal) {
                if let filterDetail = viewModel.filterDetail {
                    Text(filterDetail.title)
                        .font(.hakgyoansim(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else {
                    Text("")
                        .font(.hakgyoansim(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // 좋아요 버튼 (우상단으로 이동)
            ToolbarItem(placement: .navigationBarTrailing) {
                if let filterDetail = viewModel.filterDetail {
                    Button {
                        viewModel.input.likeFilter.send((filterId, !filterDetail.is_liked))
                    } label: {
                        Image(systemName: filterDetail.is_liked ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(filterDetail.is_liked ? .red : DesignSystem.Colors.Gray.gray75)
                    }
                } else {
                    Image(systemName: "heart")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.Gray.gray75)
                }
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.input.loadFilterDetail.send(filterId)
                }
            }
        }
        .sheet(isPresented: $showChatOuterView) {
            // 채팅 뷰 (향후 구현)
            NavigationStack {
                VStack {
                    Text("채팅 기능")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("곧 출시됩니다!")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .navigationTitle("채팅")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("닫기") {
                            showChatOuterView = false
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - 토스트 메시지 뷰 추가
struct ToastMessageView: View {
    let message: String
    let isSuccess: Bool
    @State private var isVisible = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isSuccess ? .green : .red)
                .font(.system(size: 20))
            
            Text(message)
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onAppear {
            // 3초 후 자동으로 사라지는 애니메이션
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                }
            }
        }
    }
}

// MARK: - 기존 결제/다운로드 버튼 업데이트
struct PurchaseDownloadButton: View {
    let price: Int
    let isPurchased: Bool
    let isPurchasing: Bool // 결제 중 상태 추가
    let onPurchase: () -> Void
    
    var body: some View {
        Button {
            if !isPurchased && !isPurchasing {
                onPurchase()
            }
        } label: {
            HStack {
                if isPurchasing {
                    // 결제 중 상태
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("결제 중...")
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                } else if isPurchased {
                    // 구매 완료 상태
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("구매완료")
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                } else {
                    // 결제 전 상태
                    Text("₩\(formatPrice(price)) 결제하기")
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonBackgroundColor)
            )
        }
        .disabled(isPurchased || isPurchasing)
        .padding(.horizontal, 20)
    }
    
    private var buttonBackgroundColor: Color {
        if isPurchasing {
            return Color.gray.opacity(0.6)
        } else if isPurchased {
            return Color.green.opacity(0.2)
        } else {
            return DesignSystem.Colors.Brand.brightTurquoise
        }
    }
    
    private func formatPrice(_ price: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }
}

// MARK: - 나머지 기존 컴포넌트들은 동일하게 유지...

// MARK: - 드래그 가능한 Before/After 이미지 비교 뷰
struct InteractiveBeforeAfterView: View {
    let imagePath: String
    let filterValues: FilterValues
    @State private var dividerPosition: CGFloat = 0.5
    @State private var isDragging: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 메인 이미지 영역
            GeometryReader { geometry in
                ZStack {
                    // Before 이미지 (원본) - 전체 이미지
                    if !imagePath.isEmpty {
                        AuthenticatedImageView(
                            imagePath: imagePath,
                            contentMode: .fill
                        ) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                )
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .cornerRadius(16)
                    }
                    
                    // After 이미지 (필터 적용) - 디바이더 위치에 따라 표시
                    if !imagePath.isEmpty {
                        AuthenticatedImageView(
                            imagePath: imagePath,
                            contentMode: .fill
                        ) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.2 + filterValues.saturation * 0.15),
                                    Color.cyan.opacity(0.1 + filterValues.contrast * 0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .blendMode(.multiply)
                        )
                        .brightness(filterValues.brightness * 0.3)
                        .contrast(1 + filterValues.contrast * 0.5)
                        .saturation(1 + filterValues.saturation)
                        .mask(
                            Rectangle()
                                .frame(width: geometry.size.width * dividerPosition, height: geometry.size.height)
                                .position(x: geometry.size.width * dividerPosition / 2, y: geometry.size.height / 2)
                        )
                        .cornerRadius(16)
                    }
                }
            }
            .frame(height: 400)
            
            // 통합된 디바이더 컨트롤
            ConnectedControlView(
                dividerPosition: $dividerPosition,
                isDragging: $isDragging
            )
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 연결된 컨트롤 뷰 (After-Divider-Before 통합)
struct ConnectedControlView: View {
    @Binding var dividerPosition: CGFloat
    @Binding var isDragging: Bool
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            // 통합된 After-Divider-Before 뷰
            HStack(spacing: 0) {
                // After 버튼
                Text("After")
                    .font(.pretendard(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 24)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.Gray.gray60.opacity(0.7))
                    )
                
                // 디바이더 버튼
                Button {
                    // 탭하면 중앙으로 리셋
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dividerPosition = 0.5
                    }
                } label: {
                    Image("DivideButton")
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.Gray.gray60)
                                .frame(width: 32, height: 32)
                        )
                        .scaleEffect(isDragging ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isDragging)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Before 버튼
                Text("Before")
                    .font(.pretendard(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 24)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.Gray.gray60.opacity(0.7))
                    )
            }
            .offset(x: dragOffset)
            .frame(maxWidth: .infinity)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        
                        // 슬라이드 영역 중앙 기준으로 상대 위치 계산
                        let trackWidth = geometry.size.width - 40
                        let relativeX = value.location.x - (trackWidth / 2)
                        
                        // 슬라이드 범위 제한 (± (trackWidth - 버튼 전체 너비) / 2)
                        let buttonGroupWidth: CGFloat = 60 + 32 + 60 // After + Divider + Before
                        let maxOffset = (trackWidth - buttonGroupWidth) / 2
                        dragOffset = max(-maxOffset, min(maxOffset, relativeX))
                        
                        // dragOffset을 dividerPosition으로 변환 (0.0 ~ 1.0)
                        let normalizedPosition = (dragOffset + maxOffset) / (maxOffset * 2)
                        dividerPosition = normalizedPosition
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 40)
        .onAppear {
            // 초기 dragOffset 설정을 dividerPosition 0.5 (중앙)와 동기화
            let trackWidth = (UIScreen.main.bounds.width - 40) - 40
            let buttonGroupWidth: CGFloat = 60 + 32 + 60
            let maxOffset = (trackWidth - buttonGroupWidth) / 2
            dragOffset = (0.5 * (maxOffset * 2)) - maxOffset // Start at center
        }
        .compatibleOnChange(of: dividerPosition) { newValue in
            if !isDragging {
                withAnimation(.easeInOut(duration: 0.3)) {
                    let trackWidth = (UIScreen.main.bounds.width - 40) - 40
                    let buttonGroupWidth: CGFloat = 60 + 32 + 60
                    let maxOffset = (trackWidth - buttonGroupWidth) / 2
                    dragOffset = (newValue * (maxOffset * 2)) - maxOffset
                }
            }
        }
    }
}

// MARK: - 필터 정보와 통계 섹션
struct FilterInfoWithStatsSection: View {
    let filterDetail: FilterDetailResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(filterDetail.title)
                        .font(.hakgyoansim(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("#\(filterDetail.category)")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                }
                
                Spacer()
                
                Text("₩\(formatPrice(filterDetail.price))")
                    .font(.hakgyoansim(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(filterDetail.description)
                .font(.pretendard(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(nil)
            
            // 통계 정보
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("다운로드")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    Text("\(filterDetail.buyer_count)+")
                        .font(.pretendard(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("좋아요")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    Text("\(filterDetail.like_count)")
                        .font(.pretendard(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                )
                
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func formatPrice(_ price: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }
}

// MARK: - 위치 정보 포함 메타데이터 섹션
struct PhotoMetadataWithLocationSection: View {
    let metadata: PhotoMetadata
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("촬영 정보")
                .font(.pretendard(size: 18, weight: .semiBold))
                .foregroundColor(.white)
            
            // 기기 정보
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(metadata.camera)
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("EXIF")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                
                Text("\(metadata.lens_info) · \(metadata.focal_length) mm f/\(metadata.aperture) ISO \(metadata.iso)")
                    .font(.pretendard(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                
                Text("\(metadata.pixel_width) × \(metadata.pixel_height) · \(metadata.formattedFileSize)")
                    .font(.pretendard(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
            
            // 위치 정보 (있을 때만 표시)
            if metadata.hasLocation {
                HStack(spacing: 12) {
                    // 미니 지도 표시
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "map.fill")
                                .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                                .font(.system(size: 24))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("위치")
                            .font(.pretendard(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("서울 영등포구 선유로 9길 30")
                            .font(.pretendard(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        if let lat = metadata.latitude, let lon = metadata.longitude {
                            Text("위도: \(String(format: "%.6f", lat)), 경도: \(String(format: "%.6f", lon))")
                                .font(.pretendard(size: 10, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                )
            } else {
                // 위치 정보가 없을 때
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "location.slash")
                                .foregroundColor(.gray)
                                .font(.system(size: 24))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("위치")
                            .font(.pretendard(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("위치 정보 없음")
                            .font(.pretendard(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 필터 프리셋 섹션
struct FilterPresetsSection: View {
    let filterValues: FilterValues
    let isPurchased: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filter Presets")
                    .font(.pretendard(size: 18, weight: .semiBold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("LUT")
                    .font(.pretendard(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray, lineWidth: 1)
                    )
            }
            
            if isPurchased {
                // 결제 완료 시: 배경 없이 아이콘만 gray0으로 표시
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    FilterPresetItem(iconName: "sun.max", value: filterValues.brightness, title: "밝기", formatType: .decimal, isPurchased: true)
                    FilterPresetItem(iconName: "camera.aperture", value: filterValues.exposure, title: "노출", formatType: .decimal, isPurchased: true)
                    FilterPresetItem(iconName: "circle.lefthalf.filled", value: filterValues.contrast, title: "대비", formatType: .decimal, isPurchased: true)
                    FilterPresetItem(iconName: "paintpalette", value: filterValues.saturation, title: "채도", formatType: .decimal, isPurchased: true)
                    FilterPresetItem(iconName: "camera.filters", value: filterValues.sharpness, title: "선명도", formatType: .decimal, isPurchased: true)
                    FilterPresetItem(iconName: "circle.grid.cross", value: filterValues.vignette, title: "비네팅", formatType: .decimal, isPurchased: true)
                    
                    FilterPresetItem(iconName: "aqi.medium", value: filterValues.blur, title: "블러", formatType: .decimal, isPurchased: true)
                    FilterPresetItem(iconName: "waveform", value: filterValues.noise_reduction, title: "노이즈", formatType: .decimal, isPurchased: true)
                    FilterPresetItem(iconName: "sun.min", value: filterValues.highlights, title: "하이라이트", formatType: .decimal, isPurchased: true)
                    FilterPresetItem(iconName: "moon", value: filterValues.shadows, title: "섀도우", formatType: .decimal, isPurchased: true)
                    FilterPresetItem(iconName: "thermometer", value: filterValues.temperature, title: "색온도", formatType: .temperature, isPurchased: true)
                    FilterPresetItem(iconName: "circle.fill", value: filterValues.black_point, title: "블랙포인트", formatType: .decimal, isPurchased: true)
                }
                .padding(.vertical, 20)
            } else {
                // 결제 전: 블러 처리된 상태
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    let presetIcons = ["sun.max", "camera.aperture", "circle.lefthalf.filled", "paintpalette", "camera.filters", "circle.grid.cross", "aqi.medium", "waveform", "sun.min", "moon", "thermometer", "circle.fill"]
                    
                    ForEach(Array(presetIcons.enumerated()), id: \.offset) { index, iconName in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: iconName)
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            }
                            
                            Text("0.0")
                                .font(.pretendard(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.1))
                )
                .blur(radius: 6)
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                        
                        Text("결제가 필요한 유료 필터입니다")
                            .font(.pretendard(size: 16, weight: .semiBold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.8))
                    )
                )
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 필터 프리셋 아이템
struct FilterPresetItem: View {
    let iconName: String
    let value: Double
    let title: String
    let formatType: ValueFormatType
    let isPurchased: Bool
    
    enum ValueFormatType {
        case decimal
        case temperature
    }
    
    init(iconName: String, value: Double, title: String, formatType: ValueFormatType, isPurchased: Bool = false) {
        self.iconName = iconName
        self.value = value
        self.title = title
        self.formatType = formatType
        self.isPurchased = isPurchased
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if isPurchased {
                // 결제 완료 시: 배경 없이 gray0 아이콘만 표시
                Image(systemName: iconName)
                    .foregroundColor(DesignSystem.Colors.Gray.gray0)
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 40, height: 40)
            } else {
                // 결제 전: 기존 스타일 유지
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: iconName)
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                }
            }
            
            Text(formattedValue)
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(isPurchased ? DesignSystem.Colors.Gray.gray0 : .white)
        }
    }
    
    private var formattedValue: String {
        switch formatType {
        case .decimal:
            return String(format: "%.1f", value)
        case .temperature:
            return String(format: "%.0fK", value)
        }
    }
}

// MARK: - 채팅 버튼이 있는 크리에이터 프로필 섹션
struct CreatorProfileWithChatSection: View {
    let creator: CreatorInfo
    let onChatTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("크리에이터")
                    .font(.pretendard(size: 18, weight: .semiBold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    onChatTap()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                }
            }
            
            HStack(spacing: 12) {
                // 프로필 이미지
                if let profileImagePath = creator.profileImage {
                    AuthenticatedImageView(
                        imagePath: profileImagePath,
                        contentMode: .fill
                    ) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(creator.name)
                        .font(.pretendard(size: 18, weight: .semiBold))
                        .foregroundColor(.white)
                    
                    Text(creator.nick)
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(creator.introduction)
                        .font(.pretendard(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // 해시태그
            if !creator.hashTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(creator.hashTags, id: \.self) { tag in
                            Text(tag)
                                .font(.pretendard(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
            
            // 작가 소개 텍스트
            VStack(alignment: .leading, spacing: 8) {
                Text("빛이 이끄는 섬세한 세계")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                
                Text("맑고 투명한 빛을 담은 자연 감성 필터입니다.\n너무 과하지 않으면서도 분명한 감정을 실어보세요.\n새로운 시선, 순수한 감정을 담아내는 새싹 필터를 사용해보세요.")
                    .font(.pretendard(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 20)
    }
}
