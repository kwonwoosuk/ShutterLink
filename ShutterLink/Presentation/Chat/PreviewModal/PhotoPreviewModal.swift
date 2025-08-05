//
//  PhotoPreviewModal.swift
//  ShutterLink
//
//  Created by 권우석 on 8/2/25.
//

import SwiftUI
import UIKit

struct PhotoPreviewModal: View {
    let photos: [String]
    let initialIndex: Int
    @Binding var isPresented: Bool
    
    @State private var currentIndex: Int
    @State private var verticalDragOffset: CGFloat = 0
    @State private var backgroundOpacity: Double = 1.0
    @State private var hasAppeared = true
    
    init(photos: [String], initialIndex: Int, isPresented: Binding<Bool>) {
        self.photos = photos
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            // 배경
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    print("🖱️ 배경 탭됨 - 모달 닫기")
                    dismissModal()
                }
            
            if hasAppeared {
                VStack {
                    // 상단 UI
                    topBar
                    
                    Spacer()
                    
                    // ✅ 메인 이미지 영역
                    mainImageArea
                    
                    Spacer()
                }
                .transition(.opacity)
            } else {
                // 로딩 상태
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("이미지 로딩 중...")
                        .foregroundColor(.white)
                        .font(.pretendard(size: 16, weight: .medium))
                }
            }
        }
        .onAppear {
       
        }
        .onDisappear {
            print("👋 PhotoPreviewModal onDisappear")
        }
        .statusBarHidden()
    }
    
    // MARK: - UI Components
    
    private var topBar: some View {
        HStack {
            Button("닫기") {
                print("🖱️ 닫기 버튼 탭됨")
                dismissModal()
            }
            .foregroundColor(.white)
            .font(.pretendard(size: 16, weight: .medium))
            .padding()
            
            Spacer()
            
            if photos.count > 1 {
                Text("\(currentIndex + 1) / \(photos.count)")
                    .foregroundColor(.white)
                    .font(.pretendard(size: 16, weight: .medium))
                    .padding()
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.8), Color.clear]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
        )
    }
    
    private var mainImageArea: some View {
        ZStack {
            if photos.count == 1 {
                // 단일 이미지 - UIScrollView 사용
                ScrollableImageView(
                    imagePath: photos[0],
                    onDismiss: dismissModal,
                    onVerticalDrag: { translation in
                        verticalDragOffset = max(0, translation.height)
                        let progress = min(verticalDragOffset / 200, 1.0)
                        backgroundOpacity = 1.0 - progress * 0.7
                    },
                    onVerticalDragEnd: { translation, velocity in
                        if verticalDragOffset > 150 || velocity.height > 300 {
                            dismissModal()
                        } else {
                            withAnimation(.spring()) {
                                verticalDragOffset = 0
                                backgroundOpacity = 1.0
                            }
                        }
                    }
                )
                .offset(y: verticalDragOffset)
            } else {
                PhotoPageView(
                    photos: photos,
                    currentIndex: $currentIndex,
                    onDismiss: dismissModal,
                    onVerticalDrag: { translation in
                        verticalDragOffset = max(0, translation.height)
                        let progress = min(verticalDragOffset / 200, 1.0)
                        backgroundOpacity = 1.0 - progress * 0.7
                    },
                    onVerticalDragEnd: { translation, velocity in
                        if verticalDragOffset > 150 || velocity.height > 300 {
                            dismissModal()
                        } else {
                            withAnimation(.spring()) {
                                verticalDragOffset = 0
                                backgroundOpacity = 1.0
                            }
                        }
                    }
                )
                .offset(y: verticalDragOffset)
            }
        }
    }
    
    private func dismissModal() {
        print("🔚 모달 닫기 시작")
        
        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 0
            verticalDragOffset = 200
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
            print("✅ 모달 닫기 완료")
        }
    }
}

struct ScrollableImageView: UIViewControllerRepresentable {
    let imagePath: String
    let onDismiss: () -> Void
    let onVerticalDrag: ((CGSize) -> Void)?
    let onVerticalDragEnd: ((CGSize, CGSize) -> Void)?
    
    init(
        imagePath: String,
        onDismiss: @escaping () -> Void,
        onVerticalDrag: ((CGSize) -> Void)? = nil,
        onVerticalDragEnd: ((CGSize, CGSize) -> Void)? = nil
    ) {
        self.imagePath = imagePath
        self.onDismiss = onDismiss
        self.onVerticalDrag = onVerticalDrag
        self.onVerticalDragEnd = onVerticalDragEnd
    }
    
