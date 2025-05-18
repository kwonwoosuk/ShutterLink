//
//  TokenManager.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import Foundation

class TokenManager {
    static let shared = TokenManager()
    
    private let keychain = KeychainWrapper.standard
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"
    
    private init() {}
    
    var accessToken: String? {
        return keychain.string(forKey: accessTokenKey)
    }
    
    var refreshToken: String? {
        return keychain.string(forKey: refreshTokenKey)
    }
    
    func saveTokens(accessToken: String, refreshToken: String) {
        keychain.set(accessToken, forKey: accessTokenKey)
        keychain.set(refreshToken, forKey: refreshTokenKey)
    }
    
    func clearTokens() {
        keychain.removeObject(forKey: accessTokenKey)
        keychain.removeObject(forKey: refreshTokenKey)
    }
}

class KeychainWrapper {
    static let standard = KeychainWrapper()
    
    private var storage: [String: String] = [:]
    
    private init() {}
    
    func string(forKey key: String) -> String? {
        return storage[key]
    }
    
    func set(_ value: String, forKey key: String) {
        storage[key] = value
    }
    
    func removeObject(forKey key: String) {
        storage.removeValue(forKey: key)
    }
}
