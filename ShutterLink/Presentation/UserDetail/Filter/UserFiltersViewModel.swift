//
//  UserFiltersViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 6/2/25.
//

import SwiftUI
import Combine

class UserFiltersViewModel: ObservableObject {
    struct Input {
        let loadInitialFilters = PassthroughSubject<String, Never>()
        let loadMoreFilters = PassthroughSubject<Void, Never>()
        let likeFilter = PassthroughSubject<(String, Bool), Never>()
        let refreshData = PassthroughSubject<String, Never>()
    }
    
    @Published var filters: [FilterItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreData = true
    @Published var errorMessage: String?
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    private let userUseCase: UserUseCase
    private let filterUseCase: FilterUseCase
    
    // 페이지네이션 상태
    private var currentUserId = ""
    private var nextCursor = ""
    private let pageLimit = 10
    
    // Task 관리용
    private var loadFiltersTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var likeTask: Task<Void, Never>?
    
    // 로드 방지 플래그
    private var isLoadMoreInProgress = false
    
    init(userUseCase: UserUseCase = UserUseCaseImpl(), filterUseCase: FilterUseCase = FilterUseCaseImpl()) {
        self.userUseCase = userUseCase
        self.filterUseCase = filterUseCase
        setupBindings()
    }
    
    private func setupBindings() {
        // 초기 필터 로드
        input.loadInitialFilters
            .sink { [weak self] userId in
                print("🔵 UserFiltersViewModel: loadInitialFilters 신호 수신 - \(userId)")
                self?.loadInitialFilters(userId: userId)
            }
            .store(in: &cancellables)
        
        // 더 많은 필터 로드
        input.loadMoreFilters
            .debounce(for: 1.0, scheduler: RunLoop.main)
            .sink { [weak self] in
                print("🔵 UserFiltersViewModel: loadMoreFilters 신호 수신")
                self?.loadMoreFilters()
            }
            .store(in: &cancellables)
        
        // 필터 좋아요
        input.likeFilter
            .debounce(for: 0.2, scheduler: RunLoop.main)
            .sink { [weak self] filterId, shouldLike in
                print("🔵 UserFiltersViewModel: likeFilter 신호 수신 - \(filterId), \(shouldLike)")
                self?.likeFilter(filterId: filterId, newLikeStatus: shouldLike)
            }
            .store(in: &cancellables)
        
        // 데이터 새로고침
        input.refreshData
            .sink { [weak self] userId in
                print("🔵 UserFiltersViewModel: refreshData 신호 수신 - \(userId)")
                self?.loadInitialFilters(userId: userId)
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialFilters(userId: String) {
        // 기존 작업 취소
        loadFiltersTask?.cancel()
        
        loadFiltersTask = Task {
            print("🔵 UserFiltersViewModel: 초기 필터 로드 시작 - \(userId)")
            
            // UI 상태 업데이트 (메인스레드)
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
                self.currentUserId = userId
                self.nextCursor = ""
                self.isLoadMoreInProgress = false
            }
            
            do {
                // 네트워킹 작업 (백그라운드에서 실행)
                let response = try await userUseCase.getUserFilters(
                    userId: userId,
                    category: nil,
                    next: "",
                    limit: pageLimit
                )
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                print("✅ UserFiltersViewModel: 초기 필터 로드 성공 - \(response.data.count)개 필터")
                
                // UI 업데이트 (메인스레드에서 실행)
                await MainActor.run {
                    self.filters = response.data
                    self.hasMoreData = response.next_cursor != "0"
                    self.isLoading = false
                }
                self.nextCursor = response.next_cursor
                
            } catch is CancellationError {
                print("🔵 UserFiltersViewModel: 초기 필터 로드 작업 취소됨")
                await MainActor.run {
                    self.isLoading = false
                }
            } catch let error as NetworkError {
                print("❌ UserFiltersViewModel: 초기 필터 로드 실패 - \(error)")
                
                await MainActor.run {
                    self.isLoading = false
                    self.filters = []
                    
                    switch error {
                    case .invalidStatusCode(404):
                        self.errorMessage = "사용자를 찾을 수 없습니다."
                    case .accessTokenExpired, .invalidAccessToken:
                        self.errorMessage = "로그인이 만료되었습니다. 다시 로그인해주세요."
                    default:
                        self.errorMessage = "필터 목록을 불러오는데 실패했습니다."
                    }
                }
            } catch {
                print("❌ UserFiltersViewModel: 알 수 없는 에러 - \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.filters = []
                    self.errorMessage = "필터 목록을 불러오는데 실패했습니다."
                }
            }
        }
    }
    
    private func loadMoreFilters() {
        Task {
            let canLoadMore = await MainActor.run {
                !self.isLoadingMore &&
                !self.isLoadMoreInProgress &&
                self.hasMoreData &&
                !self.nextCursor.isEmpty &&
                self.nextCursor != "0" &&
                !self.currentUserId.isEmpty
            }
            
            guard canLoadMore else {
                print("🔵 UserFiltersViewModel: 추가 로딩 조건 미충족")
                return
            }
            
            // 진행 상태 마킹
            await MainActor.run {
                self.isLoadMoreInProgress = true
            }
            
            // 기존 작업 취소
            loadMoreTask?.cancel()
            
            loadMoreTask = Task { @MainActor in
                let userId = self.currentUserId
                let cursor = self.nextCursor
                
                self.isLoadingMore = true
                
                do {
                    print("🔵 UserFiltersViewModel: 추가 필터 로드 시작 - cursor: \(cursor)")
                    
                    let response = try await userUseCase.getUserFilters(
                        userId: userId,
                        category: nil,
                        next: cursor,
                        limit: pageLimit
                    )
                    
                    try Task.checkCancellation()
                    
                    // 중복 데이터 필터링
                    let newFilters = response.data.filter { newFilter in
                        !self.filters.contains { $0.filter_id == newFilter.filter_id }
                    }
                    
                    self.filters.append(contentsOf: newFilters)
                    self.hasMoreData = response.next_cursor != "0"
                    self.isLoadingMore = false
                    self.isLoadMoreInProgress = false
                    self.nextCursor = response.next_cursor
                    
                    print("✅ UserFiltersViewModel: 추가 필터 로드 완료 - \(newFilters.count)개 새 필터")
                    
                } catch is CancellationError {
                    print("🔵 UserFiltersViewModel: 추가 필터 로드 작업 취소됨")
                    self.isLoadingMore = false
                    self.isLoadMoreInProgress = false
                } catch {
                    print("❌ UserFiltersViewModel: 추가 필터 로드 실패 - \(error)")
                    self.isLoadingMore = false
                    self.isLoadMoreInProgress = false
                    self.errorMessage = "추가 필터를 불러오는데 실패했습니다."
                    
                    Task {
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            if self.errorMessage == "추가 필터를 불러오는데 실패했습니다." {
                                self.errorMessage = nil
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func likeFilter(filterId: String, newLikeStatus: Bool) {
        // 기존 좋아요 작업 취소
        likeTask?.cancel()
        
        likeTask = Task {
            print("🔵 UserFiltersViewModel: 좋아요 처리 시작 - \(filterId), 새 상태: \(newLikeStatus)")
            
            // 즉시 UI 업데이트 (낙관적 업데이트) - 메인스레드에서 실행
            await MainActor.run {
                self.updateFilterLikeStatus(filterId: filterId, isLiked: newLikeStatus)
            }
            
            do {
                // 네트워킹 작업 (백그라운드에서 실행)
                let serverResponse = try await filterUseCase.likeFilter(filterId: filterId, likeStatus: newLikeStatus)
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                print("✅ UserFiltersViewModel: 서버 응답 - \(serverResponse)")
                
                // 서버 응답과 UI 상태가 다르면 서버 응답에 맞춰 수정
                if serverResponse != newLikeStatus {
                    print("⚠️ UserFiltersViewModel: 서버 응답과 UI 상태 불일치, 서버 상태로 수정")
                    await MainActor.run {
                        self.updateFilterLikeStatus(filterId: filterId, isLiked: serverResponse)
                    }
                }
                
            } catch is CancellationError {
                print("🔵 UserFiltersViewModel: 좋아요 처리 작업 취소됨")
                // 취소된 경우 원래 상태로 롤백
                await MainActor.run {
                    self.updateFilterLikeStatus(filterId: filterId, isLiked: !newLikeStatus)
                }
            } catch {
                print("❌ UserFiltersViewModel: 좋아요 처리 실패 - \(error)")
                
                // 실패 시 UI 상태를 원래대로 되돌림 (롤백) - 메인스레드에서 실행
                await MainActor.run {
                    self.updateFilterLikeStatus(filterId: filterId, isLiked: !newLikeStatus)
                    self.errorMessage = "좋아요 처리에 실패했습니다."
                }
                
                // 에러 메시지를 3초 후 자동으로 제거
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        if self.errorMessage == "좋아요 처리에 실패했습니다." {
                            self.errorMessage = nil
                        }
                    }
                }
            }
        }
    }
    
    @MainActor
    private func updateFilterLikeStatus(filterId: String, isLiked: Bool) {
        if let index = filters.firstIndex(where: { $0.filter_id == filterId }) {
            let oldStatus = filters[index].is_liked
            filters[index].is_liked = isLiked
            
            if oldStatus != isLiked {
                filters[index].like_count += isLiked ? 1 : -1
            }
        }
    }
    
    deinit {
        loadFiltersTask?.cancel()
        loadMoreTask?.cancel()
        likeTask?.cancel()
        cancellables.removeAll()
    }
}
