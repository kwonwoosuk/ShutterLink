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
    @State private var selectedCategory: FilterCategory? = nil // nil = 전체 상태
    @State private var hasAppeared = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 다크 모드 배경
                Color.black.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 카테고리 버튼들 - 5개 고정
                        CategoryButtonsView(
                            selectedCategory: $selectedCategory,
                            onSelectCategory: { category in
                                print("🔵 카테고리 선택: \(category?.title ?? "전체")")
                                selectedCategory = category
                                viewModel.input.selectCategory.send(category)
                            }
                        )
                        .padding(.top, 20)
                        .opacity(viewModel.isLoading ? 0.7 : 1.0)
                        
                        // Top Ranking 섹션
                        if !viewModel.allFilters.isEmpty {
                            TopRankingSection(
                                filters: Array(viewModel.allFilters.prefix(5)),
                                currentIndex: $currentTopRankingIndex,
                                onLike: { filterId, shouldLike in
                                    // Top Ranking에서도 좋아요 처리
                                    viewModel.input.likeFilter.send((filterId, shouldLike))
                                }
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
                        
                        // 현재 선택된 카테고리 표시 (디버깅용)
                        if let selectedCategory = selectedCategory {
                            Text("선택된 카테고리: \(selectedCategory.title)")
                                .font(.pretendard(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                        } else {
                            Text("전체 카테고리")
                                .font(.pretendard(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                        }
                        
                        // Filter Feed 리스트
                        if viewModel.viewMode == .list {
                            FilterListView(
                                filters: viewModel.displayedFilters,
                                onLike: { filterId, shouldLike in
                                    // 수정된 부분: 좋아요 토글 상태를 전달
                                    viewModel.input.likeFilter.send((filterId, shouldLike))
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
                                    // Block 모드에서도 좋아요 처리 추가
                                    viewModel.input.likeFilter.send((filterId, shouldLike))
                                },
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("FEED")
                        .font(.hakgyoansim(size: 18, weight: DesignSystem.Typography.FontFamily.HakgyoansimWeight.bold))
                        .foregroundColor(.gray45)
                }
                //            .toolbar {
                //                ToolbarItem(placement: .principal) {
                //                    Text("FEED")
                //                        .font(.pretendard(size: 18, weight: .medium))
                //                        .foregroundColor(.white)
                //                }
                //
                //                ToolbarItem(placement: .navigationBarLeading) {
                //                    Button {
                //                        // 뒤로가기
                //                    } label: {
                //                        Image(systemName: "chevron.left")
                //                            .foregroundColor(.white)
                //                    }
                //                }
                //            }
            }
            .onAppear {
                if !hasAppeared {
                    hasAppeared = true
                    // 메인스레드에서 약간의 지연 후 초기화 신호 전송
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("🔵 Feed 초기 로딩 시작")
                        viewModel.input.loadInitialData.send()
                        // 초기 상태: 아무 카테고리도 선택하지 않음 (전체 표시)
                        viewModel.input.selectCategory.send(nil)
                    }
                }
            }
            .refreshable {
                // refreshable은 자동으로 메인스레드에서 실행됨
                viewModel.input.refreshData.send()
            }
        }
    }
    
    // MARK: - 카테고리 버튼들 (5개 고정, GeometryReader 제거)
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
                            // 같은 카테고리를 다시 누르면 선택 해제 (전체로 돌아감)
                            let newCategory = selectedCategory == category ? nil : category
                            onSelectCategory(newCategory)
                        }
                    )
                    .frame(maxWidth: .infinity) // 5개 버튼 균등 분배
                }
            }
            .frame(height: 80) // 명시적 높이 설정으로 레이아웃 안정화
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
                print("🔵 카테고리 버튼 탭: \(category.title)")
                // 햅틱 피드백 (메인스레드에서 실행)
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                action()
            }) {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? DesignSystem.Colors.Brand.brightTurquoise.opacity(0.15) : Color.gray.opacity(0.15))
                            .frame(width: 48, height: 48) // 버튼 크기
                        
                        Image(getCategoryIcon(for: category))
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24) // 아이콘 크기
                            .foregroundColor(isSelected ? DesignSystem.Colors.Brand.brightTurquoise : .gray)
                    }
                    
                    Text(category.title)
                        .font(.pretendard(size: 12, weight: .regular))
                        .foregroundColor(isSelected ? DesignSystem.Colors.Brand.brightTurquoise : .gray)
                        .lineLimit(1)
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        isPressed = true
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
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
    
    // MARK: - Top Ranking 섹션 (좋아요 기능 추가)
    struct TopRankingSection: View {
        let filters: [FilterItem]
        @Binding var currentIndex: Int
        let onLike: (String, Bool) -> Void
        
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
                                                VerticalOvalCard(
                                                    filter: filter,
                                                    rank: index + 1,
                                                    onLike: onLike
                                                )
                                                .scaleEffect(scale)
                                                .id(index)
                                            } else {
                                                MiniVerticalOvalCard(
                                                    filter: filter,
                                                    rank: index + 1,
                                                    onLike: onLike
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
    
    // MARK: - 수정된 FilterListItem
    struct FilterListItem: View {
        let filter: FilterItem
        let onLike: (String, Bool) -> Void
        
        var body: some View {
            // NavigationLink로 전체 아이템 감싸기
            if #available(iOS 16.0, *) {
                NavigationLink(destination: FilterDetailView(filterId: filter.filter_id)) {
                    listItemContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                NavigationLink(destination: FilterDetailView(filterId: filter.filter_id)) {
                    listItemContent
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        
        @ViewBuilder
        private var listItemContent: some View {
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
                
                // 좋아요 버튼 - 별도 처리하여 네비게이션과 분리
                VStack(spacing: 4) {
                    Button {
                        // 반대 상태를 전달 (핵심 수정 부분)
                        onLike(filter.filter_id, !filter.is_liked)
                    } label: {
                        Image(systemName: filter.is_liked ? "heart.fill" : "heart")
                            .foregroundColor(filter.is_liked ? .red : .gray)
                            .font(.system(size: 20))
                    }
                    .onTapGesture {
                        // 탭 제스처를 사용하여 네비게이션 방지
                    }
                    
                    // 좋아요 개수 표시
                    Text("\(filter.like_count)")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 필터 블럭 뷰 (Block Mode) - 좋아요 기능 추가
    struct FilterBlockView: View {
        let filters: [FilterItem]
        let onLike: (String, Bool) -> Void
        let onLoadMore: () -> Void
        let isLoadingMore: Bool
        
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        
        var body: some View {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filters) { filter in
                    FilterBlockItem(filter: filter, onLike: onLike)
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
    
    // MARK: - 수정된 FilterBlockItem
    struct FilterBlockItem: View {
        let filter: FilterItem
        let onLike: (String, Bool) -> Void
        
        var body: some View {
            // NavigationLink로 전체 아이템 감싸기
            if #available(iOS 16.0, *) {
                NavigationLink(destination: FilterDetailView(filterId: filter.filter_id)) {
                    blockItemContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                NavigationLink(destination: FilterDetailView(filterId: filter.filter_id)) {
                    blockItemContent
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        
        @ViewBuilder
        private var blockItemContent: some View {
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
                    
                    // 좋아요 카운트와 버튼
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                // 반대 상태를 전달
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
                            .onTapGesture {
                                // 탭 제스처를 사용하여 네비게이션 방지
                            }
                            .padding(8)
                        }
                    }
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
}
