//
//  FeedViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/24/25.
//

import SwiftUI
import Combine

class FeedViewModel: ObservableObject {
    struct Input {
        let loadMoreData = PassthroughSubject<Void, Never>()
        let selectCategory = PassthroughSubject<FilterCategory?, Never>()
        let selectSortOption = PassthroughSubject<FilterSortOption, Never>()
        let toggleViewMode = PassthroughSubject<Void, Never>()
        let likeFilter = PassthroughSubject<(String, Bool), Never>()
    }
    
    @Published var topRankingFilter: FilterItem?
    @Published var allFilters: [FilterItem] = []
    @Published var displayedFilters: [FilterItem] = []
    @Published var selectedCategory: FilterCategory? = nil
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
    private var allFiltersNextCursor = ""
    private let pageLimit = 10
    
    private var hasEverLoaded = false
    
    private var currentLoadTask: Task<Void, Never>?
    private var currentCategoryTask: Task<Void, Never>?
    private var currentMoreDataTask: Task<Void, Never>?
    
    init(filterUseCase: FilterUseCase = FilterUseCaseImpl()) {
        self.filterUseCase = filterUseCase
        setupBindings()
    }
    
    private func setupBindings() {
        input.loadMoreData
            .sink { [weak self] in
                self?.loadMoreData()
            }
            .store(in: &cancellables)
        
        input.selectCategory
            .sink { [weak self] category in
                Task { [weak self] in
                    await MainActor.run {
                        self?.selectedCategory = category
                    }
                    self?.loadCategoryData()
                }
            }
            .store(in: &cancellables)
        
        input.selectSortOption
            .sink { [weak self] option in
                Task { [weak self] in
                    await MainActor.run {
                        self?.selectedSortOption = option
                    }
                    self?.loadInitialData()
                }
            }
            .store(in: &cancellables)
        
        input.toggleViewMode
            .sink { [weak self] in
                Task { [weak self] in
                    await MainActor.run {
                        self?.viewMode = self?.viewMode == .list ? .block : .list
                    }
                }
            }
            .store(in: &cancellables)
        
        input.likeFilter
            .sink { [weak self] filterId, shouldLike in
                self?.likeFilter(filterId: filterId, newLikeStatus: shouldLike)
            }
            .store(in: &cancellables)
    }
    
    func loadDataOnceIfNeeded() {
        guard !hasEverLoaded || (errorMessage != nil && allDataEmpty) else {
            print("🔵 FeedViewModel: 이미 로딩했거나 데이터가 있음 - 스킵")
            return
        }
        
        loadInitialData()
    }
    
    func refreshData() {
        loadInitialData()
    }
    
    private var allDataEmpty: Bool {
        return allFilters.isEmpty && displayedFilters.isEmpty
    }
    
