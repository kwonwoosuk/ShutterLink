//
//  SearchViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 6/2/25.
//

import SwiftUI
import Combine

final class SearchViewModel: ObservableObject {
    struct Input {
        let searchUsers = PassthroughSubject<String, Never>()
        let clearResults = PassthroughSubject<Void, Never>()
    }
    
    @Published var searchResults: [UserInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    private let userUseCase: UserUseCase
    
    // Task 관리용
    private var searchTask: Task<Void, Never>?
    
    init(userUseCase: UserUseCase = UserUseCaseImpl()) {
        self.userUseCase = userUseCase
        setupBindings()
    }
    
    private func setupBindings() {
        // 유저 검색
        input.searchUsers
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.searchUsers(query: query)
            }
            .store(in: &cancellables)
        
        // 검색 결과 초기화
        input.clearResults
            .sink { [weak self] in
                Task { [weak self] in
                    await MainActor.run {
                        self?.searchResults = []
                        self?.errorMessage = nil
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func searchUsers(query: String) {
        // 기존 검색 작업 취소
        searchTask?.cancel()
        
        // 빈 쿼리면 결과 초기화
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Task { @MainActor in
                self.searchResults = []
                self.errorMessage = nil
            }
            return
        }
        
        searchTask = Task {
            print("🔍 SearchViewModel: 유저 검색 시작 - \(query)")
            
            // UI 상태 업데이트 (메인스레드)
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            do {
                // 네트워킹 작업 (백그라운드에서 실행)
                let response = try await userUseCase.searchUsers(nick: query)
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                print("✅ SearchViewModel: 유저 검색 성공 - \(response.data.count)개 결과")
                
                // UI 업데이트 (메인스레드에서 실행)
                await MainActor.run {
                    self.searchResults = response.data
                    self.isLoading = false
                }
                
            } catch is CancellationError {
                print("🔍 SearchViewModel: 유저 검색 작업 취소됨")
                await MainActor.run {
                    self.isLoading = false
                }
            } catch let error as NetworkError {
                print("❌ SearchViewModel: 유저 검색 실패 - \(error)")
                
                await MainActor.run {
                    self.isLoading = false
                    self.searchResults = []
                    
                    switch error {
                    case .accessTokenExpired, .invalidAccessToken:
                        self.errorMessage = "로그인이 만료되었습니다. 다시 로그인해주세요."
                    case .tooManyRequests:
                        self.errorMessage = "검색 요청이 너무 많습니다. 잠시 후 다시 시도해주세요."
                    default:
                        self.errorMessage = "검색 중 오류가 발생했습니다."
                    }
                }
                
                // 에러 메시지를 3초 후 자동으로 제거
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        if self.errorMessage != nil {
                            self.errorMessage = nil
                        }
                    }
                }
            } catch {
                print("❌ SearchViewModel: 알 수 없는 에러 - \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.searchResults = []
                    self.errorMessage = "검색 중 오류가 발생했습니다."
                }
                
                // 에러 메시지를 3초 후 자동으로 제거
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        if self.errorMessage == "검색 중 오류가 발생했습니다." {
                            self.errorMessage = nil
                        }
                    }
                }
            }
        }
    }
    
    deinit {
        searchTask?.cancel()
        cancellables.removeAll()
    }
}
