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
            Text(message.sender.name.isEmpty ? message.sender.nick : message.sender.name)
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
            
            // 첨부 파일들
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
    
    // MARK: - 첨부 파일 표시
    
    @ViewBuilder
    private var filesView: some View {
        if !message.files.isEmpty {
            VStack(alignment: isMyMessage ? .trailing : .leading, spacing: 6) {
                ForEach(Array(message.files.enumerated()), id: \.offset) { index, file in
                    fileItemView(file: file, index: index)
                }
            }
        }
    }
    
    private func fileItemView(file: String, index: Int) -> some View {
        Group {
            if isImageFile(file) {
                // 이미지 파일
                AuthenticatedImageView(
                    imagePath: file,
                    contentMode: .fill
                ) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 150)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.title2)
                        )
                }
                .frame(width: 200, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            } else {
                // 일반 파일
                HStack(spacing: 12) {
                    Image(systemName: fileIcon(for: file))
                        .font(.title3)
                        .foregroundColor(isMyMessage ? .black : .white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fileName(from: file))
                            .font(.pretendard(size: 14, weight: .medium))
                            .foregroundColor(isMyMessage ? .black : .white)
                            .lineLimit(1)
                        
                        Text("파일")
                            .font(.pretendard(size: 12, weight: .regular))
                            .foregroundColor(isMyMessage ? .black.opacity(0.7) : .white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.down.circle")
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
            }
        }
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

