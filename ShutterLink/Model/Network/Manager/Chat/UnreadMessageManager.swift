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
    
    /// 앱 시작 시 또는 주기적으로 안읽은 메시지 개수 새로고침
    func refreshUnreadCounts() async {
        await handleFCMNotification()
    }
    
    // MARK: - Private Methods - 실제 메시지 개수 계산
    
    func updateUnreadCountsWithLatestData(_ latestChatRooms: [ChatRoom]) {
        print("🔍 UnreadMessageManager: 안읽은 메시지 개수 계산 시작")
        
        for chatRoom in latestChatRooms {
            let roomId = chatRoom.roomId
            let serverLastChatId = chatRoom.lastChat?.chatId
            let storedLastReadId = getLastReadMessageId(for: roomId)
            
            print("📊 채팅방 \(roomId): 서버 최신 chatId=\(serverLastChatId ?? "nil"), 저장된 lastReadId=\(storedLastReadId ?? "nil")")
            
            // 비동기로 실제 안읽은 개수 계산
            Task {
                let unreadCount = await calculateRealUnreadCount(
                    roomId: roomId,
                    lastReadMessageId: storedLastReadId,
                    serverLastChatId: serverLastChatId
                )
                
                await MainActor.run {
                    updateUnreadCount(for: roomId, count: unreadCount)
                }
            }
        }
    }
    
    /// 실제 안읽은 메시지 개수 계산 (로컬 DB 활용)
    private func calculateRealUnreadCount(roomId: String, lastReadMessageId: String?, serverLastChatId: String?) async -> Int {
        print("🔢 UnreadMessageManager: 실제 안읽은 개수 계산 - roomId: \(roomId)")
        
        // Case 1: 서버에 최신 메시지가 없는 경우
        guard let serverLastChatId = serverLastChatId else {
            print("📭 채팅방 \(roomId): 서버에 메시지가 없음")
            return 0
        }
        
        // Case 2: 로컬에 읽음 기록이 없는 경우 (처음 방문)
        guard let lastReadMessageId = lastReadMessageId else {
            print("🆕 채팅방 \(roomId): 처음 방문 - 로컬에서 안읽은 개수 계산")
            return await calculateUnreadFromLocalMessages(roomId: roomId, lastReadMessageId: nil)
        }
        
        // Case 3: 서버의 최신 메시지와 읽은 메시지가 같은 경우
        if serverLastChatId == lastReadMessageId {
            print("✅ 채팅방 \(roomId): 모든 메시지 읽음")
            return 0
        }
        
        // Case 4: 새로운 메시지가 있는 경우 - 로컬에서 실제 개수 계산
        return await calculateUnreadFromLocalMessages(roomId: roomId, lastReadMessageId: lastReadMessageId)
    }
    
    /// 로컬 메시지에서 실제 안읽은 개수 계산
    private func calculateUnreadFromLocalMessages(roomId: String, lastReadMessageId: String?) async -> Int {
        do {
            let localMessages = try await chatUseCase.getLocalMessages(roomId: roomId)
            let currentUserId = TokenManager.shared.getCurrentUserId()
            
            print("📋 채팅방 \(roomId): 로컬 메시지 \(localMessages.count)개 조회")
            print("   - 현재 사용자 ID: \(currentUserId ?? "nil")")
            print("   - 마지막 읽은 메시지 ID: \(lastReadMessageId ?? "nil")")
            
            // 메시지를 시간순으로 정렬 (오래된 것부터)
            let sortedMessages = localMessages.sorted { $0.createdAt < $1.createdAt }
            
            var unreadCount = 0
            var foundLastRead = false
            
            if let lastReadMessageId = lastReadMessageId {
                // 마지막 읽은 메시지 이후의 메시지들만 계산
                for message in sortedMessages {
                    if foundLastRead {
                        // 현재 사용자가 보낸 메시지는 안읽은 개수에 포함하지 않음
                        if message.sender.userId != currentUserId {
                            unreadCount += 1
                            print("   📩 안읽은 메시지: \(message.chatId) - \(message.content)")
                        }
                    } else if message.chatId == lastReadMessageId {
                        foundLastRead = true
                        print("   📍 마지막 읽은 메시지 발견: \(message.chatId)")
                    }
                }
                
                // 마지막 읽은 메시지를 찾지 못한 경우, 모든 상대방 메시지를 안읽은 것으로 처리
                if !foundLastRead {
                    unreadCount = sortedMessages.filter { $0.sender.userId != currentUserId }.count
                    print("   ⚠️ 마지막 읽은 메시지를 찾지 못함, 모든 상대방 메시지를 안읽은 것으로 처리: \(unreadCount)개")
                }
            } else {
                // 마지막 읽은 메시지 기록이 없는 경우, 모든 상대방 메시지를 안읽은 것으로 처리
                unreadCount = sortedMessages.filter { $0.sender.userId != currentUserId }.count
                print("   🆕 읽음 기록 없음, 모든 상대방 메시지를 안읽은 것으로 처리: \(unreadCount)개")
            }
            
            print("✅ 채팅방 \(roomId): 실제 안읽은 개수 \(unreadCount)개")
            return unreadCount
            
        } catch {
            print("❌ UnreadMessageManager: 로컬 메시지 조회 실패 - \(error)")
            return 0
        }
    }
    
    // MARK: - Private Methods - 기존 로직 유지
    
    func updateUnreadCount(for roomId: String, count: Int) {
        let clampedCount = max(0, count)
        let oldCount = unreadCounts[roomId] ?? 0
        
        if oldCount != clampedCount {
            unreadCounts[roomId] = clampedCount
            calculateTotalUnreadCount()
            
            print("📊 UnreadMessageManager: 안읽은 개수 업데이트 - roomId: \(roomId), \(oldCount) → \(clampedCount)")
        }
    }
    
    private func calculateTotalUnreadCount() {
        let total = unreadCounts.values.reduce(0, +)
        if totalUnreadCount != total {
            totalUnreadCount = total
            updateAppBadge()
            
            print("🔢 UnreadMessageManager: 총 안읽은 개수 업데이트 - \(total)")
        }
    }
    
    private func updateAppBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = self.totalUnreadCount
        }
    }
    
    // MARK: - UserDefaults 관련
    
    private func setLastReadMessageId(for roomId: String, chatId: String) {
        let key = "\(lastReadMessageIdKey)_\(roomId)"
        userDefaults.set(chatId, forKey: key)
        print("💾 저장: \(key) = \(chatId)")
    }
    
    private func getLastReadMessageId(for roomId: String) -> String? {
        let key = "\(lastReadMessageIdKey)_\(roomId)"
        let value = userDefaults.string(forKey: key)
        print("📖 조회: \(key) = \(value ?? "nil")")
        return value
    }
    
    private func loadUnreadCounts() {
        // 앱 시작 시 저장된 안읽은 개수 로드 (필요시 구현)
        print("📚 UnreadMessageManager: 저장된 안읽은 개수 로드")
    }
}



// MARK: - ChatRoom Extension

extension ChatRoom {
    func getUnreadCount(currentUserId: String) -> Int {
        return UnreadMessageManager.shared.getUnreadCount(for: self.roomId)
    }
}
