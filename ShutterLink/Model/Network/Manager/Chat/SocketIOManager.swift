//
//  SocketIOManager.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import Foundation
import SocketIO
import Combine

final class SocketIOManager: ObservableObject {
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private let tokenManager: TokenManager
    
    @Published var connectionStatus: SocketConnectionStatus = .disconnected
    @Published var receivedMessage: ChatMessage?
    @Published var connectionError: String?
    
    private let messageSubject = PassthroughSubject<ChatMessage, Never>()
    var messagePublisher: AnyPublisher<ChatMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    private var currentRoomId: String?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    private var reconnectTimer: Timer?
    
    init(tokenManager: TokenManager = TokenManager.shared) {
        self.tokenManager = tokenManager
    }
    
    deinit {
        disconnect()
        reconnectTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    func connect(roomId: String) {
        print("🔵 SocketIOManager: 소켓 연결 시작 - roomId: \(roomId)")
        
        currentRoomId = roomId
        disconnect() // 기존 연결 해제
        
        guard let accessToken = tokenManager.accessToken else {
            print("❌ SocketIOManager: 액세스 토큰이 없습니다")
            connectionStatus = .error("로그인이 필요합니다")
            return
        }
        
        let socketURL = APIConstants.Socket.chatURL(roomId: roomId)
        
        guard let url = URL(string: socketURL) else {
            print("❌ SocketIOManager: 잘못된 소켓 URL - \(socketURL)")
            connectionStatus = .error("잘못된 연결 주소입니다")
            return
        }
        
        // Socket.IO 매니저 및 클라이언트 설정
        manager = SocketManager(
            socketURL: url,
            config: [
                .log(true),
                .forceWebsockets(true), // 웹소켓과 폴링 방식이 있는데 웹소켓만 강제 
                .extraHeaders([
                    APIConstants.Header.sesacKey: Key.ShutterLink.apiKey.rawValue,
                    APIConstants.Header.authorization: accessToken
                ])
            ]
        )
        
        socket = manager?.defaultSocket
        setupSocketEvents()
        
        connectionStatus = .connecting
        socket?.connect()
    }
    
    func disconnect() {
        print("🔴 SocketIOManager: 소켓 연결 해제")
        
        socket?.disconnect()
        socket?.removeAllHandlers()
        socket = nil
        manager = nil
        
        connectionStatus = .disconnected
        currentRoomId = nil
        reconnectAttempts = 0
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    func reconnect() {
        guard let roomId = currentRoomId else { return }
        
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            print("🔄 SocketIOManager: 재연결 시도 \(reconnectAttempts)/\(maxReconnectAttempts)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(reconnectAttempts)) {
                self.connect(roomId: roomId)
            }
        } else {
            print("❌ SocketIOManager: 최대 재연결 시도 횟수 초과")
            connectionStatus = .error("연결에 실패했습니다. 다시 시도해주세요.")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSocketEvents() {
        guard let socket = socket else { return }
        
        // 연결 성공
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            print("🟢 SocketIOManager: 소켓 연결 성공")
            DispatchQueue.main.async {
                self?.connectionStatus = .connected
                self?.connectionError = nil
                self?.reconnectAttempts = 0
            }
        }
        
        // 연결 해제
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("🔴 SocketIOManager: 소켓 연결 해제 - \(data)")
            DispatchQueue.main.async {
                self?.connectionStatus = .disconnected
            }
        }
        
        // 연결 에러
        socket.on(clientEvent: .error) { [weak self] data, ack in
            print("❌ SocketIOManager: 소켓 연결 에러 - \(data)")
            
            if let errorData = data.first {
                self?.handleSocketError(errorData)
            } else {
                DispatchQueue.main.async {
                    self?.connectionStatus = .error("연결 오류가 발생했습니다")
                }
            }
        }
        
        // 채팅 메시지 수신
        socket.on("chat") { [weak self] data, ack in
            print("💬 SocketIOManager: 채팅 메시지 수신 - \(data)")
            
            if let messageData = data.first {
                self?.handleReceivedMessage(messageData)
            }
        }
        
        // 연결 상태 체크
        socket.on(clientEvent: .statusChange) { [weak self] data, ack in
            print("🔄 SocketIOManager: 연결 상태 변경 - \(data)")
        }
        
        // 재연결 시도
        socket.on(clientEvent: .reconnect) { [weak self] data, ack in
            print("🔄 SocketIOManager: 재연결 성공 - \(data)")
            DispatchQueue.main.async {
                self?.connectionStatus = .connected
                self?.reconnectAttempts = 0
            }
        }
        
        // 재연결 시도 중
        socket.on(clientEvent: .reconnectAttempt) { [weak self] data, ack in
            print("🔄 SocketIOManager: 재연결 시도 중 - \(data)")
            DispatchQueue.main.async {
                self?.connectionStatus = .connecting
            }
        }
    }
    
    private func handleSocketError(_ errorData: Any) {
        print("🔍 SocketIOManager: 에러 데이터 분석 - \(errorData)")
        
        var errorMessage = "알 수 없는 오류가 발생했습니다"
        
        // Dictionary 형태의 에러 응답 처리
        if let errorDict = errorData as? [String: Any],
           let message = errorDict["message"] as? String {
            
            // 소켓 인증 에러 처리
            if let authError = SocketAuthError.allCases.first(where: { $0.rawValue == message }) {
                errorMessage = authError.localizedDescription
                handleAuthError(authError)
                return
            }
            
            // 채팅방 관련 에러 처리
            if let roomError = ChatRoomError.allCases.first(where: { $0.rawValue == message }) {
                errorMessage = roomError.localizedDescription
            } else {
                errorMessage = message
            }
        }
        // String 형태의 에러 응답 처리
        else if let errorString = errorData as? String {
            if let authError = SocketAuthError.allCases.first(where: { $0.rawValue == errorString }) {
                errorMessage = authError.localizedDescription
                handleAuthError(authError)
                return
            }
            errorMessage = errorString
        }
        
        DispatchQueue.main.async {
            self.connectionStatus = .error(errorMessage)
            self.connectionError = errorMessage
        }
    }
    
    private func handleAuthError(_ authError: SocketAuthError) {
        switch authError.action {
        case .refreshTokenAndReconnect:
            print("🔄 SocketIOManager: 토큰 갱신 후 재연결 시도")
            // TODO: 토큰 갱신 로직 구현
            DispatchQueue.main.async {
                self.connectionStatus = .error("로그인이 만료되었습니다. 다시 로그인해주세요.")
            }
            
        case .checkConfiguration:
            print("⚙️ SocketIOManager: 설정 확인 필요")
            DispatchQueue.main.async {
                self.connectionStatus = .error("앱 설정에 문제가 있습니다. 앱을 재시작해주세요.")
            }
            
        case .checkPermission:
            print("🚫 SocketIOManager: 권한 확인 필요")
            DispatchQueue.main.async {
                self.connectionStatus = .error("채팅방 접근 권한이 없습니다.")
            }
            
        case .showError(let message):
            DispatchQueue.main.async {
                self.connectionStatus = .error(message)
            }
        }
    }
    
    private func handleReceivedMessage(_ messageData: Any) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: messageData)
            let chatResponse = try JSONDecoder().decode(ChatMessageResponse.self, from: jsonData)
            
