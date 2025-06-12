//
//  ChatInputView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import SwiftUI
import PhotosUI

struct ChatInputView: View {
    // 콜백 함수들
    let onSendMessage: (String, [String]) -> Void
    let onUploadFiles: ([Data], [String]) -> Void
    let uploadedFiles: [(String, String)] // (filePath, fileName)
    let onRemoveFile: (Int) -> Void
    let isUploading: Bool
    let isSending: Bool
    let canSend: Bool
    
    // 상태 변수들
    @State private var messageText = ""
    @State private var textHeight: CGFloat = 40
    @State private var showFileMenu = false
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var selectedImages: [PhotosPickerItem] = []
    @FocusState private var isTextFieldFocused: Bool
    
    // 상수
    private let minTextHeight: CGFloat = 40
    private let maxTextHeight: CGFloat = 120
    private let cornerRadius: CGFloat = 20
    
    var body: some View {
        VStack(spacing: 0) {
            // 업로드된 파일들 미리보기
            if !uploadedFiles.isEmpty {
                uploadedFilesPreview
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
            
            // 메인 입력 영역
            HStack(alignment: .bottom, spacing: 12) {
                // 파일 첨부 버튼
                attachmentButton
                
                // 텍스트 입력 영역
                textInputArea
                
                // 전송 버튼
                sendButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.black)
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $selectedImages,
            maxSelectionCount: 5,
            matching: .images
        )
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf, .text, .data],
            allowsMultipleSelection: true
        ) { result in
            handleDocumentSelection(result)
        }
        .onChange(of: selectedImages) { newImages in
            handleImageSelection(newImages)
        }
        .confirmationDialog("파일 첨부", isPresented: $showFileMenu) {
            Button("사진/동영상") {
                showImagePicker = true
            }
            
            Button("문서") {
                showDocumentPicker = true
            }
            
            Button("취소", role: .cancel) { }
        }
    }
    
    // MARK: - 업로드된 파일 미리보기
    
    private var uploadedFilesPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(uploadedFiles.enumerated()), id: \.offset) { index, file in
                    uploadedFileItem(file: file, index: index)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func uploadedFileItem(file: (String, String), index: Int) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // 파일 미리보기
                if isImageFile(file.0) {
                    AuthenticatedImageView(
                        imagePath: file.0,
                        contentMode: .fill
                    ) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: fileIcon(for: file.0))
                                .font(.title2)
                                .foregroundColor(.white)
                        )
                }
                
                // 삭제 버튼
                Button {
                    onRemoveFile(index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                }
                .offset(x: 4, y: -4)
            }
            
            // 파일명
            Text(file.1)
                .font(.pretendard(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
                .frame(width: 60)
        }
    }
    
    // MARK: - 첨부 파일 버튼
    
    private var attachmentButton: some View {
        Button {
            showFileMenu = true
        } label: {
            Image(systemName: "plus")
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.gray.opacity(0.3)))
        }
        .disabled(isUploading || isSending)
    }
    
    // MARK: - 텍스트 입력 영역
    
    private var textInputArea: some View {
        ZStack(alignment: .leading) {
            // ✅ 배경 (키보드와 함께 움직임)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.gray.opacity(0.15))
                .frame(height: textHeight)
            
            // ✅ 플레이스홀더
            if messageText.isEmpty {
                Text("메시지를 입력하세요...")
                    .font(.pretendard(size: 16, weight: .regular))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            
            // ✅ 자동 크기 조절 텍스트뷰
            AutoSizingTextView(
                text: $messageText,
                textHeight: $textHeight,
                minHeight: minTextHeight,
                maxHeight: maxTextHeight,
                font: UIFont.systemFont(ofSize: 16, weight: .regular),
                textColor: UIColor.white,
                backgroundColor: UIColor.clear
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .focused($isTextFieldFocused)
        }
        .animation(.easeInOut(duration: 0.2), value: textHeight)
    }
    
    // MARK: - 전송 버튼
    
    private var sendButton: some View {
        Button {
            sendMessage()
        } label: {
            Group {
                if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                }
            }
            .frame(width: 36, height: 36)
            .background(
                Circle().fill(
                    (canSendMessage && canSend) ? Color.yellow : Color.gray.opacity(0.3)
                )
            )
        }
        .disabled(!canSendMessage || !canSend)
        .animation(.easeInOut(duration: 0.2), value: canSendMessage)
    }
    
    // MARK: - 액션 메서드
    
    private func sendMessage() {
        guard canSendMessage else { return }
        
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let files = uploadedFiles.map { $0.0 }
        
        guard !content.isEmpty || !files.isEmpty else { return }
        
        // 메시지 전송
        onSendMessage(content, files)
        
        // 입력 필드 초기화
        messageText = ""
        textHeight = minTextHeight
        
        // 키보드 포커스 유지 (사용자 경험 향상)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = true
        }
    }
    
    // MARK: - 파일 처리
    
    private func handleImageSelection(_ images: [PhotosPickerItem]) {
        guard !images.isEmpty else { return }
        
        Task {
            var imageDataArray: [Data] = []
            var imageNames: [String] = []
            
            for item in images {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    imageDataArray.append(data)
                    
                    // 파일명 생성
                    let fileName = "image_\(Date().timeIntervalSince1970).jpg"
                    imageNames.append(fileName)
                }
            }
            
            if !imageDataArray.isEmpty {
                await MainActor.run {
                    onUploadFiles(imageDataArray, imageNames)
                }
            }
        }
        
        // 선택 초기화
        selectedImages.removeAll()
    }
    
    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var documentDataArray: [Data] = []
            var documentNames: [String] = []
            
            for url in urls {
                if let data = try? Data(contentsOf: url) {
                    documentDataArray.append(data)
                    documentNames.append(url.lastPathComponent)
                }
            }
            
            if !documentDataArray.isEmpty {
                onUploadFiles(documentDataArray, documentNames)
            }
            
        case .failure(let error):
            print("❌ ChatInputView: 문서 선택 실패 - \(error)")
        }
    }
    
    // MARK: - 유틸리티
    
    private var canSendMessage: Bool {
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasFiles = !uploadedFiles.isEmpty
        return hasText || hasFiles
    }
    
    private func isImageFile(_ filePath: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp"]
        let fileExtension = filePath.components(separatedBy: ".").last?.lowercased() ?? ""
        return imageExtensions.contains(fileExtension)
    }
    
    private func fileIcon(for filePath: String) -> String {
        let fileExtension = filePath.components(separatedBy: ".").last?.lowercased() ?? ""
        
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif":
            return "photo"
        case "pdf":
            return "doc.text"
        case "mp4", "mov", "avi":
            return "video"
        case "mp3", "wav", "m4a":
            return "music.note"
        default:
            return "doc"
        }
    }
}