    private func loadInitialData() {
        guard !isLoading else { return }
        
        currentLoadTask?.cancel()
        
        currentLoadTask = Task {
            print("🔵 FeedViewModel: 초기 데이터 로딩 시작")
            
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            self.allFiltersNextCursor = ""
            
            do {
                let currentSortOption = await MainActor.run { self.selectedSortOption }
                
                let allResponse = try await filterUseCase.getFilters(
                    next: "",
                    limit: pageLimit,
                    category: nil,
                    orderBy: currentSortOption.rawValue
                )
                
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.allFilters = allResponse.data
                    self.topRankingFilter = allResponse.data.first
                    self.hasEverLoaded = true
                }
                self.allFiltersNextCursor = allResponse.next_cursor
                
                await loadCategoryDataInternal()
                
                await MainActor.run {
                    self.isLoading = false
                }
                
            } catch is CancellationError {
                print("🔵 FeedViewModel: 초기 데이터 로딩 취소됨")
            } catch {
                print("❌ FeedViewModel: 초기 데이터 로딩 실패 - \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "필터를 불러오는데 실패했습니다"
                }
            }
        }
    }
    
    private func loadCategoryData() {
        currentCategoryTask?.cancel()
        currentCategoryTask = Task {
            await loadCategoryDataInternal()
        }
    }
    
    private func loadCategoryDataInternal() async {
        let selectedCategory = await MainActor.run { self.selectedCategory }
        let selectedSortOption = await MainActor.run { self.selectedSortOption }
        
        await MainActor.run {
            self.hasMoreData = true
        }
        self.nextCursor = ""
        
        do {
            let response = try await filterUseCase.getFilters(
                next: "",
                limit: pageLimit,
                category: selectedCategory?.rawValue,
                orderBy: selectedSortOption.rawValue
            )
            
            try Task.checkCancellation()
            
            await MainActor.run {
                self.displayedFilters = response.data
                self.hasMoreData = response.next_cursor != "0"
            }
            self.nextCursor = response.next_cursor
            
        } catch is CancellationError {
            print("🔵 FeedViewModel: 카테고리 데이터 로딩 취소됨")
        } catch {
            print("❌ FeedViewModel: 카테고리 데이터 로딩 실패 - \(error)")
            await MainActor.run {
                self.errorMessage = "카테고리 필터를 불러오는데 실패했습니다"
            }
        }
    }
    
    private func loadMoreData() {
        Task {
            let canLoadMore = await MainActor.run {
                !self.isLoadingMore && self.hasMoreData && !self.nextCursor.isEmpty && self.nextCursor != "0"
            }
            
            guard canLoadMore else { return }
            
            currentMoreDataTask?.cancel()
            
            currentMoreDataTask = Task {
                let selectedCategory = await MainActor.run { self.selectedCategory }
                let selectedSortOption = await MainActor.run { self.selectedSortOption }
                let currentCursor = self.nextCursor
                
                await MainActor.run {
                    self.isLoadingMore = true
                }
                
                do {
                    let response = try await filterUseCase.getFilters(
                        next: currentCursor,
                        limit: pageLimit,
                        category: selectedCategory?.rawValue,
                        orderBy: selectedSortOption.rawValue
                    )
                    
                    try Task.checkCancellation()
                    
                    await MainActor.run {
                        self.displayedFilters.append(contentsOf: response.data)
                        self.hasMoreData = response.next_cursor != "0"
                        self.isLoadingMore = false
                    }
                    self.nextCursor = response.next_cursor
                    
                } catch is CancellationError {
                    print("🔵 FeedViewModel: 더보기 로딩 취소됨")
                    await MainActor.run {
                        self.isLoadingMore = false
                    }
                } catch {
                    print("❌ FeedViewModel: 더보기 로딩 실패 - \(error)")
                    await MainActor.run {
                        self.isLoadingMore = false
                        self.errorMessage = "추가 데이터를 불러오는데 실패했습니다"
                    }
                }
            }
        }
    }
    
    private func likeFilter(filterId: String, newLikeStatus: Bool) {
        Task {
            await MainActor.run {
                self.updateFilterLikeStatus(filterId: filterId, isLiked: newLikeStatus)
            }
            
            do {
                let serverResponse = try await filterUseCase.likeFilter(filterId: filterId, likeStatus: newLikeStatus)
                
                if serverResponse != newLikeStatus {
                    await MainActor.run {
                        self.updateFilterLikeStatus(filterId: filterId, isLiked: serverResponse)
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.updateFilterLikeStatus(filterId: filterId, isLiked: !newLikeStatus)
                    self.errorMessage = "좋아요 처리에 실패했습니다"
                }
            }
        }
    }
    
    private func updateFilterLikeStatus(filterId: String, isLiked: Bool) {
        if let index = allFilters.firstIndex(where: { $0.filter_id == filterId }) {
            let oldStatus = allFilters[index].is_liked
            allFilters[index].is_liked = isLiked
            
            if oldStatus != isLiked {
                allFilters[index].like_count += isLiked ? 1 : -1
            }
        }
        
        if let index = displayedFilters.firstIndex(where: { $0.filter_id == filterId }) {
            let oldStatus = displayedFilters[index].is_liked
            displayedFilters[index].is_liked = isLiked
            
            if oldStatus != isLiked {
                displayedFilters[index].like_count += isLiked ? 1 : -1
            }
        }
    }
    
    deinit {
        currentLoadTask?.cancel()
        currentCategoryTask?.cancel()
        currentMoreDataTask?.cancel()
        cancellables.removeAll()
    }
}
