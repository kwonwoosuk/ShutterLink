//
//  TokenManager.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation
import Security
import JWTDecode

final class TokenManager {
    static let shared = TokenManager()
    
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"
    private let service = "com.shutterlink.app"
    
    private init() {}
    
    var accessToken: String? {
        getValue(forKey: accessTokenKey)
    }
    
    var refreshToken: String? {
        getValue(forKey: refreshTokenKey)
    }
    
    func saveTokens(accessToken: String, refreshToken: String) {
        setValue(accessToken, forKey: accessTokenKey)
        setValue(refreshToken, forKey: refreshTokenKey)
    }
    
    func clearTokens() {
        deleteValue(forKey: accessTokenKey)
        deleteValue(forKey: refreshTokenKey)
        print("🗑️ Keychain 토큰 삭제 완료")
    }
    
    private func setValue(_ value: String, forKey key: String) {
        deleteValue(forKey: key)
        
        guard let data = value.data(using: .utf8) else {
            print("Keychain: \(key) 데이터 변환 실패")
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain 저장 실패 (\(key)): \(status)")
        } else {
            print("Keychain 저장 성공 (\(key)): \(value)")
        }
    }
    
    private func getValue(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            if status == errSecItemNotFound {
                print("Keychain: \(key) 데이터 없음")
            } else {
                print("Keychain 조회 실패 (\(key)): \(status)")
            }
            return nil
        }
        print("Keychain 조회 성공 (\(key)): \(value)")
        return value
    }
    
    private func deleteValue(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Keychain 삭제 실패 (\(key)): \(status)")
        } else {
            print("Keychain 삭제 성공 (\(key))")
        }
    }
}

extension TokenManager {
    /// 현재 로그인된 사용자의 ID를 반환
    func getCurrentUserId() -> String? {
        guard let accessToken = accessToken else {
            print("❌ TokenManager: 액세스 토큰이 없습니다")
            return nil
        }
        
        do {
            // JWT 토큰 디코딩하여 사용자 ID 추출
            let jwt = try decode(jwt: accessToken)
            
            // 토큰의 payload에서 사용자 ID 추출
            // 일반적으로 "sub", "user_id", "id" 등의 키로 저장됨
            if let userId = jwt.claim(name: "id").string {
                print("✅ TokenManager: 사용자 ID 추출 성공 - \(userId)")
                return userId
            } else if let userId = jwt.claim(name: "user_id").string {
                print("✅ TokenManager: 사용자 ID 추출 성공 - \(userId)")
                return userId
            } else if let userId = jwt.claim(name: "sub").string {
                print("✅ TokenManager: 사용자 ID 추출 성공 - \(userId)")
                return userId
            } else {
                print("⚠️ TokenManager: JWT에서 사용자 ID를 찾을 수 없습니다")
                
                // 디버깅용: 토큰의 모든 claim 출력
                print("📋 TokenManager: JWT Claims - \(jwt.body)")
                return nil
            }
            
        } catch {
            print("❌ TokenManager: JWT 디코딩 실패 - \(error)")
            return nil
        }
    }
    
    /// 현재 로그인된 사용자의 닉네임을 반환
    func getCurrentUserNick() -> String? {
        guard let accessToken = accessToken else { return nil }
        
        do {
            let jwt = try decode(jwt: accessToken)
            return jwt.claim(name: "nick").string
        } catch {
            print("❌ TokenManager: JWT에서 닉네임 추출 실패 - \(error)")
            return nil
        }
    }
    
    /// 현재 로그인된 사용자의 이름을 반환
    func getCurrentUserName() -> String? {
        guard let accessToken = accessToken else { return nil }
        
        do {
            let jwt = try decode(jwt: accessToken)
            return jwt.claim(name: "name").string
        } catch {
            print("❌ TokenManager: JWT에서 이름 추출 실패 - \(error)")
            return nil
        }
    }
    
    /// JWT 토큰이 유효한지 확인
    func isTokenValid() -> Bool {
        guard let accessToken = accessToken else { return false }
        
        do {
            let jwt = try decode(jwt: accessToken)
            return !jwt.expired
        } catch {
            return false
        }
    }
    
    /// JWT 토큰 만료 시간 반환
    func getTokenExpirationTime() -> Date? {
        guard let accessToken = accessToken else { return nil }
        
        do {
            let jwt = try decode(jwt: accessToken)
            return jwt.expiresAt
        } catch {
            return nil
        }
    }
}

// MARK: - 사용자 정보 모델

struct CurrentUserInfo {
    let userId: String
    let nick: String?
    let name: String?
    let email: String?
    
    init?(from tokenManager: TokenManager) {
        guard let userId = tokenManager.getCurrentUserId() else {
            return nil
        }
        
        self.userId = userId
        self.nick = tokenManager.getCurrentUserNick()
        self.name = tokenManager.getCurrentUserName()
        self.email = nil // 필요시 추가
    }
}
