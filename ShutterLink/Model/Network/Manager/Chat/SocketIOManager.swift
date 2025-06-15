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
    
    // 강화된 메시지 스트림
    private let messageSubject = PassthroughSubject<ChatMessage, Never>()
    var messagePublisher: AnyPublisher<ChatMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    private var currentRoomId: String?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    private var reconnectTimer: Timer?
    
    // 메시지 중복 방지용
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
        
        // ✅ 수정된 소켓 URL - 네임스페이스 형식 변경
        let socketURL = APIConstants.Socket.chatURL(roomId: roomId)
        
        guard let url = URL(string: socketURL) else {
            print("❌ SocketIOManager: 잘못된 소켓 URL - \(socketURL)")
            connectionStatus = .error("잘못된 연결 주소입니다")
            return
        }
        
        processedMessageIds.removeAll()
        
        // ✅ Socket.IO 매니저 설정 개선
        manager = SocketManager(
            socketURL: url,
            config: [
                .log(true),
                .forceWebsockets(true),
                .reconnects(true), // 자동 재연결 활성화
                .reconnectAttempts(5), // 재연결 시도 횟수
                .reconnectWait(1), // 재연결 대기 시간
                .extraHeaders([
                    APIConstants.Header.sesacKey: Key.ShutterLink.apiKey.rawValue,
                    APIConstants.Header.authorization: accessToken
                ])
            ]
        )
        
        socket = manager?.defaultSocket
        
        // ✅ 연결 전에 이벤트 핸들러 먼저 등록
        setupSocketEvents()
        
        connectionStatus = .connecting
        socket?.connect()
        
        print("🔌 SocketIOManager: 연결 시도 - URL: \(socketURL)")
        print("🔌 SocketIOManager: Authorization: \(accessToken.prefix(20))...")
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
    
    // MARK: - ✅ 완전히 새로운 이벤트 핸들러 설정
    
    private func setupSocketEvents() {
        guard let socket = socket else { return }
        
        print("🔧 SocketIOManager: 이벤트 핸들러 설정 시작")
        
        // 연결 성공
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            print("🟢 SocketIOManager: 소켓 연결 성공")
            print("🟢 SocketIOManager: 연결 데이터: \(data)")
            
            DispatchQueue.main.async {
                self?.connectionStatus = .connected
                self?.connectionError = nil
                self?.reconnectAttempts = 0
            }
            
            // ✅ 연결 후 방 참여 요청
            if let roomId = self?.currentRoomId {
                self?.joinChatRoom(roomId)
            }
        }
        
        // 연결 해제
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("🔴 SocketIOManager: 소켓 연결 해제")
            print("🔴 SocketIOManager: 해제 데이터: \(data)")
            DispatchQueue.main.async {
                self?.connectionStatus = .disconnected
            }
        }
        
        // 연결 에러
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
        
        // ✅ 모든 가능한 메시지 이벤트 수신 - 와일드카드 방식
        setupMessageEventHandlers(socket)
        
        // ✅ 모든 이벤트 수신하여 디버깅
        socket.onAny { [weak self] event in
            print("🎯 SocketIOManager: 수신된 이벤트 - \(event.event)")
            print("🎯 SocketIOManager: 이벤트 데이터: \(event.items)")
            
            // 메시지 관련 이벤트인지 확인
            if self?.isMessageEvent(event.event) == true && !event.items!.isEmpty {
                print("💬 SocketIOManager: 메시지 이벤트 감지 - \(event.event)")
                self?.handleReceivedMessage(event.items?.first)
            }
        }
        
        print("✅ SocketIOManager: 이벤트 핸들러 설정 완료")
    }
    
    // ✅ 메시지 이벤트 핸들러들 설정
    private func setupMessageEventHandlers(_ socket: SocketIOClient) {
        // 가능한 모든 메시지 이벤트명 처리
        let messageEvents = [
            "chat",
            "message",
            "newMessage",
            "new_message",
            "chatMessage",
            "chat_message",
            "receiveMessage",
            "receive_message"
        ]
        
        for eventName in messageEvents {
            socket.on(eventName) { [weak self] data, ack in
                print("💬 SocketIOManager: '\(eventName)' 이벤트 수신")
                print("💬 SocketIOManager: 데이터 개수: \(data.count)")
                print("💬 SocketIOManager: 데이터 내용: \(data)")
                
                if let messageData = data.first {
                    self?.handleReceivedMessage(messageData)
                } else {
                    print("⚠️ SocketIOManager: \(eventName) 이벤트 데이터가 비어있음")
                }
            }
        }
    }
    
    // ✅ 메시지 이벤트인지 판단
    private func isMessageEvent(_ eventName: String) -> Bool {
        let messageKeywords = ["chat", "message", "msg"]
        return messageKeywords.contains { eventName.lowercased().contains($0) }
    }
    
    // ✅ 방 참여 요청
    private func joinChatRoom(_ roomId: String) {
        guard let socket = socket else { return }
        
        print("🚪 SocketIOManager: 채팅방 참여 요청 - roomId: \(roomId)")
        
        // 방 참여 이벤트 전송
        socket.emit("join", roomId)
        socket.emit("joinRoom", roomId)
        socket.emit("join_room", roomId)
        
        // 방 참여 확인 이벤트 수신
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
    
    // MARK: - ✅ 강화된 메시지 처리
    
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
            
            // ✅ 다양한 형태의 데이터 처리
            let jsonData: Data
            
            if let dictData = messageData as? [String: Any] {
                // Dictionary 형태
                jsonData = try JSONSerialization.data(withJSONObject: dictData)
                print("📋 SocketIOManager: Dictionary 데이터 처리")
            } else if let stringData = messageData as? String {
                // String 형태 (JSON 문자열일 수 있음)
                jsonData = stringData.data(using: .utf8) ?? Data()
                print("📋 SocketIOManager: String 데이터 처리")
            } else if let dataObject = messageData as? Data {
                // Data 형태
                jsonData = dataObject
                print("📋 SocketIOManager: Data 객체 처리")
            } else {
                // 기타 형태는 JSON 직렬화 시도
                jsonData = try JSONSerialization.data(withJSONObject: messageData)
                print("📋 SocketIOManager: 기타 형태 JSON 직렬화")
            }
            
            // JSON 문자열 디버깅 출력
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📋 SocketIOManager: 파싱할 JSON:")
                print(jsonString)
            }
            
            // ChatMessageResponse로 디코딩
            let decoder = JSONDecoder()
            let chatResponse = try decoder.decode(ChatMessageResponse.self, from: jsonData)
            
            print("✅ SocketIOManager: 메시지 디코딩 성공")
            print("   - chatId: \(chatResponse.chatId)")
            print("   - roomId: \(chatResponse.roomId)")
            print("   - content: \(chatResponse.content)")
            print("   - sender: \(chatResponse.sender.userId)")
            
            // 중복 메시지 체크
            guard !processedMessageIds.contains(chatResponse.chatId) else {
                print("⚠️ SocketIOManager: 중복 메시지 무시 - chatId: \(chatResponse.chatId)")
                return
            }
            
            // 메시지 ID 기록
            processedMessageIds.insert(chatResponse.chatId)
            
            // 현재 사용자 ID 가져오기
            let currentUserId = getCurrentUserId()
            guard !currentUserId.isEmpty else {
                print("❌ SocketIOManager: 현재 사용자 ID가 없습니다")
                return
            }
            
            print("🔍 SocketIOManager: 사용자 확인")
            print("   - currentUserId: '\(currentUserId)'")
            print("   - senderUserId: '\(chatResponse.sender.userId)'")
            
            // Domain 모델로 변환
            let chatMessage = chatResponse.toDomain(currentUserId: currentUserId)
            
            print("✅ SocketIOManager: Domain 변환 완료")
            print("   - isFromCurrentUser: \(chatMessage.isFromCurrentUser)")
            print("   - 메시지 내용: \(chatMessage.content)")
            
            // 메인 스레드에서 UI 업데이트
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
            
            // ✅ 더 상세한 디버깅 정보
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
            
            // JSON 직렬화 재시도로 디버깅 정보 수집
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
    
    // MARK: - 에러 처리 (기존 유지)
    
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
