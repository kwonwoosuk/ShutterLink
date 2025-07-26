//
//  CurrentChatRoomManager.swift
//  ShutterLink
//
//  Created by 권우석 on 7/26/25.
//

import Foundation

final class CurrentChatRoomManager: ObservableObject {
    static let shared = CurrentChatRoomManager()
    
    @Published private(set) var currentRoomId: String?
    @Published private(set) var isInChatView: Bool = false
    
    private init() {}
    
    func enterChatRoom(_ roomId: String) {
        currentRoomId = roomId
        isInChatView = true
        
        print("🚪 CurrentChatRoomManager: 채팅방 진입 - roomId: \(roomId)")
        
        NotificationCenter.default.post(
            name: NSNotification.Name("DidEnterChatRoom"),
            object: nil,
            userInfo: ["roomId": roomId]
        )
    }
    
    func exitChatRoom() {
        let previousRoomId = currentRoomId
        currentRoomId = nil
        isInChatView = false
        
        print("🚪 CurrentChatRoomManager: 채팅방 나가기 - 이전 roomId: \(previousRoomId ?? "nil")")
        
        // NotificationCenter로 다른 컴포넌트에 알림
        NotificationCenter.default.post(
            name: NSNotification.Name("DidExitChatRoom"),
            object: nil,
            userInfo: ["previousRoomId": previousRoomId ?? ""]
        )
    }
    
    /// 특정 룸ID가 현재 채팅방인지 확인
    func isCurrentChatRoom(_ roomId: String) -> Bool {
        return isInChatView && currentRoomId == roomId
    }
    
    /// 앱이 백그라운드로 갈 때 호출
    func appDidEnterBackground() {
        print("📱 CurrentChatRoomManager: 앱 백그라운드 진입")
        // 채팅방에 있던 상태는 유지하되, 백그라운드 상태임을 표시
    }
    
    /// 앱이 포그라운드로 올 때 호출
    func appWillEnterForeground() {
        print("📱 CurrentChatRoomManager: 앱 포그라운드 진입")
        // 현재 채팅방 상태 복원
    }
    
    /// 디버깅용 현재 상태 출력
    func printCurrentState() {
        print("🔍 CurrentChatRoomManager 현재 상태:")
        print("   - currentRoomId: \(currentRoomId ?? "nil")")
        print("   - isInChatView: \(isInChatView)")
    }
}
