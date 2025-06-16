//
//  ChatViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import SwiftUI
import Combine

final class ChatViewModel: ObservableObject {
    struct Input {
        let loadMessages = PassthroughSubject<Void, Never>()
        let refreshMessages = PassthroughSubject<Void, Never>()
        let sendMessage = PassthroughSubject<(String, [String]), Never>()
        let uploadFiles = PassthroughSubject<([Data], [String]), Never>()
    }
    
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isSending = false
    @Published var isUploading = false
    @Published var uploadedFiles: [(String, String)] = []
    @Published var socketConnected = false
    @Published var socketStatus: SocketConnectionStatus = .disconnected
    @Published var lastMessageUpdate = Date()
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    private let roomId: String
    let chatUseCase: ChatUseCase
    private let socketUseCase: SocketUseCase
    
    private var messageIds = Set<String>()
    
    init(roomId: String, chatUseCase: ChatUseCase, socketUseCase: SocketUseCase) {
        self.roomId = roomId
        self.chatUseCase = chatUseCase
        self.socketUseCase = socketUseCase
        
        setupBindings()
        setupObservers()
        
        print("🏗️ ChatViewModel 초기화 - roomId: \(roomId)")
    }
    
    // MARK: - 바인딩 설정
    
    private func setupBindings() {
        input.loadMessages
            .sink { [weak self] in
                self?.loadChatRoom()
            }
            .store(in: &cancellables)
        
        input.refreshMessages
            .sink { [weak self] in
                self?.refreshMessages()
            }
            .store(in: &cancellables)
        
        input.sendMessage
            .sink { [weak self] content, files in
                self?.sendMessage(content: content, files: files)
            }
            .store(in: &cancellables)
        
        input.uploadFiles
            .sink { [weak self] data, names in
                self?.uploadFiles(data: data, names: names)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 관찰자 설정
    
    private func setupObservers() {
        print("🔧 ChatViewModel: 관찰자 설정 시작")
        
        // 소켓 메시지 실시간 관찰
        socketUseCase.observeMessages()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                print("💬 ChatViewModel: 실시간 메시지 수신!")
                print("   - chatId: \(message.chatId)")
                print("   - 내용: \(message.content)")
                print("   - 발송자: \(message.sender.nick)")
                
                self?.handleRealtimeMessage(message)
            }
            .store(in: &cancellables)
        
        // 소켓 연결 상태 관찰
        socketUseCase.observeConnectionStatus()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                print("🔌 ChatViewModel: 소켓 상태 변경 - \(status)")
                self?.socketStatus = status
                self?.socketConnected = status.isConnected
            }
            .store(in: &cancellables)
        
        // 로컬 DB 메시지 관찰 (백업용)
        chatUseCase.observeMessages(roomId: roomId)
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] localMessages in
                print("📱 ChatViewModel: 로컬 메시지 업데이트 - 개수: \(localMessages.count)")
                self?.handleLocalMessages(localMessages)
            }
            .store(in: &cancellables)
        
        print("✅ ChatViewModel: 관찰자 설정 완료")
    }
    
    // MARK: - 실시간 메시지 처리
    
    private func handleRealtimeMessage(_ message: ChatMessage) {
        print("💬 ChatViewModel: 실시간 메시지 처리 시작")
        print("   - 메시지 ID: \(message.chatId)")
        print("   - 방 ID 일치: \(message.roomId == roomId)")
        print("   - 현재 메시지 수: \(messages.count)")
        
        guard message.roomId == roomId else {
            print("⚠️ ChatViewModel: 다른 채팅방 메시지 무시")
            return
        }
        
        guard !messageIds.contains(message.chatId) else {
            print("⚠️ ChatViewModel: 중복 메시지 무시")
            return
        }
        
        addMessageToUI(message)
        saveMessageInBackground(message)
        
        print("✅ ChatViewModel: 실시간 메시지 처리 완료")
    }
    
    private func handleLocalMessages(_ localMessages: [ChatMessage]) {
        print("📱 ChatViewModel: 로컬 메시지 업데이트 - 개수: \(localMessages.count)")
        
        let newMessages = localMessages.filter { !messageIds.contains($0.chatId) }
        
        if !newMessages.isEmpty {
            print("📱 ChatViewModel: 새로운 로컬 메시지 \(newMessages.count)개 추가")
            
            for message in newMessages {
                addMessageToUI(message)
            }
        }
    }
    
    // MARK: - UI 업데이트 메서드
    
    private func addMessageToUI(_ message: ChatMessage) {
        guard !messageIds.contains(message.chatId) else { return }
        
        messageIds.insert(message.chatId)
        messages.append(message)
        messages.sort { $0.createdAt < $1.createdAt }
        
        // UI 강제 업데이트 트리거
        lastMessageUpdate = Date()
        
        print("✅ ChatViewModel: UI 메시지 추가 완료")
        print("   - 총 메시지 수: \(messages.count)")
        print("   - 새 메시지: \(message.content)")
        print("   - 발송자: \(message.sender.nick)")
    }
    
    private func saveMessageInBackground(_ message: ChatMessage) {
        Task {
            do {
                try await chatUseCase.saveMessage(message)
                print("💾 ChatViewModel: 백그라운드 저장 완료")
            } catch {
                print("❌ ChatViewModel: 백그라운드 저장 실패 - \(error)")
            }
        }
    }
    
    // MARK: - 채팅방 로드 및 관리
    
    private func loadChatRoom() {
        Task { @MainActor in
            print("🔵 ChatViewModel: 채팅방 로드 시작")
            
            isLoading = true
            errorMessage = nil
            messageIds.removeAll()
            
            do {
                // 로컬 메시지 먼저 로드
                let localMessages = try await chatUseCase.getLocalMessages(roomId: roomId)
                updateMessagesInitially(localMessages)
                print("📱 ChatViewModel: 로컬 메시지 로드 완료 - 개수: \(localMessages.count)")
                
                // 서버와 동기화
                let latestMessage = try await chatUseCase.getLatestLocalMessage(roomId: roomId)
                let syncedMessages = try await chatUseCase.syncMessages(
                    roomId: roomId,
                    since: latestMessage?.createdAt
                )
                updateMessagesInitially(syncedMessages)
                print("🔄 ChatViewModel: 메시지 동기화 완료 - 전체: \(syncedMessages.count)개")
                
                // 소켓 연결 (지연 추가)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔌 ChatViewModel: 소켓 연결 시도")
                    self.socketUseCase.connect(roomId: self.roomId)
                }
                
            } catch {
                print("❌ ChatViewModel: 채팅방 로드 실패 - \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isLoading = false
        }
    }
    
    private func updateMessagesInitially(_ newMessages: [ChatMessage]) {
        let uniqueMessages = removeDuplicateMessages(newMessages)
        messages = uniqueMessages
        messageIds = Set(uniqueMessages.map { $0.chatId })
        
        print("📊 ChatViewModel: 초기 메시지 설정 완료 - \(messages.count)개")
    }
    
    private func sendMessage(content: String, files: [String]) {
        guard !content.isEmpty || !files.isEmpty else { return }
        
        Task { @MainActor in
            print("📤 ChatViewModel: 메시지 전송 시작")
            
            isSending = true
            errorMessage = nil
            
            do {
                let sentMessage = try await chatUseCase.sendMessage(
                    roomId: roomId,
                    content: content,
                    files: files
                )
                
                print("✅ ChatViewModel: 메시지 전송 완료")
                uploadedFiles.removeAll()
                addMessageToUI(sentMessage)
                
            } catch {
                print("❌ ChatViewModel: 메시지 전송 실패 - \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isSending = false
        }
    }
    
    private func refreshMessages() {
        Task { @MainActor in
            print("🔄 ChatViewModel: 메시지 새로고침 시작")
            
            do {
                let syncedMessages = try await chatUseCase.syncMessages(roomId: roomId, since: nil)
                updateMessagesInitially(syncedMessages)
                print("✅ ChatViewModel: 메시지 새로고침 완료")
                
            } catch {
                print("❌ ChatViewModel: 메시지 새로고침 실패 - \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func uploadFiles(data: [Data], names: [String]) {
        Task { @MainActor in
            print("📎 ChatViewModel: 파일 업로드 시작")
            
            isUploading = true
            errorMessage = nil
            
            do {
                let filePaths = try await chatUseCase.uploadFiles(roomId: roomId, files: data, fileNames: names)
                
                for (index, filePath) in filePaths.enumerated() {
                    let fileName = index < names.count ? names[index] : "파일_\(index + 1)"
                    uploadedFiles.append((filePath, fileName))
                }
                
                print("✅ ChatViewModel: 파일 업로드 완료")
                
            } catch {
                print("❌ ChatViewModel: 파일 업로드 실패 - \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isUploading = false
        }
    }
    
    private func removeDuplicateMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        var uniqueMessages: [ChatMessage] = []
        var seenChatIds: Set<String> = []
        
        for message in messages.sorted(by: { $0.createdAt < $1.createdAt }) {
            if !seenChatIds.contains(message.chatId) {
                uniqueMessages.append(message)
                seenChatIds.insert(message.chatId)
            }
        }
        
        return uniqueMessages
    }
    
    // MARK: - 생명주기 메서드
    
    func onAppear() {
        print("👀 ChatViewModel: 채팅 화면 나타남")
        input.loadMessages.send()
    }
    
    func onDisappear() {
        print("👋 ChatViewModel: 채팅 화면 사라짐")
        socketUseCase.disconnect()
    }
    
    func onAppWillEnterForeground() {
        print("🔄 ChatViewModel: 앱 포그라운드 진입")
        input.refreshMessages.send()
        socketUseCase.connect(roomId: roomId)
    }
    
    func onAppDidEnterBackground() {
        print("💤 ChatViewModel: 앱 백그라운드 진입")
    }
    
    // MARK: - 유틸리티
    
    func removeUploadedFile(at index: Int) {
        guard index < uploadedFiles.count else { return }
        uploadedFiles.remove(at: index)
    }
    
    var canSendMessage: Bool {
        return !isSending && !isUploading
    }
    
    var connectionStatusText: String {
        switch socketStatus {
        case .connected:
            return "연결됨"
        case .connecting:
            return "연결 중..."
        case .disconnected:
            return "연결 끊김"
        case .error:
            return "연결 오류"
        }
    }
    
    var connectionStatusColor: Color {
        switch socketStatus {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
}
