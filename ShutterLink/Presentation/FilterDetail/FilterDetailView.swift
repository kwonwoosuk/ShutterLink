//
//  FilterDetailView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/26/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct FilterDetailView: View {
    let filterId: String
    @StateObject private var viewModel = FilterDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @State private var hasAppeared = false
    @State private var showChatOuterView = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if let filterDetail = viewModel.filterDetail {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        InteractiveBeforeAfterView(
                            imagePath: filterDetail.files.first ?? "",
                            filterValues: filterDetail.filterValues
                        )
                        .frame(height: 400)
                        .padding(.top, 40)
                        
                        // 필터 정보와 통계
                        FilterInfoWithStatsSection(filterDetail: filterDetail)
                        
                        // 사진 메타데이터 섹션
                        PhotoMetadataSection(metadata: filterDetail.photoMetadata)
                        
                        // 필터 프리셋 섹션
                        FilterPresetsSection(
                            filterValues: filterDetail.filterValues,
                            isPurchased: filterDetail.is_downloaded
                        )
                        
                        // 결제/다운로드 버튼
                        PurchaseDownloadButton(
                            price: filterDetail.price,
                            isPurchased: filterDetail.is_downloaded,
                            isPurchasing: viewModel.isPurchasing,
                            onPurchase: {
                                print("🔵 FilterDetailView: 결제 버튼 탭 - \(filterId)")
                                viewModel.input.purchaseFilter.send(filterId)
                            }
                        )
                        
                        // 디바이더 라인
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                        
                        // 크리에이터 프로필 섹션 (수정된 버전)
                        CreatorProfileSection(
                            creator: filterDetail.creator,
                            onCreatorTap: {
                                // UserDetailView로 이동
                                let userInfo = UserInfo(
                                    user_id: filterDetail.creator.user_id,
                                    nick: filterDetail.creator.nick,
                                    name: filterDetail.creator.name,
                                    introduction: filterDetail.creator.introduction,
                                    profileImage: filterDetail.creator.profileImage,
                                    hashTags: filterDetail.creator.hashTags
                                )
                                router.pushToUserDetailFromFilter(
                                    userId: filterDetail.creator.user_id,
                                    userInfo: filterDetail.creator,
                                    from: router.selectedTab
                                )
                            },
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
            
            // 성공/에러 메시지 토스트
            if let errorMessage = viewModel.errorMessage, !viewModel.isLoading {
                VStack {
                    ToastMessageView(
                        message: errorMessage,
                        isSuccess: errorMessage.contains("완료")
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .zIndex(1000)
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
            
            // 좋아요 버튼
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
            // 채팅 뷰
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                }
            }
        }
    }
}

// MARK: - 결제/다운로드 버튼 (기존과 동일)
struct PurchaseDownloadButton: View {
    let price: Int
    let isPurchased: Bool
    let isPurchasing: Bool
    let onPurchase: () -> Void
    
