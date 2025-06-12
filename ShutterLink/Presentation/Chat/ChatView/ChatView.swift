//
//  ChatView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import SwiftUI

struct ChatView: View {
    let roomId: String
    let participantInfo: Users
    
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var keyboardHeight: CGFloat = 0
    @State private var showConnectionStatus = false
    
    init(roomId: String, participantInfo: Users) {
        self.roomId = roomId
        self.participantInfo = participantInfo
        
        // 의존성 주입 (실제 구현에서는 DI 컨테이너 사용)
        let localRepository = try! RealmChatRepository()
        let chatUseCase = ChatUseCaseImpl(localRepository: localRepository)
        let socketUseCase = SocketUseCaseImpl(chatUseCase: chatUseCase)
        
        self._viewModel = StateObject(wrappedValue: ChatViewModel(
            roomId: roomId,
            chatUseCase: chatUseCase,
            socketUseCase: socketUseCase
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 연결 상태 표시 (필요 시)
            if showConnectionStatus {
                connectionStatusBar
            }
            
            // 메시지 목록
            messagesScrollView
            
            // 입력 영역 - 키보드 위에 고정
            chatInputSection
        }
        .background(Color.black)
        .navigationTitle(participantInfo.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                connectionStatusButton
            }
        }
        .onAppear {
            viewModel.onAppear()
            setupKeyboardObservers()
        }
        .onDisappear {
            viewModel.onDisappear()
            removeKeyboardObservers()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.onAppWillEnterForeground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            viewModel.onAppDidEnterBackground()
        }
        .alert("오류", isPresented: $viewModel.showError) {
            Button("확인") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
    }
    
    // MARK: - 연결 상태 바
    
    @ViewBuilder
    private var connectionStatusBar: some View {
        HStack {
            Circle()
                .fill(viewModel.connectionStatusColor)
                .frame(width: 8, height: 8)
            
            Text(viewModel.connectionStatusText)
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.2))
        .transition(.opacity)
    }
    
    // MARK: - 메시지 스크롤뷰
    
    private var messagesScrollView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 채팅 시작 안내 (메시지가 없을 때)
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        ChatStartNotice(participantName: participantInfo.name)
                            .padding(.top, 20)
                    }
                    
                    // 메시지 목록
                    ForEach(groupedMessages, id: \.date) { group in
                        ChatDateSeparator(date: group.date)
                        
                        ForEach(group.messages) { message in
                            ChatMessageCell(
                                message: message,
                                isMyMessage: message.isFromCurrentUser
                            )
                            .id(message.chatId)
                        }
                    }
                    
                    // 로딩 인디케이터
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    }
                    
                    // 하단 여백 (키보드 높이 고려)
                    Color.clear
                        .frame(height: 10)
                }
                .padding(.bottom, keyboardHeight == 0 ? 0 : 10)
            }
            .refreshable {
                viewModel.input.refreshMessages.send()
            }
            // ✅ 실시간 메시지 업데이트 시 스크롤
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom(scrollProxy: scrollProxy)
            }
            // ✅ 키보드 올라올 때 스크롤
            .onChange(of: keyboardHeight) { newHeight in
                if newHeight > 0 {
                    scrollToBottom(scrollProxy: scrollProxy, delay: 0.1)
                }
            }
        }
    }
    
    // MARK: - 채팅 입력 섹션
    
    private var chatInputSection: some View {
        VStack(spacing: 0) {
            // 구분선
            Divider()
                .background(Color.gray.opacity(0.3))
            
            ChatInputView(
                onSendMessage: { content, files in
                    viewModel.input.sendMessage.send((content, files))
                },
                onUploadFiles: { files, fileNames in
                    viewModel.input.uploadFiles.send((files, fileNames))
                },
                uploadedFiles: viewModel.uploadedFiles,
                onRemoveFile: { index in
                    viewModel.removeUploadedFile(at: index)
                },
                isUploading: viewModel.isUploading,
                isSending: viewModel.isSending,
                canSend: viewModel.canSendMessage
            )
        }
        .background(Color.black)
        // ✅ 키보드 위에 고정
        .padding(.bottom, keyboardHeight)
        .animation(.easeOut(duration: 0.3), value: keyboardHeight)
    }
    
    // MARK: - 툴바 버튼들
    
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.white)
                
                // 참가자 프로필 이미지 (선택사항)
                if let profileImagePath = participantInfo.profileImage {
                    AuthenticatedImageView(
                        imagePath: profileImagePath,
                        contentMode: .fill
                    ) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                }
                
                Text(participantInfo.name)
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
    }
    
    private var connectionStatusButton: some View {
        Button {
            withAnimation {
                showConnectionStatus.toggle()
            }
        } label: {
            Image(systemName: viewModel.socketConnected ? "wifi" : "wifi.slash")
                .foregroundColor(viewModel.socketConnected ? .green : .red)
        }
    }
    
    // MARK: - 메시지 그룹화
    
    private var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.messages) { message in
            calendar.startOfDay(for: message.createdAt)
        }
        
        return grouped.map { date, messages in
            MessageGroup(date: date, messages: messages.sorted { $0.createdAt < $1.createdAt })
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - 스크롤 유틸리티
    
    private func scrollToBottom(scrollProxy: ScrollViewProxy, delay: TimeInterval = 0) {
        if let lastMessage = viewModel.messages.last {
            let scrollAction = {
                withAnimation(.easeOut(duration: 0.3)) {
                    scrollProxy.scrollTo(lastMessage.chatId, anchor: .bottom)
                }
            }
            
            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    scrollAction()
                }
            } else {
                scrollAction()
            }
        }
    }
    
    // MARK: - 키보드 관찰자
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                let keyboardHeightValue = keyboardFrame.height
                // SafeArea 고려
                let safeAreaBottom = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows.first?.safeAreaInsets.bottom ?? 0
                
                keyboardHeight = keyboardHeightValue - safeAreaBottom
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

// MARK: - 메시지 그룹 모델

struct MessageGroup {
    let date: Date
    let messages: [ChatMessage]
}

// MARK: - 미리보기

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ChatView(
                roomId: "sample_room",
                participantInfo: Users(
                    userId: "user1",
                    nick: "사용자닉네임",
                    name: "김철수",
                    introduction: "안녕하세요",
                    profileImage: nil,
                    hashTags: ["#사진"]
                )
            )
        }
        .preferredColorScheme(.dark)
    }
}
