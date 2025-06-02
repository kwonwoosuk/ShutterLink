//
//  SearchView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/2/25.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var path: [UserNavigationItem] = []
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 검색바
                    SearchBarView(
                        searchText: $searchText,
                        onSearchSubmitted: { query in
                            viewModel.input.searchUsers.send(query)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // 검색 결과
                    if viewModel.isLoading {
                        Spacer()
                        LoadingIndicatorView()
                        Spacer()
                    } else if viewModel.searchResults.isEmpty && !searchText.isEmpty && !viewModel.isLoading {
                        Spacer()
                        EmptySearchResultView()
                        Spacer()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.searchResults) { user in
                                    UserSearchResultItem(
                                        user: user,
                                        onTap: {
                                            path.append(UserNavigationItem(userId: user.user_id, userInfo: user))
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.top, 20)
                        }
                    }
                    
                    Spacer()
                }
                
                // 에러 메시지
                if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Spacer()
                        ErrorStateView(errorMessage: errorMessage) {
                            viewModel.input.searchUsers.send(searchText)
                        }
                        Spacer()
                    }
                }
            }
            .navigationDestination(for: UserNavigationItem.self) { item in
                UserDetailView(userId: item.userId, userInfo: item.userInfo)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SEARCH")
                        .font(.hakgyoansim(size: 18, weight: .bold))
                        .foregroundColor(.gray45)
                }
            }
        }
        .compatibleOnChange(of: searchText) { newValue in
            if newValue.isEmpty {
                viewModel.input.clearResults.send()
            }
        }
    }
}

// MARK: - 검색바 뷰
struct SearchBarView: View {
    @Binding var searchText: String
    let onSearchSubmitted: (String) -> Void
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                
                TextField("Search", text: $searchText)
                    .foregroundColor(.white)
                    .font(.pretendard(size: 16, weight: .regular))
                    .focused($isSearchFocused)
                    .onSubmit {
                        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSearchSubmitted(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
                    .submitLabel(.search)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        isSearchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.gray.opacity(0.15))
            )
        }
    }
}

// MARK: - 검색 결과 아이템
struct UserSearchResultItem: View {
    let user: UserInfo
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                // 프로필 이미지
                if let profileImagePath = user.profileImage {
                    AuthenticatedImageView(
                        imagePath: profileImagePath,
                        contentMode: .fill,
                        targetSize: CGSize(width: 60, height: 60)
                    ) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            )
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 24))
                        )
                }
                
                // 유저 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.nick)
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(user.name)
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    if !user.introduction.isEmpty {
                        Text(user.introduction)
                            .font(.pretendard(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 빈 검색 결과 뷰
struct EmptySearchResultView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("검색 결과가 없습니다")
                .font(.pretendard(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Text("다른 닉네임으로 검색해보세요")
                .font(.pretendard(size: 14, weight: .regular))
                .foregroundColor(.gray)
        }
        .padding(20)
    }
}

#Preview {
    SearchView()
}
