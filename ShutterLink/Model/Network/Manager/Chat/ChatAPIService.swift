//
//  ChatAPIService.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import Foundation

protocol ChatAPIService {
    func createOrGetChatRoom(opponentId: String) async throws -> ChatRoomResponse
    func getChatRoomList() async throws -> ChatRoomListResponse
    func sendMessage(roomId: String, content: String, files: [String]) async throws -> ChatMessageResponse
    func getChatHistory(roomId: String, next: String?) async throws -> ChatHistoryResponse
    func uploadFiles(roomId: String, files: [Data], fileNames: [String]) async throws -> FileUploadResponse
}

final class ChatAPIServiceImpl: ChatAPIService {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
    // MARK: - 채팅방 생성 또는 조회
    func createOrGetChatRoom(opponentId: String) async throws -> ChatRoomResponse {
        let request = CreateChatRoomRequest(opponentId: opponentId)
        let router = ChatRouter.createOrGetChatRoom(request: request)
        
        do {
            let response = try await networkManager.request(router, type: ChatRoomResponse.self)
            print("✅ ChatAPIService: 채팅방 생성/조회 성공 - roomId: \(response.roomId)")
            return response
        } catch let error as NetworkError {
            print("❌ ChatAPIService: 채팅방 생성/조회 실패 - \(error)")
            throw mapNetworkErrorToChatError(error)
        } catch {
            print("❌ ChatAPIService: 채팅방 생성/조회 실패 - \(error)")
            throw ChatError.unknownError(error.localizedDescription)
        }
    }
    
    // MARK: - 채팅방 목록 조회
    func getChatRoomList() async throws -> ChatRoomListResponse {
        let router = ChatRouter.getChatRoomList
        
        do {
            let response = try await networkManager.request(router, type: ChatRoomListResponse.self)
            print("✅ ChatAPIService: 채팅방 목록 조회 성공 - 개수: \(response.data.count)")
            return response
        } catch let error as NetworkError {
            print("❌ ChatAPIService: 채팅방 목록 조회 실패 - \(error)")
            throw mapNetworkErrorToChatError(error)
        } catch {
            print("❌ ChatAPIService: 채팅방 목록 조회 실패 - \(error)")
            throw ChatError.unknownError(error.localizedDescription)
        }
    }
    
    // MARK: - 메시지 전송
    func sendMessage(roomId: String, content: String, files: [String]) async throws -> ChatMessageResponse {
        let request = SendMessageRequest(content: content, files: files)
        let router = ChatRouter.sendMessage(roomId: roomId, request: request)
        
        do {
            let response = try await networkManager.request(router, type: ChatMessageResponse.self)
            print("✅ ChatAPIService: 메시지 전송 성공 - chatId: \(response.chatId)")
            return response
        } catch let error as NetworkError {
            print("❌ ChatAPIService: 메시지 전송 실패 - \(error)")
            throw mapNetworkErrorToChatError(error)
        } catch {
            print("❌ ChatAPIService: 메시지 전송 실패 - \(error)")
            throw ChatError.unknownError(error.localizedDescription)
        }
    }
    
    // MARK: - 채팅 내역 조회
    func getChatHistory(roomId: String, next: String?) async throws -> ChatHistoryResponse {
        let router = ChatRouter.getChatHistory(roomId: roomId, next: next)
        
        do {
            let response = try await networkManager.request(router, type: ChatHistoryResponse.self)
            print("✅ ChatAPIService: 채팅 내역 조회 성공 - 개수: \(response.data.count)")
            return response
        } catch let error as NetworkError {
            print("❌ ChatAPIService: 채팅 내역 조회 실패 - \(error)")
            throw mapNetworkErrorToChatError(error)
        } catch {
            print("❌ ChatAPIService: 채팅 내역 조회 실패 - \(error)")
            throw ChatError.unknownError(error.localizedDescription)
        }
    }
    
    // MARK: - 파일 업로드
    func uploadFiles(roomId: String, files: [Data], fileNames: [String]) async throws -> FileUploadResponse {
        // 파일 검증
        try FileValidation.validateFiles(files)
        for fileName in fileNames {
            try FileValidation.validateFileExtension(fileName)
        }
        
        let router = ChatRouter.uploadFiles(roomId: roomId, files: files, fileNames: fileNames)
        
        do {
            // 멀티파트 업로드의 경우 기존 NetworkManager의 uploadMultipleImages 메서드 활용
            let images = zip(files, fileNames).map { (fieldName: "files", data: $0, filename: $1) }
            let data = try await networkManager.uploadMultipleImages(router, images: images)
            let response = try JSONDecoder().decode(FileUploadResponse.self, from: data)
            print("✅ ChatAPIService: 파일 업로드 성공 - 개수: \(response.files.count)")
            return response
        } catch let error as NetworkError {
            print("❌ ChatAPIService: 파일 업로드 실패 - \(error)")
            throw mapNetworkErrorToChatError(error)
        } catch {
            print("❌ ChatAPIService: 파일 업로드 실패 - \(error)")
            throw ChatError.unknownError(error.localizedDescription)
        }
    }
    
    // MARK: - 에러 매핑
    private func mapNetworkErrorToChatError(_ networkError: NetworkError) -> ChatError {
        switch networkError {
        case .missingRequiredFields:
            return .missingRequiredFields
        case .invalidStatusCode(404):
            return .chatRoomNotFound
        case .invalidStatusCode(445):
            return .notParticipant
        case .invalidStatusCode(400):
            return .invalidDateFormat
        case .accessTokenExpired, .invalidAccessToken:
            return .networkError
        case .requestFailed, .invalidResponse, .unknownError:
            return .networkError
        case .customError(let message):
            return .unknownError(message)
        default:
            return .unknownError(networkError.errorMessage)
        }
    }
}

// MARK: - Chat Router

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

// MARK: - Date Formatter for API

extension ChatAPIServiceImpl {
    private func formatDateForAPI(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    
    private func formatDateForQuery(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS '+0000'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.string(from: date)
    }
}