            // 현재 사용자 ID 가져오기 (실제 구현에서는 UserManager 등에서 가져와야 함)
            let currentUserId = getCurrentUserId()
            let chatMessage = chatResponse.toDomain(currentUserId: currentUserId)
            
            DispatchQueue.main.async {
                self.receivedMessage = chatMessage
                self.messageSubject.send(chatMessage)
            }
            
        } catch {
            print("❌ SocketIOManager: 메시지 파싱 실패 - \(error)")
        }
    }
    
    private func getCurrentUserId() -> String {
        // TODO: UserManager나 TokenManager에서 현재 사용자 ID 가져오기
        
        return ""
    }
}

// MARK: - Connection Management

extension SocketIOManager {
    func handleAppWillEnterForeground() {
        guard let roomId = currentRoomId,
              connectionStatus != .connected else { return }
        
        print("📱 SocketIOManager: 앱 포그라운드 진입 - 소켓 재연결")
        connect(roomId: roomId)
    }
    
    func handleAppDidEnterBackground() {
        print("📱 SocketIOManager: 앱 백그라운드 진입 - 소켓 연결 해제")
        disconnect()
    }
    
    func handleNetworkStatusChanged(isConnected: Bool) {
        if isConnected, let roomId = currentRoomId {
            print("🌐 SocketIOManager: 네트워크 복구 - 소켓 재연결")
            connect(roomId: roomId)
        } else {
            print("🌐 SocketIOManager: 네트워크 연결 끊김")
            connectionStatus = .disconnected
        }
    }
}
