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
    @State private var showCommunitySheet = false
    
    var body: some View {
        NavigationStack(path: $router.profilePath) {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            profileImageSection
                            userInfoSection
                            hashTagsSection
                            diskCacheManagementSection
                            ChatButtonsSection
                            likedFiltersSection
                            logoutButtonSection
                        }
                        .padding(.bottom, 100)
                    }
                    .onReceive(router.profileScrollToTop) { _ in
                        print("🔄 ProfileView: 상단으로 스크롤")
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
                .opacity(viewModel.isLoading ? 0.7 : 1.0)
                
                if viewModel.isLoading {
                    loadingIndicator
                }
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                routeDestination(for: route)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
        }
        .onAppear {
            handleViewAppear()
        }
        .onChange(of: router.presentedSheet) { newValue in
            handleSheetChange(newValue)
        }
        
        .alert("로그아웃", isPresented: $showLogoutAlert) {
            logoutAlertButtons
        } message: {
            Text("정말 로그아웃 하시겠습니까?")
        }
    }
    
    
}

// MARK: - View Components

extension ProfileView {
    
    private var profileImageSection: some View {
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
        .id("top")
    }
    
    private var userInfoSection: some View {
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
    }
    
    private var hashTagsSection: some View {
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
        
    }
    
    // MARK: - 디스크 캐시 관리 섹션
    private var diskCacheManagementSection: some View {
        VStack {
            cacheManagementCard
        }
        .padding(.horizontal)
        
    }
    
    private var ChatButtonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // 채팅 내역 버튼
                Button {
                    router.profilePath.append(.chatRoomList)
                } label: {
                    chatHistoryButtonContent
                }
                .buttonStyle(PlainButtonStyle())
                
                // 필터 관리 버튼
                Button {
                    router.pushToFilterManagement()
                } label: {
                    filterManagementButtonContent
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 80)
            }
            
            Button {
                showCommunitySheet = true
            } label: {
                communityButtonContent
            }.sheet(isPresented: $showCommunitySheet) {
                NavigationStack {
                    CommunityView()
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
        
    }
    
    private var cacheManagementCard: some View {
        Button {
            router.pushToCacheManagement()
        } label: {
            HStack(spacing: 12) {
                cacheUsageProgressBar
                
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
        .onAppear {
            CacheManager.shared.updateCacheSizes()
        }
    }
    
    private var cacheUsageProgressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("캐시 사용량")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // 캐시 사용량 정보
            HStack {
                let cacheManager = CacheManager.shared
                let totalUsed = cacheManager.memoryCacheSize + cacheManager.diskCacheSize
                let totalMax = cacheManager.getMaxMemoryCacheSize() + cacheManager.getMaxDiskCacheSize()
                let usagePercentage = totalMax > 0 ? Double(totalUsed) / Double(totalMax) * 100 : 0
                
                Text("\(cacheManager.formatBytes(totalUsed)) / \(cacheManager.formatBytes(totalMax))")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.Gray.gray60)
                
                Spacer()
                
                Text("\(String(format: "%.1f", usagePercentage))% 사용")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.Gray.gray60)
            }
            
            // 프로그레스 바
            let cacheManager = CacheManager.shared
            let totalUsed = cacheManager.memoryCacheSize + cacheManager.diskCacheSize
            let totalMax = cacheManager.getMaxMemoryCacheSize() + cacheManager.getMaxDiskCacheSize()
            let totalUsage = totalMax > 0 ? Double(totalUsed) / Double(totalMax) : 0
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 배경
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignSystem.Colors.Gray.gray30)
                        .frame(height: 4)
                    
                    // 사용량 표시
                    RoundedRectangle(cornerRadius: 2)
                        .fill(totalUsage > 0.8 ? Color.red : totalUsage > 0.6 ? Color.orange : DesignSystem.Colors.Brand.brightTurquoise)
                        .frame(width: geometry.size.width * totalUsage, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
    
    private var likedFiltersSection: some View {
        LikedFiltersSection(
            filters: viewModel.likedFilters,
            isLoading: viewModel.isLoadingLikedFilters,
            onFilterTap: { filterId in
                router.pushToLikedFilterDetail(filterId: filterId)
            }
        )
        
    }
    
    private var logoutButtonSection: some View {
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
    
    private var loadingIndicator: some View {
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

// MARK: - Button Content Views

extension ProfileView {
    
    private var chatHistoryButtonContent: some View {
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
    
    private var filterManagementButtonContent: some View {
        VStack(spacing: 15) {
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
    
    private var communityButtonContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("커뮤니티")
                    .font(.pretendard(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text("다른 사용자들과 소통하고 게시글을 공유하세요")
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
}

// MARK: - Navigation & Actions

extension ProfileView {
    
    @ViewBuilder
    private func routeDestination(for route: ProfileRoute) -> some View {
        switch route {
        case .editProfile:
            ProfileEditView()
        case .likedFilters:
            EmptyView()
        case .filterDetail(let filterId):
            FilterDetailView(filterId: filterId)
        case .chatRoomList:
            ChatRoomListView()
        case .chatView(roomId: let roomId, participantInfo: let participantInfo):
            ChatView(roomId: roomId, participantInfo: participantInfo)
        case .filterManagement:
            FilterManagementView()
        case .cacheManagement:
            CacheManagementView()
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("PROFILE")
                .font(.hakgyoansim(size: 18, weight: .bold))
                .foregroundColor(DesignSystem.Colors.Gray.gray45)
        }
    }
    
    @ViewBuilder
    private var logoutAlertButtons: some View {
        Button("취소", role: .cancel) { }
        Button("로그아웃", role: .destructive) {
            authState.logout()
        }
    }
    
    private func handleViewAppear() {
        if !hasAppeared {
            hasAppeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔵 ProfileView: 프로필 로딩 시작")
                viewModel.loadProfile()
            }
        }
    }
    
    private func handleSheetChange(_ newValue: PresentedSheet?) {
        if newValue == nil {
            print("🔵 ProfileView: 프로필 수정 완료, 다시 로드")
            viewModel.loadProfile()
        }
    }
}

// MARK: - LikedFiltersSection

struct LikedFiltersSection: View {
    let filters: [FilterItem]
    let isLoading: Bool
    let onFilterTap: (String) -> Void
    
    private let cardWidth: CGFloat = 140
    private let cardHeight: CGFloat = 180
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader
            filterContent
        }
    }
    
    private var sectionHeader: some View {
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
    }
    
    @ViewBuilder
    private var filterContent: some View {
        if isLoading && filters.isEmpty {
            loadingState
        } else if filters.isEmpty {
            emptyState
        } else {
            filterScrollView
        }
    }
    
    private var loadingState: some View {
        HStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
            Spacer()
        }
        .frame(height: cardHeight)
    }
    
    private var emptyState: some View {
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
    }
    
    private var filterScrollView: some View {
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

// MARK: - ProfileFilterCard

struct ProfileFilterCard: View {
    let filter: FilterItem
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onFilterTap: (String) -> Void
    
    @State private var shouldLoadImage = false
    
    var body: some View {
        VStack(spacing: 6) {
            imageSection
            filterInfo
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
    
    private var imageSection: some View {
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
                        placeholderView
                    }
                } else {
                    placeholderView
                }
                
                likeCountOverlay
            }
            .frame(width: cardWidth, height: cardHeight * 0.8)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.6)
            )
    }
    
    private var likeCountOverlay: some View {
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
    
    private var filterInfo: some View {
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
}
