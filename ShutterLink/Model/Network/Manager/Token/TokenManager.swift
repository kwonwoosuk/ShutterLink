//
//  TokenManager.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation
import Security
import JWTDecode

// MARK: - Token Manager

final class TokenManager: ObservableObject {
    static let shared = TokenManager()
    
    private let service = Bundle.main.bundleIdentifier ?? "com.shutterlink.app"
    private let accessTokenKey = "AccessToken"
    private let refreshTokenKey = "RefreshToken"
    
    private init() {}
    
    // MARK: - Token Properties
    
    var accessToken: String? {
        get { getValue(forKey: accessTokenKey) }
        set {
            if let newValue = newValue {
                setValue(newValue, forKey: accessTokenKey)
            } else {
                deleteValue(forKey: accessTokenKey)
            }
        }
    }
    
    var refreshToken: String? {
        get { getValue(forKey: refreshTokenKey) }
        set {
            if let newValue = newValue {
                setValue(newValue, forKey: refreshTokenKey)
            } else {
                deleteValue(forKey: refreshTokenKey)
            }
        }
    }
    
    // MARK: - Token Management
    
    func saveTokens(accessToken: String, refreshToken: String) {
        print("🔑 TokenManager: 토큰 저장 시작")
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        print("✅ TokenManager: 토큰 저장 완료")
    }
    
    func clearTokens() {
        print("🔑 TokenManager: 토큰 삭제 시작")
        accessToken = nil
        refreshToken = nil
        print("✅ TokenManager: 토큰 삭제 완료")
    }
    
    func hasValidTokens() -> Bool {
        let hasTokens = accessToken != nil && refreshToken != nil
        print("🔍 TokenManager: 토큰 존재 여부 - \(hasTokens)")
        return hasTokens
    }
    
    // MARK: - Keychain Helper Methods
    
    private func setValue(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // 기존 항목 삭제
        SecItemDelete(query as CFDictionary)
        
        // 새 항목 추가
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain 저장 실패 (\(key)): \(status)")
        } else {
            print("Keychain 저장 성공 (\(key))")
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

// MARK: - JWT Token Extensions

extension TokenManager {
    /// 현재 로그인된 사용자의 ID를 반환
    func getCurrentUserId() -> String? {
        guard let accessToken = accessToken else {
            print("❌ TokenManager: 액세스 토큰이 없습니다")
            return nil
        }
        
        do {
            let jwt = try decode(jwt: accessToken)
            if let userId = jwt.claim(name: "id").string {
                print("✅ TokenManager: 사용자 ID 추출 성공 (id) - \(userId)")
                return userId
            } else if let userId = jwt.claim(name: "user_id").string {
                print("✅ TokenManager: 사용자 ID 추출 성공 (user_id) - \(userId)")
                return userId
            } else if let userId = jwt.claim(name: "sub").string {
                print("✅ TokenManager: 사용자 ID 추출 성공 (sub) - \(userId)")
                return userId
            } else {
                print("⚠️ TokenManager: JWT에서 사용자 ID를 찾을 수 없습니다")
                
                return nil
            }
            
        } catch {
            print("❌ TokenManager: JWT 디코딩 실패 - \(error)")
            print("📋 TokenManager: 토큰 일부 - \(String(accessToken.prefix(50)))...")
            return nil
        }
    }

    func getCurrentUserNick() -> String? {
        guard let accessToken = accessToken else {
            print("❌ TokenManager: 액세스 토큰이 없습니다 (닉네임 조회)")
            return nil
        }
        
        do {
            let jwt = try decode(jwt: accessToken)
            if let nick = jwt.claim(name: "nick").string {
                print("✅ TokenManager: 닉네임 추출 성공 - \(nick)")
                return nick
            } else {
                print("⚠️ TokenManager: JWT에서 닉네임을 찾을 수 없습니다")
                return nil
            }
        } catch {
            print("❌ TokenManager: JWT에서 닉네임 추출 실패 - \(error)")
            return nil
        }
    }
    
    func getCurrentUserName() -> String? {
        guard let accessToken = accessToken else {
            print("❌ TokenManager: 액세스 토큰이 없습니다 (이름 조회)")
            return nil
        }
        
        do {
            let jwt = try decode(jwt: accessToken)
            if let name = jwt.claim(name: "name").string {
                print("✅ TokenManager: 이름 추출 성공 - \(name)")
                return name
            } else {
                print("⚠️ TokenManager: JWT에서 이름을 찾을 수 없습니다")
                return nil
            }
        } catch {
            print("❌ TokenManager: JWT에서 이름 추출 실패 - \(error)")
            return nil
        }
    }
    
    func isTokenValid() -> Bool {
        guard let accessToken = accessToken else {
            print("❌ TokenManager: 액세스 토큰이 없습니다 (유효성 검사)")
            return false
        }
        
        do {
            let jwt = try decode(jwt: accessToken)
            let isValid = !jwt.expired
            print("🔍 TokenManager: 토큰 유효성 - \(isValid)")
            if !isValid {
                print("⏰ TokenManager: 토큰 만료됨 - \(String(describing: jwt.expiresAt))")
            }
            return isValid
        } catch {
            print("❌ TokenManager: 토큰 유효성 검사 실패 - \(error)")
            return false
        }
    }
    
    func getTokenExpirationTime() -> Date? {
        guard let accessToken = accessToken else {
            print("❌ TokenManager: 액세스 토큰이 없습니다 (만료시간 조회)")
            return nil
        }
        
        do {
            let jwt = try decode(jwt: accessToken)
            let expirationTime = jwt.expiresAt
            print("📅 TokenManager: 토큰 만료 시간 - \(String(describing: expirationTime))")
            return expirationTime
        } catch {
            print("❌ TokenManager: 토큰 만료시간 조회 실패 - \(error)")
            return nil
        }
    }
    
    func debugToken() {
        guard let accessToken = accessToken else {
            print("🚫 TokenManager: 디버깅할 토큰이 없습니다")
            return
        }
        
        print("🔍 TokenManager: JWT 토큰 디버깅 시작")
        print("📝 TokenManager: 토큰 길이 - \(accessToken.count) 문자")
        print("📝 TokenManager: 토큰 시작 - \(String(accessToken.prefix(50)))...")
        
        do {
            let jwt = try decode(jwt: accessToken)
            print("✅ TokenManager: JWT 디코딩 성공")
            print("📋 TokenManager: 전체 Claims - \(jwt.body)")
            
            ["id", "user_id", "sub", "nick", "name", "email", "iat", "exp", "iss"].forEach { key in
                if let value = jwt.claim(name: key).string {
                    print("  - \(key): \(value)")
                } else if let value = jwt.claim(name: key).integer {
                    print("  - \(key): \(value)")
                } else if let value = jwt.claim(name: key).date {
                    print("  - \(key): \(value)")
                }
            }
            
        } catch {
            print("❌ TokenManager: JWT 디코딩 실패 - \(error)")
        }
    }
}

struct CurrentUserInfo {
    let userId: String
    let nick: String?
    let name: String?
    let email: String?
    
    init?(from tokenManager: TokenManager) {
        guard let userId = tokenManager.getCurrentUserId() else {
            print("❌ CurrentUserInfo: 사용자 ID를 가져올 수 없습니다")
            return nil
        }
        
        self.userId = userId
        self.nick = tokenManager.getCurrentUserNick()
        self.name = tokenManager.getCurrentUserName()
        self.email = nil // 필요시 추가
        
        print("✅ CurrentUserInfo: 사용자 정보 생성 완료 - ID: \(userId), 닉네임: \(nick ?? "nil")")
    }
}
