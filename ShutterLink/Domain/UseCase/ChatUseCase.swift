//
//  ChatUseCase.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import Foundation
import Combine

protocol ChatUseCase {
    // 채팅방 관련
    func createOrGetChatRoom(opponentId: String) async throws -> ChatRoom
    func getChatRooms() async throws -> [ChatRoom]
    func syncChatRooms() async throws -> [ChatRoom]
    
    // 채팅 메시지 관련
    func getMessages(roomId: String) async throws -> [ChatMessage]
    func syncMessages(roomId: String, since: Date?) async throws -> [ChatMessage]
    func sendMessage(roomId: String, content: String, files: [String]) async throws -> ChatMessage
    func uploadFiles(roomId: String, files: [Data], fileNames: [String]) async throws -> [String]
    
    // 로컬 저장
    func saveMessage(_ message: ChatMessage) async throws
    func saveMessages(_ messages: [ChatMessage]) async throws
    func getLocalMessages(roomId: String) async throws -> [ChatMessage]
    func getLatestLocalMessage(roomId: String) async throws -> ChatMessage?
    
    // 실시간 관찰
    func observeMessages(roomId: String) -> AnyPublisher<[ChatMessage], Never>
    func observeChatRooms() -> AnyPublisher<[ChatRoom], Never>
}

final class ChatUseCaseImpl: ChatUseCase {
    private let apiService: ChatAPIService
    private let localRepository: ChatLocalRepository
    private let tokenManager: TokenManager
    
    init(
        apiService: ChatAPIService = ChatAPIServiceImpl(),
        localRepository: ChatLocalRepository,
        tokenManager: TokenManager = TokenManager.shared
    ) {
        self.apiService = apiService
        self.localRepository = localRepository
        self.tokenManager = tokenManager
    }
    
    // MARK: - 채팅방 관련
    
    func createOrGetChatRoom(opponentId: String) async throws -> ChatRoom {
        print("🔵 ChatUseCase: 채팅방 생성/조회 시작 - opponentId: \(opponentId)")
        
        do {
            // 1. 서버에서 채팅방 생성/조회
            let response = try await apiService.createOrGetChatRoom(opponentId: opponentId)
            let currentUserId = getCurrentUserId()
            let chatRoom = response.toDomain(currentUserId: currentUserId)
            
            // 2. 로컬에 저장
            try await localRepository.saveChatRoom(chatRoom)
            
            print("✅ ChatUseCase: 채팅방 생성/조회 완료 - roomId: \(chatRoom.roomId)")
            return chatRoom
            
        } catch {
            print("❌ ChatUseCase: 채팅방 생성/조회 실패 - \(error)")
            throw error
        }
    }
    
    func getChatRooms() async throws -> [ChatRoom] {
        print("🔵 ChatUseCase: 채팅방 목록 조회 시작")
        
        // 1. 로컬 데이터 먼저 반환
        let localChatRooms = try await localRepository.getChatRooms()
        print("📱 ChatUseCase: 로컬 채팅방 개수: \(localChatRooms.count)")
        
        return localChatRooms
    }
    
    func syncChatRooms() async throws -> [ChatRoom] {
        print("🔄 ChatUseCase: 채팅방 목록 동기화 시작")
        
        do {
            // 1. 서버에서 최신 채팅방 목록 가져오기
            let response = try await apiService.getChatRoomList()
            let currentUserId = getCurrentUserId()
            let serverChatRooms = response.data.map { $0.toDomain(currentUserId: currentUserId) }
            
            // 2. 로컬에 저장
            for chatRoom in serverChatRooms {
                try await localRepository.saveChatRoom(chatRoom)
            }
            
            // 3. 최신 로컬 데이터 반환
            let syncedChatRooms = try await localRepository.getChatRooms()
            
            print("✅ ChatUseCase: 채팅방 목록 동기화 완료 - 개수: \(syncedChatRooms.count)")
            return syncedChatRooms
            
        } catch {
            print("❌ ChatUseCase: 채팅방 목록 동기화 실패, 로컬 데이터 반환 - \(error)")
            // 동기화 실패 시 로컬 데이터 반환
            return try await localRepository.getChatRooms()
        }
    }
    
    // MARK: - 채팅 메시지 관련
    
