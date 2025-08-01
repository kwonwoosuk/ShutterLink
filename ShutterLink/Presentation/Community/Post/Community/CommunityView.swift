//
//  CommunityView.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import SwiftUI
import Combine

struct CommunityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = CommunityViewModel()
    @State private var hasAppeared = false
    @State private var searchText = ""
    @State private var selectedCategory = ""
    @State private var showSearchResults = false
    @State private var searchResults: [Post] = []
    @State private var selectedSortOrder = "createdAt" // "createdAt" 또는 "likes"
    @State private var showSortOptions = false
    
    var body: some View {
        ZStack {
            // 다크 테마 배경
            Color.black.ignoresSafeArea()
            

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // 검색바와 필터 (스크롤 포함)
                        searchAndFilterSection
                            .id("search_filter_top")
                        
                        // 게시글 목록
                        if showSearchResults {
                            searchResultsSection
                        } else {
                            postListSection
                        }
                    }
                }
                .refreshable {
                    await viewModel.refreshPostsAsync()
                }
                .onReceive(router.communityScrollToTop) { _ in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo("search_filter_top", anchor: .top)
                    }
                }
            }
            
            // 플로팅 버튼
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        router.pushToCreatePost()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color.blue)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 90) // 탭바 위에 배치
                }
            }
            
            if viewModel.isLoading && !viewModel.isLoadingMore {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("로딩 중...")
                        .font(DesignSystem.Typography.TextStyle.caption1.font())
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                .padding(20)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("COMMUNITY")
                    .font(.hakgyoansim(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        router.pushToMyLikedPosts()
                    } label: {
                        Label("내가 좋아요한 글", systemImage: "heart.fill")
                    }
                    
                    Button {
                        router.pushToMyPosts()
                    } label: {
                        Label("내 글 관리", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                viewModel.loadPosts()
            }
        }
        .onChange(of: searchText) { newValue in
            if newValue.isEmpty {
                showSearchResults = false
                searchResults.removeAll()
            }
        }
        .alert("오류", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("확인") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .actionSheet(isPresented: $showSortOptions) {
            ActionSheet(
                title: Text("정렬 기준"),
                buttons: [
                    .default(Text("최신순")) {
                        selectedSortOrder = "createdAt"
                        viewModel.updateSortOrder("createdAt")
                    },
                    .default(Text("좋아요 많은 순")) {
                        selectedSortOrder = "likes"
                        viewModel.updateSortOrder("likes")
                    },
                    .cancel(Text("취소"))
                ]
            )
        }
    }
    
    // MARK: - Search and Filter Section
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 16) {
            // 검색바
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    
                    TextField("게시글을 검색해주세요", text: $searchText)
                        .foregroundColor(.white)
                        .font(.pretendard(size: 14, weight: .medium))
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            showSearchResults = false
                            searchResults.removeAll()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.gray90)
                .cornerRadius(20)
                
                if !searchText.isEmpty {
                    Button("검색") {
                        performSearch()
                    }
                    .foregroundColor(.blue)
                    .font(.pretendard(size: 14, weight: .semiBold))
                }
            }
            .padding(.horizontal, 16)
            
            // 정렬 옵션 (위치 기반 검색 제거)
            HStack {
                Spacer()
                
                Button {
                    showSortOptions = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                        
                        Text(selectedSortOrder == "createdAt" ? "최신순" : "좋아요순")
                            .font(.pretendard(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray75)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            
            // 카테고리 필터
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    categoryButton("전체", category: "")
                    categoryButton("핫스팟", category: "핫스팟")
                    categoryButton("맛집", category: "맛집")
                    categoryButton("일상", category: "일상")
                    categoryButton("여행", category: "여행")
                    categoryButton("취미", category: "취미")
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .background(Color.black)
    }
    
    private func categoryButton(_ title: String, category: String) -> some View {
        Button {
            selectedCategory = category
            viewModel.filterByCategory(category.isEmpty ? nil : category, orderBy: selectedSortOrder)
        } label: {
            Text(title)
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(selectedCategory == category ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selectedCategory == category ? Color.white : Color.gray90)
                )
        }
    }
    
    // MARK: - Search Results Section
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("검색 결과")
                    .font(.pretendard(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("(\(searchResults.count))")
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button("닫기") {
                    showSearchResults = false
                    searchResults.removeAll()
                    searchText = ""
                }
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("검색 결과가 없습니다")
                        .font(.pretendard(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("다른 키워드로 검색해보세요")
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.gray60)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                .padding(.bottom, 100)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults) { post in
                        PostCell(post: post) {
                            router.pushToPostDetail(postId: post.postId)
                        } onLikeTapped: { post in
                            Task {
                                await viewModel.toggleLike(post: post)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Post List Section
    
    private var postListSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.posts) { post in
                PostCell(post: post) {
                    router.pushToPostDetail(postId: post.postId)
                } onLikeTapped: { post in
                    Task {
                        await viewModel.toggleLike(post: post)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .onAppear {
                    // 무한 스크롤
                    if post.id == viewModel.posts.last?.id {
                        viewModel.loadMorePosts()
                    }
                }
                .id(post.id)
            }
            
            // 더 로딩 중 인디케이터
            if viewModel.isLoadingMore {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    
                    Text("더 불러오는 중...")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 20)
            }
            
            // 하단 여백 (탭바 공간)
            Color.clear.frame(height: 100)
        }
    }
    
    // MARK: - Methods
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        Task {
            do {
                let results = try await viewModel.searchPosts(query: searchText)
                await MainActor.run {
                    self.searchResults = results
                    self.showSearchResults = true
                }
            } catch {
                await MainActor.run {
                    viewModel.setError(error.localizedDescription)
                }
            }
        }
    }
}
