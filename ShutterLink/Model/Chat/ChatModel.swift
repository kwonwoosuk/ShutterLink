//
//  ChatModel.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import Foundation
import RealmSwift

// MARK: - RealmSwift Models (로컬 DB용)

class ChatRoomEntity: Object {
    @Persisted var roomId: String = ""
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()
    @Persisted var participants: List<UserEntity>
    @Persisted var lastChat: ChatMessageEntity?
    
    override static func primaryKey() -> String? { "roomId" }
}

class ChatMessageEntity: Object {
    @Persisted var chatId: String = ""
    @Persisted var roomId: String = ""
    @Persisted var content: String = ""
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()
    @Persisted var senderId: String = ""
    @Persisted var senderNick: String = ""
    @Persisted var senderName: String = ""
    @Persisted var senderIntroduction: String = ""
    @Persisted var senderProfileImage: String = ""
    @Persisted var senderHashTags: List<String>
    @Persisted var files: List<String>
    @Persisted var isFromCurrentUser: Bool = false
    
    override static func primaryKey() -> String? { "chatId" }
}

class UserEntity: Object {
    @Persisted var userId: String = ""
    @Persisted var nick: String = ""
    @Persisted var name: String = ""
    @Persisted var introduction: String = ""
    @Persisted var profileImage: String = ""
    @Persisted var hashTags: List<String>
    
    override static func primaryKey() -> String? { "userId" }
}

// MARK: - Domain Models (비즈니스 로직용)

struct ChatRoom: Equatable, Identifiable {
    var id: String { roomId }
    let roomId: String
    let createdAt: Date
    let updatedAt: Date
    let participants: [Users]
    let lastChat: ChatMessage?
    
    static func == (lhs: ChatRoom, rhs: ChatRoom) -> Bool {
        return lhs.roomId == rhs.roomId &&
               lhs.updatedAt == rhs.updatedAt &&
               lhs.participants == rhs.participants &&
               lhs.lastChat == rhs.lastChat
    }
}

struct ChatMessage: Equatable, Identifiable {
    var id: String { chatId }
    let chatId: String
    let roomId: String
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let sender: Users
    let files: [String]
    let isFromCurrentUser: Bool
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.chatId == rhs.chatId &&
               lhs.content == rhs.content &&
               lhs.createdAt == rhs.createdAt &&
               lhs.sender == rhs.sender &&
               lhs.files == rhs.files &&
               lhs.isFromCurrentUser == rhs.isFromCurrentUser
    }
}

struct Users: Equatable, Identifiable, Hashable {
    var id: String { userId }
    let userId: String
    let nick: String
    let name: String
    let introduction: String
    let profileImage: String?
    let hashTags: [String]
    
    static func == (lhs: Users, rhs: Users) -> Bool {
        return lhs.userId == rhs.userId &&
               lhs.nick == rhs.nick &&
               lhs.name == rhs.name &&
               lhs.introduction == rhs.introduction &&
               lhs.profileImage == rhs.profileImage &&
               lhs.hashTags == rhs.hashTags
    }
}

// MARK: - API Response Models

struct ChatRoomResponse: Codable {
    let roomId: String
    let createdAt: String
    let updatedAt: String
    let participants: [UserResponse]
    let lastChat: ChatMessageResponse?
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case createdAt, updatedAt, participants, lastChat
    }
}

struct ChatRoomListResponse: Codable {
    let data: [ChatRoomResponse]
}

struct ChatMessageResponse: Codable {
    let chatId: String
    let roomId: String
    let content: String
    let createdAt: String
    let updatedAt: String
    let sender: UserResponse
    let files: [String]
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case roomId = "room_id"
        case createdAt, updatedAt, sender, content, files
    }
}

struct ChatHistoryResponse: Codable {
    let data: [ChatMessageResponse]
}

struct UserResponse: Codable {
    let userId: String
    let nick: String
    let name: String?
    let introduction: String?
    let profileImage: String?
    let hashTags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nick, name, introduction
        case profileImage, hashTags
    }
   
   }


struct FileUploadResponse: Codable {
    let files: [String]
}

// MARK: - Request Models

struct CreateChatRoomRequest: Codable {
    let opponentId: String
    
    enum CodingKeys: String, CodingKey {
        case opponentId = "opponent_id"
    }
}

struct SendMessageRequest: Codable {
    let content: String
    let files: [String]
}

// MARK: - Extensions for Conversion

extension ChatRoomEntity {
    func toDomain() -> ChatRoom {
        return ChatRoom(
            roomId: roomId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            participants: participants.map { $0.toDomain() },
            lastChat: lastChat?.toDomain()
        )
    }
    
    static func fromDomain(_ chatRoom: ChatRoom) -> ChatRoomEntity {
        let entity = ChatRoomEntity()
        entity.roomId = chatRoom.roomId
        entity.createdAt = chatRoom.createdAt
        entity.updatedAt = chatRoom.updatedAt
        entity.participants.append(objectsIn: chatRoom.participants.map { UserEntity.fromDomain($0) })
        if let lastChat = chatRoom.lastChat {
            entity.lastChat = ChatMessageEntity.fromDomain(lastChat)
        }
        return entity
    }
}

extension ChatMessageEntity {
    func toDomain() -> ChatMessage {
        let user = Users(
            userId: senderId,
            nick: senderNick,
            name: senderName,
            introduction: senderIntroduction,
            profileImage: senderProfileImage.isEmpty ? nil : senderProfileImage,
            hashTags: Array(senderHashTags)
        )
        
        return ChatMessage(
            chatId: chatId,
            roomId: roomId,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sender: user,
            files: Array(files),
            isFromCurrentUser: isFromCurrentUser
        )
    }
    
    static func fromDomain(_ message: ChatMessage) -> ChatMessageEntity {
        let entity = ChatMessageEntity()
        entity.chatId = message.chatId
        entity.roomId = message.roomId
        entity.content = message.content
        entity.createdAt = message.createdAt
        entity.updatedAt = message.updatedAt
        entity.senderId = message.sender.userId
        entity.senderNick = message.sender.nick
        entity.senderName = message.sender.name
        entity.senderIntroduction = message.sender.introduction
        entity.senderProfileImage = message.sender.profileImage ?? ""
        entity.senderHashTags.append(objectsIn: message.sender.hashTags)
        entity.files.append(objectsIn: message.files)
        entity.isFromCurrentUser = message.isFromCurrentUser
        return entity
    }
}

extension UserEntity {
    func toDomain() -> Users {
        return Users(
            userId: userId,
            nick: nick,
            name: name,
            introduction: introduction,
            profileImage: profileImage.isEmpty ? nil : profileImage,
            hashTags: Array(hashTags)
        )
    }
    
    static func fromDomain(_ user: Users) -> UserEntity {
        let entity = UserEntity()
        entity.userId = user.userId
        entity.nick = user.nick
        entity.name = user.name
        entity.introduction = user.introduction
        entity.profileImage = user.profileImage ?? ""
        entity.hashTags.append(objectsIn: user.hashTags)
        return entity
    }
}




extension UserResponse {
    func toDomain() -> Users {
        return Users(
            userId: userId,
            nick: nick,
            name: name ?? "",
            introduction: introduction ?? "",
            profileImage: profileImage,
            hashTags: hashTags ?? []
        )
    }
}
