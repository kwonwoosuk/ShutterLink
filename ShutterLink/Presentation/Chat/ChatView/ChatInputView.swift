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
    
    // ✅ 플레이스홀더 상태 추가
    @State private var isShowingPlaceholder = true
    
    // 상수 - 3줄 제한 및 스크롤 구현
    private let minTextHeight: CGFloat = 40  // 1줄 최소 높이
    private let maxTextHeight: CGFloat = 120 // 3줄 최대 높이 (40 * 3)
    private let cornerRadius: CGFloat = 20
    private let placeholderText = "메시지를 입력하세요..."
    
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
                
                // ✅ 개선된 텍스트 입력 영역
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
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleDocumentSelection(result)
        }
        .confirmationDialog("파일 첨부", isPresented: $showFileMenu) {
            fileMenuButtons
        }
        .onChange(of: selectedImages) { newImages in
            if !newImages.isEmpty {
                handleImageSelection(newImages)
            }
        }
    }
    
    // MARK: - 업로드된 파일 미리보기
    
    private var uploadedFilesPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(uploadedFiles.enumerated()), id: \.offset) { index, file in
                    uploadedFileCard(file: file, index: index)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func uploadedFileCard(file: (String, String), index: Int) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // 파일 타입별 미리보기
                if isImageFile(file.0) {
                    AuthenticatedImageView(
                        imagePath: file.0,
                        contentMode: .fill
                    ) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
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
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                        .background(Color.white, in: Circle())
                }
                .offset(x: 8, y: -8)
            }
            
            // 파일명
            Text(file.1)
                .font(.pretendard(size: 10, weight: .regular))
                .foregroundColor(.gray)
                .lineLimit(1)
                .frame(maxWidth: 60)
        }
        .frame(width: 70, height: 90)
    }
    
    // MARK: - 첨부 버튼
    
    private var attachmentButton: some View {
        Button {
            showFileMenu = true
        } label: {
            Image(systemName: "plus")
                .font(.title3)
                .foregroundColor(.gray)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.gray.opacity(0.3)))
        }
        .disabled(isUploading)
    }
    
    // ✅ 파일 첨부 메뉴 (전체 용량 5MB로 수정)
    private var fileMenuButtons: some View {
        Group {
            if uploadedFiles.isEmpty {
                Button("사진 선택 (최대 5개, 전체 5MB)") {
                    showImagePicker = true
                }
                Button("PDF 문서 선택 (최대 5개, 전체 5MB)") {
                    showDocumentPicker = true
                }
            } else {
                let hasImages = uploadedFiles.contains { isImageFile($0.0) }
                let hasPDF = uploadedFiles.contains { isPDFFile($0.0) }
                
                if hasImages && uploadedFiles.count < 5 {
                    Button("사진 추가 (현재 \(uploadedFiles.count)/5개)") {
                        showImagePicker = true
                    }
                } else if hasPDF && uploadedFiles.count < 5 {
                    Button("PDF 추가 (현재 \(uploadedFiles.count)/5개)") {
                        showDocumentPicker = true
                    }
                } else if uploadedFiles.count >= 5 {
                    Button("최대 5개까지만 첨부 가능") {
                        // 아무 동작 안함
                    }
                    .disabled(true)
                }
            }
            
            Button("취소", role: .cancel) { }
        }
    }
    
    // MARK: - ✅ 개선된 텍스트 입력 영역 (가로 늘어남 방지)
    
    private var textInputArea: some View {
        ZStack(alignment: .leading) {
            // 배경
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.gray.opacity(0.15))
                .frame(height: max(minTextHeight, textHeight))
            
            CustomTextView(
                text: $messageText,
                height: $textHeight,
                maxHeight: maxTextHeight,
                textFont: UIFont.systemFont(ofSize: 16, weight: .regular),
                textColor: UIColor.white,
                cornerRadius: 0,
                borderWidth: 0,
                isScrollEnabled: textHeight >= maxTextHeight,
                lineFragmentPadding: 0,
                textContainerInset: UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16),
                placeholder: placeholderText,
                placeholderColor: UIColor.systemGray,
                // ✅ 플레이스홀더 상태 바인딩 추가
                isShowingPlaceholder: $isShowingPlaceholder
            )
            .frame(height: max(minTextHeight, textHeight))
            .background(Color.clear)
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
        
        let content = getActualMessageText()
        let files = uploadedFiles.map { $0.0 } // filePath들 추출
        
        // ✅ 디버깅: 전송할 파일 경로들 로깅
        print("🔍 ChatInputView sendMessage:")
        print("   - content: '\(content)'")
        print("   - uploadedFiles: \(uploadedFiles)")
        print("   - 추출한 files (filePaths): \(files)")
        
        guard !content.isEmpty || !files.isEmpty else { return }
        
        // 메시지 전송
        onSendMessage(content, files)
        
        // ✅ 입력 필드 완전 초기화
        messageText = ""
        textHeight = minTextHeight
        isShowingPlaceholder = true
        
        // ✅ 포커스 해제 후 다시 설정하여 플레이스홀더 강제 적용
        isTextFieldFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = true
        }
    }
    
    // ✅ 실제 메시지 텍스트 가져오기 (플레이스홀더 제외)
    private func getActualMessageText() -> String {
        if isShowingPlaceholder || messageText == placeholderText {
            return ""
        }
        return messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - ✅ 파일 처리 (서버 응답 경로 사용)
    
    private func handleImageSelection(_ images: [PhotosPickerItem]) {
        guard !images.isEmpty else { return }
        
        // ✅ PDF가 이미 있으면 이미지 선택 차단
        let hasPDF = uploadedFiles.contains { isPDFFile($0.0) }
        if hasPDF {
            print("❌ ChatInputView: PDF가 있어서 이미지 선택 불가")
            return
        }
        
        // ✅ 5개 제한 확인
        let remainingSlots = 5 - uploadedFiles.count
        if remainingSlots <= 0 {
            print("❌ ChatInputView: 이미 5개 파일이 첨부됨")
            return
        }
        
        let imagesToProcess = Array(images.prefix(remainingSlots))
        
        Task {
            var imageDataArray: [Data] = []
            var imageNames: [String] = []
            var totalSize = 0
            
            for (index, item) in imagesToProcess.enumerated() {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    // ✅ 전체 용량 5MB 체크
                    if totalSize + data.count <= (5 * 1024 * 1024) {
                        imageDataArray.append(data)
                        // ✅ 서버가 인식할 수 있는 임시 파일명 (업로드 후 실제 경로로 교체됨)
                        let fileName = "upload_image_\(Date().timeIntervalSince1970)_\(index + 1).jpg"
                        imageNames.append(fileName)
                        totalSize += data.count
                        
                        print("🔍 ChatInputView: 이미지 추가 - \(fileName), 크기: \(data.count)")
                    } else {
                        print("❌ ChatInputView: 용량 초과 - 총 \(totalSize + data.count) bytes")
                    }
                }
            }
            
            await MainActor.run {
                if !imageDataArray.isEmpty {
                    print("📤 ChatInputView: onUploadFiles 호출 - \(imageNames)")
                    onUploadFiles(imageDataArray, imageNames)
                }
            }
        }
        
        selectedImages.removeAll()
    }
    
    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            // ✅ 이미지가 이미 있으면 PDF 선택 차단
            let hasImages = uploadedFiles.contains { isImageFile($0.0) }
            if hasImages {
                print("❌ ChatInputView: 이미지가 있어서 PDF 선택 불가")
                return
            }
            
            // ✅ 5개 제한 확인
            let remainingSlots = 5 - uploadedFiles.count
            if remainingSlots <= 0 {
                print("❌ ChatInputView: 이미 5개 파일이 첨부됨")
                return
            }
            
            var documentDataArray: [Data] = []
            var documentNames: [String] = []
            var oversizedFiles: [String] = []
            var totalSize = 0
            
            // ✅ PDF만 필터링하고 남은 슬롯만큼 처리
            let pdfUrls = urls.filter { $0.pathExtension.lowercased() == "pdf" }
            let urlsToProcess = Array(pdfUrls.prefix(remainingSlots))
            
            for url in urlsToProcess {
                if let data = try? Data(contentsOf: url) {
                    // ✅ 전체 용량 5MB 체크 (각 파일이 아닌 전체 용량)
                    if totalSize + data.count <= (5 * 1024 * 1024) {
                        documentDataArray.append(data)
                        documentNames.append(url.lastPathComponent)
                        totalSize += data.count
                    } else {
                        oversizedFiles.append(url.lastPathComponent)
                    }
                }
            }
            
            if !documentDataArray.isEmpty {
                onUploadFiles(documentDataArray, documentNames)
            }
            
            // 용량 초과 파일 알림
            if !oversizedFiles.isEmpty {
                showFileSizeError(count: oversizedFiles.count)
            }
            
        case .failure(let error):
            print("❌ ChatInputView: 문서 선택 실패 - \(error)")
        }
    }
    
    // MARK: - 유틸리티
    
    // ✅ 개선된 canSendMessage 로직
    private var canSendMessage: Bool {
        let hasActualText = !getActualMessageText().isEmpty
        let hasFiles = !uploadedFiles.isEmpty
        return hasActualText || hasFiles
    }
    
    private func isImageFile(_ filePath: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp"]
        let fileExtension = filePath.components(separatedBy: ".").last?.lowercased() ?? ""
        return imageExtensions.contains(fileExtension)
    }
    
    // ✅ PDF 파일 체크 함수 추가
    private func isPDFFile(_ filePath: String) -> Bool {
        let fileExtension = filePath.components(separatedBy: ".").last?.lowercased() ?? ""
        return fileExtension == "pdf"
    }
    
    // ✅ 파일 크기 초과 알림 (전체 용량 기준으로 수정)
    private func showFileSizeError(count: Int) {
        print("❌ ChatInputView: \(count)개 파일이 전체 용량 5MB를 초과함")
        // TODO: 실제 앱에서는 Alert나 Toast 메시지로 사용자에게 알림
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
    
    private func getSafeAreaBottom() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - ✅ 개선된 CustomTextView (가로 늘어남 방지)

struct CustomTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var maxHeight: CGFloat
    var textFont: UIFont
    var textColor: UIColor = .white
    var textLimit: Int = 1000
    var cornerRadius: CGFloat? = nil
    var borderWidth: CGFloat? = nil
    var borderColor: CGColor? = nil
    var isScrollEnabled: Bool = true
    var isEditable: Bool = true
    var isUserInteractionEnabled: Bool = true
    var lineFragmentPadding: CGFloat = 0
    var textContainerInset: UIEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    var placeholder: String? = nil
    var placeholderColor: UIColor = .systemGray
    
    // ✅ 플레이스홀더 상태 바인딩 추가
    @Binding var isShowingPlaceholder: Bool
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        
        // 스타일 설정
        if let cornerRadius = cornerRadius {
            textView.layer.cornerRadius = cornerRadius
            textView.layer.masksToBounds = true
        }
        
        if let borderWidth = borderWidth {
            textView.layer.borderWidth = borderWidth
        }
        
        if let borderColor = borderColor {
            textView.layer.borderColor = borderColor
        }
        
        textView.font = textFont
        textView.isScrollEnabled = isScrollEnabled
        textView.isEditable = isEditable
        textView.isUserInteractionEnabled = isUserInteractionEnabled
        textView.textContainer.lineFragmentPadding = lineFragmentPadding
        textView.textContainerInset = textContainerInset
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        
        // ✅ iOS 16 호환: 가로 스크롤 방지 설정
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.size = CGSize(width: textView.frame.width, height: .greatestFiniteMagnitude)
        textView.showsHorizontalScrollIndicator = false
        textView.isScrollEnabled = false // 초기에는 스크롤 비활성화
        
        // 키보드 설정
        textView.keyboardType = .default
        textView.autocorrectionType = .default
        textView.spellCheckingType = .default
        textView.returnKeyType = .default
        
        // ✅ 초기 플레이스홀더 설정
        setupPlaceholder(textView)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // ✅ iOS 16 호환: 가로 크기 제한 설정
        uiView.textContainer.size = CGSize(width: uiView.frame.width, height: .greatestFiniteMagnitude)
        
        // ✅ delegate를 임시로 제거하여 textViewDidChange 방지
        let currentDelegate = uiView.delegate
        uiView.delegate = nil
        
        // 플레이스홀더 상태에 따른 업데이트
        if isShowingPlaceholder && uiView.text != placeholder {
            uiView.text = placeholder ?? ""
            uiView.textColor = placeholderColor
        } else if !isShowingPlaceholder && uiView.text != text {
            uiView.text = text
            uiView.textColor = textColor
        }
        
        // delegate 복원
        uiView.delegate = currentDelegate
        
        updateHeight(uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    // ✅ 초기 플레이스홀더 설정
    private func setupPlaceholder(_ textView: UITextView) {
        // delegate 임시 제거
        let currentDelegate = textView.delegate
        textView.delegate = nil
        
        if text.isEmpty {
            textView.text = placeholder ?? ""
            textView.textColor = placeholderColor
            DispatchQueue.main.async {
                isShowingPlaceholder = true
            }
        } else {
            textView.text = text
            textView.textColor = textColor
            DispatchQueue.main.async {
                isShowingPlaceholder = false
            }
        }
        
        // delegate 복원
        textView.delegate = currentDelegate
    }
    
    private func updateHeight(_ uiView: UITextView) {
        let size = uiView.sizeThatFits(CGSize(width: uiView.frame.width, height: .infinity))
        let newHeight = min(maxHeight, size.height)
        
        DispatchQueue.main.async {
            if abs(height - newHeight) > 1 {
                height = newHeight
            }
            // ✅ 높이가 최대값에 도달했을 때만 스크롤 활성화
            uiView.isScrollEnabled = size.height > maxHeight
        }
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextView
        
        init(parent: CustomTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // ✅ 플레이스홀더 텍스트인지 확인
            if textView.text == parent.placeholder {
                return // 플레이스홀더 텍스트는 무시
            }
            
            // ✅ 플레이스홀더 상태가 아닐 때만 텍스트 업데이트
            if !parent.isShowingPlaceholder {
                // 텍스트 길이 제한
                if textView.text.count > parent.textLimit {
                    textView.text = String(textView.text.prefix(parent.textLimit))
                }
                parent.text = textView.text
            }
            
            parent.updateHeight(textView)
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            // ✅ 플레이스홀더 제거
            if parent.isShowingPlaceholder {
                // delegate 임시 제거
                let currentDelegate = textView.delegate
                textView.delegate = nil
                
                textView.text = ""
                textView.textColor = parent.textColor
                
                // delegate 복원
                textView.delegate = currentDelegate
                
                DispatchQueue.main.async {
                    self.parent.isShowingPlaceholder = false
                    self.parent.text = ""
                }
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            // ✅ 텍스트가 비어있으면 플레이스홀더 표시
            if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // delegate 임시 제거
                let currentDelegate = textView.delegate
                textView.delegate = nil
                
                textView.text = parent.placeholder ?? ""
                textView.textColor = parent.placeholderColor
                
                // delegate 복원
                textView.delegate = currentDelegate
                
                DispatchQueue.main.async {
                    self.parent.isShowingPlaceholder = true
                    self.parent.text = ""
                }
            }
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
