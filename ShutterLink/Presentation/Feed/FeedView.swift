//
//  FeedView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/24/25.
//

import SwiftUI
import Combine

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var currentTopRankingIndex = 0
    @State private var selectedCategory: FilterCategory? = nil
    @EnvironmentObject private var router: NavigationRouter
    
    var body: some View {
        NavigationStack(path: $router.feedPath) {
            feedContent
                .navigationDestination(for: FilterRoute.self) { route in
                    switch route {
                    case .filterDetail(let filterId):
                        FilterDetailView(filterId: filterId)
                    }
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
                                router.pushToFilterDetail(filterId: filterId, from: .feed)
                            }
                        )
                        .padding(.top, 24)
                    }
                    
                    // 정렬 옵션과 뷰 모드 토글
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
                                print("🔵 Block Mode 버튼 터치됨 - 현재 모드: \(viewModel.viewMode)")
                                viewModel.input.toggleViewMode.send()
                            } label: {
                                Text(viewModel.viewMode == .list ? "Block Mode" : "List Mode")
                                    .font(.pretendard(size: 14, weight: .regular))
                                    .foregroundColor(DesignSystem.Colors.Gray.gray45)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            .zIndex(100)
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 30)
                    
                    // Filter Feed 리스트/블록 뷰
                    if viewModel.viewMode == .list {
                        FilterListView(
                            filters: viewModel.displayedFilters,
                            onLike: { filterId, shouldLike in
                                viewModel.input.likeFilter.send((filterId, shouldLike))
                            },
                            onFilterTap: { filterId in
                                router.pushToFilterDetail(filterId: filterId, from: .feed)
                            },
                            onLoadMore: {
                                viewModel.input.loadMoreData.send()
                            },
                            isLoadingMore: viewModel.isLoadingMore
                        )
                    } else {
                        SafePinterestBlockView(
                            filters: viewModel.displayedFilters,
                            onLike: { filterId, shouldLike in
                                viewModel.input.likeFilter.send((filterId, shouldLike))
                            },
                            onFilterTap: { filterId in
                                router.pushToFilterDetail(filterId: filterId, from: .feed)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.loadDataOnceIfNeeded()
                viewModel.input.selectCategory.send(nil)
            }
        }
        .refreshable {
            print("🔵 FeedView: Pull-to-refresh")
            await MainActor.run {
                viewModel.input.refreshData.send()
            }
        }
        .compatibleOnChange(of: router.feedPath) { newPath in
            let filterIds = newPath.map { route in
                switch route {
                case .filterDetail(let filterId):
                    return filterId
                }
            }
            print("🔵 FeedView Navigation Path: \(filterIds)")
        }
    }
}

// MARK: - 안전한 Pinterest 스타일 Block View
struct SafePinterestBlockView: View {
    let filters: [FilterItem]
    let onLike: (String, Bool) -> Void
    let onFilterTap: (String) -> Void
    let onLoadMore: () -> Void
    let isLoadingMore: Bool
    
    private let spacing: CGFloat = 8
    private var columnWidth: CGFloat {
        (UIScreen.main.bounds.width - 40 - spacing) / 2
    }
    
    var body: some View {
        LazyVStack(spacing: 0) {
            // 간단한 2열 레이아웃으로 변경
            ForEach(Array(stride(from: 0, to: filters.count, by: 2)), id: \.self) { index in
                HStack(alignment: .top, spacing: spacing) {
                    // 왼쪽 열
                    if index < filters.count {
                        SafeFilterBlockItem(
                            filter: filters[index],
                            columnWidth: columnWidth,
                            isLarge: shouldBeLarge(index: index),
                            onLike: onLike,
                            onFilterTap: onFilterTap
                        )
                        .onAppear {
                            if index >= filters.count - 4 {
                                onLoadMore()
                            }
                        }
                    }
                    
                    // 오른쪽 열
                    if index + 1 < filters.count {
                        SafeFilterBlockItem(
                            filter: filters[index + 1],
                            columnWidth: columnWidth,
                            isLarge: shouldBeLarge(index: index + 1),
                            onLike: onLike,
                            onFilterTap: onFilterTap
                        )
                    } else {
                        Spacer()
                            .frame(width: columnWidth)
                    }
                }
                .padding(.bottom, spacing)
            }
            
            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                    Spacer()
                }
                .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // 랜덤하게 큰 셀과 작은 셀 배치
    private func shouldBeLarge(index: Int) -> Bool {
        let patterns = [false, true, false, false, true, false, true, false]
        return patterns[index % patterns.count]
    }
}

// MARK: - 안전한 필터 블록 아이템
struct SafeFilterBlockItem: View {
    let filter: FilterItem
    let columnWidth: CGFloat
    let isLarge: Bool
    let onLike: (String, Bool) -> Void
    let onFilterTap: (String) -> Void
    
