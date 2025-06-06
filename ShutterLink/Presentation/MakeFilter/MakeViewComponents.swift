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
                        Image(systemName: "location.slash")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
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
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

// MARK: - 필터 속성 슬라이더 컴포넌트
struct FilterPropertySlider: View {
    let property: FilterProperty
    @Binding var value: Double
    let onValueChanged: (String, Double) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 아이콘과 값 표시
            VStack(spacing: 4) {
                Image(property.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
                
                Text(formatValue(value))
                    .font(.pretendard(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(width: 50)
            
            // 슬라이더
            VStack {
                Slider(
                    value: Binding(
                        get: { value },
                        set: { newValue in
                            value = newValue
                            onValueChanged(property.key, newValue)
                        }
                    ),
                    in: property.minValue...property.maxValue,
                    step: property.step
                )
                .tint(DesignSystem.Colors.Brand.brightTurquoise)
                
                // 범위 표시
                HStack {
                    Text(formatValue(property.minValue))
                        .font(.pretendard(size: 8, weight: .regular))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(formatValue(property.maxValue))
                        .font(.pretendard(size: 8, weight: .regular))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 80)
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

// MARK: - EXIF 정보 표시 컴포넌트
struct ExifInfoSection: View {
    let metadata: PhotoMetadataRequest?
    
    var body: some View {
        if let metadata = metadata {
            VStack(alignment: .leading, spacing: 12) {
                Text("촬영 정보")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                
                HStack(spacing: 16) {
                    MiniMapView(
                        latitude: metadata.latitude,
                        longitude: metadata.longitude
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        if let camera = metadata.camera {
                            Text(camera)
                                .font(.pretendard(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        if let lens = metadata.lensInfo, let focal = metadata.focalLength {
                            Text("\(lens) • \(Int(focal))mm")
                                .font(.pretendard(size: 11, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        
                        if let width = metadata.pixelWidth, let height = metadata.pixelHeight {
                            Text("\(width) × \(height)")
                                .font(.pretendard(size: 11, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        
                        if let fileSize = metadata.fileSize {
                            let sizeInMB = Double(fileSize) / (1024 * 1024)
                            Text(String(format: "%.1fMB", sizeInMB))
                                .font(.pretendard(size: 11, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                )
            }
        }
    }
}

// MARK: - 편집 버튼들 (Undo/Redo, Before/After)
struct EditingControlButtons: View {
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onBeforeAfterStart: () -> Void
    let onBeforeAfterEnd: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                // 왼쪽: Undo/Redo 버튼들
                HStack(spacing: 12) {
                    Button {
                        onUndo()
                    } label: {
                        Image("Undo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(canUndo ? .white : .gray)
                    }
                    .disabled(!canUndo)
                    
                    Button {
                        onRedo()
                    } label: {
                        Image("Redo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(canRedo ? .white : .gray)
                    }
                    .disabled(!canRedo)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.7))
                )
                
                Spacer()
                
                // 오른쪽: Before/After 버튼
                Button {
                    // 이 버튼은 onPressingChanged를 사용하므로 여기서는 빈 액션
                } label: {
                    Text("비포에프터")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.7))
                        )
                }
                .onPressingChanged { isPressing in
                    if isPressing {
                        onBeforeAfterStart()
                    } else {
                        onBeforeAfterEnd()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
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

// MARK: - 성공/에러 토스트 메시지
struct ToastMessage: View {
    let message: String
    let isSuccess: Bool
    @State private var isVisible = false
    
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
            isVisible = true
        }
    }
}
