//
//  HomeViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI
import Combine

final class HomeViewModel: ObservableObject {
    @Published var todayFilter: TodayFilterResponse?
    @Published var hotTrendFilters: [FilterItem] = []
    @Published var todayAuthor: TodayAuthorResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let filterUseCase: FilterUseCase
    private let userUseCase: UserUseCase
    private var loadDataTask: Task<Void, Never>?
    
    private var hasEverLoaded = false
    
    init(filterUseCase: FilterUseCase = FilterUseCaseImpl(), userUseCase: UserUseCase = UserUseCaseImpl()) {
        self.filterUseCase = filterUseCase
        self.userUseCase = userUseCase
    }
    
    func loadDataOnceIfNeeded() {
        guard !hasEverLoaded || (errorMessage != nil && allDataEmpty) else {
            print("🔵 HomeViewModel: 이미 로딩했거나 데이터가 있음 - 스킵")
            return
        }
        
        loadData()
    }
    
    func refreshData() {
        loadData()
    }
    
    private var allDataEmpty: Bool {
        return todayFilter == nil && hotTrendFilters.isEmpty && todayAuthor == nil
    }
    
    private func loadData() {
        guard !isLoading else { return }
        
        loadDataTask?.cancel()
        
        loadDataTask = Task {
            print("🔵 HomeViewModel: 홈 데이터 로딩 시작")
            
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    await self?.loadTodayFilter()
                }
                
                group.addTask { [weak self] in
                    await self?.loadHotTrendFilters()
                }
                
                group.addTask { [weak self] in
                    await self?.loadTodayAuthor()
                }
            }
            
            await MainActor.run {
                self.isLoading = false
                self.hasEverLoaded = true
            }
            print("🔵 HomeViewModel: 홈 데이터 로딩 완료")
        }
    }
    
    private func loadTodayFilter() async {
        do {
            let filter = try await filterUseCase.getTodayFilter()
            try Task.checkCancellation()
            
            await MainActor.run {
                self.todayFilter = filter
            }
            
        } catch is CancellationError {
            print("🔵 HomeViewModel: 오늘의 필터 로드 취소됨")
        } catch {
            print("❌ HomeViewModel: 오늘의 필터 로드 실패 - \(error)")
            await MainActor.run {
                if self.errorMessage == nil {
                    self.errorMessage = "오늘의 필터를 불러오는데 실패했습니다"
                }
            }
        }
    }
    
    private func loadHotTrendFilters() async {
        do {
            let filters = try await filterUseCase.getHotTrendFilters()
            try Task.checkCancellation()
            
            await MainActor.run {
                self.hotTrendFilters = filters
            }
            
        } catch is CancellationError {
            print("🔵 HomeViewModel: 핫트랜드 필터 로드 취소됨")
        } catch {
            print("❌ HomeViewModel: 핫트랜드 필터 로드 실패 - \(error)")
            await MainActor.run {
                if self.errorMessage == nil {
                    self.errorMessage = "핫트랜드 필터를 불러오는데 실패했습니다"
                }
            }
        }
    }
    
    private func loadTodayAuthor() async {
        do {
            let author = try await userUseCase.getTodayAuthor()
            try Task.checkCancellation()
            
            await MainActor.run {
                self.todayAuthor = author
            }
            
        } catch is CancellationError {
            print("🔵 HomeViewModel: 오늘의 작가 로드 취소됨")
        } catch {
            print("❌ HomeViewModel: 오늘의 작가 로드 실패 - \(error)")
            await MainActor.run {
                self.todayAuthor = nil
            }
        }
    }
    
    deinit {
        loadDataTask?.cancel()
    }
}
