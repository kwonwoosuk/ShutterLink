//
//  ChatRoomListView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import SwiftUI

struct ChatRoomListView: View {
    @StateObject private var viewModel: ChatRoomListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingChatView = false
    @State private var selectedChatRoom: ChatRoom?
    
    // ✅ TokenManager 인스턴스 추가
    private let tokenManager = TokenManager.shared
    
    init() {
        // 의존성 주입 (실제 구현에서는 DI 컨테이너 사용)
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
        .sheet(isPresented: $showingChatView) {
            if let selectedChatRoom = selectedChatRoom,
               let participant = getOtherParticipant(from: selectedChatRoom) {
                NavigationStack {
                    ChatView(roomId: selectedChatRoom.roomId, participantInfo: participant)
                }
            }
        }
        .alert("오류", isPresented: $viewModel.showError) {
            Button("확인") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
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
            
            // 새로고침 버튼
            Button {
                viewModel.input.refreshChatRooms.send()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .disabled(viewModel.isRefreshing)
            .opacity(viewModel.isRefreshing ? 0.6 : 1.0)
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
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.chatRooms) { chatRoom in
                    ChatRoomCell(
                        chatRoom: chatRoom,
                        currentUserId: getCurrentUserId()
                    )
                    .onTapGesture {
                        openChatRoom(chatRoom)
                    }
                    
                    // 구분선
                    if chatRoom.roomId != viewModel.chatRooms.last?.roomId {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.leading, 80)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - 액션 메서드
    
    private func openChatRoom(_ chatRoom: ChatRoom) {
        selectedChatRoom = chatRoom
        showingChatView = true
    }
    
    private func getOtherParticipant(from chatRoom: ChatRoom) -> Users? {
        let currentUserId = getCurrentUserId()
        return chatRoom.participants.first { $0.userId != currentUserId }
    }
    
    // ✅ 실제 TokenManager를 사용하여 현재 사용자 ID 가져오기
    private func getCurrentUserId() -> String {
        if let userId = tokenManager.getCurrentUserId() {
            print("✅ ChatRoomListView: 현재 사용자 ID - \(userId)")
            return userId
        } else {
            print("⚠️ ChatRoomListView: 사용자 ID를 가져올 수 없음, 빈 문자열 반환")
            return ""
        }
    }
}

// MARK: - 채팅방 셀

struct ChatRoomCell: View {
    let chatRoom: ChatRoom
    let currentUserId: String
    
    // ✅ 상대방 찾기 로직 개선
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
    
    // ✅ 표시할 이름 로직 개선 (name 없으면 nick 사용)
    private var displayName: String {
        guard let participant = otherParticipant else {
            return "알 수 없는 사용자"
        }
        
        // name이 비어있지 않으면 name 사용, 아니면 nick 사용
        if !participant.name.isEmpty {
            return participant.name
        } else if !participant.nick.isEmpty {
            return participant.nick
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
                    // ✅ 개선된 이름 표시
                    Text(displayName)
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // 시간
                    if let lastChat = chatRoom.lastChat {
                        Text(formatTime(lastChat.createdAt))
                            .font(.pretendard(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                }
                
                // 마지막 메시지
                HStack {
                    lastMessageView
                    
                    Spacer()
                    
                    // 읽지 않은 메시지 배지 (TODO: 구현)
                    // unreadBadge
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }
    
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
                    
                    Text("파일 \(lastChat.files.count)개")
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
            } else {
                Text("메시지 없음")
                    .font(.pretendard(size: 14, weight: .regular))
                    .foregroundColor(.gray.opacity(0.6))
                    .italic()
            }
        } else {
            Text("메시지 없음")
                .font(.pretendard(size: 14, weight: .regular))
                .foregroundColor(.gray.opacity(0.6))
                .italic()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "a h:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "어제"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yy/M/d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - 미리보기

struct ChatRoomListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ChatRoomListView()
        }
        .preferredColorScheme(.dark)
    }
}
