//
//  ChatLocalRepository.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import Foundation
import RealmSwift
import Combine

protocol ChatLocalRepository {
    // 채팅방 관련
    func saveChatRoom(_ chatRoom: ChatRoom) async throws
    func getChatRooms() async throws -> [ChatRoom]
    func getChatRoom(roomId: String) async throws -> ChatRoom?
    func deleteChatRoom(roomId: String) async throws
    
    // 채팅 메시지 관련
    func saveMessage(_ message: ChatMessage) async throws
    func saveMessages(_ messages: [ChatMessage]) async throws
    func getMessages(roomId: String) async throws -> [ChatMessage]
    func getLatestMessage(roomId: String) async throws -> ChatMessage?
    func deleteMessages(roomId: String) async throws
    func getMessagesAfter(roomId: String, date: Date) async throws -> [ChatMessage]
    
    // 실시간 관찰
    func observeMessages(roomId: String) -> AnyPublisher<[ChatMessage], Never>
    func observeChatRooms() -> AnyPublisher<[ChatRoom], Never>
    
}

final class RealmChatRepository: ChatLocalRepository {
    private let realm: Realm
    
    init() throws {
        // Realm 설정
        var config = Realm.Configuration()
        config.schemaVersion = 1
        config.migrationBlock = { migration, oldSchemaVersion in
            // 마이그레이션 로직 (필요 시 추가)
        }
        
        self.realm = try Realm(configuration: config)
        print("✅ RealmChatRepository: Realm 초기화 성공")
    }
    
    // MARK: - 채팅방 관련
    
    func saveChatRoom(_ chatRoom: ChatRoom) async throws {
        try await Task { @MainActor in
            let entity = ChatRoomEntity.fromDomain(chatRoom)
            
            try realm.write {
                realm.add(entity, update: .modified)
            }
            
            print("✅ RealmChatRepository: 채팅방 저장 완료 - roomId: \(chatRoom.roomId)")
        }.value
    }
    
    func getChatRooms() async throws -> [ChatRoom] {
        return await Task { @MainActor in
            let entities = realm.objects(ChatRoomEntity.self)
                .sorted(byKeyPath: "updatedAt", ascending: false)
            
            let chatRooms = Array(entities).map { $0.toDomain() }
            print("✅ RealmChatRepository: 채팅방 목록 조회 완료 - 개수: \(chatRooms.count)")
            return chatRooms
        }.value
    }
    
    func getChatRoom(roomId: String) async throws -> ChatRoom? {
        return await Task { @MainActor in
            let entity = realm.object(ofType: ChatRoomEntity.self, forPrimaryKey: roomId)
            let chatRoom = entity?.toDomain()
            
            if let chatRoom = chatRoom {
                print("✅ RealmChatRepository: 채팅방 조회 완료 - roomId: \(roomId)")
            } else {
                print("⚠️ RealmChatRepository: 채팅방을 찾을 수 없음 - roomId: \(roomId)")
            }
            
            return chatRoom
        }.value
    }
    
