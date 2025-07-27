//
//  FCMTokenManager.swift
//  ShutterLink
//
//  Created by 권우석 on 7/21/25.
//

import Foundation
import FirebaseMessaging
import Security

final class FCMTokenManager: ObservableObject {
    static let shared = FCMTokenManager()
    
    @Published var currentFCMToken: String?
    
    private let keychainService = "com.kwonws.ShutterLink"
    private let keychainAccount = "fcmToken"
    private let userUseCase: UserUseCase
    
    private init() {
        self.userUseCase = UserUseCaseImpl()
        
        loadSavedToken()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFCMTokenRefresh),
            name: Notification.Name("FCMToken"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    func getCurrentFCMToken() -> String? {
        return currentFCMToken
    }
    
    func refreshFCMToken() {
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("❌ FCM 토큰 갱신 실패: \(error)")
            } else if let token = token {
                print("✅ FCM 토큰 갱신 성공: \(token)")
                self?.updateFCMToken(token)
            }
        }
    }
    
    /// APNS 토큰 설정 후 FCM 토큰 요청
    func requestFCMTokenAfterAPNS() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshFCMToken()
        }
    }
    
    func syncTokenWithServer() async {
        guard let token = currentFCMToken else {
            print("⚠️ FCM 토큰이 없어서 서버 동기화 불가")
            return
        }
        
        await sendTokenToServer(token)
    }
    
    // MARK: - Private Methods
    
    private func loadSavedToken() {
        currentFCMToken = getTokenFromKeychain()
    }
    
    private func updateFCMToken(_ token: String) {
        DispatchQueue.main.async { [weak self] in
            self?.currentFCMToken = token
            self?.saveTokenToKeychain(token)
            
            // 서버에 토큰 업데이트 (백그라운드에서 실행)
            Task {
                await self?.sendTokenToServer(token)
            }
        }
    }
    
    private func sendTokenToServer(_ token: String) async {
        guard AuthState.shared.isLoggedIn else {
            print("⚠️ 로그인 상태가 아니므로 FCM 토큰 서버 전송 건너뛰기")
            return
        }
        
        do {
            try await userUseCase.updateDeviceToken(token)
            print("✅ FCM 토큰 서버 전송 성공")
        } catch {
            print("❌ FCM 토큰 서버 전송 실패: \(error)")
        }
    }
    
    @objc private func handleFCMTokenRefresh(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let token = userInfo["token"] as? String {
            updateFCMToken(token)
        }
    }
    
    // MARK: - Keychain Methods
    
    private func saveTokenToKeychain(_ token: String) {
        guard let tokenData = token.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: tokenData
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ FCM 토큰 키체인 저장 성공")
        } else {
            print("❌ FCM 토큰 키체인 저장 실패: \(status)")
        }
    }
    
    private func getTokenFromKeychain() -> String? {
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
        }
        
        return nil
    }
    
    func deleteFCMToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        SecItemDelete(query as CFDictionary)
        
        DispatchQueue.main.async { [weak self] in
            self?.currentFCMToken = nil
        }
        
        print("🗑️ FCM 토큰 삭제됨")
    }
}
