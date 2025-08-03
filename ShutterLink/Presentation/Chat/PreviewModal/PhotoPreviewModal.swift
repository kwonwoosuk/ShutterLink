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
                            onDismiss: dismissModal,
                            onVerticalDrag: { translation in
                                // ✅ ZoomableImageView에서 세로 드래그 처리
                                if scale <= 1.0 {
                                    verticalDragOffset = max(0, translation.height)
                                    let progress = min(verticalDragOffset / 200, 1.0)
                                    backgroundOpacity = 1.0 - progress * 0.7
                                }
                            },
                            onVerticalDragEnd: { translation, velocity in
                                // ✅ ZoomableImageView에서 세로 드래그 종료 처리
                                if scale <= 1.0 {
                                    if verticalDragOffset > 150 || velocity.height > 300 {
                                        dismissModal()
                                    } else {
                                        withAnimation(.spring()) {
                                            verticalDragOffset = 0
                                            backgroundOpacity = 1.0
                                        }
                                    }
                                }
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .offset(y: verticalDragOffset)
                
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

// MARK: - ✅ 줌 가능한 이미지 뷰 (핀치줌 1.0~4.0배 + 방향별 드래그 감지)

struct ZoomableImageView: View {
    let imagePath: String
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    let onDismiss: () -> Void
    let onVerticalDrag: ((CGSize) -> Void)?
    let onVerticalDragEnd: ((CGSize, CGSize) -> Void)?
    
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var dragStartPosition: CGPoint = .zero
    
    // ✅ onVerticalDrag 파라미터들을 옵셔널로 만들어 기존 호환성 유지
    init(
        imagePath: String,
        scale: Binding<CGFloat>,
        offset: Binding<CGSize>,
        onDismiss: @escaping () -> Void,
        onVerticalDrag: ((CGSize) -> Void)? = nil,
        onVerticalDragEnd: ((CGSize, CGSize) -> Void)? = nil
    ) {
        self.imagePath = imagePath
        self._scale = scale
        self._offset = offset
        self.onDismiss = onDismiss
        self.onVerticalDrag = onVerticalDrag
        self.onVerticalDragEnd = onVerticalDragEnd
    }
    
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
                
                // ✅ 개선된 드래그 제스처 (방향 감지)
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            // 드래그 시작 - 방향 결정
                            isDragging = true
                            dragStartPosition = value.startLocation
                        }
                        
                        let translation = value.translation
                        let isVerticalDrag = abs(translation.height) > abs(translation.width)
                        
                        if scale > 1.0 {
                            // ✅ 줌 상태: 이미지 팬 (가로/세로 모두)
                            let newOffset = CGSize(
                                width: lastOffset.width + translation.width,
                                height: lastOffset.height + translation.height
                            )
                            
                            // 이동 범위 제한
                            let maxOffsetX = (scale - 1) * 100
                            let maxOffsetY = (scale - 1) * 100
                            
                            offset = CGSize(
                                width: max(-maxOffsetX, min(maxOffsetX, newOffset.width)),
                                height: max(-maxOffsetY, min(maxOffsetY, newOffset.height))
                            )
                        } else if isVerticalDrag && translation.height > 0 {
                            // ✅ 줌 안 된 상태 + 세로 아래 드래그: 모달 닫기 제스처
                            onVerticalDrag?(translation)
                        }
                        // ✅ 가로 드래그는 TabView가 처리하도록 아무것도 안 함
                    }
                    .onEnded { value in
                        isDragging = false
                        
                        let translation = value.translation
                        let velocity = value.predictedEndTranslation
                        let isVerticalDrag = abs(translation.height) > abs(translation.width)
                        
                        if scale > 1.0 {
                            // ✅ 줌 상태: 오프셋 저장
                            lastOffset = offset
                        } else if isVerticalDrag && translation.height > 0 {
                            // ✅ 세로 드래그 종료: 모달 닫기 처리
                            onVerticalDragEnd?(translation, velocity)
                        }
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
