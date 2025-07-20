//
//  SocketIOManager.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import Foundation
import SocketIO
import Combine

enum SocketErrorType {
    case authenticationFailed
    case invalidAccessToken
    case expiredAccessToken
    case checkConfiguration
    case checkPermission
    case showError(String)
}

final class SocketIOManager: ObservableObject {
    private var socket: SocketIOClient?
    private var manager: SocketManager?
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
    
    private var processedMessageIds = Set<String>()
    private let messageQueue = DispatchQueue(label: "com.shutterlink.socket.message", qos: .userInitiated)
    
    init(tokenManager: TokenManager = TokenManager.shared) {
        self.tokenManager = tokenManager
        print("🏗️ SocketIOManager 초기화 완료")
    }
    
    deinit {
        disconnect()
        reconnectTimer?.invalidate()
        print("💀 SocketIOManager 해제")
    }
    
    func connect(roomId: String) {
        print("🔵 SocketIOManager: 소켓 연결 시작 - roomId: \(roomId)")
        
        currentRoomId = roomId
        disconnect()
        
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
        
        processedMessageIds.removeAll()
        
        manager = SocketManager(
            socketURL: url,
            config: [
                .log(true),
                .forceWebsockets(true),
                .reconnects(true),
                .reconnectAttempts(5),
                .reconnectWait(1),
                .extraHeaders([
                    APIConstants.Header.sesacKey: Key.ShutterLink.apiKey.rawValue,
                    APIConstants.Header.authorization: accessToken
                ])
            ]
        )
        
         socket = manager?.socket(forNamespace: "/chats-\(roomId)")
         print("🔧 SocketIOManager: 네임스페이스 설정 - /chats-\(roomId)")
         
         setupSocketEvents()
         connectionStatus = .connecting
         socket?.connect()
         
         print("🔌 SocketIOManager: 연결 시도 - URL: \(socketURL)")
         print("🔌 SocketIOManager: 네임스페이스: /chats-\(roomId)")
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
        processedMessageIds.removeAll()
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

    private func setupSocketEvents() {
        guard let socket = socket else { return }
        
        print("🔧 SocketIOManager: 이벤트 핸들러 설정 시작")
        
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            print("🟢 SocketIOManager: 소켓 연결 성공")
            print("🟢 SocketIOManager: 연결 데이터: \(data)")
            
            DispatchQueue.main.async {
                self?.connectionStatus = .connected
                self?.connectionError = nil
                self?.reconnectAttempts = 0
            }
            
            if let roomId = self?.currentRoomId {
                self?.joinChatRoom(roomId)
            }
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("🔴 SocketIOManager: 소켓 연결 해제")
            print("🔴 SocketIOManager: 해제 데이터: \(data)")
            DispatchQueue.main.async {
                self?.connectionStatus = .disconnected
            }
        }
        
        socket.on(clientEvent: .error) { [weak self] data, ack in
            print("❌ SocketIOManager: 소켓 연결 에러")
            print("❌ SocketIOManager: 에러 데이터: \(data)")
            
            if let errorData = data.first {
                self?.handleSocketError(errorData)
            } else {
                DispatchQueue.main.async {
                    self?.connectionStatus = .error("연결 오류가 발생했습니다")
                }
            }
        }
        
        setupMessageEventHandlers(socket)
        
        socket.onAny { [weak self] event in
            print("🎯 SocketIOManager: 수신된 이벤트 - \(event.event)")
            print("🎯 SocketIOManager: 이벤트 데이터: \(event.items)")
            
            if self?.isMessageEvent(event.event) == true && !event.items!.isEmpty {
                print("💬 SocketIOManager: 메시지 이벤트 감지 - \(event.event)")
                self?.handleReceivedMessage(event.items?.first)
            }
        }
        
        print("✅ SocketIOManager: 이벤트 핸들러 설정 완료")
    }
    

