//
//  ChatRoomListViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import SwiftUI
import Combine

// MARK: - 채팅방 목록 ViewModel

final class ChatRoomListViewModel: ObservableObject {
    struct Input {
        let loadChatRooms = PassthroughSubject<Void, Never>()
        let refreshChatRooms = PassthroughSubject<Void, Never>()
        let createChatRoom = PassthroughSubject<String, Never>() // opponentId
        let deleteChatRoom = PassthroughSubject<String, Never>() // roomId
        let enterChatRoom = PassthroughSubject<String, Never>() // roomId - 채팅방 진입 시
        let handleFCMNotification = PassthroughSubject<Void, Never>() // FCM 알림 처리
    }
    
    
    
    @Published var chatRooms: [ChatRoom] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRefreshing = false
    @Published var showError = false
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    let chatUseCase: ChatUseCase
    private let unreadMessageManager = UnreadMessageManager.shared
    
    init(chatUseCase: ChatUseCase) {
        self.chatUseCase = chatUseCase
        setupBindings()
        setupObservers()
        setupUnreadMessageObserver()
    }
    
    private func setupBindings() {
        // 채팅방 목록 로드
        input.loadChatRooms
            .sink { [weak self] in
                self?.loadChatRooms()
            }
            .store(in: &cancellables)
        
        // 채팅방 목록 새로고침
        input.refreshChatRooms
            .sink { [weak self] in
                self?.refreshChatRooms()
            }
            .store(in: &cancellables)
        
        // 채팅방 생성
        input.createChatRoom
            .sink { [weak self] opponentId in
                self?.createChatRoom(opponentId: opponentId)
            }
            .store(in: &cancellables)
        
        // 채팅방 삭제
        input.deleteChatRoom
            .sink { [weak self] roomId in
                self?.deleteChatRoom(roomId: roomId)
            }
            .store(in: &cancellables)
        
        // 채팅방 진입
        input.enterChatRoom
            .sink { [weak self] roomId in
                print("📨 ChatRoomListViewModel: 채팅방 진입 요청 - roomId: \(roomId)")
                self?.enterChatRoom(roomId: roomId)
            }
            .store(in: &cancellables)
        
        // FCM 알림 처리
        input.handleFCMNotification
            .sink { [weak self] in
                self?.handleFCMNotification()
            }
            .store(in: &cancellables)
    }
    