    @State private var shouldLoadImage = false
    @State private var isVisible = false
    
    private var imageHeight: CGFloat {
        if isLarge {
            return columnWidth * 1.4 // 세로 이미지용
        } else {
            return columnWidth * 0.8 // 가로 이미지용
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // 이미지 영역
            ZStack {
                Button {
                    onFilterTap(filter.filter_id)
                } label: {
                    Group {
                        if shouldLoadImage && isVisible, let firstImagePath = filter.files.first {
                            AuthenticatedImageView(
                                imagePath: firstImagePath,
                                contentMode: .fill,
                                targetSize: CGSize(width: columnWidth * 2, height: imageHeight * 2)
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
                                        .font(.system(size: 28))
                                )
                        }
                    }
                    .frame(width: columnWidth, height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                
                // 필터명 오버레이 (좌하단)
                VStack {
                    Spacer()
                    HStack {
                        Text(filter.title)
                            .font(.hakgyoansim(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
                
                // 좋아요 버튼 (우하단)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            // 메인스레드에서 실행 보장
                            DispatchQueue.main.async {
                                onLike(filter.filter_id, !filter.is_liked)
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: filter.is_liked ? "heart.fill" : "heart")
                                    .font(.system(size: 11))
                                    .foregroundColor(filter.is_liked ? .red : .white)
                                Text("\(filter.like_count)")
                                    .font(.pretendard(size: 9, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 6)
                        .padding(.bottom, 6)
                    }
                }
            }
            
            // 작가 이름
            Text(filter.creator.nick)
                .font(.pretendard(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
        }
        .frame(width: columnWidth)
        .onAppear {
            // 메인스레드에서 상태 업데이트
            DispatchQueue.main.async {
                isVisible = true
            }
            
            // 이미지 로딩 지연
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                shouldLoadImage = true
            }
        }
        .onDisappear {
            // 메인스레드에서 상태 업데이트
            DispatchQueue.main.async {
                isVisible = false
                shouldLoadImage = false
            }
        }
    }
}

// MARK: - 나머지 확장들 (카테고리, 랭킹, 정렬, 리스트뷰)
extension FeedView {
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
            LazyVStack(spacing: 20) {
                ForEach(filters) { filter in
                    FilterListItem(
                        filter: filter,
                        onLike: onLike,
                        onFilterTap: onFilterTap
                    )
                    .id(filter.filter_id)
                    .onAppear {
                        if let index = filters.firstIndex(where: { $0.id == filter.id }),
                           index >= filters.count - 3 {
                            onLoadMore()
                        }
                    }
                }
                
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        Spacer()
                    }
                    .padding(.vertical, 16)
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
        
        @State private var shouldLoadImage = false
        
        var body: some View {
            HStack(spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    Button {
                        onFilterTap(filter.filter_id)
                    } label: {
                        if shouldLoadImage, let firstImagePath = filter.files.first {
                            AuthenticatedImageView(
                                imagePath: firstImagePath,
                                contentMode: .fill,
                                targetSize: CGSize(width: 80, height: 80)
                            ) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    )
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 24))
                                )
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button {
                        // 메인스레드에서 실행 보장
                        DispatchQueue.main.async {
                            onLike(filter.filter_id, !filter.is_liked)
                        }
                    } label: {
                        Image(systemName: filter.is_liked ? "heart.fill" : "heart")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(filter.is_liked ? DesignSystem.Colors.Gray.gray15 : DesignSystem.Colors.Gray.gray45)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .offset(x: -6, y: -6)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(filter.title)
                            .font(.hakgyoansim(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("#\(filter.category ?? "인물")")
                            .font(.pretendard(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        
                        Spacer()
                    }
                    
                    Text(filter.creator.nick)
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(filter.description)
                        .font(.pretendard(size: 12, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.Gray.gray45)
                        .lineLimit(3)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onFilterTap(filter.filter_id)
                }
            }
            .frame(minHeight: 100)
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
}
