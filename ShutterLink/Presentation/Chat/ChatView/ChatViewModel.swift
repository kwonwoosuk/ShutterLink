//
//  ChatViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import SwiftUI
import Combine

// MARK: - 채팅 ViewModel

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
    @Published var uploadedFiles: [(String, String)] = [] // (filePath, fileName)
    @Published var socketConnected = false
    @Published var socketStatus: SocketConnectionStatus = .disconnected
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    private let roomId: String
    private let chatUseCase: ChatUseCase
    private let socketUseCase: SocketUseCase
    
    init(
        roomId: String,
        chatUseCase: ChatUseCase,
        socketUseCase: SocketUseCase
    ) {
        self.roomId = roomId
        self.chatUseCase = chatUseCase
        self.socketUseCase = socketUseCase
        
        setupBindings()
        setupObservers()
    }
    
    // MARK: - 바인딩 설정
    
    private func setupBindings() {
        // 메시지 로드
        input.loadMessages
            .sink { [weak self] in
                self?.loadChatRoom(roomId: self?.roomId ?? "")
            }
            .store(in: &cancellables)
        
        // 메시지 새로고침
        input.refreshMessages
            .sink { [weak self] in
                self?.refreshMessages()
            }
            .store(in: &cancellables)
        
        // 메시지 전송
        input.sendMessage
            .sink { [weak self] content, files in
                self?.sendMessage(content: content, files: files)
            }
            .store(in: &cancellables)
        
        // 파일 업로드
        input.uploadFiles
            .sink { [weak self] data, names in
                self?.uploadFiles(data: data, names: names)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 관찰자 설정
    
    private func setupObservers() {
        // ✅ 로컬 메시지 실시간 관찰 (DB 변경 감지)
        chatUseCase.observeMessages(roomId: roomId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                print("📱 ChatViewModel: 로컬 메시지 업데이트 - 개수: \(messages.count)")
                self?.messages = messages
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
        
        // ✅ 소켓 메시지 수신 관찰 - 실시간 UI 업데이트 강제
        socketUseCase.observeMessages()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                print("💬 ChatViewModel: 소켓 메시지 수신 - \(message.content)")
                
                // 메시지가 현재 채팅방의 메시지인지 확인
                guard message.roomId == self?.roomId else {
                    print("⚠️ ChatViewModel: 다른 채팅방의 메시지 - roomId: \(message.roomId)")
                    return
                }
                
                // ✅ 실시간 UI 업데이트를 위해 메시지 배열에 즉시 추가
                self?.addRealtimeMessage(message)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 액션 메서드
    
    private func loadChatRoom(roomId: String) {
        Task { @MainActor in
            print("🔵 ChatViewModel: 채팅방 로드 시작 - roomId: \(roomId)")
            
            isLoading = true
            errorMessage = nil
            
            do {
                // 1. 로컬 메시지 먼저 로드
                let localMessages = try await chatUseCase.getLocalMessages(roomId: roomId)
                messages = localMessages
                print("📱 ChatViewModel: 로컬 메시지 로드 완료 - 개수: \(localMessages.count)")
                
                // 2. 서버와 동기화 (최신 메시지만)
                let latestMessage = try await chatUseCase.getLatestLocalMessage(roomId: roomId)
                let syncedMessages = try await chatUseCase.syncMessages(
                    roomId: roomId,
                    since: latestMessage?.createdAt
                )
                messages = syncedMessages
                print("🔄 ChatViewModel: 메시지 동기화 완료 - 전체: \(syncedMessages.count)개")
                
                // 3. 소켓 연결
                socketUseCase.connect(roomId: roomId)
                
            } catch {
                print("❌ ChatViewModel: 채팅방 로드 실패 - \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isLoading = false
        }
    }
    
    private func refreshMessages() {
        Task { @MainActor in
            print("🔄 ChatViewModel: 메시지 새로고침 시작")
            
            do {
                let syncedMessages = try await chatUseCase.syncMessages(roomId: roomId, since: nil)
                messages = syncedMessages
                print("✅ ChatViewModel: 메시지 새로고침 완료 - 개수: \(syncedMessages.count)")
                
            } catch {
                print("❌ ChatViewModel: 메시지 새로고침 실패 - \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func sendMessage(content: String, files: [String]) {
        guard !content.isEmpty || !files.isEmpty else { return }
        
        Task { @MainActor in
            print("📤 ChatViewModel: 메시지 전송 시작 - 내용: \(content)")
            
            isSending = true
            errorMessage = nil
            
            do {
                let sentMessage = try await chatUseCase.sendMessage(
                    roomId: roomId,
                    content: content,
                    files: files
                )
                
                print("✅ ChatViewModel: 메시지 전송 완료 - chatId: \(sentMessage.chatId)")
                
                // 업로드된 파일 목록 초기화
                uploadedFiles.removeAll()
                
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
            print("📎 ChatViewModel: 파일 업로드 시작 - 개수: \(data.count)")
            
            isUploading = true
            errorMessage = nil
            
            do {
                let filePaths = try await chatUseCase.uploadFiles(roomId: roomId, files: data, fileNames: names)
                
                // 업로드된 파일을 임시 목록에 추가
                for (index, filePath) in filePaths.enumerated() {
                    let fileName = index < names.count ? names[index] : "파일_\(index + 1)"
                    uploadedFiles.append((filePath, fileName))
                }
                
                print("✅ ChatViewModel: 파일 업로드 완료 - 경로: \(filePaths)")
                
            } catch {
                print("❌ ChatViewModel: 파일 업로드 실패 - \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isUploading = false
        }
    }
    
    // ✅ 실시간 메시지 추가 메서드
    private func addRealtimeMessage(_ message: ChatMessage) {
        // 중복 메시지 방지
        guard !messages.contains(where: { $0.chatId == message.chatId }) else {
            print("⚠️ ChatViewModel: 중복 메시지 무시 - chatId: \(message.chatId)")
            return
        }
        
        // 메시지를 시간순으로 정렬하여 추가
        var updatedMessages = messages
        updatedMessages.append(message)
        updatedMessages.sort { $0.createdAt < $1.createdAt }
        
        messages = updatedMessages
        print("✅ ChatViewModel: 실시간 메시지 추가 완료 - 총 개수: \(messages.count)")
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
        // 포그라운드 진입 시 최신 메시지 동기화
        input.refreshMessages.send()
        
        // 소켓 재연결
        socketUseCase.connect(roomId: roomId)
    }
    
    func onAppDidEnterBackground() {
        print("💤 ChatViewModel: 앱 백그라운드 진입")
        // 백그라운드 진입 시 소켓 연결 해제 (선택사항)
        // socketUseCase.disconnect()
    }
    
    // MARK: - 유틸리티
    
    func removeUploadedFile(at index: Int) {
        guard index < uploadedFiles.count else { return }
        uploadedFiles.remove(at: index)
        print("🗑️ ChatViewModel: 업로드 파일 제거 - 인덱스: \(index)")
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
