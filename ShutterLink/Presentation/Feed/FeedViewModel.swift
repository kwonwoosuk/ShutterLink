//
//  FeedViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/24/25.
//

import SwiftUI
import Combine

class FeedViewModel: ObservableObject {
    // MARK: - Input
    struct Input {
        let loadInitialData = PassthroughSubject<Void, Never>()
        let loadMoreData = PassthroughSubject<Void, Never>()
        let selectCategory = PassthroughSubject<FilterCategory, Never>()
        let selectSortOption = PassthroughSubject<FilterSortOption, Never>()
        let toggleViewMode = PassthroughSubject<Void, Never>()
        let likeFilter = PassthroughSubject<(String, Bool), Never>()
        let refreshData = PassthroughSubject<Void, Never>()
    }
    
    // MARK: - Output
    @Published var topRankingFilter: FilterItem?
    @Published var allFilters: [FilterItem] = [] // 전체 필터 데이터
    @Published var displayedFilters: [FilterItem] = [] // 화면에 표시할 필터 데이터
    @Published var selectedCategory: FilterCategory = .all
    @Published var selectedSortOption: FilterSortOption = .popularity
    @Published var viewMode: FeedViewMode = .list
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreData = true
    @Published var errorMessage: String?
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    private let filterUseCase: FilterUseCase
    private var nextCursor = ""
    private let pageLimit = 10
    
    init(filterUseCase: FilterUseCase = FilterUseCaseImpl()) {
        self.filterUseCase = filterUseCase
        setupBindings()
    }
    
    private func setupBindings() {
        // 초기 데이터 로드
        input.loadInitialData
            .sink { [weak self] in
                Task {
                    await self?.loadInitialData()
                }
            }
            .store(in: &cancellables)
        
        // 더 많은 데이터 로드
        input.loadMoreData
            .sink { [weak self] in
                Task {
                    await self?.loadMoreData()
                }
            }
            .store(in: &cancellables)
        
        // 카테고리 선택
        input.selectCategory
            .sink { [weak self] category in
                self?.selectedCategory = category
                self?.applyFilters()
            }
            .store(in: &cancellables)
        
        // 정렬 옵션 선택
        input.selectSortOption
            .sink { [weak self] option in
                self?.selectedSortOption = option
                Task {
                    await self?.loadInitialData()
                }
            }
            .store(in: &cancellables)
        
        // 뷰 모드 토글
        input.toggleViewMode
            .sink { [weak self] in
                self?.viewMode = self?.viewMode == .list ? .block : .list
            }
            .store(in: &cancellables)
        
        // 필터 좋아요
        input.likeFilter
            .sink { [weak self] filterId, likeStatus in
                Task {
                    await self?.likeFilter(filterId: filterId, likeStatus: likeStatus)
                }
            }
            .store(in: &cancellables)
        
        // 데이터 새로고침
        input.refreshData
            .sink { [weak self] in
                Task {
                    await self?.loadInitialData()
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        nextCursor = ""
        hasMoreData = true
        
        do {
            // 필터 목록 로드
            let response = try await filterUseCase.getFilters(
                next: "",
                limit: pageLimit,
                category: nil, // 서버에서 전체 데이터를 받아온 후 클라이언트에서 필터링
                orderBy: selectedSortOption.rawValue
            )
            
            allFilters = response.data
            applyFilters()
            
            // Top Ranking 필터 설정 (첫 번째 필터)
            topRankingFilter = allFilters.first
            
            nextCursor = response.next_cursor
            hasMoreData = response.next_cursor != "0"
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "필터를 불러오는데 실패했습니다"
            print("❌ 필터 로드 실패: \(error)")
        }
    }
    
    @MainActor
    private func loadMoreData() async {
        guard !isLoadingMore && hasMoreData && !nextCursor.isEmpty && nextCursor != "0" else { return }
        
        isLoadingMore = true
        
        do {
            let response = try await filterUseCase.getFilters(
                next: nextCursor,
                limit: pageLimit,
                category: nil,
                orderBy: selectedSortOption.rawValue
            )
            
            allFilters.append(contentsOf: response.data)
            applyFilters()
            
            nextCursor = response.next_cursor
            hasMoreData = response.next_cursor != "0"
            
            isLoadingMore = false
        } catch {
            isLoadingMore = false
            errorMessage = "추가 데이터를 불러오는데 실패했습니다"
            print("❌ 추가 데이터 로드 실패: \(error)")
        }
    }
    
    private func applyFilters() {
        if selectedCategory == .all {
            displayedFilters = allFilters
        } else {
            displayedFilters = allFilters.filter { filter in
                filter.category == selectedCategory.rawValue
            }
        }
    }
    
    @MainActor
    private func likeFilter(filterId: String, likeStatus: Bool) async {
        do {
            let success = try await filterUseCase.likeFilter(filterId: filterId, likeStatus: likeStatus)
            
            if success {
                // 좋아요 상태 업데이트
                if let index = allFilters.firstIndex(where: { $0.filter_id == filterId }) {
                    allFilters[index].is_liked = likeStatus
                    allFilters[index].like_count += likeStatus ? 1 : -1
                }
                
                if let index = displayedFilters.firstIndex(where: { $0.filter_id == filterId }) {
                    displayedFilters[index].is_liked = likeStatus
                    displayedFilters[index].like_count += likeStatus ? 1 : -1
                }
            }
        } catch {
            errorMessage = "좋아요 처리에 실패했습니다"
            print("❌ 좋아요 처리 실패: \(error)")
        }
    }
}
