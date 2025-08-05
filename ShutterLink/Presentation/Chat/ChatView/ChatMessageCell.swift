//
//  ChatMessageCell.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import SwiftUI

struct ChatMessageCell: View {
    let message: ChatMessage
    let isMyMessage: Bool
    
    @State private var showPhotoPreview = false
    @State private var photoPreviewIndex = 0
    @State private var photoPreviewList: [String] = []
    
    @State private var showPDFPreview = false
    @State private var pdfPreviewList: [String] = []
    @State private var pdfPreviewIndex = 0
    
    private let maxBubbleWidth: CGFloat = 280
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // ✅ 내 메시지: 왼쪽 여백 + 오른쪽 정렬
            if isMyMessage {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 4) {
                    messageBubble
                    messageInfo
                }
            }
            // ✅ 상대방 메시지: 왼쪽 정렬 + 오른쪽 여백
            else {
                profileImage
                
                VStack(alignment: .leading, spacing: 2) {
                    senderName
                    HStack(alignment: .bottom, spacing: 8) {
                        messageBubble
                        messageInfo
                    }
                }
                
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .fullScreenCover(isPresented: $showPhotoPreview) {
            let _ = photoPreviewList
            let _ = photoPreviewIndex
            let _ = showPhotoPreview

            let currentPhotos = photoPreviewList
            let currentIndex = photoPreviewIndex
            
            return PhotoPreviewModal(
                photos: currentPhotos.isEmpty ? photoPreviewList : currentPhotos,
                initialIndex: currentPhotos.isEmpty ? photoPreviewIndex : currentIndex,
                isPresented: $showPhotoPreview
            )
        }
        .fullScreenCover(isPresented: $showPDFPreview) {
            let _ = pdfPreviewList
            let _ = pdfPreviewIndex
            let _ = showPDFPreview
            
            let currentPDFs = pdfPreviewList
            let currentIndex = pdfPreviewIndex
            
            return PDFPreviewModal(
                pdfPaths: currentPDFs.isEmpty ? pdfPreviewList : currentPDFs,
                initialIndex: currentPDFs.isEmpty ? pdfPreviewIndex : currentIndex,
                isPresented: $showPDFPreview
            )
        }
        .onAppear {
            preloadImages()
        }
    }
    
    private func preloadImages() {
        let imageFiles = message.files.filter { isImageFile($0) }
        guard !imageFiles.isEmpty else { return }
        
        print("🔄 이미지 프리로딩 시작: \(imageFiles.count)개")
        
        Task {
            for (index, imagePath) in imageFiles.prefix(3).enumerated() {
                do {
                    let _ = try await ImageLoader.shared.loadOriginalImage(from: imagePath)
                    print("✅ 프리로딩 성공 [\(index + 1)/\(min(3, imageFiles.count))]: \(imagePath)")
                } catch {
                    print("❌ 프리로딩 실패 [\(index + 1)]: \(error)")
                }
            }
            print("🎯 이미지 프리로딩 완료")
        }
    }
    
    // MARK: - 프로필 이미지
    
    @ViewBuilder
    private var profileImage: some View {
        if !isMyMessage {
            if let profileImagePath = message.sender.profileImage {
                AuthenticatedImageView(
                    imagePath: profileImagePath,
                    contentMode: .fill,
                    useOriginalImage: true
                ) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                    )
            }
        }
    }
    
    // MARK: - 발신자 이름
    
    @ViewBuilder
    private var senderName: some View {
        if !isMyMessage {
            Text(message.sender.nick.isEmpty ? message.sender.name : message.sender.nick)
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .padding(.leading, 4)
        }
    }
    
    // MARK: - 메시지 정보 (시간, 읽음 표시)
    
    private var messageInfo: some View {
        VStack(alignment: isMyMessage ? .trailing : .leading, spacing: 2) {
            Text(formattedTime)
                .font(.pretendard(size: 10, weight: .regular))
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - 메시지 버블
    
    private var messageBubble: some View {
        VStack(alignment: isMyMessage ? .trailing : .leading, spacing: 8) {
            // 텍스트 메시지
            if !message.content.isEmpty {
                textBubble
            }
            
            if !message.files.isEmpty {
                filesView
            }
        }
    }
    
    private var textBubble: some View {
        Text(message.content)
            .font(.pretendard(size: 16, weight: .regular))
            .foregroundColor(isMyMessage ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isMyMessage ? Color.yellow : Color.gray.opacity(0.8))
            )
            .frame(maxWidth: maxBubbleWidth, alignment: isMyMessage ? .trailing : .leading)
    }
    
    // MARK: - ✅ 첨부 파일 표시 (PDF/일반파일 분기 처리)
    
    @ViewBuilder
    private var filesView: some View {
        if !message.files.isEmpty {
            let imageFiles = message.files.filter { isImageFile($0) }
            let pdfFiles = message.files.filter { isPDFFile($0) }
            let otherFiles = message.files.filter { !isImageFile($0) && !isPDFFile($0) }
            
          
            VStack(alignment: isMyMessage ? .trailing : .leading, spacing: 8) {
                if !imageFiles.isEmpty {
                    let _ = print("📸 이미지 파일 표시: \(imageFiles.count)개")
                    imageFilesView(images: imageFiles)
                }
                
                if !pdfFiles.isEmpty {
                    let _ = print("📄 PDF 파일 표시: \(pdfFiles.count)개 (하얀색 배경)")
                    ForEach(Array(pdfFiles.enumerated()), id: \.offset) { index, file in
                        pdfFileView(file: file, allPDFs: pdfFiles, index: index)
                    }
                }
                
                if !otherFiles.isEmpty {
                    let _ = print("📁 기타 파일 표시: \(otherFiles.count)개 (기존 색상)")
                    ForEach(Array(otherFiles.enumerated()), id: \.offset) { index, file in
                        generalFileView(file: file, index: index)
                    }
                }
            }
        }
    }
    
    // MARK: - ✅ 이미지 파일들 레이아웃 (개수별 분기)
    
    @ViewBuilder
    private func imageFilesView(images: [String]) -> some View {
        switch images.count {
        case 1:
            // 1개: 큰 이미지
            singleImageView(image: images[0], allImages: images, index: 0)
        case 2:
            // 2개: 좌우 배치
            HStack(spacing: 4) {
                imageItemView(image: images[0], width: 138, height: 165, allImages: images, index: 0)
                imageItemView(image: images[1], width: 138, height: 165, allImages: images, index: 1)
            }
        case 3:
            // 3개: 일렬 배치
            HStack(spacing: 4) {
                imageItemView(image: images[0], width: 90, height: 126, allImages: images, index: 0)
                imageItemView(image: images[1], width: 90, height: 126, allImages: images, index: 1)
                imageItemView(image: images[2], width: 90, height: 126, allImages: images, index: 2)
            }
        case 4:
            // 4개: 2x2 그리드
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    imageItemView(image: images[0], width: 138, height: 110, allImages: images, index: 0)
                    imageItemView(image: images[1], width: 138, height: 110, allImages: images, index: 1)
                }
                HStack(spacing: 4) {
                    imageItemView(image: images[2], width: 138, height: 110, allImages: images, index: 2)
                    imageItemView(image: images[3], width: 138, height: 110, allImages: images, index: 3)
                }
            }
        case 5:
            // 5개: 2+3 배치
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    imageItemView(image: images[0], width: 138, height: 110, allImages: images, index: 0)
                    imageItemView(image: images[1], width: 138, height: 110, allImages: images, index: 1)
                }
                HStack(spacing: 4) {
                    imageItemView(image: images[2], width: 90, height: 110, allImages: images, index: 2)
                    imageItemView(image: images[3], width: 90, height: 110, allImages: images, index: 3)
                    imageItemView(image: images[4], width: 90, height: 110, allImages: images, index: 4)
                }
            }
        default:
            // 기본: 스크롤 뷰
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        imageItemView(image: image, width: 168, height: 134, allImages: images, index: index)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - ✅ 단일 이미지 뷰
    
    private func singleImageView(image: String, allImages: [String], index: Int) -> some View {
        AuthenticatedImageView(
            imagePath: image,
            contentMode: .fill,
            useOriginalImage: true
        ) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .frame(width: maxBubbleWidth, height: 224)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .font(.title2)
                )
        }
        .frame(width: maxBubbleWidth, height: 224)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            handleImageTap(allImages: allImages, index: index)
        }
    }
    
    // MARK: - ✅ 개별 이미지 아이템 뷰
    
    private func imageItemView(image: String, width: CGFloat, height: CGFloat, allImages: [String], index: Int) -> some View {
        AuthenticatedImageView(
            imagePath: image,
            contentMode: .fill,
            useOriginalImage: true
        ) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .frame(width: width, height: height)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .font(.title2)
                )
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            handleImageTap(allImages: allImages, index: index)
        }
    }
    
    // MARK: - ✅ PDF 파일 뷰
    
    private func pdfFileView(file: String, allPDFs: [String], index: Int) -> some View {
        let _ = print("🔍 pdfFileView 렌더링:")
        let _ = print("   - file: '\(file)'")
        let _ = print("   - allPDFs: \(allPDFs)")
        let _ = print("   - index: \(index)")
        
        return HStack(spacing: 12) {
            Image(systemName: "doc.richtext.fill")
                .font(.title2)
                .foregroundColor(.red)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName(from: file))
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                Text("PDF 문서")
                    .font(.pretendard(size: 12, weight: .regular))
                    .foregroundColor(.black.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "eye")
                .font(.title3)
                .foregroundColor(.black.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .frame(maxWidth: maxBubbleWidth)
        .onTapGesture {
            handlePDFTap(allPDFs: allPDFs, index: index)
        }
    }
    
    private func handleImageTap(allImages: [String], index: Int) {
        
        // 검증
        guard !allImages.isEmpty else {
            print("❌ allImages가 비어있음!")
            return
        }
        
        guard allImages.indices.contains(index) else {
            print("❌ 인덱스 범위 초과! 인덱스: \(index), 배열 크기: \(allImages.count)")
            return
        }
        openPhotoPreview(photos: allImages, index: index)
    }
    
    private func handlePDFTap(allPDFs: [String], index: Int) {
        guard !allPDFs.isEmpty else {
            print("❌ PDF 배열이 비어있음!")
            return
        }
        
        guard allPDFs.indices.contains(index) else {
            print("❌ PDF 인덱스 범위 초과!")
            return
        }
        
        print("✅ PDF 탭 검증 통과 - openPDFPreview 호출")
        openPDFPreview(pdfs: allPDFs, index: index)
    }
    // 미리보기 열기 액션
    
    private func openPhotoPreview(photos: [String], index: Int) {
        photoPreviewList = photos
        photoPreviewIndex = index
        showPhotoPreview = true
        
    }
    
    private func openPDFPreview(pdfs: [String], index: Int) {
        pdfPreviewList = pdfs
        pdfPreviewIndex = index
        showPDFPreview = true
    }
    
    // MARK: - 시간 포맷팅
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.createdAt)
    }
    
    private func isImageFile(_ filePath: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic", "bmp", "tiff"]
        let fileExtension = filePath.components(separatedBy: ".").last?.lowercased() ?? ""
        let result = imageExtensions.contains(fileExtension)
        
        print("🔍 isImageFile('\(filePath)') -> \(result) (확장자: '\(fileExtension)')")
        return result
    }
    
    private func isPDFFile(_ filePath: String) -> Bool {
        let fileExtension = filePath.components(separatedBy: ".").last?.lowercased() ?? ""
        let result = fileExtension == "pdf"
        
        print("🔍 isPDFFile('\(filePath)') -> \(result) (확장자: '\(fileExtension)')")
        return result
    }
    // pdf 아닌경우
    private func generalFileView(file: String, index: Int) -> some View {
        print("🔍 generalFileView 렌더링: '\(file)'")
        
        return HStack(spacing: 12) {
            Image(systemName: fileIcon(for: file))
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName(from: file))
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(isMyMessage ? .black : .white)
                    .lineLimit(1)
                
                Text(fileType(from: file))
                    .font(.pretendard(size: 12, weight: .regular))
                    .foregroundColor(isMyMessage ? .black.opacity(0.7) : .white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "eye")
                .font(.title3)
                .foregroundColor(isMyMessage ? .black.opacity(0.7) : .white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isMyMessage ? Color.yellow.opacity(0.8) : Color.gray.opacity(0.6))  // ✅ 기존 색상 유지
        )
        .frame(maxWidth: maxBubbleWidth)
    }
    
    private func fileType(from filePath: String) -> String {
        let fileExtension = filePath.components(separatedBy: ".").last?.lowercased() ?? ""
        
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "bmp", "tiff":
            return "이미지 파일"
        case "pdf":
            return "PDF 문서"
        case "mp4", "mov", "avi", "mkv":
            return "비디오 파일"
        case "mp3", "wav", "m4a", "aac":
            return "오디오 파일"
        case "doc", "docx":
            return "Word 문서"
        case "xls", "xlsx":
            return "Excel 파일"
        case "txt":
            return "텍스트 파일"
        default:
            return "파일"
        }
    }
    
    private func fileName(from filePath: String) -> String {
        let result = filePath.components(separatedBy: "/").last ?? filePath
        return result
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
