//
//  PhotoPreviewModal.swift
//  ShutterLink
//
//  Created by 권우석 on 8/2/25.
//

import SwiftUI

struct PhotoPreviewModal: View {
    let photos: [String]
    let initialIndex: Int
    @Binding var isPresented: Bool
    
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    // 스와이프 닫기를 위한 상태
    @State private var verticalDragOffset: CGFloat = 0
    @State private var backgroundOpacity: Double = 1.0
    
    init(photos: [String], initialIndex: Int, isPresented: Binding<Bool>) {
        self.photos = photos
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            // 배경 (투명도 변화)
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissModal()
                }
            
            VStack {
                // 상단 닫기 버튼
                HStack {
                    Button("닫기") {
                        dismissModal()
                    }
                    .foregroundColor(.white)
                    .padding()
                    
                    Spacer()
                    
                    // 페이지 인디케이터
                    if photos.count > 1 {
                        Text("\(currentIndex + 1) / \(photos.count)")
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                // 메인 이미지 영역
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        ZoomableImageView(
                            imagePath: photo,
                            scale: $scale,
                            offset: $offset,
                            onDismiss: dismissModal
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .offset(y: verticalDragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // 스케일이 1.0일 때만 세로 드래그 허용 (줌 상태가 아닐 때)
                            if scale <= 1.0 {
                                verticalDragOffset = max(0, value.translation.height)
                                
                                // 배경 투명도 조절
                                let progress = min(verticalDragOffset / 200, 1.0)
                                backgroundOpacity = 1.0 - progress * 0.7
                            }
                        }
                        .onEnded { value in
                            if scale <= 1.0 {
                                if verticalDragOffset > 150 || value.predictedEndTranslation.height > 300 {
                                    // 충분히 아래로 드래그했거나 빠른 속도로 드래그한 경우
                                    dismissModal()
                                } else {
                                    // 원래 위치로 복귀
                                    withAnimation(.spring()) {
                                        verticalDragOffset = 0
                                        backgroundOpacity = 1.0
                                    }
                                }
                            }
                        }
                )
                
                Spacer()
            }
        }
        .onAppear {
            // 상태 초기화
            scale = 1.0
            offset = .zero
            verticalDragOffset = 0
            backgroundOpacity = 1.0
        }
    }
    
    private func dismissModal() {
        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 0
            verticalDragOffset = 200
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

// MARK: - ✅ 줌 가능한 이미지 뷰 (핀치줌 1.0~4.0배)

struct ZoomableImageView: View {
    let imagePath: String
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    let onDismiss: () -> Void
    
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        AuthenticatedImageView(
            imagePath: imagePath,
            contentMode: .fit
        ) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .font(.largeTitle)
                )
        }
        .scaleEffect(scale)
        .offset(offset)
        .gesture(
            SimultaneousGesture(
                // 핀치 줌 제스처 (1.0 ~ 4.0배)
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = lastScale * value
                        scale = max(1.0, min(newScale, 4.0)) // ✅ 1.0 ~ 4.0 제한
                    }
                    .onEnded { _ in
                        lastScale = scale
                        
                        // 스케일이 1.0에 가까우면 자동으로 1.0으로 스냅
                        if scale < 1.2 {
                            withAnimation(.spring()) {
                                scale = 1.0
                                offset = .zero
                            }
                            lastScale = 1.0
                            lastOffset = .zero
                        }
                    },
                
                // 드래그 제스처 (줌 상태일 때만)
                DragGesture()
                    .onChanged { value in
                        if scale > 1.0 {
                            let newOffset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                            
                            // 이동 범위 제한
                            let maxOffsetX = (scale - 1) * 100
                            let maxOffsetY = (scale - 1) * 100
                            
                            offset = CGSize(
                                width: max(-maxOffsetX, min(maxOffsetX, newOffset.width)),
                                height: max(-maxOffsetY, min(maxOffsetY, newOffset.height))
                            )
                        }
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
        )
        .onTapGesture(count: 2) {
            // 더블 탭으로 줌 토글
            withAnimation(.spring()) {
                if scale == 1.0 {
                    scale = 2.0
                    lastScale = 2.0
                } else {
                    scale = 1.0
                    offset = .zero
                    lastScale = 1.0
                    lastOffset = .zero
                }
            }
        }
        .onTapGesture {
            // 단일 탭으로 닫기 (줌 상태가 아닐 때만)
            if scale == 1.0 {
                onDismiss()
            }
        }
    }
}
