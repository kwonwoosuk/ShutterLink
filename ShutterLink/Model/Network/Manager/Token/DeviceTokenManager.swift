//
//  DeviceTokenManager.swift
//  ShutterLink
//
//  Created by 권우석 on 5/18/25.
//

import Foundation
import SwiftUI
import UserNotifications
import Security

final class DeviceTokenManager: ObservableObject {
    static let shared = DeviceTokenManager()
    
    private let tokenKey = "device_token_key"
    private let keychainService = "com.kwonws.ShutterLink"
    private let keychainAccount = "deviceToken"
    
    private init() {
        // 앱 처음 실행 시 토큰이 없으면 생성
        if getCurrentToken() == nil {
            generateNewToken()
        }
    }
    
    func getCurrentToken() -> String? {
        // 먼저 키체인에서 확인
        if let token = getTokenFromKeychain() {
            return token
        }
        
        // 키체인에 없으면 UserDefaults 확인 (이전 버전 호환성)
        return UserDefaults.standard.string(forKey: tokenKey)
    }
    
    func generateNewToken() -> String {
        // SwiftUI 환경에서 고유 식별자 생성
        let appInstallID = UUID().uuidString
        let timestamp = Date().timeIntervalSince1970
        let token = "\(appInstallID)_\(timestamp)".data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
        
        // KeyChain으로 토큰 저장 (앱 재설치해도 유지)
        storeInKeychain(token: token)
        
        // UserDefaults에도 저장 (빠른 접근용)
        UserDefaults.standard.set(token, forKey: tokenKey)
        
        return token
    }
    
    private func storeInKeychain(token: String) {
        guard let tokenData = token.data(using: .utf8) else { return }
        
        // 쿼리 준비
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: tokenData
        ]
        
        // 기존 항목 삭제
        SecItemDelete(query as CFDictionary)
        
        // 새 항목 추가
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("키체인에 토큰 저장 실패: \(status)")
        } else {
            print("키체인에 토큰 저장 성공")
        }
    }
    
    private func getTokenFromKeychain() -> String? {
        // 쿼리 준비
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        } else {
            if status != errSecItemNotFound {
                print("키체인에서 토큰 검색 실패: \(status)")
            }
            return nil
        }
    }
    
    func deleteTokenFromKeychain() {
        // 삭제 미구현 
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            print("키체인에서 토큰 삭제 실패: \(status)")
        } else {
            print("키체인에서 토큰 삭제됨 또는 이미 없음")
        }
    }
    
    // 기존 알림 관련 메서드들...
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("알림 권한 획득 완료")
            } else {
                print("알림 권한 거부됨: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }
    
    func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
