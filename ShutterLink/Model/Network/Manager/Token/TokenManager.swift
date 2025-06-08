//
//  TokenManager.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation
import Security

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
