//
//  ChatRouter.swift
//  ShutterLink
//
//  Created by 권우석 on 7/22/25.
//

import Foundation

enum ChatRouter: APIRouter {
    case createOrGetChatRoom(request: CreateChatRoomRequest)
    case getChatRoomList
    case sendMessage(roomId: String, request: SendMessageRequest)
    case getChatHistory(roomId: String, next: String?)
    case uploadFiles(roomId: String, files: [Data], fileNames: [String])
    
    var path: String {
        switch self {
        case .createOrGetChatRoom, .getChatRoomList:
            return APIConstants.Path.chats
        case .sendMessage(let roomId, _), .getChatHistory(let roomId, _):
            return APIConstants.Path.chatRoom(roomId)
        case .uploadFiles(let roomId, _, _):
            return APIConstants.Path.chatFiles(roomId)
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .createOrGetChatRoom, .sendMessage, .uploadFiles:
            return .post
        case .getChatRoomList, .getChatHistory:
            return .get
        }
    }
    
    var authorizationType: AuthorizationType {
        return .accessToken
    }
    
    var body: Data? {
        switch self {
        case .createOrGetChatRoom(let request):
            return try? JSONEncoder().encode(request)
        case .sendMessage(_, let request):
            return try? JSONEncoder().encode(request)
        case .uploadFiles:
            // 멀티파트 데이터는 NetworkManager에서 처리
            return nil
        default:
            return nil
        }
    }
    
    var contentType: String {
        switch self {
        case .uploadFiles:
            return APIConstants.ContentType.multipartFormData
        default:
            return APIConstants.ContentType.json
        }
    }
    
    var queryItems: [URLQueryItem]? {
        switch self {
        case .getChatHistory(_, let next):
            if let next = next {
                return [URLQueryItem(name: "next", value: next)]
            }
            return nil
        default:
            return nil
        }
    }
}