    func deleteChatRoom(roomId: String) async throws {
            try await Task { @MainActor in
                print("🗑️ RealmChatRepository: 채팅방 삭제 시작 - roomId: \(roomId)")
                
                // 1. 해당 채팅방의 모든 메시지 조회
                let messages = realm.objects(ChatMessageEntity.self)
                    .filter("roomId == %@", roomId)
           
                
                // 2. 채팅방 삭제
                if let chatRoom = realm.object(ofType: ChatRoomEntity.self, forPrimaryKey: roomId) {
                    try realm.write {
                        // 메시지 먼저 삭제
                        realm.delete(messages)
                        // 채팅방 삭제
                        realm.delete(chatRoom)
                    }
                    print("✅ RealmChatRepository: 채팅방, 메시지 및 로컬 파일 삭제 완료 - roomId: \(roomId), 삭제된 메시지: \(messages.count)개")
                } else {
                    print("⚠️ RealmChatRepository: 삭제할 채팅방을 찾을 수 없음 - roomId: \(roomId)")
                    throw NSError(domain: "ChatRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "채팅방을 찾을 수 없습니다."])
                }
            }.value
        }
    
    // MARK: - 채팅 메시지 관련
    
    func saveMessage(_ message: ChatMessage) async throws {
        try await Task { @MainActor in
            let entity = ChatMessageEntity.fromDomain(message)
            
            try realm.write {
                realm.add(entity, update: .modified)
            }
            
            // 채팅방의 lastChat 업데이트
            if let chatRoom = realm.object(ofType: ChatRoomEntity.self, forPrimaryKey: message.roomId) {
                try realm.write {
                    chatRoom.lastChat = entity
                    chatRoom.updatedAt = message.createdAt
                }
            }
            
            print("✅ RealmChatRepository: 메시지 저장 완료 - chatId: \(message.chatId)")
        }.value
    }
    
    func saveMessages(_ messages: [ChatMessage]) async throws {
        try await Task { @MainActor in
            let entities = messages.map { ChatMessageEntity.fromDomain($0) }
            
            try realm.write {
                realm.add(entities, update: .modified)
            }
            
            // 각 채팅방의 lastChat 업데이트
            let roomIds = Set(messages.map { $0.roomId })
            for roomId in roomIds {
                if let latestMessage = messages
                    .filter({ $0.roomId == roomId })
                    .max(by: { $0.createdAt < $1.createdAt }),
                   let chatRoom = realm.object(ofType: ChatRoomEntity.self, forPrimaryKey: roomId),
                   let messageEntity = entities.first(where: { $0.chatId == latestMessage.chatId }) {
                    
                    try realm.write {
                        chatRoom.lastChat = messageEntity
                        chatRoom.updatedAt = latestMessage.createdAt
                    }
                }
            }
            
            print("✅ RealmChatRepository: 메시지 목록 저장 완료 - 개수: \(messages.count)")
        }.value
    }
    
    func getMessages(roomId: String) async throws -> [ChatMessage] {
        return await Task { @MainActor in
            let entities = realm.objects(ChatMessageEntity.self)
                .filter("roomId == %@", roomId)
                .sorted(byKeyPath: "createdAt", ascending: true)
            
            let messages = Array(entities).map { $0.toDomain() }
            print("✅ RealmChatRepository: 메시지 목록 조회 완료 - roomId: \(roomId), 개수: \(messages.count)")
            return messages
        }.value
    }
    
    func getLatestMessage(roomId: String) async throws -> ChatMessage? {
        return await Task { @MainActor in
            let entity = realm.objects(ChatMessageEntity.self)
                .filter("roomId == %@", roomId)
                .sorted(byKeyPath: "createdAt", ascending: false)
                .first
            
            let message = entity?.toDomain()
            
            if let message = message {
                print("✅ RealmChatRepository: 최신 메시지 조회 완료 - roomId: \(roomId)")
            } else {
                print("⚠️ RealmChatRepository: 최신 메시지를 찾을 수 없음 - roomId: \(roomId)")
            }
            
            return message
        }.value
    }
    
    func deleteMessages(roomId: String) async throws {
        try await Task { @MainActor in
            let messages = realm.objects(ChatMessageEntity.self)
                .filter("roomId == %@", roomId)
            
            try realm.write {
                realm.delete(messages)
            }
            
            print("✅ RealmChatRepository: 메시지 삭제 완료 - roomId: \(roomId)")
        }.value
    }
    
    func getMessagesAfter(roomId: String, date: Date) async throws -> [ChatMessage] {
        return await Task { @MainActor in
            let entities = realm.objects(ChatMessageEntity.self)
                .filter("roomId == %@ AND createdAt > %@", roomId, date)
                .sorted(byKeyPath: "createdAt", ascending: true)
            
            let messages = Array(entities).map { $0.toDomain() }
            print("✅ RealmChatRepository: 특정 날짜 이후 메시지 조회 완료 - roomId: \(roomId), 개수: \(messages.count)")
            return messages
        }.value
    }
    
    // MARK: - 실시간 관찰
    
    func observeMessages(roomId: String) -> AnyPublisher<[ChatMessage], Never> {
        return Future<[ChatMessage], Never> { promise in
            Task { @MainActor in
                let entities = self.realm.objects(ChatMessageEntity.self)
                    .filter("roomId == %@", roomId)
                    .sorted(byKeyPath: "createdAt", ascending: true)
                
                // Realm 객체의 변경사항을 관찰
                let notificationToken = entities.observe { changes in
                    switch changes {
                    case .initial(let results), .update(let results, _, _, _):
                        let messages = Array(results).map { $0.toDomain() }
                        promise(.success(messages))
                    case .error(let error):
                        print("❌ RealmChatRepository: 메시지 관찰 에러 - \(error)")
                        promise(.success([]))
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // 초기 데이터 로드를 위한 지연
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func observeChatRooms() -> AnyPublisher<[ChatRoom], Never> {
        return Future<[ChatRoom], Never> { promise in
            Task { @MainActor in
                let entities = self.realm.objects(ChatRoomEntity.self)
                    .sorted(byKeyPath: "updatedAt", ascending: false)
                
                // Realm 객체의 변경사항을 관찰
                let notificationToken = entities.observe { changes in
                    switch changes {
                    case .initial(let results), .update(let results, _, _, _):
                        let chatRooms = Array(results).map { $0.toDomain() }
                        promise(.success(chatRooms))
                    case .error(let error):
                        print("❌ RealmChatRepository: 채팅방 관찰 에러 - \(error)")
                        promise(.success([]))
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // 초기 데이터 로드를 위한 지연
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - 유틸리티 메서드

extension RealmChatRepository {
    func clearAllChatData() async throws {
        try await Task { @MainActor in
            try realm.write {
                realm.delete(realm.objects(ChatMessageEntity.self))
                realm.delete(realm.objects(ChatRoomEntity.self))
                realm.delete(realm.objects(UserEntity.self))
            }
            print("✅ RealmChatRepository: 모든 채팅 데이터 삭제 완료")
        }.value
    }
    
    func getDatabaseInfo() async -> String {
        return await Task { @MainActor in
            let chatRoomCount = realm.objects(ChatRoomEntity.self).count
            let messageCount = realm.objects(ChatMessageEntity.self).count
            let userCount = realm.objects(UserEntity.self).count
            
            return """
            📊 Realm Database Info:
            - 채팅방: \(chatRoomCount)개
            - 메시지: \(messageCount)개  
            - 사용자: \(userCount)명
            """
        }.value
    }
}
