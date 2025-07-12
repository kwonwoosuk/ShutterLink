//
//  ProfileView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/21/25.
//

import SwiftUI
import Combine

struct ProfileView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showLogoutAlert = false
    @State private var hasAppeared = false
    
    var body: some View {
        NavigationStack(path: $router.profilePath) {
            ZStack {
                // 다크 모드 배경
                Color.black.ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 25) {
                            // 프로필 원형 이미지
                            HStack {
                                Spacer()
                                if let profileImageURL = viewModel.profile?.profileImage, !profileImageURL.isEmpty {
                                    AuthenticatedImageView(
                                        imagePath: profileImageURL,
                                        contentMode: .fill
                                    ) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 50)
                                                .foregroundColor(.gray)
                                        )
                                }
                                Spacer()
                            }
                            .padding(.top, 30)
                            .id("top") // 스크롤 참조점
                            
                            // 사용자 이름 및 프로필 수정 버튼
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(viewModel.profile?.nick ?? authState.currentUser?.nickname ?? "")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(viewModel.profile?.name ?? "SESAC USER")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Button {
                                    router.presentSheet(.profileEdit)
                                } label: {
                                    Text("프로필 수정")
                                        .font(.system(size: 14))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.9))
                                        .cornerRadius(20)
                                }
                            }
                            .padding(.horizontal)
                            
                            // 해시태그
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.profile?.hashTags ?? [], id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.black)
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                            
                            // 📱 문의 내역 섹션 (채팅 내역과 필터 관리 버튼)
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 12) {
                                    // 채팅 내역 버튼
                                    Button {
                                        router.profilePath.append(.chatRoomList)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("채팅 내역")
                                                    .font(.pretendard(size: 16, weight: .medium))
                                                    .foregroundColor(.white)
                                                
                                                Text("작가와의 채팅 내역을 확인하세요")
                                                    .font(.pretendard(size: 13, weight: .regular))
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.black)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // 🆕 필터 관리 버튼 (채팅 내역 버튼의 절반 크기)
                                    Button {
                                        router.pushToFilterManagement()
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: "slider.horizontal.3")
                                                .font(.system(size: 18))
                                                .foregroundColor(.orange)
                                            
                                            Text("필터 관리")
                                                .font(.pretendard(size: 12, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.black)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .frame(width: 80) // 채팅 내역 버튼의 절반 크기로 제한
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top, 10)
                            
                            // 좋아요한 필터 섹션 (기존 유지)
                            LikedFiltersSection(
                                filters: viewModel.likedFilters,
                                isLoading: viewModel.isLoadingLikedFilters,
                                onFilterTap: { filterId in
                                    router.pushToLikedFilterDetail(filterId: filterId)
                                }
                            )
                            .padding(.top, 10)
                            
                            // 로그아웃 버튼
                            Button {
                                showLogoutAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("로그아웃")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .background(Color.black)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                        }
                        .padding(.bottom, 100) // 탭바 높이만큼 하단 패딩
                    }
                    .onReceive(router.profileScrollToTop) { _ in
                        print("🔄 ProfileView: 상단으로 스크롤")
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
                .opacity(viewModel.isLoading ? 0.7 : 1.0)
                
                // 로딩 인디케이터 - 중앙 작은 크기로 변경
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        
                        Text("로딩 중...")
                            .font(.pretendard(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.top, 8)
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                }
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .editProfile:
                    ProfileEditView()
                case .likedFilters:
                    EmptyView() // 필요시 전체 좋아요한 필터 리스트 뷰
                case .filterDetail(let filterId):
                    FilterDetailView(filterId: filterId)
                case .chatRoomList:
                    ChatRoomListView()
                case .chatView(roomId: let roomId, participantInfo: let participantInfo):
                    ChatView(roomId: roomId, participantInfo: participantInfo)
                case .filterManagement:
                    FilterManagementView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PROFILE")
                        .font(.hakgyoansim(size: 18, weight: .bold))
                        .foregroundColor(.gray45)
                }
            }
        }
        .onAppear {
            // 탭 전환 완료 후 로딩 시작
            if !hasAppeared {
                hasAppeared = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🔵 ProfileView: 프로필 로딩 시작")
                    viewModel.loadProfile()
                }
            }
        }
        .onChange(of: router.presentedSheet) { newValue in
            if newValue == nil {
                // 프로필 수정 화면이 닫힌 후 프로필 다시 로드
                print("🔵 ProfileView: 프로필 수정 완료, 다시 로드")
                viewModel.loadProfile()
            }
        }
        // 로그아웃 확인 알림창
        .alert("로그아웃", isPresented: $showLogoutAlert) {
            Button("취소", role: .cancel) { }
            Button("로그아웃", role: .destructive) {
                // 로그아웃 처리 (메인스레드에서 실행됨)
                authState.logout()
            }
        } message: {
            Text("정말 로그아웃 하시겠습니까?")
        }
    }
}

// MARK: - 좋아요한 필터 섹션 (기존 유지)
struct LikedFiltersSection: View {
    let filters: [FilterItem]
    let isLoading: Bool
    let onFilterTap: (String) -> Void
    
    private let cardWidth: CGFloat = 140
    private let cardHeight: CGFloat = 180
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 섹션 헤더
            HStack {
                Text("좋아요한 필터")
                    .font(.pretendard(size: 18, weight: .semiBold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if !filters.isEmpty {
                    Text("\(filters.count)개")
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            // 필터 가로 스크롤
            if isLoading && filters.isEmpty {
                // 로딩 상태
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: cardHeight)
            } else if filters.isEmpty {
                // 빈 상태
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    
                    Text("아직 좋아요한 필터가 없습니다")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(height: cardHeight)
                .frame(maxWidth: .infinity)
            } else {
                // 필터 목록
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filters) { filter in
                            ProfileFilterCard(
                                filter: filter,
                                cardWidth: cardWidth,
                                cardHeight: cardHeight,
                                onFilterTap: onFilterTap
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - 프로필용 필터 카드
struct ProfileFilterCard: View {
    let filter: FilterItem
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onFilterTap: (String) -> Void
    
    @State private var shouldLoadImage = false
    
    var body: some View {
        VStack(spacing: 6) {
            // 이미지 영역
            Button {
                onFilterTap(filter.filter_id)
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    if shouldLoadImage, let firstImagePath = filter.files.first {
                        AuthenticatedImageView(
                            imagePath: firstImagePath,
                            contentMode: .fill,
                            targetSize: CGSize(width: cardWidth * 2, height: cardHeight * 1.2)
                        ) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.6)
                                )
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 24))
                            )
                    }
                    
                    // 좋아요 표시 (우하단)
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        Text("\(filter.like_count)")
                            .font(.pretendard(size: 9, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.trailing, 6)
                    .padding(.bottom, 6)
                }
                .frame(width: cardWidth, height: cardHeight * 0.8)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PlainButtonStyle())
            
            // 필터 정보
            VStack(spacing: 2) {
                Text(filter.title)
                    .font(.pretendard(size: 12, weight: .semiBold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(filter.creator.nick)
                    .font(.pretendard(size: 10, weight: .regular))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: cardWidth)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                shouldLoadImage = true
            }
        }
        .onDisappear {
            shouldLoadImage = false
        }
    }
}
