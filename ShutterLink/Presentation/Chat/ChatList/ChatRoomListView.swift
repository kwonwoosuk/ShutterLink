//
//  ChatRoomListView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import SwiftUI

struct ChatRoomListView: View {
    @StateObject private var viewModel: ChatRoomListViewModel
    @StateObject private var unreadManager = UnreadMessageManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @State private var roomToDelete: ChatRoom?
    @State private var showDeleteAlert = false
    
    private let tokenManager = TokenManager.shared
    
    init() {
        let localRepository = try! RealmChatRepository()
        let chatUseCase = ChatUseCaseImpl(localRepository: localRepository)
        self._viewModel = StateObject(wrappedValue: ChatRoomListViewModel(chatUseCase: chatUseCase))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 헤더
                headerView
                
                // 콘텐츠
                if viewModel.isLoading && viewModel.chatRooms.isEmpty {
                    loadingView
                } else if viewModel.chatRooms.isEmpty {
                    emptyStateView
                } else {
                    chatRoomsList
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.input.loadChatRooms.send()
        }
        .refreshable {
            viewModel.input.refreshChatRooms.send()
        }
        // ✅ 추가: 푸시 알림으로 인한 자동 네비게이션 관찰
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToSpecificChatRoom"))) { notification in
            handlePushNavigationToChat(notification: notification)
        }
        // ✅ 추가: 앱이 포그라운드로 올 때 채팅방 목록 새로고침
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("📱 ChatRoomListView: 앱 포그라운드 진입 - 채팅방 목록 새로고침")
            viewModel.input.handleFCMNotification.send()
        }
        // ✅ 추가: FCM 알림 수신 시 채팅방 목록 새로고침
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FCMChatNotificationReceived"))) { _ in
            print("🔔 ChatRoomListView: FCM 채팅 알림 수신 - 채팅방 목록 새로고침")
            viewModel.input.handleFCMNotification.send()
        }
        .alert("오류", isPresented: $viewModel.showError) {
            Button("확인") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
        .alert("채팅방 삭제", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) {
                roomToDelete = nil
            }
            Button("삭제", role: .destructive) {
                if let room = roomToDelete {
                    deleteChatRoom(room)
                }
            }
        } message: {
            Text("이 채팅방을 삭제하시겠습니까? 모든 메시지가 영구적으로 삭제됩니다.")
        }
    }
    
    // ✅ 새로 추가: 푸시 알림으로 인한 자동 채팅방 네비게이션
    private func handlePushNavigationToChat(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let roomId = userInfo["roomId"] as? String else {
            print("⚠️ ChatRoomListView: roomId 정보 없음")
            return
        }
        
        print("🔔 ChatRoomListView: 푸시 알림으로 특정 채팅방 이동 - roomId: \(roomId)")
        
        // 해당 roomId의 채팅방 찾기
        if let targetChatRoom = viewModel.chatRooms.first(where: { $0.roomId == roomId }) {
            print("✅ ChatRoomListView: 대상 채팅방 찾음")
            
            // 기존 openChatRoom 메서드 사용
            openChatRoom(targetChatRoom)
            
        } else {
            print("⚠️ ChatRoomListView: 채팅방을 찾을 수 없음, 새로고침 후 재시도")
            
            // 채팅방 목록 새로고침 후 재시도
            viewModel.input.refreshChatRooms.send()
            
            // 잠시 후 재시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let targetChatRoom = viewModel.chatRooms.first(where: { $0.roomId == roomId }) {
                    openChatRoom(targetChatRoom)
                    print("✅ ChatRoomListView: 새로고침 후 채팅방 이동 완료")
                } else {
                    print("❌ ChatRoomListView: 새로고침 후에도 채팅방을 찾을 수 없음")
                }
            }
        }
    }
    
    // MARK: - 헤더
    
    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Text("문의 내역")
                .font(.pretendard(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }
    
    // MARK: - 로딩 뷰
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("채팅방 목록을 불러오는 중...")
                .font(.pretendard(size: 16, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 빈 상태 뷰
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("아직 채팅 내역이 없어요")
                    .font(.pretendard(size: 18, weight: .semiBold))
                    .foregroundColor(.white)
                
                Text("필터 상세 페이지에서 작가와\n채팅을 시작해보세요")
                    .font(.pretendard(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - 채팅방 목록
    
    private var chatRoomsList: some View {
        List {
            ForEach(viewModel.chatRooms) { chatRoom in
                ChatRoomCell(
                    chatRoom: chatRoom,
                    currentUserId: getCurrentUserId(),
                    unreadCount: viewModel.getUnreadCount(for: chatRoom.roomId)
                )
                .onTapGesture {
                    openChatRoom(chatRoom)
                }
                .listRowBackground(Color.black)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing) {
                    Button("삭제", role: .destructive) {
                        roomToDelete = chatRoom
                        showDeleteAlert = true
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .background(Color.black)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - 액션 메서드
    
    private func openChatRoom(_ chatRoom: ChatRoom) {
        print("🔓 ChatRoomListViewModel: 채팅방 열기 - roomId: \(chatRoom.roomId)")
        
        // 채팅방 진입 전 읽음 처리
        viewModel.enterChatRoom(roomId: chatRoom.roomId)
        
        if let participant = getOtherParticipant(from: chatRoom) {
            router.pushToChatView(roomId: chatRoom.roomId, participantInfo: participant)
            print("✅ ChatRoomListViewModel: 채팅방 네비게이션 완료")
        } else {
            print("❌ ChatRoomListViewModel: 상대방 참가자를 찾을 수 없음")
        }
    }
    
    private func getOtherParticipant(from chatRoom: ChatRoom) -> Users? {
        let currentUserId = getCurrentUserId()
        return chatRoom.participants.first { $0.userId != currentUserId }
    }
    
    private func getCurrentUserId() -> String {
        if let userId = tokenManager.getCurrentUserId() {
            print("✅ ChatRoomListView: 현재 사용자 ID - \(userId)")
            return userId
        } else {
            print("⚠️ ChatRoomListView: 사용자 ID를 가져올 수 없음, 빈 문자열 반환")
            return ""
        }
    }
    
    private func deleteChatRoom(_ chatRoom: ChatRoom) {
        viewModel.input.deleteChatRoom.send(chatRoom.roomId)
        roomToDelete = nil
    }
}

// MARK: - ChatRoomCell with Message ID Based Badge

struct ChatRoomCell: View {
    let chatRoom: ChatRoom
    let currentUserId: String
    let unreadCount: Int
    
    private var otherParticipant: Users? {
        let otherParticipants = chatRoom.participants.filter { $0.userId != currentUserId }
        let participant = otherParticipants.first
        
        if let participant = participant {
            print("✅ ChatRoomCell: 상대방 찾음 - userId: \(participant.userId), name: \(participant.name), nick: \(participant.nick)")
        } else {
            print("⚠️ ChatRoomCell: 상대방을 찾을 수 없음 - currentUserId: \(currentUserId)")
            print("📋 ChatRoomCell: 참가자 목록:")
            for (index, p) in chatRoom.participants.enumerated() {
                print("  \(index): userId=\(p.userId), name=\(p.name), nick=\(p.nick)")
            }
        }
        
        return participant
    }
    
    private var displayName: String {
        guard let participant = otherParticipant else {
            return "알 수 없는 사용자"
        }
        
        // nick이 비어있지 않으면 nick 사용, 아니면 name 사용
        if !participant.nick.isEmpty {
            return participant.nick
        } else if !participant.name.isEmpty {
            return participant.name
        } else {
            return "사용자"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            profileImage
            
            // 채팅방 정보
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // 시간과 뱃지를 수직으로 배열
                    VStack(alignment: .trailing, spacing: 4) {
                        if let lastChat = chatRoom.lastChat {
                            Text(formatTime(lastChat.createdAt))
                                .font(.pretendard(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        } else {
                            Text(formatTime(chatRoom.updatedAt))
                                .font(.pretendard(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        
                        // 메시지 ID 기반 안읽은 메시지 뱃지
                        if unreadCount > 0 {
                            unreadBadge
                        }
                    }
                }
                
                // 마지막 메시지
                lastMessageView
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var profileImage: some View {
        if let profileImagePath = otherParticipant?.profileImage {
            AuthenticatedImageView(
                imagePath: profileImagePath,
                contentMode: .fill
            ) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                )
        }
    }
    
    @ViewBuilder
    private var lastMessageView: some View {
        if let lastChat = chatRoom.lastChat {
            if !lastChat.content.isEmpty {
                Text(lastChat.content)
                    .font(.pretendard(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            } else if !lastChat.files.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "paperclip")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("첨부파일")
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
            } else {
                Text("메시지가 없습니다")
                    .font(.pretendard(size: 14, weight: .regular))
                    .foregroundColor(.gray)
            }
        } else {
            Text("메시지가 없습니다")
                .font(.pretendard(size: 14, weight: .regular))
                .foregroundColor(.gray)
        }
    }
    
    private var unreadBadge: some View {
        Text("\(unreadCount)")
            .font(.pretendard(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, unreadCount > 99 ? 6 : 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.red)
            )
            .opacity(unreadCount > 0 ? 1.0 : 0.0)
            .scaleEffect(unreadCount > 0 ? 1.0 : 0.1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: unreadCount)
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        // iOS 16에서 Calendar.isToday, isYesterday 메서드 사용
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            return "어제"
        } else {
            formatter.dateFormat = "MM/dd"
        }
        return formatter.string(from: date)
    }
}