    private func setupObservers() {
        // 실시간 채팅방 목록 관찰
        chatUseCase.observeChatRooms()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chatRooms in
                self?.chatRooms = chatRooms
                self?.updateUnreadCounts()
            }
            .store(in: &cancellables)
    }
    
    private func setupUnreadMessageObserver() {
        // UnreadMessageManager의 변경 사항 관찰
        unreadMessageManager.$unreadCounts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // 안읽은 메시지 개수 변경 시 UI 업데이트
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // 총 안읽은 메시지 개수 관찰 (앱 뱃지용)
        unreadMessageManager.$totalUnreadCount
            .receive(on: DispatchQueue.main)
            .sink { totalCount in
                print("📱 총 안읽은 메시지: \(totalCount)")
            }
            .store(in: &cancellables)
    }
    
    private func loadChatRooms() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            
            do {
                // 1. 로컬 데이터 먼저 로드
                let localChatRooms = try await chatUseCase.getChatRooms()
                chatRooms = localChatRooms
                updateUnreadCounts()
                
                // 2. 서버와 동기화 (백그라운드)
                Task {
                    do {
                        let syncedChatRooms = try await chatUseCase.syncChatRooms()
                        await MainActor.run {
                            chatRooms = syncedChatRooms
                            updateUnreadCounts()
                        }
                    } catch {
                        print("❌ 채팅방 동기화 실패: \(error)")
                    }
                }
                
                print("✅ ChatRoomListViewModel: 채팅방 목록 로드 완료 - 개수: \(localChatRooms.count)")
                
            } catch {
                print("❌ ChatRoomListViewModel: 채팅방 목록 로드 실패 - \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isLoading = false
        }
    }
    
    private func refreshChatRooms() {
        Task { @MainActor in
            isRefreshing = true
            errorMessage = nil
            
            do {
                let syncedChatRooms = try await chatUseCase.syncChatRooms()
                chatRooms = syncedChatRooms
                updateUnreadCounts()
                
                print("✅ ChatRoomListViewModel: 채팅방 목록 새로고침 완료 - 개수: \(syncedChatRooms.count)")
                
            } catch {
                print("❌ ChatRoomListViewModel: 채팅방 목록 새로고침 실패 - \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isRefreshing = false
        }
    }
    
    private func createChatRoom(opponentId: String) {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            
            do {
                let chatRoom = try await chatUseCase.createOrGetChatRoom(opponentId: opponentId)
                print("✅ ChatRoomListViewModel: 채팅방 생성 완료 - roomId: \(chatRoom.roomId)")
                
                // 새 채팅방이 목록에 없으면 추가
                if !chatRooms.contains(where: { $0.roomId == chatRoom.roomId }) {
                    chatRooms.insert(chatRoom, at: 0)
                    updateUnreadCounts()
                }
                
            } catch {
                print("❌ ChatRoomListViewModel: 채팅방 생성 실패 - \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isLoading = false
        }
    }
    
    private func deleteChatRoom(roomId: String) {
        Task { @MainActor in
            print("🗑️ ChatRoomListViewModel: 채팅방 삭제 시작 - roomId: \(roomId)")
            
            do {
                try await chatUseCase.deleteChatRoom(roomId: roomId)
                print("✅ ChatRoomListViewModel: 채팅방 삭제 완료 - roomId: \(roomId)")
                
                // 목록에서 제거
                chatRooms.removeAll { $0.roomId == roomId }
                
                // 안읽은 메시지 개수도 제거
                unreadMessageManager.updateUnreadCount(for: roomId, count: 0)
                
            } catch {
                print("❌ ChatRoomListViewModel: 채팅방 삭제 실패 - \(error)")
                errorMessage = "채팅방 삭제에 실패했습니다."
                showError = true
            }
        }
    }
    
    func enterChatRoom(roomId: String) {
        print("📖 ChatRoomListViewModel: 채팅방 진입 - roomId: \(roomId)")
        
        // 해당 채팅방의 마지막 메시지 ID로 읽음 처리
        if let chatRoom = chatRooms.first(where: { $0.roomId == roomId }) {
            let lastChatId = chatRoom.lastChat?.chatId
            
            // UnreadMessageManager에 읽음 처리 요청
            unreadMessageManager.markAsRead(roomId: roomId, lastChatId: lastChatId)
            
            print("✅ ChatRoomListViewModel: 채팅방 읽음 처리 완료 - roomId: \(roomId), lastChatId: \(lastChatId ?? "없음")")
            
            // 즉시 UI 업데이트를 위해 안읽은 메시지 개수 0으로 설정
            unreadMessageManager.updateUnreadCount(for: roomId, count: 0)
        } else {
            print("⚠️ ChatRoomListViewModel: 채팅방을 찾을 수 없음 - roomId: \(roomId)")
        }
    }
    
    // MARK: - FCM 알림 처리
    
    private func handleFCMNotification() {
        print("🔔 ChatRoomListViewModel: FCM 알림 처리 시작")
        
        Task {
            // UnreadMessageManager에서 FCM 처리 (서버 동기화 포함)
            await unreadMessageManager.handleFCMNotification()
            
            // 로컬 채팅방 목록도 업데이트
            await MainActor.run {
                input.refreshChatRooms.send()
            }
        }
    }
    
    // MARK: - 안읽은 메시지 관리
    
    private func updateUnreadCounts() {
        guard let currentUserId = getCurrentUserId() else { return }
        
        // 메시지 ID 기반으로 안읽은 메시지 개수 업데이트
        Task {
            await unreadMessageManager.updateUnreadCountsWithLatestData(chatRooms)
        }
    }
    
    func getUnreadCount(for roomId: String) -> Int {
        return unreadMessageManager.getUnreadCount(for: roomId)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserId() -> String? {
        return TokenManager.shared.getCurrentUserId()
    }
}

// MARK: - Static Method for FCM Notification

extension ChatRoomListViewModel {
    /// FCM 알림 수신 시 전역적으로 호출할 수 있는 메서드
    static func handleGlobalFCMNotification() {
        Task {
            await UnreadMessageManager.shared.handleFCMNotification()
        }
    }
}
