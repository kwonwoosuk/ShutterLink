//
//  ChatView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import SwiftUI
import Combine

struct ChatView: View {
    let roomId: String
    let participantInfo: Users
    
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject private var router: NavigationRouter
    @State private var keyboardHeight: CGFloat = 0
    @State private var showDeleteAlert = false
    @State private var showConnectionStatus = false // 🆕 추가 - 연결 상태 표시
    
    // 스크롤 상태 추적
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isUserScrolling = false
    @State private var autoScrollTimer: Timer?
    
    init(roomId: String, participantInfo: Users) {
        self.roomId = roomId
        self.participantInfo = participantInfo
        
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
        ZStack {
            VStack(spacing: 0) {
                // 🆕 추가 - 연결 상태 바
                if showConnectionStatus {
                    connectionStatusBar
                }
                
                enhancedMessagesScrollView
                
                // 입력 영역
                chatInputSection
            }
            .background(Color.black)
            .offset(y: -keyboardHeight)
            .animation(.easeOut(duration: 0.3), value: keyboardHeight)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            // 🆕 추가 - 탭바 숨기기
            router.hideTabBar()
        }
        .onDisappear {
            // 🆕 추가 - 탭바 다시 보이기
            router.showTabBar()
        }
        .navigationTitle(participantInfo.nick)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    connectionStatusButton // 🆕 수정 - 연결 상태 버튼으로 변경
                    exitButton
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
            setupKeyboardObservers()
        }
        .onDisappear {
            viewModel.onDisappear()
            removeKeyboardObservers()
            autoScrollTimer?.invalidate()
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
        .alert("채팅방 나가기", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("나가기", role: .destructive) {
                Task {
                    await deleteRoom()
                }
            }
        } message: {
            Text("채팅방을 나가시겠습니까?\n나간 채팅방은 복구할 수 없습니다.")
        }
        .ignoresSafeArea(.keyboard, edges: .all)
    }
    
    // MARK: - 강화된 메시지 스크롤뷰
    
    private var enhancedMessagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 채팅 시작 안내
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        ChatStartNotice(participantName: participantInfo.nick)
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
                            .transition(.asymmetric(
                                insertion: .move(edge: message.isFromCurrentUser ? .trailing : .leading)
                                    .combined(with: .opacity),
                                removal: .opacity
                            ))
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
                    
                    Color.clear
                        .frame(height: 20)
                        .id("bottom_anchor")
                }
            }
            .refreshable {
                viewModel.input.refreshMessages.send()
            }
            // 다중 변화 감지로 실시간 업데이트 보장
            .onChange(of: viewModel.messages.count) { newCount in
                print("📱 ChatView: 메시지 개수 변화 - \(newCount)개")
                scheduleAutoScroll(proxy: proxy, reason: "메시지 개수 변화")
            }
            .onChange(of: viewModel.lastMessageUpdate) { _ in
                print("📱 ChatView: 마지막 메시지 업데이트 감지")
                scheduleAutoScroll(proxy: proxy, reason: "마지막 메시지 업데이트")
            }
            .onChange(of: viewModel.socketConnected) { isConnected in
                if isConnected {
                    print("✅ ChatView: 소켓 연결됨")
                    scheduleAutoScroll(proxy: proxy, reason: "소켓 연결", delay: 0.5)
                }
            }
            .onChange(of: keyboardHeight) { newHeight in
                if newHeight > 0 {
                    scheduleAutoScroll(proxy: proxy, reason: "키보드 표시", delay: 0.1)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { _ in
                        isUserScrolling = true
                        autoScrollTimer?.invalidate()
                    }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            isUserScrolling = false
                        }
                    }
            )
            .onAppear {
                scrollProxy = proxy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
        }
    }
    
    // MARK: - 자동 스크롤 관리
    
    private func scheduleAutoScroll(proxy: ScrollViewProxy, reason: String, delay: TimeInterval = 0.2) {
        guard !isUserScrolling else {
            print("⏸️ ChatView: 사용자 스크롤 중이므로 자동 스크롤 건너뜀 - \(reason)")
            return
        }
        
        autoScrollTimer?.invalidate()
        
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            print("📜 ChatView: 자동 스크롤 실행 - \(reason)")
            scrollToBottom(proxy: proxy, animated: true)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.5)) {
                proxy.scrollTo("bottom_anchor", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom_anchor", anchor: .bottom)
        }
    }
    
    // MARK: - 채팅 입력 섹션
    
    private var chatInputSection: some View {
        VStack(spacing: 0) {
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
    }
    
    // MARK: - 강화된 연결 상태 표시
    
    private var connectionStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.socketConnected ? .green : .red)
                .frame(width: 8, height: 8)
                .scaleEffect(viewModel.socketConnected ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.socketConnected)
            
            Text(viewModel.socketConnected ? "실시간 연결됨" : "연결 끊김")
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(viewModel.socketConnected ? .green : .red)
            
            Spacer()
            
            Text("메시지 \(viewModel.messages.count)개")
                .font(.pretendard(size: 10, weight: .regular))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.9))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - 툴바 버튼들
    
    private var backButton: some View {
        Button {
            router.popProfileRoute()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.white)
            }
        }
    }
    
    private var connectionStatusButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                showConnectionStatus.toggle()
            }
        } label: {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundColor(viewModel.socketConnected ? .green : .red)
        }
    }
    
    private var exitButton: some View {
        Button {
            showDeleteAlert = true
        } label: {
            Text("나가기")
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - 지원 메서드
    
    private var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.messages) { message in
            calendar.startOfDay(for: message.createdAt)
        }
        
        return grouped.map { date, messages in
            MessageGroup(date: date, messages: messages.sorted { $0.createdAt < $1.createdAt })
        }.sorted { $0.date < $1.date }
    }
    
    private func deleteRoom() async {
        do {
            // 직접 UseCase를 통해 삭제
            let localRepository = try! RealmChatRepository()
            let chatUseCase = ChatUseCaseImpl(localRepository: localRepository)
            try await chatUseCase.deleteChatRoom(roomId: roomId)
            
            await MainActor.run {
                router.popProfileRoute()
            }
        } catch {
            await MainActor.run {
                viewModel.errorMessage = "채팅방 나가기에 실패했습니다: \(error.localizedDescription)"
                viewModel.showError = true
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
                withAnimation(.easeOut(duration: 0.3)) {
                    keyboardHeight = keyboardFrame.height - getSafeAreaBottom()
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = 0
            }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func getSafeAreaBottom() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - 지원 뷰들

struct ChatStartNotice: View {
    let participantName: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("\(participantName)님과의 대화가 시작되었습니다")
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
}

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
