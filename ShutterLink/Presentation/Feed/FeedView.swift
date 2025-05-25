//
//  FeedView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/24/25.
//

import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var currentTopRankingIndex = 0
    @State private var selectedCategory: FilterCategory? // 옵셔널로 유지
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 다크 모드 배경
                Color.black.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 카테고리 버튼들
                        CategoryButtonsView(
                            selectedCategory: $selectedCategory,
                            onSelectCategory: { category in
                                viewModel.input.selectCategory.send(category ?? .all)
                                selectedCategory = category
                            }
                        )
                        .padding(.top, 20)
                        
                        // Top Ranking 섹션
                        if !viewModel.allFilters.isEmpty {
                            TopRankingSection(
                                filters: Array(viewModel.allFilters.prefix(5)),
                                currentIndex: $currentTopRankingIndex
                            )
                            .padding(.top, 24)
                        }
                        
                        // 정렬 옵션과 Filter Feed 타이틀
                        VStack(spacing: 20) {
                            // 정렬 옵션 탭
                            SortOptionTabs(
                                selectedOption: $viewModel.selectedSortOption,
                                onSelectOption: { option in
                                    viewModel.input.selectSortOption.send(option)
                                }
                            )
                            
                            // Filter Feed 헤더
                            HStack {
                                Text("Filter Feed")
                                    .font(.pretendard(size: 20, weight: .regular))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                // View Mode 토글
                                Button {
                                    viewModel.input.toggleViewMode.send()
                                } label: {
                                    Text(viewModel.viewMode == .list ? "List Mode" : "Block Mode")
                                        .font(.pretendard(size: 14, weight: .regular))
                                        .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 30)
                        
                        // Filter Feed 리스트
                        if viewModel.viewMode == .list {
                            FilterListView(
                                filters: viewModel.displayedFilters,
                                onLike: { filterId, isLiked in
                                    viewModel.input.likeFilter.send((filterId, !isLiked))
                                },
                                onLoadMore: {
                                    viewModel.input.loadMoreData.send()
                                },
                                isLoadingMore: viewModel.isLoadingMore
                            )
                        } else {
                            FilterBlockView(
                                filters: viewModel.displayedFilters,
                                onLoadMore: {
                                    viewModel.input.loadMoreData.send()
                                },
                                isLoadingMore: viewModel.isLoadingMore
                            )
                        }
                        
                        // 하단 여백
                        Color.clear.frame(height: 100)
                    }
                }
                
                // 로딩 인디케이터
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("FEED")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("FEED")
                        .font(.pretendard(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // 뒤로가기
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            viewModel.input.loadInitialData.send()
            if selectedCategory == nil {
                viewModel.input.selectCategory.send(.all) // 초기 로드 시 전체 카테고리 선택
            }
        }
        .refreshable {
            viewModel.input.refreshData.send()
        }
    }
}

// MARK: - 카테고리 버튼들
struct CategoryButtonsView: View {
    @Binding var selectedCategory: FilterCategory?
    let onSelectCategory: (FilterCategory?) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) { // spacing 조정
                    ForEach(FilterCategory.allCases.filter { $0 != .all }, id: \.self) { category in
                        CategoryButton(
                            category: category,
                            isSelected: selectedCategory == category,
                            action: {
                                let newCategory = selectedCategory == category ? nil : category
                                onSelectCategory(newCategory)
                            }
                        )
                        .frame(width: geometry.size.width / 5.5) // 5개 카테고리에 맞게 너비 조정
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(height: 80) // 높이 고정
    }
}

struct CategoryButton: View {
    let category: FilterCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? DesignSystem.Colors.Brand.brightTurquoise.opacity(0.15) : Color.gray.opacity(0.15))
                        .frame(width: 48, height: 48) // 버튼 크기 축소
                    
                    Image(getCategoryIcon(for: category))
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24) // 아이콘 크기 조정
                        .foregroundColor(isSelected ? DesignSystem.Colors.Brand.brightTurquoise : .gray)
                }
                
                Text(category.title)
                    .font(.pretendard(size: 12, weight: .regular)) // 폰트 크기 축소
                    .foregroundColor(isSelected ? DesignSystem.Colors.Brand.brightTurquoise : .gray)
                    .lineLimit(1)
            }
        }
    }
    
    private func getCategoryIcon(for category: FilterCategory) -> String {
        switch category {
        case .all: return "Food" // 사용되지 않지만 호환성 유지
        case .food: return "Food"
        case .people: return "People"
        case .landscape: return "Landscape"
        case .night: return "Night"
        case .star: return "Star"
        }
    }
}