    func getMessages(roomId: String) async throws -> [ChatMessage] {
        print("🔵 ChatUseCase: 메시지 목록 조회 시작 - roomId: \(roomId)")
        
        // 로컬 데이터 반환
        let messages = try await localRepository.getMessages(roomId: roomId)
        print("📱 ChatUseCase: 로컬 메시지 개수: \(messages.count)")
        
        return messages
    }
    
    func syncMessages(roomId: String, since: Date?) async throws -> [ChatMessage] {
        print("🔄 ChatUseCase: 메시지 동기화 시작 - roomId: \(roomId)")
        
        do {
            // 1. since 날짜를 API 형식으로 변환
            var nextParam: String?
            if let since = since {
                nextParam = formatDateForAPI(since)
                print("📅 ChatUseCase: since 파라미터: \(nextParam ?? "nil")")
            }
            
            // 2. 서버에서 최신 메시지 가져오기
            let response = try await apiService.getChatHistory(roomId: roomId, next: nextParam)
            let currentUserId = getCurrentUserId()
            let serverMessages = response.data.map { $0.toDomain(currentUserId: currentUserId) }
            
            // 3. 로컬에 저장 (중복 제거는 Realm의 primaryKey로 처리)
            if !serverMessages.isEmpty {
                try await localRepository.saveMessages(serverMessages)
            }
            
            // 4. 최신 로컬 데이터 반환
            let syncedMessages = try await localRepository.getMessages(roomId: roomId)
            
            print("✅ ChatUseCase: 메시지 동기화 완료 - 새 메시지: \(serverMessages.count)개, 전체: \(syncedMessages.count)개")
            return syncedMessages
            
        } catch {
            print("❌ ChatUseCase: 메시지 동기화 실패, 로컬 데이터 반환 - \(error)")
            // 동기화 실패 시 로컬 데이터 반환
            return try await localRepository.getMessages(roomId: roomId)
        }
    }
    
    func sendMessage(roomId: String, content: String, files: [String]) async throws -> ChatMessage {
        print("🔵 ChatUseCase: 메시지 전송 시작 - roomId: \(roomId)")
        
        do {
            // 1. 서버로 메시지 전송
            let response = try await apiService.sendMessage(roomId: roomId, content: content, files: files)
            let currentUserId = getCurrentUserId()
            let sentMessage = response.toDomain(currentUserId: currentUserId)
            
            // 2. 로컬에 저장
            try await localRepository.saveMessage(sentMessage)
            
            print("✅ ChatUseCase: 메시지 전송 완료 - chatId: \(sentMessage.chatId)")
            return sentMessage
            
        } catch {
            print("❌ ChatUseCase: 메시지 전송 실패 - \(error)")
            throw error
        }
    }
    
    func uploadFiles(roomId: String, files: [Data], fileNames: [String]) async throws -> [String] {
        print("🔵 ChatUseCase: 파일 업로드 시작 - roomId: \(roomId), 개수: \(files.count)")
        
        do {
            let response = try await apiService.uploadFiles(roomId: roomId, files: files, fileNames: fileNames)
            
            print("✅ ChatUseCase: 파일 업로드 완료 - 개수: \(response.files.count)")
            return response.files
            
        } catch {
            print("❌ ChatUseCase: 파일 업로드 실패 - \(error)")
            throw error
        }
    }
    
    // MARK: - 로컬 저장
    
    func saveMessage(_ message: ChatMessage) async throws {
        try await localRepository.saveMessage(message)
    }
    
    func saveMessages(_ messages: [ChatMessage]) async throws {
        try await localRepository.saveMessages(messages)
    }
    
    func getLocalMessages(roomId: String) async throws -> [ChatMessage] {
        return try await localRepository.getMessages(roomId: roomId)
    }
    
    func getLatestLocalMessage(roomId: String) async throws -> ChatMessage? {
        return try await localRepository.getLatestMessage(roomId: roomId)
    }
    
    // MARK: - 실시간 관찰
    
    func observeMessages(roomId: String) -> AnyPublisher<[ChatMessage], Never> {
        return localRepository.observeMessages(roomId: roomId)
    }
    
    func observeChatRooms() -> AnyPublisher<[ChatRoom], Never> {
        return localRepository.observeChatRooms()
    }
    
    // MARK: - 유틸리티
    
    private func getCurrentUserId() -> String {
        // TODO: TokenManager에서 현재 사용자 ID 가져오기
        return tokenManager.getCurrentUserId() ?? ""
    }
    
    private func formatDateForAPI(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

