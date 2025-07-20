//
//  SocketUseCase.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import Foundation
import Combine


enum SocketConnectionStatus: Equatable {
    case connecting
    case connected
    case disconnected
    case error(String)
    
    static func == (lhs: SocketConnectionStatus, rhs: SocketConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.connecting, .connecting),
             (.connected, .connected),
             (.disconnected, .disconnected):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    var isConnected: Bool {
        switch self {
        case .connected:
            return true
        default:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .connecting:
            return "연결 중..."
        case .connected:
            return "연결됨"
        case .disconnected:
            return "연결 끊김"
        case .error(let message):
            return "오류: \(message)"
        }
    }
}

protocol SocketUseCase {
    func connect(roomId: String)
    func disconnect()
    func observeConnectionStatus() -> AnyPublisher<SocketConnectionStatus, Never>
    func observeMessages() -> AnyPublisher<ChatMessage, Never>
}

final class SocketUseCaseImpl: SocketUseCase {
    private let socketManager: SocketIOManager
    private let chatUseCase: ChatUseCase
    private var cancellables = Set<AnyCancellable>()
    
    // ✅ 강화된 실시간 메시지 스트림
    private let realtimeMessageSubject = PassthroughSubject<ChatMessage, Never>()
    
    // ✅ 메시지 처리 상태 추적
    private var isProcessingMessage = false
    private let messageProcessingQueue = DispatchQueue(label: "com.shutterlink.socket.processing", qos: .userInitiated)
    
    init(
        socketManager: SocketIOManager = SocketIOManager(),
        chatUseCase: ChatUseCase
    ) {
        self.socketManager = socketManager
        self.chatUseCase = chatUseCase
        
        print("🏗️ SocketUseCase 초기화")
        setupMessageHandling()
    }
    
    func connect(roomId: String) {
        print("🔵 SocketUseCase: 소켓 연결 시작 - roomId: \(roomId)")
        socketManager.connect(roomId: roomId)
    }
    
    func disconnect() {
        print("🔴 SocketUseCase: 소켓 연결 해제")
        socketManager.disconnect()
    }
    
    func observeConnectionStatus() -> AnyPublisher<SocketConnectionStatus, Never> {
        return socketManager.$connectionStatus.eraseToAnyPublisher()
    }
    
    func observeMessages() -> AnyPublisher<ChatMessage, Never> {
        return realtimeMessageSubject.eraseToAnyPublisher()
    }
    
    
    private func setupMessageHandling() {
        print("🔧 SocketUseCase: 메시지 처리 설정 시작")
        
        // ✅ 소켓 메시지 수신 처리
        socketManager.messagePublisher
            .receive(on: messageProcessingQueue)
            .sink { [weak self] message in
                self?.handleIncomingMessage(message)
            }
            .store(in: &cancellables)
        
        print("✅ SocketUseCase: 메시지 처리 설정 완료")
    }
    
    private func handleIncomingMessage(_ message: ChatMessage) {
        print("📨 SocketUseCase: 메시지 수신 처리 시작")
        print("   - chatId: \(message.chatId)")
        print("   - 발송자: \(message.sender.nick)")
        print("   - 내용: \(message.content)")
        print("   - 현재 사용자 메시지: \(message.isFromCurrentUser)")
        print("   - 파일 개수: \(message.files.count)")
        
        // ✅ 1단계: 즉시 UI 업데이트 (최우선)
        immediateUIUpdate(message)
        
        // ✅ 2단계: 백그라운드 로컬 저장 (독립적)
        backgroundSave(message)
    }
    
    // ✅ 1단계: 즉시 UI 업데이트
    private func immediateUIUpdate(_ message: ChatMessage) {
        DispatchQueue.main.async { [weak self] in
            print("⚡ SocketUseCase: 즉시 UI 업데이트 - chatId: \(message.chatId)")
            self?.realtimeMessageSubject.send(message)
        }
    }
    