    private func setupMessageEventHandlers(_ socket: SocketIOClient) {
            socket.on("chat") { [weak self] data, ack in
                print("💬 SocketIOManager: 데이터 개수: \(data.count)")
                print("💬 SocketIOManager: 데이터 내용: \(data)")
                
                if let messageData = data.first {
                    self?.handleReceivedMessage(messageData)
                } else {
                    print("이벤트 데이터가 비어있음")
                }
            }
        
    }

    private func isMessageEvent(_ eventName: String) -> Bool {
        let messageKeywords = ["chat", "message", "msg"]
        return messageKeywords.contains { eventName.lowercased().contains($0) }
    }
    
    private func joinChatRoom(_ roomId: String) {
        guard let socket = socket else { return }
        
        print("🚪 SocketIOManager: 채팅방 참여 요청 - roomId: \(roomId)")
        
        socket.emit("join", roomId)
        socket.emit("joinRoom", roomId)
        socket.emit("join_room", roomId)
        
        socket.on("joined") { data, ack in
            print("✅ SocketIOManager: 방 참여 성공 - \(data)")
        }
        
        socket.on("joinedRoom") { data, ack in
            print("✅ SocketIOManager: 방 참여 성공 - \(data)")
        }
        
        socket.on("joined_room") { data, ack in
            print("✅ SocketIOManager: 방 참여 성공 - \(data)")
        }
    }
    
    private func handleReceivedMessage(_ messageData: Any?) {
        guard let messageData = messageData else {
            print("⚠️ SocketIOManager: 메시지 데이터가 nil")
            return
        }
        
        print("🔍 SocketIOManager: 메시지 처리 시작")
        print("🔍 SocketIOManager: 데이터 타입: \(type(of: messageData))")
        
        messageQueue.async { [weak self] in
            self?.processMessage(messageData)
        }
    }
    
