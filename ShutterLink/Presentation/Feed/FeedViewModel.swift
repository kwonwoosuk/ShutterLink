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
        let refreshData = PassthroughSubject<Void, Never>()
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
    
    private let initialPageLimit = 5
    private let pageLimit = 8
    
    private var hasEverLoaded = false
    private var lastLoadTime: Date?
    private var lastLoadMoreTime: Date? // 추가: 마지막 더 로드한 시간
    private let cacheValidDuration: TimeInterval = 300
    private let loadMoreCooldown: TimeInterval = 1.0 // 추가: 로드 더 쿨다운
    
    private var currentLoadTask: Task<Void, Never>?
    private var currentCategoryTask: Task<Void, Never>?
    private var currentMoreDataTask: Task<Void, Never>?
    
    // 추가: 로딩 방지 플래그들
    private var isLoadMoreInProgress = false
    private var loadMoreRequestCount = 0
    
    init(filterUseCase: FilterUseCase = FilterUseCaseImpl()) {
        self.filterUseCase = filterUseCase
        setupBindings()
    }
    
    private func setupBindings() {
        // 로드 더 요청 debounce 강화 및 중복 방지
        input.loadMoreData
            .debounce(for: 1.0, scheduler: RunLoop.main) // 1초로 증가
            .sink { [weak self] in
                guard let self = self else { return }
                
                // 쿨다운 체크
                if let lastTime = self.lastLoadMoreTime,
                   Date().timeIntervalSince(lastTime) < self.loadMoreCooldown {
                    print("🚫 FeedViewModel: 로드 더 쿨다운 중 - 스킵")
                    return
                }
                
                // 이미 진행 중인지 체크
                guard !self.isLoadMoreInProgress else {
                    print("🚫 FeedViewModel: 이미 로드 더 진행 중 - 스킵")
                    return
                }
                
                self.loadMoreData()
            }
            .store(in: &cancellables)
        
        input.selectCategory
            .debounce(for: 0.3, scheduler: RunLoop.main) // 0.3초로 증가
            .removeDuplicates() // 중복 제거
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
            .debounce(for: 0.3, scheduler: RunLoop.main)
            .removeDuplicates()
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
            .debounce(for: 0.1, scheduler: RunLoop.main) // debounce 추가
            .sink { [weak self] in
                Task { [weak self] in
                    await MainActor.run {
                        self?.viewMode = self?.viewMode == .list ? .block : .list
                        print("🔄 FeedViewModel: 뷰 모드 변경됨 - \(self?.viewMode.rawValue ?? "unknown")")
                    }
                }
            }
            .store(in: &cancellables)
        
        input.likeFilter
            .debounce(for: 0.2, scheduler: RunLoop.main) // debounce 추가
            .sink { [weak self] filterId, shouldLike in
                self?.likeFilter(filterId: filterId, newLikeStatus: shouldLike)
            }
            .store(in: &cancellables)
        
        input.refreshData
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }
    
    func loadDataOnceIfNeeded() {
        if let lastLoadTime = lastLoadTime,
           Date().timeIntervalSince(lastLoadTime) < cacheValidDuration,
           !allDataEmpty {
            print("🔵 FeedViewModel: 캐시된 데이터 사용")
            return
        }
        
        guard !hasEverLoaded || (errorMessage != nil && allDataEmpty) else {
            print("🔵 FeedViewModel: 이미 로딩했거나 데이터가 있음 - 스킵")
            return
        }
        
        loadInitialData()
    }
    
    func refreshData() {
        print("🔵 FeedViewModel: 데이터 새로고침")
        hasEverLoaded = false
        lastLoadTime = nil
        lastLoadMoreTime = nil // 추가
        isLoadMoreInProgress = false // 추가
        loadInitialData()
    }
    
    private var allDataEmpty: Bool {
        return allFilters.isEmpty && displayedFilters.isEmpty
    }
    
    private func loadInitialData() {
        guard !isLoading else { return }
        
        currentLoadTask?.cancel()
        
        currentLoadTask = Task { @MainActor in
            print("🔵 FeedViewModel: 초기 데이터 로딩 시작")
            
            self.isLoading = true
            self.errorMessage = nil
            self.allFiltersNextCursor = ""
            self.isLoadMoreInProgress = false // 리셋
            
            do {
                let currentSortOption = self.selectedSortOption
                
                let response = try await filterUseCase.getFilters(
                    next: "",
                    limit: initialPageLimit,
                    category: nil,
                    orderBy: currentSortOption.rawValue
                )
                
                try Task.checkCancellation()
                
                self.allFilters = response.data
                self.topRankingFilter = response.data.first
                self.hasEverLoaded = true
                self.lastLoadTime = Date()
                self.allFiltersNextCursor = response.next_cursor
                
                await loadCategoryDataInternal()
                
                self.isLoading = false
                
                print("✅ FeedViewModel: 초기 데이터 로딩 완료 - \(response.data.count)개 항목")
                
            } catch is CancellationError {
                print("🔵 FeedViewModel: 초기 데이터 로딩 취소됨")
                self.isLoading = false
            } catch {
                print("❌ FeedViewModel: 초기 데이터 로딩 실패 - \(error)")
                self.isLoading = false
                self.errorMessage = "필터를 불러오는데 실패했습니다"
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
            self.isLoadMoreInProgress = false // 리셋
        }
        self.nextCursor = ""
        
        do {
            let response = try await filterUseCase.getFilters(
                next: "",
                limit: initialPageLimit,
                category: selectedCategory?.rawValue,
                orderBy: selectedSortOption.rawValue
            )
            
            try Task.checkCancellation()
            
            await MainActor.run {
                self.displayedFilters = response.data
                self.hasMoreData = response.next_cursor != "0"
            }
            self.nextCursor = response.next_cursor
            
            print("✅ FeedViewModel: 카테고리 데이터 로딩 완료 - \(response.data.count)개 항목")
            
        } catch is CancellationError {
            print("🔵 FeedViewModel: 카테고리 데이터 로딩 취소됨")
        } catch {
            print("❌ FeedViewModel: 카테고리 데이터 로딩 실패 - \(error)")
            await MainActor.run {
                self.errorMessage = "카테고리 필터를 불러오는데 실패했습니다"
            }
        }
    }
    
    // MARK: - 개선된 로드 더 로직
    private func loadMoreData() {
        Task {
            let canLoadMore = await MainActor.run {
                !self.isLoadingMore &&
                !self.isLoadMoreInProgress &&
                self.hasMoreData &&
                !self.nextCursor.isEmpty &&
                self.nextCursor != "0" &&
                self.displayedFilters.count >= 5 // 최소 데이터 확보 후 로딩
            }
            
            guard canLoadMore else {
                print("🔵 FeedViewModel: 추가 로딩 조건 미충족")
                return
            }
            
            // 진행 상태 마킹
            await MainActor.run {
                self.isLoadMoreInProgress = true
                self.lastLoadMoreTime = Date()
            }
            
            currentMoreDataTask?.cancel()
            
            currentMoreDataTask = Task { @MainActor in
                let selectedCategory = self.selectedCategory
                let selectedSortOption = self.selectedSortOption
                let currentCursor = self.nextCursor
                
                self.isLoadingMore = true
                
                do {
                    print("🔵 FeedViewModel: 추가 데이터 로딩 시작 - cursor: \(currentCursor)")
                    
                    let response = try await filterUseCase.getFilters(
                        next: currentCursor,
                        limit: pageLimit,
                        category: selectedCategory?.rawValue,
                        orderBy: selectedSortOption.rawValue
                    )
                    
                    try Task.checkCancellation()
                    
                    // 중복 데이터 필터링
                    let newFilters = response.data.filter { newFilter in
                        !self.displayedFilters.contains { $0.filter_id == newFilter.filter_id }
                    }
                    
                    self.displayedFilters.append(contentsOf: newFilters)
                    self.hasMoreData = response.next_cursor != "0"
                    self.isLoadingMore = false
                    self.isLoadMoreInProgress = false
                    self.nextCursor = response.next_cursor
                    
                    print("✅ FeedViewModel: 추가 데이터 로딩 완료 - \(newFilters.count)개 새 항목")
                    
                } catch is CancellationError {
                    print("🔵 FeedViewModel: 추가 데이터 로딩 취소됨")
                    self.isLoadingMore = false
                    self.isLoadMoreInProgress = false
                } catch {
                    print("❌ FeedViewModel: 추가 데이터 로딩 실패 - \(error)")
                    self.isLoadingMore = false
                    self.isLoadMoreInProgress = false
                    self.errorMessage = "추가 데이터를 불러오는데 실패했습니다"
                    
                    Task {
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            if self.errorMessage == "추가 데이터를 불러오는데 실패했습니다" {
                                self.errorMessage = nil
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func likeFilter(filterId: String, newLikeStatus: Bool) {
        Task { @MainActor in
            self.updateFilterLikeStatus(filterId: filterId, isLiked: newLikeStatus)
            
            do {
                let serverResponse = try await filterUseCase.likeFilter(filterId: filterId, likeStatus: newLikeStatus)
                
                if serverResponse != newLikeStatus {
                    print("⚠️ FeedViewModel: 서버 응답과 UI 상태 불일치, 서버 상태로 수정")
                    self.updateFilterLikeStatus(filterId: filterId, isLiked: serverResponse)
                }
                
            } catch {
                print("❌ FeedViewModel: 좋아요 처리 실패 - \(error)")
                self.updateFilterLikeStatus(filterId: filterId, isLiked: !newLikeStatus)
                
                self.errorMessage = "좋아요 처리에 실패했습니다"
                Task {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        if self.errorMessage == "좋아요 처리에 실패했습니다" {
                            self.errorMessage = nil
                        }
                    }
                }
            }
        }
    }
    
    @MainActor
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
        print("🗑️ FeedViewModel: 메모리 해제")
        currentLoadTask?.cancel()
        currentCategoryTask?.cancel()
        currentMoreDataTask?.cancel()
        cancellables.removeAll()
    }
}

// MARK: - ViewMode enum 추가
extension FeedViewMode {
    var rawValue: String {
        switch self {
        case .list: return "list"
        case .block: return "block"
        }
    }
}
