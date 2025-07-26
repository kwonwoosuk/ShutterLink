//
//  UnreadMessageManager.swift
//  ShutterLink
//
//  Created by 권우석 on 7/22/25.
//

import Foundation
import Combine
import UIKit

final class UnreadMessageManager: ObservableObject {
    static let shared = UnreadMessageManager()
    
    @Published var unreadCounts: [String: Int] = [:] // roomId: unreadCount
    @Published var totalUnreadCount: Int = 0 // 앱 뱃지용 총 개수
    
    private let userDefaults = UserDefaults.standard
    private let lastReadMessageIdKey = "ChatRoom_LastReadMessageId"
    private let chatUseCase: ChatUseCase
    
    private init() {
        // 임시로 nil로 초기화, 실제 사용 시에는 의존성 주입 필요
        let localRepository = try! RealmChatRepository()
        self.chatUseCase = ChatUseCaseImpl(localRepository: localRepository)
        
        loadUnreadCounts()
        updateAppBadge()
    }
    
    // MARK: - Public Methods
    
    /// 특정 채팅방의 안읽은 메시지 개수 반환
    func getUnreadCount(for roomId: String) -> Int {
        return unreadCounts[roomId] ?? 0
    }
    
    /// 채팅방 진입 시 마지막 읽은 메시지 ID 업데이트
    func markAsRead(roomId: String, lastChatId: String?) {
        if let chatId = lastChatId {
            setLastReadMessageId(for: roomId, chatId: chatId)
            print("✅ UnreadMessageManager: 채팅방 읽음 처리 - roomId: \(roomId), lastChatId: \(chatId)")
        }
        
        // 해당 채팅방의 안읽은 메시지 개수를 0으로 설정
        updateUnreadCount(for: roomId, count: 0)
    }
    
    /// FCM 알림 수신 시 호출 - 서버에서 최신 데이터 가져와서 업데이트
    func handleFCMNotification() async {
        print("🔔 UnreadMessageManager: FCM 알림 수신 - 채팅방 데이터 새로고침")
        
        do {
            // 서버에서 최신 채팅방 목록 가져오기
            let latestChatRooms = try await chatUseCase.syncChatRooms()
            
            await MainActor.run {
                updateUnreadCountsWithLatestData(latestChatRooms)
            }
        } catch {
            print("❌ UnreadMessageManager: FCM 처리 중 오류 - \(error)")
        }
    }
    