    var body: some View {
        Button {
            if !isPurchased && !isPurchasing {
                onPurchase()
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("결제 중...")
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                } else if isPurchased {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("구매완료")
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                } else {
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

// MARK: - 드래그 가능한 Before/After 이미지 비교 뷰 (기존과 동일)
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

// MARK: - 연결된 컨트롤 뷰 (기존과 동일)
struct ConnectedControlView: View {
    @Binding var dividerPosition: CGFloat
    @Binding var isDragging: Bool
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
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
                        
                        let trackWidth = geometry.size.width - 40
                        let relativeX = value.location.x - (trackWidth / 2)
                        
                        let buttonGroupWidth: CGFloat = 60 + 32 + 60
                        let maxOffset = (trackWidth - buttonGroupWidth) / 2
                        dragOffset = max(-maxOffset, min(maxOffset, relativeX))
                        
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
            let trackWidth = (UIScreen.main.bounds.width - 40) - 40
            let buttonGroupWidth: CGFloat = 60 + 32 + 60
            let maxOffset = (trackWidth - buttonGroupWidth) / 2
            dragOffset = (0.5 * (maxOffset * 2)) - maxOffset
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

// MARK: - 필터 정보와 통계 섹션 (기존과 동일)
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


struct PhotoMetadataSection: View {
    let metadata: PhotoMetadata
    @State private var address: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단 헤더 띠
            HStack {
                Text(metadata.camera)
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("EXIF")
                    .font(.pretendard(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            
            // 메인 컨텐츠 영역
            HStack(spacing: 16) {
                // 왼쪽: 지도 또는 위치 없음 아이콘
                if metadata.hasLocation {
                    MapPreviewView(
                        latitude: metadata.latitude!,
                        longitude: metadata.longitude!,
                        address: $address
                    )
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "location.slash")
                                .foregroundColor(.gray)
                                .font(.system(size: 24))
                        )
                }
                
                // 오른쪽: 카메라 정보와 위치 정보
                VStack(alignment: .leading, spacing: 8) {
                    
                    Text("\(metadata.lens_info) · \(Int(metadata.focal_length))mm f/\(String(format: "%.1f", metadata.aperture)) ISO \(metadata.iso)")
                        .font(.pretendard(size: 12, weight: .regular))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text("\(metadata.pixel_width) × \(metadata.pixel_height) · \(metadata.formattedFileSize)")
                        .font(.pretendard(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                    
                    // 위치 정보
                    if metadata.hasLocation {
                        if !address.isEmpty && address != "주소를 찾을 수 없습니다" {
                            Text(address)
                                .font(.pretendard(size: 12, weight: .regular))
                                .foregroundColor(.white)
                                .lineLimit(2)
                        } else if address == "주소를 찾을 수 없습니다" {
                            Text("주소를 찾을 수 없습니다")
                                .font(.pretendard(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        } else {
                            Text("위치 확인 중...")
                                .font(.pretendard(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("위치 정보 없음")
                            .font(.pretendard(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.gray.opacity(0.1))
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}

// MARK: - 지도 미리보기 뷰
struct MapPreviewView: UIViewRepresentable {
    func updateUIView(_ uiView: MKMapView, context: Context) {
        //
    }
    
    let latitude: Double
    let longitude: Double
    @Binding var address: String
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isUserInteractionEnabled = false
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: false)
        
        reverseGeocode()
        
        return mapView
    }
    
    private func reverseGeocode() {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                var addressComponents: [String] = []
                
                // 한국 주소 형식에 맞게 순서 조정
                if let country = placemark.country {
                    addressComponents.append(country)
                }
                if let administrativeArea = placemark.administrativeArea {
                    addressComponents.append(administrativeArea)
                }
                if let locality = placemark.locality {
                    addressComponents.append(locality)
                }
                if let thoroughfare = placemark.thoroughfare {
                    addressComponents.append(thoroughfare)
                }
                if let subThoroughfare = placemark.subThoroughfare {
                    addressComponents.append(subThoroughfare)
                }
                
                DispatchQueue.main.async {
                    self.address = addressComponents.joined(separator: " ")
                }
            } else {
                DispatchQueue.main.async {
                    self.address = "주소를 찾을 수 없습니다"
                }
            }
        }
    }
}

struct FilterPresetsSection: View {
    let filterValues: FilterValues
    let isPurchased: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단 헤더 띠
            HStack {
                Text("Filter Presets")
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("LUT")
                    .font(.pretendard(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            
            // 메인 컨텐츠 영역
            if isPurchased {
                // 결제 완료 시: 실제 필터 값들 표시
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    FilterPresetItem(iconName: "Brightness", value: filterValues.brightness, title: "밝기", formatType: .decimal)
                    FilterPresetItem(iconName: "Exposure", value: filterValues.exposure, title: "노출", formatType: .decimal)
                    FilterPresetItem(iconName: "Contrast", value: filterValues.contrast, title: "대비", formatType: .decimal)
                    FilterPresetItem(iconName: "Saturation", value: filterValues.saturation, title: "채도", formatType: .decimal)
                    FilterPresetItem(iconName: "Sharpness", value: filterValues.sharpness, title: "선명도", formatType: .decimal)
                    FilterPresetItem(iconName: "Vignette", value: filterValues.vignette, title: "비네팅", formatType: .decimal)
                    
                    FilterPresetItem(iconName: "Blur", value: filterValues.blur, title: "블러", formatType: .decimal)
                    FilterPresetItem(iconName: "Noise", value: filterValues.noise_reduction, title: "노이즈", formatType: .decimal)
                    FilterPresetItem(iconName: "Highlights", value: filterValues.highlights, title: "하이라이트", formatType: .decimal)
                    FilterPresetItem(iconName: "Shadows", value: filterValues.shadows, title: "섀도우", formatType: .decimal)
                    FilterPresetItem(iconName: "Temperature", value: filterValues.temperature, title: "색온도", formatType: .temperature)
                    FilterPresetItem(iconName: "BlackPoint", value: filterValues.black_point, title: "블랙포인트", formatType: .decimal)
                }
                .padding(20)
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
                    let presetIcons = ["Brightness", "Exposure", "Contrast", "Saturation", "Sharpness", "Vignette", "Blur", "Noise", "Highlights", "Shadows", "Temperature", "BlackPoint"]
                    
                    ForEach(Array(presetIcons.enumerated()), id: \.offset) { index, iconName in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                
                                Image(iconName)
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
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}

// MARK: - 필터 프리셋 아이템 (기존과 동일)
struct FilterPresetItem: View {
    let iconName: String
    let value: Double
    let title: String
    let formatType: ValueFormatType
    
    enum ValueFormatType {
        case decimal
        case temperature
    }
    
    var body: some View {
        VStack(spacing: 8) {
                  Image(iconName)
                .overlay(DesignSystem.Colors.Gray.gray15)
                 .mask(Image(iconName))
                      .font(.system(size: 16))
                      .frame(width: 40, height: 40)
                  
                  Text(formattedValue)
                      .font(.pretendard(size: 12, weight: .medium))
                      .foregroundColor(.white)
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

// MARK: - 수정된 크리에이터 프로필 섹션
struct CreatorProfileSection: View {
    let creator: CreatorInfo
    let onCreatorTap: () -> Void
    let onChatTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                // 프로필 이미지 (탭 가능)
                Button {
                    onCreatorTap()
                } label: {
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
                }
                .buttonStyle(PlainButtonStyle())
                
                // 작가 정보 (탭 가능)
                Button {
                    onCreatorTap()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(creator.name)
                            .font(.pretendard(size: 18, weight: .semiBold))
                            .foregroundColor(.white)
                        
                        Text(creator.nick)
                            .font(.pretendard(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        // 해시태그
                        if !creator.hashTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(creator.hashTags.prefix(3), id: \.self) { tag in
                                        Text(tag)
                                            .font(.pretendard(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.black)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button {
                    onChatTap()
                } label: {
                    Rectangle()
                        .fill(Color.deepTurquoise.opacity(0.5))
                        .frame(width: 45,height: 45)
                        .overlay {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.gray15)
                        }
                        .cornerRadius(8)
                }
                .frame(height: 60, alignment: .center)
                .padding(.top, 0)
                .padding(.trailing, 16)
            }
            
            if !creator.introduction.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(creator.introduction)
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                        .lineLimit(nil) // 전체 텍스트 표시
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
