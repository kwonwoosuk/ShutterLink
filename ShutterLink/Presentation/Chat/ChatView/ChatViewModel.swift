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
    @Published private var syncState: SyncState = .notStarted
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    private let roomId: String
    let chatUseCase: ChatUseCase
    private let socketUseCase: SocketUseCase
    
    private var messageIds = Set<String>()

    private var syncStartTime: Date?
    private var pendingMessages: [ChatMessage] = []
    private let syncQueue = DispatchQueue(label: "chat.sync", qos: .userInitiated)
    
    enum SyncState {
        case notStarted
        case syncing
        case completed
        case failed
    }
    
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
                Task { @MainActor in
                    await self?.loadChatRoom()
                }
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
        
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            switch self.syncState {
            case .syncing:
                self.handleMessageDuringSync(message)
            case .completed:
                self.handleMessageAfterSync(message)
            case .notStarted, .failed:
                self.handleMessageWithFallback(message)
            }
        }
    }

    private func handleMessageDuringSync(_ message: ChatMessage) {
        guard let syncStartTime = syncStartTime else {
            handleMessageWithFallback(message)
            return
        }
        
        if message.createdAt >= syncStartTime {
            // 동기화 시작 이후 메시지는 펜딩
            pendingMessages.append(message)
            print("⏳ 펜딩 저장: \(message.chatId) - \(message.createdAt)")
        } else {
            // 과거 메시지는 동기화에서 처리될 것이므로 무시
            print("🚫 과거 메시지 무시: \(message.chatId) - \(message.createdAt)")
        }
    }
    
    // ✅ 동기화 완료 후 메시지 처리
    private func handleMessageAfterSync(_ message: ChatMessage) {
        DispatchQueue.main.async {
            self.addMessageToUI(message)
        }
    }
    
    // ✅ 폴백 처리 (즉시 표시)
    private func handleMessageWithFallback(_ message: ChatMessage) {
        DispatchQueue.main.async {
            self.addMessageToUI(message)
        }
    }
    
    // ✅ 펜딩 메시지 처리
    private func processPendingMessages() async {
        guard !pendingMessages.isEmpty else {
            print("📝 ChatViewModel: 처리할 펜딩 메시지 없음")
            return
        }
        
        await syncQueue.sync {
            let sortedPending = pendingMessages.sorted { $0.createdAt < $1.createdAt }
            print("📝 ChatViewModel: 펜딩 메시지 처리 시작 - \(sortedPending.count)개")
            
            for message in sortedPending {
                // 중복 확인 후 추가
                if !messageIds.contains(message.chatId) {
                    DispatchQueue.main.async {
                        self.addMessageToUI(message)
                    }
                } else {
                    print("🚫 펜딩 메시지 중복 무시: \(message.chatId)")
                }
            }
            
            pendingMessages.removeAll()
            print("✅ 펜딩 메시지 처리 완료: \(sortedPending.count)개")
        }
    }
    
    private func handleLocalMessages(_ localMessages: [ChatMessage]) {
        // ✅ 동기화 중에는 로컬 메시지 업데이트 지연
        guard syncState == .completed || syncState == .failed else {
            print("⏳ ChatViewModel: 동기화 중이므로 로컬 메시지 업데이트 지연")
            return
        }
        
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
        
        // ✅ 타임스탬프 기준으로 올바른 위치에 삽입
        let insertIndex = messages.firstIndex { existingMessage in
            existingMessage.createdAt > message.createdAt
        } ?? messages.endIndex
        
        messages.insert(message, at: insertIndex)
        
        // UI 강제 업데이트 트리거
        lastMessageUpdate = Date()
        
        print("✅ ChatViewModel: UI 메시지 추가 완료")
        print("   - 삽입 위치: \(insertIndex)")
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
    
    @MainActor
    private func loadChatRoom() async {
        print("🔵 ChatViewModel: 채팅방 로드 시작")
        isLoading = true
        errorMessage = nil
        messageIds.removeAll()
        
        // ✅ 동기화 시작 시간 기록
        syncStartTime = Date()
        syncState = .syncing
        
        do {
            // ✅ 병렬 실행: 소켓 연결 + 데이터 동기화
            async let socketConnection: Void = connectSocketAsync()
            async let dataSync: Void = performDataSyncAsync()
            
            // 둘 다 완료 대기
            let _ = try await (socketConnection, dataSync)
            
            // ✅ 동기화 완료 후 펜딩 메시지 처리
            syncState = .completed
            await processPendingMessages()
            
            print("✅ ChatViewModel: 채팅방 로드 완료")
            
        } catch {
            syncState = .failed
            print("❌ ChatViewModel: 채팅방 로드 실패 - \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        
        isLoading = false
    }
    
    private func connectSocketAsync() async {
        print("🔌 ChatViewModel: 소켓 연결 시도")
        socketUseCase.connect(roomId: roomId)
    }
    
    private func performDataSyncAsync() async throws {
        // 로컬 메시지 먼저 로드
        let localMessages = try await chatUseCase.getLocalMessages(roomId: roomId)
        await MainActor.run {
            updateMessagesInitially(localMessages)
        }
        print("📱 ChatViewModel: 로컬 메시지 로드 완료 - 개수: \(localMessages.count)")
        
        // 서버와 동기화
        let latestMessage = try await chatUseCase.getLatestLocalMessage(roomId: roomId)
        let syncedMessages = try await chatUseCase.syncMessages(
            roomId: roomId,
            since: latestMessage?.createdAt
        )
        await MainActor.run {
            updateMessagesInitially(syncedMessages)
        }
        print("🔄 ChatViewModel: 메시지 동기화 완료 - 전체: \(syncedMessages.count)개")
    }
    
    private func updateMessagesInitially(_ newMessages: [ChatMessage]) {
        let uniqueMessages = removeDuplicateMessages(newMessages)
        messages = uniqueMessages.sorted { $0.createdAt < $1.createdAt }
        messageIds = Set(uniqueMessages.map { $0.chatId })
        
        print("📊 ChatViewModel: 초기 메시지 설정 완료 - \(messages.count)개")
    }
    
    private func removeDuplicateMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        var seen = Set<String>()
        return messages.filter { message in
            if seen.contains(message.chatId) {
                return false
            }
            seen.insert(message.chatId)
            return true
        }
    }
    
    // MARK: - 메시지 전송 및 파일 업로드
    
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
    
    private func sendMessage(content: String, files: [String]) {
        Task { @MainActor in
            print("📤 ChatViewModel: 메시지 전송 시작")
            print("   - 내용: \(content)")
            print("   - 파일 수: \(files.count)")
            
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
    
    private func uploadFiles(data: [Data], names: [String]) {
        Task { @MainActor in
            print("📎 ChatViewModel: 파일 업로드 시작")
            
            isUploading = true
            errorMessage = nil
            
            do {
                let filePaths = try await chatUseCase.uploadFiles(roomId: roomId, files: data, fileNames: names)
                
                for (index, filePath) in filePaths.enumerated() {
                    let fileName = index < names.count ? names[index] : "파일\(index + 1)"
                    uploadedFiles.append((fileName, filePath))
                }
                
                print("✅ ChatViewModel: 파일 업로드 완료 - \(filePaths.count)개")
                
            } catch {
                print("❌ ChatViewModel: 파일 업로드 실패 - \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isUploading = false
        }
    }
    
    // MARK: - 유틸리티 메서드
    
    var canSendMessage: Bool {
        return !isSending && !isUploading
    }
    
    func removeUploadedFile(at index: Int) {
        guard index < uploadedFiles.count else { return }
        uploadedFiles.remove(at: index)
        print("🗑️ ChatViewModel: 업로드된 파일 제거 - index: \(index)")
    }
    
    func onDisappear() {
        print("👋 ChatViewModel: onDisappear 호출")
        socketUseCase.disconnect()
    }
}