// MARK: - Top Ranking 섹션
struct TopRankingSection: View {
    let filters: [FilterItem]
    @Binding var currentIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Top Ranking")
                .font(.pretendard(size: 20, weight: .regular))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            // 커스텀 캐러셀
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: -50) {
                            ForEach(Array(filters.enumerated()), id: \.element.id) { index, filter in
                                GeometryReader { itemGeometry in
                                    let minX = itemGeometry.frame(in: .global).minX
                                    let screenWidth = UIScreen.main.bounds.width
                                    let centerX = screenWidth / 2
                                    let distance = abs(minX + 130 - centerX) // 130은 카드 너비의 절반
                                    let scale = max(0.8, 1 - (distance / 500))
                                    let isCentered = distance < 50
                                    
                                    Group {
                                        if isCentered {
                                            VerticalOvalCard(filter: filter, rank: index + 1)
                                                .scaleEffect(scale)
                                                .id(index)
                                        } else {
                                            MiniVerticalOvalCard(filter: filter, rank: index + 1)
                                                .scaleEffect(scale)
                                                .id(index)
                                        }
                                    }
                                    .frame(width: 260, height: 360)
                                    .offset(x: distance < 50 ? 0 : (minX < centerX ? -20 : 20))
                                }
                                .frame(width: 260, height: 360)
                            }
                        }
                        .padding(.horizontal, (UIScreen.main.bounds.width - 260) / 2)
                    }
                    .onAppear {
                        withAnimation {
                            proxy.scrollTo(currentIndex, anchor: .center)
                        }
                    }
                }
            }
            .frame(height: 380)
        }
    }
}

// MARK: - 정렬 옵션 탭
struct SortOptionTabs: View {
    @Binding var selectedOption: FilterSortOption
    let onSelectOption: (FilterSortOption) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(FilterSortOption.allCases, id: \.self) { option in
                Button {
                    onSelectOption(option)
                } label: {
                    Text(option.title)
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(selectedOption == option ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedOption == option ?
                                     DesignSystem.Colors.Brand.brightTurquoise :
                                     Color.gray.opacity(0.2))
                        )
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 필터 리스트 뷰 (List Mode)
struct FilterListView: View {
    let filters: [FilterItem]
    let onLike: (String, Bool) -> Void
    let onLoadMore: () -> Void
    let isLoadingMore: Bool
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(filters) { filter in
                FilterListItem(filter: filter, onLike: onLike)
                    .onAppear {
                        if filter.id == filters.last?.id {
                            onLoadMore()
                        }
                    }
            }
            
            if isLoadingMore {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
}

struct FilterListItem: View {
    let filter: FilterItem
    let onLike: (String, Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 썸네일
            if let firstImagePath = filter.files.first {
                AuthenticatedImageView(
                    imagePath: firstImagePath,
                    contentMode: .fill
                ) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // 필터 정보
            VStack(alignment: .leading, spacing: 6) {
                Text(filter.title)
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("#\(filter.category ?? "인물")")
                    .font(.pretendard(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                Text(filter.creator.nick)
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(filter.description)
                    .font(.pretendard(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 좋아요 버튼
            Button {
                onLike(filter.filter_id, filter.is_liked)
            } label: {
                Image(systemName: filter.is_liked ? "heart.fill" : "heart")
                    .foregroundColor(filter.is_liked ? .red : .gray)
                    .font(.system(size: 20))
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - 필터 블럭 뷰 (Block Mode)
struct FilterBlockView: View {
    let filters: [FilterItem]
    let onLoadMore: () -> Void
    let isLoadingMore: Bool
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(filters) { filter in
                FilterBlockItem(filter: filter)
                    .onAppear {
                        if filter.id == filters.last?.id {
                            onLoadMore()
                        }
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        
        if isLoadingMore {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .padding()
        }
    }
}

struct FilterBlockItem: View {
    let filter: FilterItem
    
    var body: some View {
        VStack(spacing: 8) {
            // 썸네일
            ZStack(alignment: .bottomTrailing) {
                if let firstImagePath = filter.files.first {
                    AuthenticatedImageView(
                        imagePath: firstImagePath,
                        contentMode: .fill
                    ) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // 좋아요 카운트
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    Text("\(filter.like_count)")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .padding(8)
            }
            
            // 필터 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(filter.title)
                    .font(.pretendard(size: 14, weight: .semiBold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(filter.creator.nick)
                    .font(.pretendard(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}