    func makeUIViewController(context: Context) -> ScrollableImageViewController {
        let controller = ScrollableImageViewController()
        controller.imagePath = imagePath
        controller.onDismiss = onDismiss
        controller.onVerticalDrag = onVerticalDrag
        controller.onVerticalDragEnd = onVerticalDragEnd
        
        print("🏗️ ScrollableImageViewController 생성: \(imagePath)")
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ScrollableImageViewController, context: Context) {
        if uiViewController.imagePath != imagePath {
            print("🔄 ScrollableImageViewController 업데이트: \(imagePath)")
            uiViewController.imagePath = imagePath
        }
    }
}

// MARK: - UIScrollView 기반 이미지 뷰 컨트롤러

class ScrollableImageViewController: UIViewController, UIScrollViewDelegate {
    var imagePath: String = ""
    var onDismiss: (() -> Void)?
    var onVerticalDrag: ((CGSize) -> Void)?
    var onVerticalDragEnd: ((CGSize, CGSize) -> Void)?
    
    private let scrollView = UIScrollView()
    private var hostedView: UIView?
    private var hostingController: UIHostingController<AnyView>?
    
    private var hostedViewCenterXConstraint: NSLayoutConstraint?
    private var hostedViewCenterYConstraint: NSLayoutConstraint?
    private var hostedViewWidthConstraint: NSLayoutConstraint?
    private var hostedViewHeightConstraint: NSLayoutConstraint?
    
