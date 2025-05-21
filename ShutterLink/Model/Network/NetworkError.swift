//
//  NetworkError.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation

enum NetworkError: Error, Equatable {
    case invalidURL
    case requestFailed
    case invalidResponse
    case decodingFailed
    case invalidStatusCode(Int)
    case emptyData
    case unknownError
    case customError(String)
    case refreshTokenInvalid
    case userSessionInvalid
    
    // 서버 에러 코드에 따른 처리
    case invalidAccessToken        // 401
    case forbidden                  // 403
    case accessTokenExpired        // 419
    case invalidSesacKey           // 420
    case refreshTokenExpired       // 418
    case tooManyRequests           // 429
    case invalidAPICall            // 444
    case serverError               // 500
    
    // 비즈니스 로직 에러
    case missingRequiredFields     // 400
    case emailAlreadyExists        // 409
    case invalidCredentials        // 401 (로그인 실패)
    
    var errorMessage: String {
        switch self {
        case .invalidURL:
            return "유효하지 않은 URL입니다."
        case .requestFailed:
            return "요청에 실패했습니다."
        case .invalidResponse:
            return "유효하지 않은 응답입니다."
        case .decodingFailed:
            return "데이터 디코딩에 실패했습니다."
        case .invalidStatusCode(let code):
            return "서버 오류: \(code) 상태 코드"
        case .emptyData:
            return "데이터가 비어있습니다."
        case .unknownError:
            return "알 수 없는 오류가 발생했습니다."
        case .customError(let message):
            return message
        case .invalidAccessToken:
            return "인증할 수 없는 엑세스 토큰입니다."
        case .forbidden:
            return "접근 권한이 없습니다."
        case .accessTokenExpired:
            return "액세스 토큰이 만료되었습니다."
        case .invalidSesacKey:
            return "유효하지 않은 SeSAC 키입니다."
        case .refreshTokenExpired:
            return "리프레시 토큰이 만료되었습니다. 다시 로그인 해주세요."
        case .refreshTokenInvalid:
                    return "세션이 만료되었습니다. 다시 로그인해주세요."
        case .userSessionInvalid:
                    return "사용자 세션이 변경되었습니다. 다시 로그인해주세요."                
        case .tooManyRequests:
            return "과도한 요청이 발생했습니다. 잠시 후 다시 시도해주세요."
        case .invalidAPICall:
            return "잘못된 API 호출입니다."
        case .serverError:
            return "서버 오류가 발생했습니다."
        case .missingRequiredFields:
            return "필수 입력값을 모두 채워주세요."
        case .emailAlreadyExists:
            return "이미 사용 중인 이메일입니다."
        case .invalidCredentials:
            return "이메일 또는 비밀번호가 일치하지 않습니다."
        }
    }
}
