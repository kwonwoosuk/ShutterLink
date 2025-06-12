//
//  UserFiltersView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/2/25.
//

import SwiftUI

struct UserFiltersView: View {
    let userId: String
    let userNick: String
    
    @StateObject private var viewModel = UserFiltersViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @State private var path: [FilterRoute] = [] // Sheet 내부에서 독립적인 네비게이션
    @State private var hasAppeared = false
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 헤더
                    UserFiltersHeader(userNick: userNick) {
                        dismiss()
                    }
                    .padding(.top, 20)
                    
                    // 필터 목록
                    if viewModel.isLoading && viewModel.filters.isEmpty {
                        Spacer()
                        LoadingIndicatorView()
                        Spacer()
                    } else if viewModel.filters.isEmpty && !viewModel.isLoading {
                        Spacer()
                        EmptyFiltersView()
                        Spacer()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.filters) { filter in
                                    UserFilterItem(
                                        filter: filter,
                                        onFilterTap: { filterId in
                                            path.append(FilterRoute.filterDetail(filterId: filterId))
                                        },
                                        onLike: { filterId, shouldLike in
                                            viewModel.input.likeFilter.send((filterId, shouldLike))
                                        }
                                    )
                                    .onAppear {
                                        // 무한 스크롤: 마지막에서 3번째 아이템에 도달하면 더 로드
                                        if let index = viewModel.filters.firstIndex(where: { $0.id == filter.id }),
                                           index >= viewModel.filters.count - 3 {
                                            viewModel.input.loadMoreFilters.send()
                                        }
                                    }
                                }
                                
                                // 더 로딩 인디케이터
                                if viewModel.isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Spacer()
                                    }
                                    .padding(.vertical, 16)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 60)
                        }
                    }
                    
                    // 에러 상태
                    if let errorMessage = viewModel.errorMessage, viewModel.filters.isEmpty {
                        Spacer()
                        ErrorStateView(errorMessage: errorMessage) {
                            viewModel.input.loadInitialFilters.send(userId)
                        }
                        Spacer()
                    }
                }
            }
            .navigationDestination(for: FilterRoute.self) { route in
                switch route {
                case .filterDetail(let filterId):
                    FilterDetailView(filterId: filterId)
                case .userDetail(let userId, let userInfo):
                    // CreatorInfo를 UserInfo로 변환해서 전달
                    UserDetailView(
                        userId: userId,
                        userInfo: UserInfo(
                            user_id: userInfo.user_id,
                            nick: userInfo.nick,
                            name: userInfo.name,
                            introduction: userInfo.introduction,
                            profileImage: userInfo.profileImage,
                            hashTags: userInfo.hashTags
                        )
                    )
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.input.loadInitialFilters.send(userId)
                }
            }
        }
    }
}

// MARK: - 헤더 (dismiss 콜백 추가)
struct UserFiltersHeader: View {
    let userNick: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 드래그 인디케이터
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            // 헤더 타이틀과 닫기 버튼
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(userNick)
                        .font(.hakgyoansim(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("필터")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
}

// MARK: - 필터 아이템
struct UserFilterItem: View {
    let filter: FilterItem
    let onFilterTap: (String) -> Void
    let onLike: (String, Bool) -> Void
    
    @State private var shouldLoadImage = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 이미지와 좋아요 버튼
            ZStack(alignment: .bottomTrailing) {
                Button {
                    onFilterTap(filter.filter_id)
                } label: {
                    if shouldLoadImage, let firstImagePath = filter.files.first {
                        AuthenticatedImageView(
                            imagePath: firstImagePath,
                            contentMode: .fill,
                            targetSize: CGSize(width: UIScreen.main.bounds.width - 40, height: 200)
                        ) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                )
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 32))
                            )
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // 좋아요 버튼
                Button {
                    onLike(filter.filter_id, !filter.is_liked)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filter.is_liked ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(filter.is_liked ? .red : .white)
                        
                        Text("\(filter.like_count)")
                            .font(.pretendard(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(8)
            }
            
            // 필터 정보
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(filter.title)
                        .font(.hakgyoansim(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let category = filter.category {
                        Text("#\(category)")
                            .font(.pretendard(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                
                Text(filter.description)
                    .font(.pretendard(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text("\(filter.like_count)")
                            .font(.pretendard(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text("\(filter.buyer_count)")
                            .font(.pretendard(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
            }
            .padding(.top, 12)
        }
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

// MARK: - 빈 필터 목록 뷰
struct EmptyFiltersView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.filters")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("아직 필터가 없습니다")
                .font(.pretendard(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Text("이 작가가 만든 필터가 없습니다")
                .font(.pretendard(size: 14, weight: .regular))
                .foregroundColor(.gray)
        }
        .padding(20)
    }
}

#Preview {
    UserFiltersView(userId: "test_user_id", userNick: "윤새싹")
        .preferredColorScheme(.dark)
}
