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
    
    // ✅ Equatable 구현
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
    
    // ✅ 실시간 메시지 스트림 - PassthroughSubject 사용
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
        // ✅ 소켓으로 받은 메시지 처리 - 이중 스트림 방식
        socketManager.messagePublisher
            .sink { [weak self] message in
                print("📨 SocketUseCase: 메시지 수신 - chatId: \(message.chatId), 내용: \(message.content)")
                self?.handleReceivedMessage(message)
            }
            .store(in: &cancellables)
    }
    
    // ✅ 수신 메시지 처리 (로컬 저장 + 즉시 UI 알림)
    private func handleReceivedMessage(_ message: ChatMessage) {
        // 1. ✅ 먼저 UI에 즉시 반영 (가장 빠른 업데이트)
        Task { @MainActor in
            print("⚡ SocketUseCase: 즉시 UI 업데이트 - chatId: \(message.chatId)")
            realtimeMessageSubject.send(message)
        }
        
        // 2. ✅ 백그라운드에서 로컬 저장 (실패해도 UI는 이미 업데이트됨)
        Task {
            do {
                try await chatUseCase.saveMessage(message)
                print("✅ SocketUseCase: 수신 메시지 로컬 저장 완료 - chatId: \(message.chatId)")
                
            } catch {
                print("❌ SocketUseCase: 수신 메시지 로컬 저장 실패 - \(error)")
                // 저장 실패해도 UI는 이미 업데이트되었으므로 사용자는 메시지를 볼 수 있음
                // 필요시 재시도 로직 추가 가능
                await scheduleRetryMessageSave(message)
            }
        }
    }
    
    // ✅ 메시지 저장 재시도 스케줄링
    private func scheduleRetryMessageSave(_ message: ChatMessage) async {
        // 3초 후 재시도
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        
        do {
            try await chatUseCase.saveMessage(message)
            print("✅ SocketUseCase: 메시지 저장 재시도 성공 - chatId: \(message.chatId)")
        } catch {
            print("❌ SocketUseCase: 메시지 저장 재시도 실패 - chatId: \(message.chatId), 에러: \(error)")
            // 최종 실패 시 로그만 남기고 넘어감 (UI는 이미 업데이트됨)
        }
    }
}