    private func processMessage(_ messageData: Any) {
        do {
            print("🔄 SocketIOManager: 메시지 파싱 시작")
            
            let jsonData: Data
            
            if let dictData = messageData as? [String: Any] {
                jsonData = try JSONSerialization.data(withJSONObject: dictData)
                print("📋 SocketIOManager: Dictionary 데이터 처리")
            } else if let stringData = messageData as? String {
                jsonData = stringData.data(using: .utf8) ?? Data()
                print("📋 SocketIOManager: String 데이터 처리")
            } else if let dataObject = messageData as? Data {
                jsonData = dataObject
                print("📋 SocketIOManager: Data 객체 처리")
            } else {
                jsonData = try JSONSerialization.data(withJSONObject: messageData)
                print("📋 SocketIOManager: 기타 형태 JSON 직렬화")
            }
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📋 SocketIOManager: 파싱할 JSON:")
                print(jsonString)
            }
            
            let decoder = JSONDecoder()
            let chatResponse = try decoder.decode(ChatMessageResponse.self, from: jsonData)
            
            print("✅ SocketIOManager: 메시지 디코딩 성공")
            print("   - chatId: \(chatResponse.chatId)")
            print("   - roomId: \(chatResponse.roomId)")
            print("   - content: \(chatResponse.content)")
            print("   - sender: \(chatResponse.sender.userId)")
            
            guard !processedMessageIds.contains(chatResponse.chatId) else {
                print("⚠️ SocketIOManager: 중복 메시지 무시 - chatId: \(chatResponse.chatId)")
                return
            }
            
            processedMessageIds.insert(chatResponse.chatId)
            
            let currentUserId = getCurrentUserId()
            guard !currentUserId.isEmpty else {
                print("❌ SocketIOManager: 현재 사용자 ID가 없습니다")
                return
            }
            
            print("🔍 SocketIOManager: 사용자 확인")
            print("   - currentUserId: '\(currentUserId)'")
            print("   - senderUserId: '\(chatResponse.sender.userId)'")
            
            let chatMessage = chatResponse.toDomain(currentUserId: currentUserId)
            
            print("✅ SocketIOManager: Domain 변환 완료")
            print("   - isFromCurrentUser: \(chatMessage.isFromCurrentUser)")
            print("   - 메시지 내용: \(chatMessage.content)")
            
            DispatchQueue.main.async { [weak self] in
                print("📤 SocketIOManager: 메시지 발행 시작")
                
                self?.receivedMessage = chatMessage
                self?.messageSubject.send(chatMessage)
                
                print("✅ SocketIOManager: 메시지 발행 완료 - chatId: \(chatMessage.chatId)")
            }
            
        } catch {
            print("❌ SocketIOManager: 메시지 처리 실패 - \(error)")
            print("📋 SocketIOManager: 원본 데이터 타입: \(type(of: messageData))")
            print("📋 SocketIOManager: 원본 데이터: \(messageData)")
            
            if let decodingError = error as? DecodingError {
                print("📋 SocketIOManager: 디코딩 에러 상세:")
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   - 키 없음: \(key), 경로: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("   - 타입 불일치: \(type), 경로: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   - 값 없음: \(type), 경로: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("   - 데이터 손상: \(context.debugDescription)")
                @unknown default:
                    print("   - 알 수 없는 디코딩 에러")
                }
            }
            
            do {
                let debugData = try JSONSerialization.data(withJSONObject: messageData, options: .prettyPrinted)
                if let debugString = String(data: debugData, encoding: .utf8) {
                    print("📋 SocketIOManager: 디버그 JSON:")
                    print(debugString)
                }
            } catch {
                print("📋 SocketIOManager: JSON 변환도 실패 - \(error)")
            }
        }
    }
    
    private func handleSocketError(_ errorData: Any) {
        print("🔍 SocketIOManager: 에러 데이터 분석 - \(errorData)")
        
        var errorMessage = "알 수 없는 오류가 발생했습니다"
        
        if let errorDict = errorData as? [String: Any],
           let message = errorDict["message"] as? String {
            errorMessage = message
        } else if let errorString = errorData as? String {
            errorMessage = errorString
        }
        
        let errorType = classifySocketError(errorMessage)
        handleSocketErrorType(errorType)
    }
    
    private func classifySocketError(_ message: String) -> SocketErrorType {
        switch message {
        case let msg where msg.contains("sesac_memolease"):
            return .authenticationFailed
        case let msg where msg.contains("만료"):
            return .expiredAccessToken
        case let msg where msg.contains("인증할 수 없는"):
            return .invalidAccessToken
        case "Forbidden":
            return .checkPermission
        case "Invalid namespace":
            return .checkConfiguration
        default:
            return .showError(message)
        }
    }
    
    private func handleSocketErrorType(_ errorType: SocketErrorType) {
        switch errorType {
        case .authenticationFailed:
            print("🔑 SocketIOManager: 인증 실패")
            DispatchQueue.main.async {
                self.connectionStatus = .error("인증에 실패했습니다. 다시 로그인해주세요.")
            }
            
        case .expiredAccessToken:
            print("⏰ SocketIOManager: 토큰 만료")
            DispatchQueue.main.async {
                self.connectionStatus = .error("로그인이 만료되었습니다. 다시 로그인해주세요.")
            }
            
        case .invalidAccessToken:
            print("🚫 SocketIOManager: 유효하지 않은 토큰")
            DispatchQueue.main.async {
                self.connectionStatus = .error("유효하지 않은 로그인 정보입니다. 다시 로그인해주세요.")
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
    
    // MARK: - 사용자 ID 획득
    private func getCurrentUserId() -> String {
        if let userId = tokenManager.getCurrentUserId() {
            print("✅ SocketIOManager: 사용자 ID 획득 성공 - \(userId)")
            return userId
        } else {
            print("⚠️ SocketIOManager: TokenManager에서 사용자 ID를 가져올 수 없음")
            
            if let accessToken = tokenManager.accessToken {
                print("🔍 SocketIOManager: AccessToken 존재 - 길이: \(accessToken.count)")
                tokenManager.debugToken()
            } else {
                print("⚠️ SocketIOManager: AccessToken이 nil")
            }
            
            return ""
        }
    }
}

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
