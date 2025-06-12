//
//  SocketUseCase.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import Foundation
import Combine

// MARK: - Socket Connection Status

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

// MARK: - Socket UseCase Protocol

protocol SocketUseCase {
    func connect(roomId: String)
    func disconnect()
    func observeConnectionStatus() -> AnyPublisher<SocketConnectionStatus, Never>
    func observeMessages() -> AnyPublisher<ChatMessage, Never>
}

// MARK: - Socket UseCase Implementation

final class SocketUseCaseImpl: SocketUseCase {
    private let socketManager: SocketIOManager
    private let chatUseCase: ChatUseCase
    private var cancellables = Set<AnyCancellable>()
    
    // ✅ 실시간 메시지 스트림
    private let realtimeMessageSubject = PassthroughSubject<ChatMessage, Never>()
    
    init(
        socketManager: SocketIOManager = SocketIOManager(),
        chatUseCase: ChatUseCase
    ) {
        self.socketManager = socketManager
        self.chatUseCase = chatUseCase
        
        // 소켓 메시지 수신 처리 설정
        setupMessageHandling()
    }
    
    func connect(roomId: String) {
        print("🔵 SocketUseCase: 소켓 연결 시작 - roomId: \(roomId)")
        socketManager.connect(roomId: roomId)
    }
    
    func disconnect() {
        print("🔵 SocketUseCase: 소켓 연결 해제")
        socketManager.disconnect()
    }
    
    func observeConnectionStatus() -> AnyPublisher<SocketConnectionStatus, Never> {
        return socketManager.$connectionStatus.eraseToAnyPublisher()
    }
    
    func observeMessages() -> AnyPublisher<ChatMessage, Never> {
        return realtimeMessageSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 메시지 처리 설정
    
    private func setupMessageHandling() {
        // ✅ 소켓으로 받은 메시지 처리
        socketManager.messagePublisher
            .sink { [weak self] message in
                self?.handleReceivedMessage(message)
            }
            .store(in: &cancellables)
    }
    
    // ✅ 수신 메시지 처리 (로컬 저장 + UI 알림)
    private func handleReceivedMessage(_ message: ChatMessage) {
        print("📨 SocketUseCase: 메시지 수신 - chatId: \(message.chatId), 내용: \(message.content)")
        
        Task {
            do {
                // 1. 로컬 DB에 저장
                try await chatUseCase.saveMessage(message)
                print("✅ SocketUseCase: 수신 메시지 로컬 저장 완료 - chatId: \(message.chatId)")
                
                // 2. UI 업데이트를 위해 실시간 스트림에 전송
                await MainActor.run {
                    realtimeMessageSubject.send(message)
                }
                print("✅ SocketUseCase: 실시간 UI 업데이트 신호 전송 완료")
                
            } catch {
                print("❌ SocketUseCase: 수신 메시지 처리 실패 - \(error)")
                
                // 저장 실패해도 UI 업데이트는 시도 (임시 메시지로 표시)
                await MainActor.run {
                    realtimeMessageSubject.send(message)
                }
            }
        }
    }
}

// MARK: - TokenManager Extension (임시)
extension TokenManager {
    func getCurrentUserId() -> String? {
        // TODO: 실제 구현에서는 JWT 토큰을 디코딩하여 사용자 ID 추출
        // 또는 별도의 사용자 정보 저장소에서 가져오기
        return nil
    }
}
