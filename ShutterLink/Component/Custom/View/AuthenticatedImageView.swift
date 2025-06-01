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
    
    private let tokenManager = TokenManager.shared
    
    init(
        imagePath: String,
        contentMode: ContentMode = .fill,
        targetSize: CGSize? = nil,
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
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            } else {
                Color.clear
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard !imagePath.isEmpty else {
            hasError = true
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        hasError = false
        
        Task {
            do {
                let data = try await ImageLoader.shared.loadImage(from: imagePath, targetSize: targetSize)
                await MainActor.run {
                    self.imageData = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.hasError = true
                    self.isLoading = false
                }
                print("이미지 로드 실패: \(error)")
            }
        }
    }
}
