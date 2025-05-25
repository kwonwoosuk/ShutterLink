//
//  FeedViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/24/25.
//

import SwiftUI
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    // MARK: - Input
    struct Input {
        let loadInitialData = PassthroughSubject<Void, Never>()
        let loadMoreData = PassthroughSubject<Void, Never>()
        let selectCategory = PassthroughSubject<FilterCategory?, Never>()
        let selectSortOption = PassthroughSubject<FilterSortOption, Never>()
        let toggleViewMode = PassthroughSubject<Void, Never>()
        let likeFilter = PassthroughSubject<(String, Bool), Never>()
        let refreshData = PassthroughSubject<Void, Never>()
    }
    
    // MARK: - Output
    @Published var topRankingFilter: FilterItem?
    @Published var allFilters: [FilterItem] = [] // Top Ranking용 전체 데이터
    @Published var displayedFilters: [FilterItem] = [] // 현재 선택된 카테고리의 필터 데이터
    @Published var selectedCategory: FilterCategory? = nil // nil = 전체 표시
    @Published var selectedSortOption: FilterSortOption = .popularity
    @Published var viewMode: FeedViewMode = .list
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreData = true
    @Published var errorMessage: String?
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    private let filterUseCase: FilterUseCase
    private var nextCursor = "" // 현재 카테고리용 커서
    private var allFiltersNextCursor = "" // 전체 데이터용 커서
    private let pageLimit = 10
    
    // Task 관리용
    private var currentLoadTask: Task<Void, Never>?
    private var currentCategoryTask: Task<Void, Never>?
    private var currentMoreDataTask: Task<Void, Never>?
    
    init(filterUseCase: FilterUseCase = FilterUseCaseImpl()) {
        self.filterUseCase = filterUseCase
        setupBindings()
    }
    
    private func setupBindings() {
        // 초기 데이터 로드
        input.loadInitialData
            .sink { [weak self] in
                print("🔵 ViewModel: loadInitialData 신호 수신")
                self?.loadInitialData()
            }
            .store(in: &cancellables)
        
        // 더 많은 데이터 로드
        input.loadMoreData
            .sink { [weak self] in
                print("🔵 ViewModel: loadMoreData 신호 수신")
                self?.loadMoreData()
            }
            .store(in: &cancellables)
        
        // 카테고리 선택 - 서버에서 해당 카테고리 데이터 요청
        input.selectCategory
            .sink { [weak self] category in
                let categoryName = category?.title ?? "전체"
                print("🔵 ViewModel: selectCategory 신호 수신 - \(categoryName)")
                self?.selectedCategory = category
                self?.loadCategoryData()
            }
            .store(in: &cancellables)
        
        // 정렬 옵션 선택
        input.selectSortOption
            .sink { [weak self] option in
                print("🔵 ViewModel: selectSortOption 신호 수신 - \(option.title)")
                self?.selectedSortOption = option
                self?.loadInitialData()
            }
            .store(in: &cancellables)
        
        // 뷰 모드 토글 (즉시 UI 업데이트)
        input.toggleViewMode
            .sink { [weak self] in
                print("🔵 ViewModel: toggleViewMode 신호 수신")
                self?.viewMode = self?.viewMode == .list ? .block : .list
            }
            .store(in: &cancellables)
        
        // 필터 좋아요 - 수정된 부분
        input.likeFilter
            .sink { [weak self] filterId, shouldLike in
                print("🔵 ViewModel: likeFilter 신호 수신 - \(filterId), 새 상태: \(shouldLike)")
                self?.likeFilter(filterId: filterId, newLikeStatus: shouldLike)
            }
            .store(in: &cancellables)
        
        // 데이터 새로고침
        input.refreshData
            .sink { [weak self] in
                print("🔵 ViewModel: refreshData 신호 수신")
                self?.loadInitialData()
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        // 기존 작업 취소
        currentLoadTask?.cancel()
        
        currentLoadTask = Task {
            print("🔵 ViewModel: loadInitialData 실행 시작")
            
            // UI 상태 업데이트 (메인스레드)
            isLoading = true
            errorMessage = nil
            allFiltersNextCursor = ""
            
            do {
                // 네트워크 작업 (백그라운드)
                let allResponse = try await Task.detached { [filterUseCase, selectedSortOption, pageLimit] in
                    return try await filterUseCase.getFilters(
                        next: "",
                        limit: pageLimit,
                        category: nil, // 전체 데이터
                        orderBy: selectedSortOption.rawValue
                    )
                }.value
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                print("🔵 ViewModel: 전체 필터 \(allResponse.data.count)개 로드 완료")
                
                // UI 업데이트 (메인스레드)
                allFilters = allResponse.data
                allFiltersNextCursor = allResponse.next_cursor
                topRankingFilter = allFilters.first
                
                // 현재 선택된 카테고리 데이터 로드
                await loadCategoryDataInternal()
                
                isLoading = false
                
            } catch is CancellationError {
                print("🔵 ViewModel: loadInitialData 작업 취소됨")
            } catch {
                print("❌ ViewModel: 필터 로드 실패 - \(error)")
                isLoading = false
                errorMessage = "필터를 불러오는데 실패했습니다"
            }
        }
    }
    
    private func loadCategoryData() {
        // 기존 카테고리 작업 취소
        currentCategoryTask?.cancel()
        
        currentCategoryTask = Task {
            await loadCategoryDataInternal()
        }
    }
    
    private func loadCategoryDataInternal() async {
        let categoryName = selectedCategory?.title ?? "전체"
        print("🔵 ViewModel: 카테고리 '\(categoryName)' 데이터 로드")
        
        // UI 상태 업데이트 (메인스레드)
        nextCursor = ""
        hasMoreData = true
        
        do {
            // 네트워크 작업 (백그라운드)
            let response = try await Task.detached { [filterUseCase, selectedCategory, selectedSortOption, pageLimit] in
                return try await filterUseCase.getFilters(
                    next: "",
                    limit: pageLimit,
                    category: selectedCategory?.rawValue, // 서버에서 카테고리 필터링
                    orderBy: selectedSortOption.rawValue
                )
            }.value
            
            // Task가 취소되었는지 확인
            try Task.checkCancellation()
            
            print("🔵 ViewModel: '\(categoryName)' 카테고리 \(response.data.count)개 필터 로드 완료")
            
            // UI 업데이트 (메인스레드)
            displayedFilters = response.data
            nextCursor = response.next_cursor
            hasMoreData = response.next_cursor != "0"
            
            print("🔵 ViewModel: 표시할 필터 개수 - \(displayedFilters.count)")
            print("🔵 ViewModel: 다음 커서 - \(nextCursor)")
            print("🔵 ViewModel: 더 많은 데이터 있음 - \(hasMoreData)")
            
        } catch is CancellationError {
            print("🔵 ViewModel: loadCategoryData 작업 취소됨")
        } catch {
            print("❌ ViewModel: 카테고리 필터 로드 실패 - \(error)")
            errorMessage = "카테고리 필터를 불러오는데 실패했습니다"
        }
    }
    
    private func loadMoreData() {
        // 로딩 조건 확인
        guard !isLoadingMore && hasMoreData && !nextCursor.isEmpty && nextCursor != "0" else {
            print("🔵 ViewModel: loadMoreData 조건 불충족")
            print("  - isLoadingMore: \(isLoadingMore)")
            print("  - hasMoreData: \(hasMoreData)")
            print("  - nextCursor: '\(nextCursor)'")
            return
        }
        
        // 기존 더보기 작업 취소
        currentMoreDataTask?.cancel()
        
        currentMoreDataTask = Task {
            let categoryName = selectedCategory?.title ?? "전체"
            print("🔵 ViewModel: '\(categoryName)' 카테고리 추가 데이터 로드 시작")
            
            // UI 상태 업데이트 (메인스레드)
            isLoadingMore = true
            
            do {
                // 네트워크 작업 (백그라운드)
                let response = try await Task.detached { [filterUseCase, nextCursor, selectedCategory, selectedSortOption, pageLimit] in
                    return try await filterUseCase.getFilters(
                        next: nextCursor,
                        limit: pageLimit,
                        category: selectedCategory?.rawValue,
                        orderBy: selectedSortOption.rawValue
                    )
                }.value
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                print("🔵 ViewModel: '\(categoryName)' 카테고리 추가로 \(response.data.count)개 필터 로드 완료")
                
                // UI 업데이트 (메인스레드)
                displayedFilters.append(contentsOf: response.data)
                nextCursor = response.next_cursor
                hasMoreData = response.next_cursor != "0"
                isLoadingMore = false
                
                print("🔵 ViewModel: 총 표시 필터 개수 - \(displayedFilters.count)")
                print("🔵 ViewModel: 다음 커서 - \(nextCursor)")
                
            } catch is CancellationError {
                print("🔵 ViewModel: loadMoreData 작업 취소됨")
                isLoadingMore = false
            } catch {
                print("❌ ViewModel: 추가 데이터 로드 실패 - \(error)")
                isLoadingMore = false
                errorMessage = "추가 데이터를 불러오는데 실패했습니다"
            }
        }
    }
    
    // MARK: - 수정된 좋아요 처리 메서드
    private func likeFilter(filterId: String, newLikeStatus: Bool) {
        Task {
            print("🔵 ViewModel: likeFilter 실행 - \(filterId), 새 상태: \(newLikeStatus)")
            
            // 즉시 UI 업데이트 (낙관적 업데이트)
            updateFilterLikeStatus(filterId: filterId, isLiked: newLikeStatus)
            
            do {
                // 네트워크 작업 (백그라운드)
                let serverResponse = try await Task.detached { [filterUseCase] in
                    return try await filterUseCase.likeFilter(filterId: filterId, likeStatus: newLikeStatus)
                }.value
                
                print("🔵 ViewModel: 서버 응답 - \(serverResponse)")
                
                // 서버 응답과 UI 상태가 다르면 서버 응답에 맞춰 수정
                if serverResponse != newLikeStatus {
                    print("⚠️ ViewModel: 서버 응답과 UI 상태 불일치, 서버 상태로 수정")
                    updateFilterLikeStatus(filterId: filterId, isLiked: serverResponse)
                }
                
            } catch {
                print("❌ ViewModel: 좋아요 처리 실패 - \(error)")
                
                // 실패 시 UI 상태를 원래대로 되돌림 (롤백)
                updateFilterLikeStatus(filterId: filterId, isLiked: !newLikeStatus)
                
                errorMessage = "좋아요 처리에 실패했습니다"
            }
        }
    }
    
    // MARK: - UI 업데이트를 별도 메서드로 분리
    private func updateFilterLikeStatus(filterId: String, isLiked: Bool) {
        // allFilters에서 업데이트 (Top Ranking용)
        if let index = allFilters.firstIndex(where: { $0.filter_id == filterId }) {
            let oldStatus = allFilters[index].is_liked
            allFilters[index].is_liked = isLiked
            
            // 좋아요 카운트 업데이트 (상태 변경 시에만)
            if oldStatus != isLiked {
                allFilters[index].like_count += isLiked ? 1 : -1
                print("🔵 ViewModel: allFilters 업데이트 - 좋아요: \(isLiked), 카운트: \(allFilters[index].like_count)")
            }
        }
        
        // displayedFilters에서 업데이트 (현재 화면 표시용)
        if let index = displayedFilters.firstIndex(where: { $0.filter_id == filterId }) {
            let oldStatus = displayedFilters[index].is_liked
            displayedFilters[index].is_liked = isLiked
            
            // 좋아요 카운트 업데이트 (상태 변경 시에만)
            if oldStatus != isLiked {
                displayedFilters[index].like_count += isLiked ? 1 : -1
                print("🔵 ViewModel: displayedFilters 업데이트 - 좋아요: \(isLiked), 카운트: \(displayedFilters[index].like_count)")
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        // 모든 진행 중인 작업 취소
        currentLoadTask?.cancel()
        currentCategoryTask?.cancel()
        currentMoreDataTask?.cancel()
        cancellables.removeAll()
    }
}