    /// 특정 채팅방의 안읽은 메시지 개수 업데이트
    func updateUnreadCount(for roomId: String, count: Int) {
        let clampedCount = max(0, count)
        let oldCount = unreadCounts[roomId] ?? 0
        
        if oldCount != clampedCount {
            unreadCounts[roomId] = clampedCount
            
            // 전체 개수 재계산
            let newTotal = unreadCounts.values.reduce(0, +)
            totalUnreadCount = newTotal
            
            print("📊 UnreadMessageManager: 채팅방 \(roomId) 안읽은 메시지 \(oldCount) → \(clampedCount), 전체: \(newTotal)")
            
            // 앱 뱃지 즉시 업데이트
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = newTotal
                print("🔢 앱 뱃지 업데이트: \(newTotal)")
            }
            
            // UserDefaults에 저장
            saveUnreadCounts()
        }
    }
    
    /// 최신 채팅방 데이터로 안읽은 메시지 개수 계산
    func updateUnreadCountsWithLatestData(_ chatRooms: [ChatRoom]) {
        guard let currentUserId = getCurrentUserId() else { return }
        
        var newUnreadCounts: [String: Int] = [:]
        
        for chatRoom in chatRooms {
            let lastReadMessageId = getLastReadMessageId(for: chatRoom.roomId)
            
            // 마지막 읽은 메시지 이후의 새 메시지 개수 계산
            let unreadCount = calculateUnreadCount(
                chatRoom: chatRoom,
                lastReadMessageId: lastReadMessageId,
                currentUserId: currentUserId
            )
            
            newUnreadCounts[chatRoom.roomId] = unreadCount
        }
        
        // 기존 unreadCounts와 비교하여 변경된 경우만 업데이트
        let hasChanges = newUnreadCounts != unreadCounts
        
        if hasChanges {
            unreadCounts = newUnreadCounts
            let newTotal = newUnreadCounts.values.reduce(0, +)
            totalUnreadCount = newTotal
            
            print("📊 UnreadMessageManager: 전체 안읽은 메시지 업데이트 - 총 \(newTotal)개")
            for (roomId, count) in newUnreadCounts where count > 0 {
                print("   채팅방 \(roomId): \(count)개")
            }
            
            // 앱 뱃지 업데이트
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = newTotal
                print("🔢 앱 뱃지 업데이트: \(newTotal)")
            }
            
            saveUnreadCounts()
        }
    }
    
    /// 메시지 ID 기반으로 안읽은 메시지 개수 계산
    private func calculateUnreadCountByMessageId(for chatRoom: ChatRoom, currentUserId: String) -> Int {
        // 본인이 보낸 마지막 메시지면 안읽은 메시지 없음
        guard let lastChat = chatRoom.lastChat,
              !lastChat.isFromCurrentUser else {
            return 0
        }
        
        // 마지막으로 읽은 메시지 ID 가져오기
        let lastReadMessageId = getLastReadMessageId(for: chatRoom.roomId)
        
        // 읽은 적이 없거나, 새로운 메시지가 있으면 카운트
        if lastReadMessageId.isEmpty || lastChat.chatId != lastReadMessageId {
            // 실제로는 서버 API나 로컬 DB에서 정확한 개수를 계산해야 하지만
            // 현재는 단순화해서 1로 표시 (lastChat이 새로우면 최소 1개는 있음)
            return calculateDetailedUnreadCount(
                roomId: chatRoom.roomId,
                lastReadMessageId: lastReadMessageId,
                currentLastChatId: lastChat.chatId
            )
        }
        
        return 0
    }
    
    /// 상세한 안읽은 메시지 개수 계산 (로컬 DB 활용)
    private func calculateDetailedUnreadCount(roomId: String, lastReadMessageId: String, currentLastChatId: String) -> Int {
        // 비동기 작업을 동기적으로 처리하기 위한 임시 구현
        // 실제로는 더 효율적인 방법을 사용해야 함
        
        // 단순화: 마지막 읽은 메시지와 현재 마지막 메시지가 다르면 1개로 표시
        // 실제 구현에서는 로컬 DB에서 해당 범위의 메시지 개수를 조회
        return lastReadMessageId != currentLastChatId ? 1 : 0
    }
    
    // MARK: - Message ID Management
    
    private func getLastReadMessageId(for roomId: String) -> String {
        let key = "\(lastReadMessageIdKey)_\(roomId)"
        return userDefaults.string(forKey: key) ?? ""
    }
    
    private func setLastReadMessageId(for roomId: String, chatId: String) {
        let key = "\(lastReadMessageIdKey)_\(roomId)"
        userDefaults.set(chatId, forKey: key)
    }
    
    // MARK: - App Badge Management
    
    private func updateAppBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = self.totalUnreadCount
            print("📱 앱 뱃지 업데이트: \(self.totalUnreadCount)")
        }
    }
    
    // MARK: - Persistence
    
    private func loadUnreadCounts() {
        if let data = userDefaults.data(forKey: "UnreadMessageCounts"),
           let counts = try? JSONDecoder().decode([String: Int].self, from: data) {
            unreadCounts = counts
            totalUnreadCount = counts.values.reduce(0, +)
        }
    }
    
    private func saveUnreadCounts() {
        if let data = try? JSONEncoder().encode(unreadCounts) {
            userDefaults.set(data, forKey: "UnreadMessageCounts")
        }
    }
    
    // MARK: - Utility
    
    private func getCurrentUserId() -> String? {
        return TokenManager.shared.getCurrentUserId()
    }

    // MARK: - 1. 새로 추가할 메서드

    /// 앱 포그라운드 진입 시 뱃지 동기화
    func syncBadgeCount() async {
        await MainActor.run {
            let currentTotal = unreadCounts.values.reduce(0, +)
            totalUnreadCount = currentTotal
            UIApplication.shared.applicationIconBadgeNumber = currentTotal
            print("🔄 UnreadMessageManager: 뱃지 동기화 완료 - \(currentTotal)")
        }
    }

    /// 정확한 안읽은 메시지 개수 계산 헬퍼 메서드
    private func calculateUnreadCount(chatRoom: ChatRoom, lastReadMessageId: String, currentUserId: String) -> Int {
        // 마지막 채팅이 없으면 0
        guard let lastChat = chatRoom.lastChat else { return 0 }
        
        // 마지막 채팅이 내가 보낸 메시지면 0
        if lastChat.sender.userId == currentUserId { return 0 }
        
        // 마지막 읽은 메시지 ID가 없으면 1 (새 메시지 있음)
        if lastReadMessageId.isEmpty { return 1 }
        
        // 마지막 채팅 ID와 마지막 읽은 메시지 ID 비교
        if lastChat.chatId != lastReadMessageId { return 1 }
        
        return 0
    }
}



// MARK: - ChatRoom Extension

extension ChatRoom {
    func getUnreadCount(currentUserId: String) -> Int {
        return UnreadMessageManager.shared.getUnreadCount(for: self.roomId)
    }
}
