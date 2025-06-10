//
//  AuthenticatedImageView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI

struct AuthenticatedImageView: View {
    let imagePath: String
    let contentMode: ContentMode
    let placeholder: AnyView?
    let targetSize: CGSize?
    
    @State private var imageData: Data?
    @State private var isLoading = false
    @State private var hasError = false
    @State private var loadingTask: Task<Void, Never>?
    
    private let tokenManager = TokenManager.shared
    
    init(
        imagePath: String,
        contentMode: ContentMode = .fill,
        targetSize: CGSize? = CGSize(width: 250, height: 250),
        @ViewBuilder placeholder: @escaping () -> some View = {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
        }
    ) {
        self.imagePath = imagePath
        self.contentMode = contentMode
        self.placeholder = AnyView(placeholder())
        self.targetSize = targetSize
    }
    
    var body: some View {
        Group {
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                placeholder ?? AnyView(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)))
            } else if hasError {
                VStack(spacing: 4) {
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                    
                    Button {
                        retryImageLoad()
                    } label: {
                        Text("재시도")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            } else {
                Color.clear
            }
        }
        .task(id: imagePath) { // onAppear 대신 task 사용으로 최적화
            await loadImageIfNeeded()
        }
        .onDisappear {
            cleanUp()
        }
    }

    private func cleanUp() {
        loadingTask?.cancel()
        loadingTask = nil
    }
    
    private func loadImageIfNeeded() async {
        guard !imagePath.isEmpty else {
            await MainActor.run {
                hasError = true
            }
            return
        }
        
        guard !isLoading else { return }
        
        await performImageLoad()
    }
    
    private func retryImageLoad() {
        hasError = false
        Task {
            await performImageLoad()
        }
    }
    
    private func performImageLoad() async {
        await MainActor.run {
            isLoading = true
            hasError = false
        }
        
        loadingTask = Task {
            do {
                // 최적화된 ImageLoader 사용 (재시도 로직 제거)
                let data = try await ImageLoader.shared.loadImage(
                    from: imagePath,
                    targetSize: targetSize
                )
                
                await MainActor.run {
                    self.imageData = data
                    self.isLoading = false
                }
                print("✅ 이미지 로딩 성공: \(imagePath)")
            } catch {
                await MainActor.run {
                    self.hasError = true
                    self.isLoading = false
                }
                print("❌ 이미지 로드 실패: \(error)")
            }
        }
    }
}
