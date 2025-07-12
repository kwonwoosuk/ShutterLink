//
//  MakeViewComponents.swift
//  ShutterLink
//
//  Created by 권우석 on 6/6/25.
//

import SwiftUI
import MapKit
import PhotosUI

// MARK: - MiniMapView (재사용 가능한 지도 컴포넌트)
struct MiniMapView: View {
    let latitude: Double?
    let longitude: Double?
    let width: CGFloat
    let height: CGFloat
    
    init(latitude: Double?, longitude: Double?, width: CGFloat = 76, height: CGFloat = 76) {
        self.latitude = latitude
        self.longitude = longitude
        self.width = width
        self.height = height
    }
    
    var body: some View {
        Group {
            if let latitude = latitude, let longitude = longitude {
                let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                let region = MKCoordinateRegion(
                    center: center,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                )
                
                if #available(iOS 17.0, *) {
                    Map(initialPosition: .region(region))
                        .disabled(true)
                } else {
                    MapViewiOS16(region: region)
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image("NoLocation")
                            .overlay(DesignSystem.Colors.Gray.gray15)
                            .mask(Image("NoLocation"))
                            .font(.system(size: 16))
                            .frame(width: 40, height: 40)
                    )
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - iOS 16 호환 MapView
struct MapViewiOS16: UIViewRepresentable {
    let region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isUserInteractionEnabled = false
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.setRegion(region, animated: false)
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(region, animated: false)
    }
}

// MARK: - 카테고리 선택 컴포넌트
struct CategorySelector: View {
    @Binding var selectedCategory: String
    let categories: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("카테고리")
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category)
                                .font(.pretendard(size: 14, weight: .medium))
                                .foregroundColor(selectedCategory == category ? .black : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedCategory == category ? DesignSystem.Colors.Brand.brightTurquoise : Color.gray.opacity(0.3))
                                )
                        }
                        .animation(.easeInOut(duration: 0.2), value: selectedCategory)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

// MARK: - EXIF 정보 표시 컴포넌트 (조건부)
struct ExifInfoSection: View {
    let metadata: PhotoMetadataRequest?
    
    var body: some View {
        if let metadata = metadata {
            VStack(alignment: .leading, spacing: 16) {
                Text("촬영 정보")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                
                HStack(spacing: 16) {
                    // 미니 지도 또는 위치 정보
                    MiniMapView(
                        latitude: metadata.latitude,
                        longitude: metadata.longitude,
                        width: 80,
                        height: 80
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // 카메라 정보
                        if let camera = metadata.camera, !camera.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "camera")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 12))
                                
                                Text(camera)
                                    .font(.pretendard(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                        
                        // 렌즈 및 초점거리 정보
                        if let lens = metadata.lensInfo, let focal = metadata.focalLength {
                            HStack(spacing: 8) {
                                Image(systemName: "scope")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 12))
                                
                                Text("\(lens) • \(Int(focal))mm")
                                    .font(.pretendard(size: 11, weight: .regular))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                        
                        // 해상도 정보
                        if let width = metadata.pixelWidth, let height = metadata.pixelHeight {
                            HStack(spacing: 8) {
                                Image(systemName: "viewfinder")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 12))
                                
                                Text("\(width) × \(height)")
                                    .font(.pretendard(size: 11, weight: .regular))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                        
                        // 파일 크기 정보
                        if let fileSize = metadata.fileSize {
                            HStack(spacing: 8) {
                                Image(systemName: "doc")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 12))
                                
                                Text(formatFileSize(fileSize))
                                    .font(.pretendard(size: 11, weight: .regular))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                )
            }
        }
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let sizeInMB = Double(size) / (1024 * 1024)
        if sizeInMB >= 1.0 {
            return String(format: "%.1fMB", sizeInMB)
        } else {
            let sizeInKB = Double(size) / 1024
            return String(format: "%.0fKB", sizeInKB)
        }
    }
}

// MARK: - 성공/에러 토스트 메시지 (개선된 버전)
struct ToastMessage: View {
    let message: String
    let isSuccess: Bool
    @State private var isVisible = false
    @State private var offset: CGFloat = 50
    
    var body: some View {
        HStack(spacing: 12) {
            // 아이콘
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isSuccess ? DesignSystem.Colors.Brand.brightTurquoise : .red)
                .font(.system(size: 20, weight: .medium))
            
            // 메시지
            Text(message)
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: offset)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: offset)
        .onAppear {
            withAnimation {
                isVisible = true
                offset = 0
            }
            
            // 3초 후 자동 숨김
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    isVisible = false
                    offset = -50
                }
            }
        }
    }
}

// MARK: - 로딩 인디케이터 컴포넌트
struct LoadingOverlayView: View {
    let message: String
    
    init(message: String = "처리 중...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.Brand.brightTurquoise))
                .scaleEffect(1.5)
            
            Text(message)
                .font(.pretendard(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        )
    }
}

// MARK: - 메시지 오버레이 컴포넌트
struct MessageOverlayView: View {
    let message: String
    let isError: Bool
    let onDismiss: (() -> Void)?
        
    var body: some View {
        VStack(spacing: 16) {
            // 아이콘
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(isError ? .red : DesignSystem.Colors.Brand.brightTurquoise)
            
            // 메시지
            Text(message)
                .font(.pretendard(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            // 확인 버튼 (에러인 경우만)
            if isError, let onDismiss = onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Text("확인")
                        .font(.pretendard(size: 14, weight: .semiBold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.5))
                        )
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal, 40)
    }
}

// MARK: - 카테고리 드롭다운 뷰
struct CategoryDropdownView: View {
    @Binding var selectedCategory: FilterCreationCategory
    @State private var isExpanded = false
    
    private let categories: [FilterCreationCategory] = [.food, .people, .landscape, .star, .night]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("카테고리")
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            VStack(spacing: 0) {
                // 선택된 카테고리 표시
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(selectedCategory.title)
                            .font(.pretendard(size: 16, weight: .regular))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // 드롭다운 목록
                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(categories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded = false
                                }
                            } label: {
                                HStack {
                                    Text(category.title)
                                        .font(.pretendard(size: 16, weight: .regular))
                                        .foregroundColor(selectedCategory == category ? DesignSystem.Colors.Brand.brightTurquoise : .white)
                                    
                                    Spacer()
                                    
                                    if selectedCategory == category {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                                    }
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                            }
                        }
                    }
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.top, 2)
                }
            }
        }
    }
}

// MARK: - FilterCreationCategory enum
enum FilterCreationCategory: String, CaseIterable {
    case food = "푸드"
    case people = "인물"
    case landscape = "풍경"
    case star = "별"
    case night = "야경"
    
    var title: String {
        return self.rawValue
    }
}
