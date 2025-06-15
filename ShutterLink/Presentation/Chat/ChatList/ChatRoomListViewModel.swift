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
        // ✅ 채팅방 삭제 Input 추가
        let deleteChatRoom = PassthroughSubject<String, Never>() // roomId
    }
    
    @Published var chatRooms: [ChatRoom] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRefreshing = false
    @Published var showError = false
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    let chatUseCase: ChatUseCase
    
    init(chatUseCase: ChatUseCase) {
        self.chatUseCase = chatUseCase
        setupBindings()
        setupObservers()
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
        
        // ✅ 채팅방 삭제
        input.deleteChatRoom
            .sink { [weak self] roomId in
                self?.deleteChatRoom(roomId: roomId)
            }
            .store(in: &cancellables)
    }
    
    private func setupObservers() {
        // 실시간 채팅방 목록 관찰
        chatUseCase.observeChatRooms()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chatRooms in
                self?.chatRooms = chatRooms
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
                
                // 2. 서버와 동기화
                let syncedChatRooms = try await chatUseCase.syncChatRooms()
                chatRooms = syncedChatRooms
                
                print("✅ ChatRoomListViewModel: 채팅방 목록 로드 완료 - 개수: \(syncedChatRooms.count)")
                
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
                
                // 채팅방 목록을 새로고침하여 최신 상태 반영
                try await chatUseCase.syncChatRooms()
                
            } catch {
                print("❌ ChatRoomListViewModel: 채팅방 생성 실패 - \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isLoading = false
        }
    }
    
    // ✅ 채팅방 삭제 기능
    private func deleteChatRoom(roomId: String) {
        Task { @MainActor in
            print("🗑️ ChatRoomListViewModel: 채팅방 삭제 시작 - roomId: \(roomId)")
            
            do {
                try await chatUseCase.deleteChatRoom(roomId: roomId)
                print("✅ ChatRoomListViewModel: 채팅방 삭제 완료 - roomId: \(roomId)")
                
                // 삭제 후 채팅방 목록 새로고침
                let syncedChatRooms = try await chatUseCase.getChatRooms()
                chatRooms = syncedChatRooms
                
            } catch {
                print("❌ ChatRoomListViewModel: 채팅방 삭제 실패 - \(error)")
                errorMessage = "채팅방 삭제에 실패했습니다."
                showError = true
            }
        }
    }
}