    private var layoutObservationTimer: Timer?
    private var hasPerformedInitialLayout = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupImageView()
        setupGestures()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startLayoutObservation()
    }
    
    private func startLayoutObservation() {
        layoutObservationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            self?.checkImageLoadingAndAdjustLayout()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if !self.hasPerformedInitialLayout {
                self.hasPerformedInitialLayout = true
                self.alignImageToCenter()
                self.view.alpha = 1.0
            }
            self.layoutObservationTimer?.invalidate()
            self.layoutObservationTimer = nil
        }
    }
    
    private func checkImageLoadingAndAdjustLayout() {
        guard let hostedView = hostedView else { return }
        guard !hasPerformedInitialLayout else { return }
        
        let hostedViewSize = hostedView.bounds.size
        if hostedViewSize.width > 0 && hostedViewSize.height > 0 {
        
            hasPerformedInitialLayout = true
            layoutObservationTimer?.invalidate()
            layoutObservationTimer = nil
            
            DispatchQueue.main.async {
                self.alignImageToCenter()
                self.view.alpha = 1.0
                print("✅ 레이아웃 조정 완료")
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        layoutObservationTimer?.invalidate()
        layoutObservationTimer = nil
    }
    
    private func setDefaultLayout() {
        let screenSize = scrollView.bounds.size
        
        hostedViewWidthConstraint?.constant = screenSize.width
        hostedViewHeightConstraint?.constant = screenSize.height
        hostedViewCenterXConstraint?.constant = 0
        hostedViewCenterYConstraint?.constant = 0
        
        view.setNeedsUpdateConstraints()
        view.updateConstraintsIfNeeded()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        scrollView.contentSize = screenSize
        scrollView.contentInset = UIEdgeInsets.zero
        scrollView.contentOffset = CGPoint.zero
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        scrollView.delegate = self
        scrollView.maximumZoomScale = 3.0
        scrollView.minimumZoomScale = 0.8
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.decelerationRate = .fast
        scrollView.contentInsetAdjustmentBehavior = .never
        
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        
        scrollView.contentInset = UIEdgeInsets.zero
        
        view.alpha = 0.0
    }
    
    private func setupImageView() {
        let screenSize = UIScreen.main.bounds.size
        
        let swiftUIView = AnyView(
            AuthenticatedImageView(
                imagePath: imagePath,
                contentMode: .fit,
                useOriginalImage: true
            ) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: screenSize.width, height: screenSize.height)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.largeTitle)
                    )
            }
            .frame(maxWidth: screenSize.width, maxHeight: screenSize.height)
        )
        
        let controller = UIHostingController(rootView: swiftUIView)
        hostingController = controller
        hostedView = controller.view
        
        guard let hostedView = hostedView else { return }
        
        scrollView.addSubview(hostedView)
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .clear
        
        hostedViewCenterXConstraint = hostedView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor, constant: 0)
        hostedViewCenterYConstraint = hostedView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor, constant: 0)
        hostedViewWidthConstraint = hostedView.widthAnchor.constraint(equalToConstant: screenSize.width)
        hostedViewHeightConstraint = hostedView.heightAnchor.constraint(equalToConstant: screenSize.height)
        
        NSLayoutConstraint.activate([
            hostedViewCenterXConstraint!,
            hostedViewCenterYConstraint!,
            hostedViewWidthConstraint!,
            hostedViewHeightConstraint!
        ])
        
    
        scrollView.contentSize = screenSize
        
        print("🖼️ 이미지 뷰 설정 완료: \(imagePath)")
        print("📐 초기 설정 크기: \(screenSize)")
        print("📐 중앙 정렬 constraint 설정 완료")
    }
    
    private func setupGestures() {
        // 단일 탭 제스처
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        scrollView.addGestureRecognizer(singleTap)
        
        // 더블 탭 제스처
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        
        // 단일 탭이 더블 탭을 기다리도록 설정
        singleTap.require(toFail: doubleTap)
        
        // 팬 제스처 (모달 닫기용) - view에 추가하여 UIScrollView 제스처와 충돌 방지
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
    }
    

    private func alignImageToCenter() {
        guard let hostedView = hostedView else { return }
        
        let scrollViewSize = scrollView.bounds.size
        let hostedViewSize = hostedView.bounds.size
    
        guard hostedViewSize.width > 0 && hostedViewSize.height > 0 else {
            setDefaultLayout()
            return
        }
        
        let imageAspectRatio = hostedViewSize.width / hostedViewSize.height
        let screenAspectRatio = scrollViewSize.width / scrollViewSize.height
        
        var finalWidth: CGFloat
        var finalHeight: CGFloat
        if imageAspectRatio > screenAspectRatio {
            finalWidth = scrollViewSize.width
            finalHeight = finalWidth / imageAspectRatio
        } else {
            finalHeight = scrollViewSize.height
            finalWidth = finalHeight * imageAspectRatio
        }
        
        finalWidth = max(100, min(finalWidth, scrollViewSize.width))
        finalHeight = max(100, min(finalHeight, scrollViewSize.height))
        
        print("📐 계산된 최종 크기: \(finalWidth) x \(finalHeight)")
        
        hostedViewWidthConstraint?.constant = finalWidth
        hostedViewHeightConstraint?.constant = finalHeight
        
        hostedViewCenterXConstraint?.constant = 0
        hostedViewCenterYConstraint?.constant = 0
        
        view.setNeedsUpdateConstraints()
        view.updateConstraintsIfNeeded()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        let contentWidth = max(finalWidth, scrollViewSize.width)
        let contentHeight = max(finalHeight, scrollViewSize.height)
        scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)
        
        scrollView.contentInset = UIEdgeInsets.zero
        
        print("✅ 이미지 중앙 정렬 완료 - contentSize: \(scrollView.contentSize)")
    }
    
    private func recenterImage() {
        let scrollViewSize = scrollView.bounds.size
        let contentSize = scrollView.contentSize
        let zoomScale = scrollView.zoomScale
        
        if zoomScale > 1.0 {
            scrollView.contentInset = UIEdgeInsets.zero
        }
        
        print("🔍 recenterImage - zoomScale: \(zoomScale), contentSize: \(contentSize)")
    }
    
    // MARK: - UIScrollViewDelegate
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return hostedView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        recenterImage()
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        // ✅ 줌 종료 후 중앙 정렬
        recenterImage()
        print("🔍 줌 종료 - scale: \(scale)")
    }
    
    // MARK: - 제스처 처리
    
    @objc private func handleSingleTap() {
        // 줌 상태가 아닐 때만 닫기
        if scrollView.zoomScale <= scrollView.minimumZoomScale + 0.1 {
            print("🖱️ 단일 탭 - 모달 닫기")
            onDismiss?()
        } else {
            print("🖱️ 단일 탭 - 줌 상태이므로 무시")
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        print("🖱️ 더블 탭 - 줌 토글")
        
        if scrollView.zoomScale <= scrollView.minimumZoomScale + 0.1 {
            // ✅ 줌 인 - 탭한 위치를 중심으로
            let location = gesture.location(in: hostedView)
            let zoomScale = scrollView.maximumZoomScale
            
            // 줌할 영역 계산
            let zoomWidth = scrollView.bounds.width / zoomScale
            let zoomHeight = scrollView.bounds.height / zoomScale
            let zoomRect = CGRect(
                x: location.x - zoomWidth / 2,
                y: location.y - zoomHeight / 2,
                width: zoomWidth,
                height: zoomHeight
            )
            
            scrollView.zoom(to: zoomRect, animated: true)
            print("🔍 줌 인 - 위치: \(location), 스케일: \(zoomScale)")
        } else {
            // ✅ 줌 아웃
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            print("🔍 줌 아웃")
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        // 줌 상태에서는 팬 제스처 무시
        guard scrollView.zoomScale <= scrollView.minimumZoomScale + 0.1 else { 
            print("🚫 줌 상태에서 팬 제스처 무시 - zoomScale: \(scrollView.zoomScale)")
            return 
        }
        
        switch gesture.state {
        case .began:
            print("🖱️ 팬 제스처 시작 - translation: \(translation)")
            
        case .changed:
            // 아래로 드래그 + 세로 방향이 우세한 경우만 처리
            let isDownward = translation.y > 5  // 최소 5px 아래로
            let isVerticalDominant = abs(translation.y) > abs(translation.x) * 1.5  // 세로가 가로보다 1.5배 이상
            
            if isDownward && (isVerticalDominant || abs(translation.y) > 20) {
                let translationSize = CGSize(width: translation.x, height: translation.y)
                onVerticalDrag?(translationSize)
                print("📱 드래그 중 - y: \(translation.y), x: \(translation.x), 세로우세: \(isVerticalDominant)")
            } else {
                print("🔄 드래그 무시 - y: \(translation.y), x: \(translation.x), 아래로: \(isDownward), 세로우세: \(isVerticalDominant)")
            }
            
        case .ended, .cancelled:
            // 아래로 드래그한 경우만 처리 (더 관대한 조건)
            let isDownward = translation.y > 5
            let isVerticalDominant = abs(translation.y) > abs(translation.x) * 1.2  // 종료 시에는 더 관대하게
            
            if isDownward && (isVerticalDominant || abs(translation.y) > 15) {
                let translationSize = CGSize(width: translation.x, height: translation.y)
                let velocitySize = CGSize(width: velocity.x, height: velocity.y)
                onVerticalDragEnd?(translationSize, velocitySize)
                print("🖱️ 팬 제스처 종료 - y: \(translation.y), velocity.y: \(velocity.y)")
            } else {
                print("🚫 종료 시 드래그 무시 - y: \(translation.y), x: \(translation.x)")
            }
            
        default:
            break
        }
    }
}


// MARK: - UIGestureRecognizerDelegate

extension ScrollableImageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 커스텀 팬 제스처인 경우
        if gestureRecognizer is UIPanGestureRecognizer && gestureRecognizer.view == view {
            // 줌되지 않은 상태에서만 동시 인식 허용
            let isNotZoomed = scrollView.zoomScale <= scrollView.minimumZoomScale + 0.1
            print("🤝 shouldRecognizeSimultaneouslyWith - isNotZoomed: \(isNotZoomed)")
            return isNotZoomed
        }
        return false
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPanGestureRecognizer {
            let isNotZoomed = scrollView.zoomScale <= scrollView.minimumZoomScale + 0.1
            
            print("🔍 gestureRecognizerShouldBegin - isNotZoomed: \(isNotZoomed), zoomScale: \(scrollView.zoomScale)")
            
            // 줌되지 않은 상태에서만 커스텀 팬 제스처 허용
            if isNotZoomed {
                print("✅ 팬 제스처 허용 - 줌 안됨")
                return true
            } else {
                print("🚫 팬 제스처 거부 - 줌 상태")
                return false
            }
        }
        return true
    }
}

struct PhotoPageView: View {
    let photos: [String]
    @Binding var currentIndex: Int
    let onDismiss: () -> Void
    let onVerticalDrag: (CGSize) -> Void
    let onVerticalDragEnd: (CGSize, CGSize) -> Void
    
    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                ScrollableImageView(
                    imagePath: photo,
                    onDismiss: onDismiss,
                    onVerticalDrag: onVerticalDrag,
                    onVerticalDragEnd: onVerticalDragEnd
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .onAppear {
            print("🔄 PhotoPageView appeared - currentIndex: \(currentIndex)")
        }
        .onChange(of: currentIndex) { newIndex in
            print("📄 페이지 변경됨: \(newIndex)")
        }
    }
}
