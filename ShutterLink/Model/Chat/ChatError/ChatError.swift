//
//  ChatError.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import Foundation

enum ChatError: Error, LocalizedError {
    case invalidOpponentId          // 400
    case chatRoomNotFound          // 404
    case notParticipant            // 445
    case invalidDateFormat         // 400 (next 파라미터)
    case fileTooLarge             // 400 (5MB 초과)
    case invalidFileType          // 400 (jpg,png,jpeg,gif,pdf만)
    case tooManyFiles            // 400 (최대 5개)
    case networkError
    case socketConnectionFailed
    case missingRequiredFields
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidOpponentId:
            return "상대방 정보가 올바르지 않습니다."
        case .chatRoomNotFound:
            return "채팅방을 찾을 수 없습니다."
        case .notParticipant:
            return "채팅방 참여 권한이 없습니다."
        case .invalidDateFormat:
            return "잘못된 날짜 형식입니다."
        case .fileTooLarge:
            return "파일 크기는 5MB 이하여야 합니다."
        case .invalidFileType:
            return "jpg, png, jpeg, gif, pdf 파일만 업로드 가능합니다."
        case .tooManyFiles:
            return "최대 5개 파일까지만 첨부 가능합니다."
        case .networkError:
            return "네트워크 연결을 확인해주세요."
        case .socketConnectionFailed:
            return "실시간 연결에 실패했습니다."
        case .missingRequiredFields:
            return "필수값을 채워주세요."
        case .unknownError(let message):
            return message
        }
    }
}

enum SocketAuthError: String, CaseIterable {
    case invalidSeSACKey = "This service sesac_memolease only"
    case expiredToken = "액세스 토큰이 만료되었습니다."
    case invalidToken = "인증할 수 없는 엑세스 토큰입니다."
    case forbidden = "Forbidden"
    
    var action: SocketErrorAction {
        switch self {
        case .expiredToken, .invalidToken:
            return .refreshTokenAndReconnect
        case .invalidSeSACKey:
            return .checkConfiguration
        case .forbidden:
            return .checkPermission
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .invalidSeSACKey:
            return "서비스 키 검증에 실패했습니다."
        case .expiredToken:
            return "로그인이 만료되었습니다. 다시 로그인해주세요."
        case .invalidToken:
            return "인증 토큰이 유효하지 않습니다."
        case .forbidden:
            return "접근 권한이 없습니다."
        }
    }
}

enum SocketErrorAction {
    case refreshTokenAndReconnect
    case checkConfiguration
    case checkPermission
    case showError(String)
}


// MARK: - 채팅방 관련 에러
enum ChatRoomError: String, CaseIterable {
    case invalidNamespace = "Invalid namespace"
    case roomNotFound = "채팅방을 찾을 수 없습니다."
    case notParticipant = "채팅방 참여자가 아닙니다."
    
    var localizedDescription: String {
        switch self {
        case .invalidNamespace:
            return "잘못된 네임스페이스 형식입니다."
        case .roomNotFound:
            return "채팅방을 찾을 수 없습니다."
        case .notParticipant:
            return "채팅방 참여 권한이 없습니다."
        }
    }
}

// MARK: - 파일 업로드 관련 검증
struct FileValidation {
    static let maxFileSize: Int = 5 * 1024 * 1024 // 5MB
    static let maxFileCount: Int = 5
    static let allowedExtensions: [String] = ["jpg", "jpeg", "png", "gif", "pdf"]
    
    static func validateFiles(_ files: [Data]) throws {
        // 파일 개수 검증
        guard files.count <= maxFileCount else {
            throw ChatError.tooManyFiles
        }
        
        // 파일 크기 검증
        for file in files {
            guard file.count <= maxFileSize else {
                throw ChatError.fileTooLarge
            }
        }
    }
    
    static func validateFileExtension(_ fileName: String) throws {
        let fileExtension = fileName.lowercased().components(separatedBy: ".").last ?? ""
        guard allowedExtensions.contains(fileExtension) else {
            throw ChatError.invalidFileType
        }
    }
}
