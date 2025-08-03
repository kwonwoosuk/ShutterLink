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
    
    // ✅ 미리보기 모달 상태들 (최소한만 추가)
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
        // ✅ 미리보기 모달들 (필요시에만)
        .fullScreenCover(isPresented: $showPhotoPreview) {
            PhotoPreviewModal(
                photos: photoPreviewList,
                initialIndex: photoPreviewIndex,
                isPresented: $showPhotoPreview
            )
        }
        .fullScreenCover(isPresented: $showPDFPreview) {
            PDFPreviewModal(
                pdfPaths: pdfPreviewList,
                initialIndex: pdfPreviewIndex,
                isPresented: $showPDFPreview
            )
        }
    }
    
    init(message: ChatMessage, isMyMessage: Bool) {
        self.message = message
        self.isMyMessage = isMyMessage
        print("📂 message.files: \(message.files)")
    }
    
    // MARK: - 프로필 이미지
    
    @ViewBuilder
    private var profileImage: some View {
        if !isMyMessage {
            if let profileImagePath = message.sender.profileImage {
                AuthenticatedImageView(
                    imagePath: profileImagePath,
                    contentMode: .fill
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
            
            // 내 메시지일 때만 읽음 표시 (필요 시)
            if isMyMessage {
                // TODO: 읽음 상태 구현 시 추가
                // Text("읽음")
                //     .font(.pretendard(size: 9, weight: .regular))
                //     .foregroundColor(.yellow)
            }
        }
    }
    
    // MARK: - 메시지 버블
    
    private var messageBubble: some View {
        VStack(alignment: isMyMessage ? .trailing : .leading, spacing: 8) {
            // 텍스트 메시지
            if !message.content.isEmpty {
                textBubble
            }
            
            // ✅ 첨부 파일들 (원본 기반 + 분기 처리)
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
    
    // MARK: - ✅ 첨부 파일 표시 (원본 기반 + 이미지/PDF 분기)
    
    @ViewBuilder
    private var filesView: some View {
        
        if !message.files.isEmpty {
            let imageFiles = message.files.filter { isImageFile($0) }
            let pdfFiles = message.files.filter { isPDFFile($0) }
            
            VStack(alignment: isMyMessage ? .trailing : .leading, spacing: 8) {
                // ✅ 이미지 파일들 - 개수별 레이아웃
                if !imageFiles.isEmpty {
                    imageFilesView(images: imageFiles)
                }
                
                // ✅ PDF 파일들 - 개별 표시
                if !pdfFiles.isEmpty {
                    ForEach(Array(pdfFiles.enumerated()), id: \.offset) { index, file in
                        pdfFileView(file: file, allPDFs: pdfFiles, index: index)
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
    
    // MARK: - ✅ 단일 이미지 뷰 (원본 크기 기반)
    
    private func singleImageView(image: String, allImages: [String], index: Int) -> some View {
        AuthenticatedImageView(
            imagePath: image,
            contentMode: .fill
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
            openPhotoPreview(photos: allImages, index: index)
        }
    }
    
    // MARK: - ✅ 개별 이미지 아이템 뷰 (원본 구조 기반)
    
    private func imageItemView(image: String, width: CGFloat, height: CGFloat, allImages: [String], index: Int) -> some View {
        AuthenticatedImageView(
            imagePath: image,
            contentMode: .fill
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
            openPhotoPreview(photos: allImages, index: index)
        }
    }
    
    // MARK: - ✅ PDF 파일 뷰 (원본 스타일 기반)
    
    private func pdfFileView(file: String, allPDFs: [String], index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext.fill")
                .font(.title2)
                .foregroundColor(.red)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName(from: file))
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(isMyMessage ? .black : .white)
                    .lineLimit(1)
                
                Text("PDF 문서")
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
                .fill(isMyMessage ? Color.yellow.opacity(0.8) : Color.gray.opacity(0.6))
        )
        .frame(maxWidth: maxBubbleWidth)
        .onTapGesture {
            openPDFPreview(pdfs: allPDFs, index: index)
        }
    }
    
    // MARK: - ✅ 미리보기 열기 액션들
    
    private func openPhotoPreview(photos: [String], index: Int) {
        photoPreviewList = photos
        photoPreviewIndex = index
        showPhotoPreview = true
        
        print("🖼 사진 미리보기 열기: \(photos[index]) (인덱스: \(index))")
    }
    
    private func openPDFPreview(pdfs: [String], index: Int) {
        pdfPreviewList = pdfs
        pdfPreviewIndex = index
        showPDFPreview = true
        
        print("📄 PDF 미리보기 열기: \(pdfs[index]) (인덱스: \(index))")
    }
    
    // MARK: - 시간 포맷팅
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.createdAt)
    }
    
    // MARK: - 파일 유틸리티
    
    private func isImageFile(_ filePath: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp"]
        let fileExtension = filePath.components(separatedBy: ".").last?.lowercased() ?? ""
        return imageExtensions.contains(fileExtension)
    }
    
    private func isPDFFile(_ filePath: String) -> Bool {
        let fileExtension = filePath.components(separatedBy: ".").last?.lowercased() ?? ""
        return fileExtension == "pdf"
    }
    
    private func fileName(from filePath: String) -> String {
        return filePath.components(separatedBy: "/").last ?? filePath
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