// MARK: - 첨부 파일 모델

struct AttachedFile {
    let data: Data
    let name: String
    let isImage: Bool
    let thumbnail: UIImage?
}

// MARK: - 자동 크기 조절 텍스트뷰 (UIKit 래핑)

struct AutoSizingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var textHeight: CGFloat
    
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let font: UIFont
    let textColor: UIColor
    let backgroundColor: UIColor
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.isScrollEnabled = false
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.delegate = context.coordinator
        textView.returnKeyType = .default
        textView.enablesReturnKeyAutomatically = false
        
        // ✅ 키보드 타입 설정
        textView.keyboardType = .default
        textView.autocorrectionType = .default
        textView.spellCheckingType = .default
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        
        updateHeight(uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updateHeight(_ textView: UITextView) {
        let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .greatestFiniteMagnitude))
        let newHeight = max(minHeight, min(maxHeight, size.height))
        
        if abs(textHeight - newHeight) > 1 {
            DispatchQueue.main.async {
                self.textHeight = newHeight
            }
        }
        
        // 최대 높이에 도달하면 스크롤 활성화
        textView.isScrollEnabled = size.height > maxHeight
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: AutoSizingTextView
        
        init(_ parent: AutoSizingTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.updateHeight(textView)
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // 줄바꿈 허용
            return true
        }
    }
}

// MARK: - 미리보기

struct ChatInputView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            
            ChatInputView(
                onSendMessage: { content, files in
                    print("Send: \(content), Files: \(files)")
                },
                onUploadFiles: { data, names in
                    print("Upload: \(names)")
                },
                uploadedFiles: [
                    ("/data/chats/image1.jpg", "사진1.jpg"),
                    ("/data/chats/document.pdf", "문서.pdf")
                ],
                onRemoveFile: { index in
                    print("Remove file at index: \(index)")
                },
                isUploading: false,
                isSending: false,
                canSend: true
            )
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