    // ✅ 2단계: 백그라운드 로컬 저장
    private func backgroundSave(_ message: ChatMessage) {
        Task {
            await saveMessageWithRetry(message, maxRetries: 3)
        }
    }
    
    // ✅ 재시도 로직을 포함한 메시지 저장
    private func saveMessageWithRetry(_ message: ChatMessage, maxRetries: Int) async {
        for attempt in 1...maxRetries {
            do {
                try await chatUseCase.saveMessage(message)
                print("✅ SocketUseCase: 메시지 저장 성공 (시도 \(attempt)) - chatId: \(message.chatId)")
                return
                
            } catch {
                print("❌ SocketUseCase: 메시지 저장 실패 (시도 \(attempt)/\(maxRetries)) - \(error)")
                
                if attempt == maxRetries {
                    print("💥 SocketUseCase: 메시지 저장 최종 실패 - chatId: \(message.chatId)")
                    await handleSaveFailure(message, error: error)
                } else {
                    // 지수 백오프로 재시도 지연
                    let delay = pow(2.0, Double(attempt - 1))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
    }
    
    // ✅ 저장 실패 처리
    private func handleSaveFailure(_ message: ChatMessage, error: Error) async {
        print("💥 SocketUseCase: 메시지 저장 실패 처리")
    
        await notifyPersistenceFailure(message, error: error)
    }
    
    // ✅ 저장 실패 알림
    private func notifyPersistenceFailure(_ message: ChatMessage, error: Error) async {
        print("🔔 SocketUseCase: 저장 실패 알림 - chatId: \(message.chatId)")
        
        // 예시: 연결 상태 확인 후 재시도 스케줄링
        await scheduleRetryWhenNetworkAvailable(message)
    }
    
    // ✅ 네트워크 복구 시 재시도 스케줄링
    private func scheduleRetryWhenNetworkAvailable(_ message: ChatMessage) async {
        
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10초
        
        do {
            try await chatUseCase.saveMessage(message)
            print("🔄 SocketUseCase: 지연된 메시지 저장 성공 - chatId: \(message.chatId)")
        } catch {
            print("🔄 SocketUseCase: 지연된 메시지 저장도 실패 - chatId: \(message.chatId)")
        }
    }
}

// MARK: - ✅ 메시지 처리 상태 관리

extension SocketUseCaseImpl {
    
    // ✅ 현재 처리 중인 메시지 수 추적
    private func trackMessageProcessing(_ action: String, messageId: String) {
        print("📊 SocketUseCase: 메시지 처리 추적 - \(action) - \(messageId)")
    }
    
    // ✅ 메시지 처리 성능 모니터링 
    private func measureProcessingTime<T>(_ operation: () async throws -> T, label: String) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        print("⏱️ SocketUseCase: \(label) 처리 시간: \(String(format: "%.3f", timeElapsed))초")
        
        return result
    }
}

// MARK: - ✅ 생명주기 및 앱 상태 관리

extension SocketUseCaseImpl {
    
    func handleAppWillEnterForeground() {
        print("📱 SocketUseCase: 앱 포그라운드 진입")
        socketManager.handleAppWillEnterForeground()
    }
    
    func handleAppDidEnterBackground() {
        print("📱 SocketUseCase: 앱 백그라운드 진입")
        socketManager.handleAppDidEnterBackground()
    }
    
    func handleNetworkStatusChanged(isConnected: Bool) {
        print("🌐 SocketUseCase: 네트워크 상태 변경 - 연결: \(isConnected)")
        socketManager.handleNetworkStatusChanged(isConnected: isConnected)
    }
}

// MARK: - ✅ 디버깅 및 모니터링

extension SocketUseCaseImpl {
    
    func getCurrentConnectionInfo() -> String {
        let status = socketManager.connectionStatus
        return """
        📊 SocketUseCase 연결 정보:
        - 상태: \(status.description)
        - 연결됨: \(status.isConnected)
        - 메시지 처리 중: \(isProcessingMessage)
        """
    }
    
    func printDebugInfo() {
        print(getCurrentConnectionInfo())
    }
}
