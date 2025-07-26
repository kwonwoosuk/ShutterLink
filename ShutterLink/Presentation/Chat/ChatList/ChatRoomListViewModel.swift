//
//  ChatRoomListViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import SwiftUI
import Combine

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
                // 1. 로컬 채팅방 목록 먼저 로드
                let localChatRooms = try await chatUseCase.getChatRooms()
                chatRooms = localChatRooms
                print("📱 ChatRoomListViewModel: 로컬 채팅방 \(localChatRooms.count)개 로드")
                
                // 2. 서버 동기화
                let syncedChatRooms = try await chatUseCase.syncChatRooms()
                chatRooms = syncedChatRooms
                print("🔄 ChatRoomListViewModel: 서버 동기화 완료 - \(syncedChatRooms.count)개")
                
                // ✅ 3. 안읽은 메시지 개수 업데이트
                updateUnreadCounts()
                
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                print("❌ ChatRoomListViewModel: 채팅방 목록 로드 실패 - \(error)")
            }
            
            isLoading = false
        }
    }
    
    private func refreshChatRooms() {
        Task { @MainActor in
            isRefreshing = true
            
            do {
                let refreshedChatRooms = try await chatUseCase.syncChatRooms()
                chatRooms = refreshedChatRooms
                print("🔄 ChatRoomListViewModel: 새로고침 완료 - \(refreshedChatRooms.count)개")
                
                // ✅ 안읽은 메시지 개수 업데이트
                updateUnreadCounts()
                
            } catch {
                errorMessage = "새로고침 중 오류가 발생했습니다: \(error.localizedDescription)"
                showError = true
                print("❌ ChatRoomListViewModel: 새로고침 실패 - \(error)")
            }
            
            isRefreshing = false
        }
    }
    
    // ✅ 안읽은 메시지 개수 업데이트
    private func updateUnreadCounts() {
        print("🔢 ChatRoomListViewModel: 안읽은 메시지 개수 업데이트 시작")
        
        Task {
            await unreadMessageManager.handleFCMNotification()
        }
    }
    
    private func createChatRoom(opponentId: String) {
        Task { @MainActor in
            do {
                let newChatRoom = try await chatUseCase.createOrGetChatRoom(opponentId: opponentId)
                print("✅ ChatRoomListViewModel: 채팅방 생성 완료 - roomId: \(newChatRoom.roomId)")
                
                // 채팅방 목록 새로고침
                input.loadChatRooms.send()
                
            } catch {
                errorMessage = "채팅방 생성에 실패했습니다: \(error.localizedDescription)"
                showError = true
                print("❌ ChatRoomListViewModel: 채팅방 생성 실패 - \(error)")
            }
        }
    }
    
    private func deleteChatRoom(roomId: String) {
        Task { @MainActor in
            do {
                try await chatUseCase.deleteChatRoom(roomId: roomId)
                print("✅ ChatRoomListViewModel: 채팅방 삭제 완료 - roomId: \(roomId)")
                
                // ✅ 안읽은 개수에서도 제거
                unreadMessageManager.updateUnreadCount(for: roomId, count: 0)
                
                // 채팅방 목록 새로고침
                input.loadChatRooms.send()
                
            } catch {
                errorMessage = "채팅방 삭제에 실패했습니다: \(error.localizedDescription)"
                showError = true
                print("❌ ChatRoomListViewModel: 채팅방 삭제 실패 - \(error)")
            }
        }
    }
    
    /// 채팅방 진입 시 읽음 처리
    func enterChatRoom(roomId: String) {
        print("🚪 ChatRoomListViewModel: 채팅방 진입 처리 - roomId: \(roomId)")
        
        // 해당 채팅방의 마지막 메시지 ID로 읽음 처리
        if let chatRoom = chatRooms.first(where: { $0.roomId == roomId }),
           let lastChat = chatRoom.lastChat {
            unreadMessageManager.markAsRead(roomId: roomId, lastChatId: lastChat.chatId)
        } else {
            // 마지막 메시지가 없어도 안읽은 개수는 0으로 설정
            unreadMessageManager.markAsRead(roomId: roomId, lastChatId: nil)
        }
    }
    
    /// FCM 알림 처리 (채팅방 목록도 함께 새로고침)
    private func handleFCMNotification() {
        print("🔔 ChatRoomListViewModel: FCM 알림 처리 시작")
        
        Task { @MainActor in
            do {
                // ✅ 1. 서버에서 최신 채팅방 목록 가져오기 (lastChat 업데이트)
                let latestChatRooms = try await chatUseCase.syncChatRooms()
                
                // ✅ 2. UI 업데이트
                chatRooms = latestChatRooms
                print("✅ ChatRoomListViewModel: FCM으로 인한 채팅방 목록 업데이트 - \(latestChatRooms.count)개")
                
                // ✅ 3. 안읽은 메시지 개수도 업데이트
                await unreadMessageManager.handleFCMNotification()
                
            } catch {
                print("❌ ChatRoomListViewModel: FCM 처리 실패 - \(error)")
            }
        }
    }
    
    // ✅ UnreadMessageManager에서 안읽은 개수 가져오기
    func getUnreadCount(for roomId: String) -> Int {
        return unreadMessageManager.getUnreadCount(for: roomId)
    }
    
    // MARK: - 유틸리티
    
    private func getCurrentUserId() -> String? {
        return TokenManager.shared.getCurrentUserId()
    }
}

// MARK: - Static Method for FCM Notification

extension ChatRoomListViewModel {
    static func handleGlobalFCMNotification() {
        Task {
            await UnreadMessageManager.shared.handleFCMNotification()
        }
    }
}
