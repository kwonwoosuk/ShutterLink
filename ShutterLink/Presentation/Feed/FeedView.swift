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
    @State private var selectedCategory: FilterCategory? = nil
    @State private var path: [FilterNavigationItem] = [] // 네비게이션 경로 관리
    
    var body: some View {
        NavigationStack(path: $path) {
            feedContent
                .navigationDestination(for: FilterNavigationItem.self) { item in
                    FilterDetailView(filterId: item.filterId)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("FEED")
                            .font(.hakgyoansim(size: 18, weight: .bold))
                            .foregroundColor(.gray45)
                    }
                }
        }
    }
    
    @ViewBuilder
    private var feedContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // 카테고리 버튼들
                    CategoryButtonsView(
                        selectedCategory: $selectedCategory,
                        onSelectCategory: { category in
                            selectedCategory = category
                            viewModel.input.selectCategory.send(category)
                        }
                    )
                    .padding(.top, 20)
                    
                    // Top Ranking 섹션
                    if !viewModel.allFilters.isEmpty {
                        TopRankingSection(
                            filters: Array(viewModel.allFilters.prefix(5)),
                            currentIndex: $currentTopRankingIndex,
                            onFilterTap: { filterId in
                                path.append(FilterNavigationItem(filterId: filterId))
                            }
                        )
                        .padding(.top, 24)
                    }
                    
                    VStack(spacing: 20) {
                        SortOptionTabs(
                            selectedOption: $viewModel.selectedSortOption,
                            onSelectOption: { option in
                                viewModel.input.selectSortOption.send(option)
                            }
                        )
                        
                        HStack {
                            Text("Filter Feed")
                                .font(.pretendard(size: 20, weight: .regular))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button {
                                viewModel.input.toggleViewMode.send()
                            } label: {
                                Text(viewModel.viewMode == .list ? "Block Mode" : "List Mode")
                                    .font(.pretendard(size: 14, weight: .regular))
                                    .foregroundColor(.brightTurquoise)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 30)
                    
                    // Filter Feed 리스트
                    if viewModel.viewMode == .list {
                        FilterListView(
                            filters: viewModel.displayedFilters,
                            onLike: { filterId, shouldLike in
                                viewModel.input.likeFilter.send((filterId, shouldLike))
                            },
                            onFilterTap: { filterId in
                                path.append(FilterNavigationItem(filterId: filterId))
                            },
                            onLoadMore: {
                                viewModel.input.loadMoreData.send()
                            },
                            isLoadingMore: viewModel.isLoadingMore
                        )
                    } else {
                        FilterBlockView(
                            filters: viewModel.displayedFilters,
                            onLike: { filterId, shouldLike in
                                viewModel.input.likeFilter.send((filterId, shouldLike))
                            },
                            onFilterTap: { filterId in
                                path.append(FilterNavigationItem(filterId: filterId))
                            },
                            onLoadMore: {
                                viewModel.input.loadMoreData.send()
                            },
                            isLoadingMore: viewModel.isLoadingMore
                        )
                    }
                    
                    Color.clear.frame(height: 100)
                }
            }
            
            // 로딩 인디케이터
            if viewModel.isLoading && viewModel.allFilters.isEmpty && viewModel.displayedFilters.isEmpty {
                LoadingIndicatorView()
            }
            
            // 에러 상태
            if let errorMessage = viewModel.errorMessage,
               viewModel.allFilters.isEmpty && viewModel.displayedFilters.isEmpty {
                ErrorStateView(errorMessage: errorMessage) {
                    viewModel.refreshData()
                }
            }
        }
        .onAppear {
            print("🔵 FeedView: onAppear - 처음만 로딩")
            viewModel.loadDataOnceIfNeeded()
            viewModel.input.selectCategory.send(nil)
        }
        .refreshable {
            print("🔵 FeedView: Pull-to-refresh")
            viewModel.refreshData()
        }
        .onChange(of: path) { newPath in
            print("🔵 FeedView Navigation Path: \(newPath.map { $0.filterId })")
        }
    }
    
    // MARK: - 서브뷰들
    struct CategoryButtonsView: View {
        @Binding var selectedCategory: FilterCategory?
        let onSelectCategory: (FilterCategory?) -> Void
        
        var body: some View {
            HStack(spacing: 0) {
                ForEach(FilterCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category,
                        action: {
                            let newCategory = selectedCategory == category ? nil : category
                            onSelectCategory(newCategory)
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)
            .padding(.horizontal, 20)
        }
    }
    
    struct CategoryButton: View {
        let category: FilterCategory
        let isSelected: Bool
        let action: () -> Void
        @State private var isPressed = false
        
        var body: some View {
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                action()
            }) {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? .brightTurquoise.opacity(0.15) : Color.gray.opacity(0.15))
                            .frame(width: 48, height: 48)
                        
                        Image(getCategoryIcon(for: category))
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(isSelected ? .brightTurquoise : .gray)
                    }
                    
                    Text(category.title)
                        .font(.pretendard(size: 12, weight: .regular))
                        .foregroundColor(isSelected ? .brightTurquoise : .gray)
                        .lineLimit(1)
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
        }
        
        private func getCategoryIcon(for category: FilterCategory) -> String {
            switch category {
            case .food: return "Food"
            case .people: return "People"
            case .landscape: return "Landscape"
            case .night: return "Night"
            case .star: return "Star"
            }
        }
    }
    
    struct TopRankingSection: View {
        let filters: [FilterItem]
        @Binding var currentIndex: Int
        let onFilterTap: (String) -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("Top Ranking")
                    .font(.pretendard(size: 20, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: -50) {
                                ForEach(Array(filters.enumerated()), id: \.element.id) { index, filter in
                                    GeometryReader { itemGeometry in
                                        let minX = itemGeometry.frame(in: .global).minX
                                        let screenWidth = UIScreen.main.bounds.width
                                        let centerX = screenWidth / 2
                                        let distance = abs(minX + 130 - centerX)
                                        let scale = max(0.8, 1 - (distance / 500))
                                        let isCentered = distance < 50
                                        
                                        Group {
                                            if isCentered {
                                                VerticalOvalCard(
                                                    filter: filter,
                                                    rank: index + 1,
                                                    onFilterTap: onFilterTap
                                                )
                                                .scaleEffect(scale)
                                                .id(index)
                                            } else {
                                                MiniVerticalOvalCard(
                                                    filter: filter,
                                                    rank: index + 1,
                                                    onFilterTap: onFilterTap
                                                )
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
                                    .fill(selectedOption == option ? .brightTurquoise : Color.gray.opacity(0.2))
                            )
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
    
    struct FilterListView: View {
        let filters: [FilterItem]
        let onLike: (String, Bool) -> Void
        let onFilterTap: (String) -> Void
        let onLoadMore: () -> Void
        let isLoadingMore: Bool
        
        var body: some View {
            LazyVStack(spacing: 16) {
                ForEach(filters) { filter in
                    FilterListItem(
                        filter: filter,
                        onLike: onLike,
                        onFilterTap: onFilterTap
                    )
                    .onAppear {
                        if filter.id == filters.last?.id {
                            onLoadMore()
                        }
                    }
                }
                
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Spacer()
                    }
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
        let onFilterTap: (String) -> Void
        
        var body: some View {
            Button {
                onFilterTap(filter.filter_id)
            } label: {
                HStack(spacing: 12) {
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
                    
                    VStack(spacing: 4) {
                        Button {
                            onLike(filter.filter_id, !filter.is_liked)
                        } label: {
                            Image(systemName: filter.is_liked ? "heart.fill" : "heart")
                                .foregroundColor(filter.is_liked ? .red : .gray)
                                .font(.system(size: 20))
                        }
                        
                        Text("\(filter.like_count)")
                            .font(.pretendard(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .padding(16)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }
    
    struct FilterBlockView: View {
        let filters: [FilterItem]
        let onLike: (String, Bool) -> Void
        let onFilterTap: (String) -> Void
        let onLoadMore: () -> Void
        let isLoadingMore: Bool
        
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        
        var body: some View {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filters) { filter in
                    FilterBlockItem(
                        filter: filter,
                        onLike: onLike,
                        onFilterTap: onFilterTap
                    )
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
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    struct FilterBlockItem: View {
        let filter: FilterItem
        let onLike: (String, Bool) -> Void
        let onFilterTap: (String) -> Void
        
        var body: some View {
            Button {
                onFilterTap(filter.filter_id)
            } label: {
                VStack(spacing: 8) {
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
                        
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button {
                                    onLike(filter.filter_id, !filter.is_liked)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: filter.is_liked ? "heart.fill" : "heart")
                                            .font(.system(size: 12))
                                            .foregroundColor(filter.is_liked ? .red : .white)
                                        Text("\(filter.like_count)")
                                            .font(.pretendard(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(12)
                                }
                                .padding(8)
                            }
                        }
                    }
                    
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
            .buttonStyle(.plain)
        }
    }
}
