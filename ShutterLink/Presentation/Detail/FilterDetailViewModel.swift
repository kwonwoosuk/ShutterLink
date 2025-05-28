//
//  FilterDetailViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/26/25.
//

import SwiftUI
import Combine

class FilterDetailViewModel: ObservableObject {
    // MARK: - Input
    struct Input {
        let loadFilterDetail = PassthroughSubject<String, Never>()
        let likeFilter = PassthroughSubject<(String, Bool), Never>()
        let refreshData = PassthroughSubject<String, Never>()
    }
    
    // MARK: - Output (@Published 프로퍼티들은 자동으로 메인스레드에서 UI 업데이트)
    @Published var filterDetail: FilterDetailResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    private let filterUseCase: FilterUseCase
    
    // Task 관리용
    private var loadDetailTask: Task<Void, Never>?
    private var likeTask: Task<Void, Never>?
    
    init(filterUseCase: FilterUseCase = FilterUseCaseImpl()) {
        self.filterUseCase = filterUseCase
        setupBindings()
    }
    
    private func setupBindings() {
        // 필터 상세 로드
        input.loadFilterDetail
            .sink { [weak self] filterId in
                print("🔵 FilterDetailViewModel: loadFilterDetail 신호 수신 - \(filterId)")
                self?.loadFilterDetail(filterId: filterId)
            }
            .store(in: &cancellables)
        
        // 필터 좋아요
        input.likeFilter
            .sink { [weak self] filterId, shouldLike in
                print("🔵 FilterDetailViewModel: likeFilter 신호 수신 - \(filterId), 새 상태: \(shouldLike)")
                self?.likeFilter(filterId: filterId, newLikeStatus: shouldLike)
            }
            .store(in: &cancellables)
        
        // 데이터 새로고침
        input.refreshData
            .sink { [weak self] filterId in
                print("🔵 FilterDetailViewModel: refreshData 신호 수신 - \(filterId)")
                self?.loadFilterDetail(filterId: filterId)
            }
            .store(in: &cancellables)
    }
    
    private func loadFilterDetail(filterId: String) {
        // 기존 작업 취소
        loadDetailTask?.cancel()
        
        loadDetailTask = Task {
            print("🔵 FilterDetailViewModel: 필터 상세 로드 시작 - \(filterId)")
            
            // UI 상태 업데이트 (메인스레드)
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            do {
                // 네트워킹 작업 (백그라운드에서 실행)
                let detail = try await filterUseCase.getFilterDetail(filterId: filterId)
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                print("✅ FilterDetailViewModel: 필터 상세 로드 성공 - \(detail.title)")
                
                // UI 업데이트 (메인스레드에서 실행)
                await MainActor.run {
                    self.filterDetail = detail
                    self.isLoading = false
                }
                
            } catch is CancellationError {
                print("🔵 FilterDetailViewModel: 필터 상세 로드 작업 취소됨")
                await MainActor.run {
                    self.isLoading = false
                }
            } catch let error as NetworkError {
                print("❌ FilterDetailViewModel: 필터 상세 로드 실패 - \(error)")
                
                await MainActor.run {
                    self.isLoading = false
                    
                    switch error {
                    case .invalidStatusCode(404):
                        self.errorMessage = "필터를 찾을 수 없습니다."
                    case .accessTokenExpired, .invalidAccessToken:
                        // 토큰 갱신이 실패한 경우에만 여기에 도달
                        print("⚠️ FilterDetailViewModel: 토큰 갱신 실패로 인한 에러")
                        self.errorMessage = "로그인이 만료되었습니다. 다시 로그인해주세요."
                    default:
                        self.errorMessage = error.errorMessage
                    }
                }
            } catch {
                print("❌ FilterDetailViewModel: 알 수 없는 에러 - \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "필터 정보를 불러오는데 실패했습니다."
                }
            }
        }
    }
    
    private func likeFilter(filterId: String, newLikeStatus: Bool) {
        // 기존 좋아요 작업 취소
        likeTask?.cancel()
        
        likeTask = Task {
            print("🔵 FilterDetailViewModel: 좋아요 처리 시작 - \(filterId), 새 상태: \(newLikeStatus)")
            
            // 즉시 UI 업데이트 (낙관적 업데이트) - 메인스레드에서 실행
            await MainActor.run {
                self.updateFilterLikeStatus(isLiked: newLikeStatus)
            }
            
            do {
                // 네트워킹 작업 (백그라운드에서 실행)
                let serverResponse = try await filterUseCase.likeFilter(filterId: filterId, likeStatus: newLikeStatus)
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                print("✅ FilterDetailViewModel: 서버 응답 - \(serverResponse)")
                
                // 서버 응답과 UI 상태가 다르면 서버 응답에 맞춰 수정
                if serverResponse != newLikeStatus {
                    print("⚠️ FilterDetailViewModel: 서버 응답과 UI 상태 불일치, 서버 상태로 수정")
                    await MainActor.run {
                        self.updateFilterLikeStatus(isLiked: serverResponse)
                    }
                }
                
            } catch is CancellationError {
                print("🔵 FilterDetailViewModel: 좋아요 처리 작업 취소됨")
                // 취소된 경우 원래 상태로 롤백
                await MainActor.run {
                    self.updateFilterLikeStatus(isLiked: !newLikeStatus)
                }
            } catch {
                print("❌ FilterDetailViewModel: 좋아요 처리 실패 - \(error)")
                
                // 실패 시 UI 상태를 원래대로 되돌림 (롤백) - 메인스레드에서 실행
                await MainActor.run {
                    self.updateFilterLikeStatus(isLiked: !newLikeStatus)
                    self.errorMessage = "좋아요 처리에 실패했습니다."
                }
                
                // 에러 메시지를 3초 후 자동으로 제거
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000) // 3초
                    await MainActor.run {
                        if self.errorMessage == "좋아요 처리에 실패했습니다." {
                            self.errorMessage = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - UI 업데이트를 별도 메서드로 분리 (메인스레드에서만 호출)
    private func updateFilterLikeStatus(isLiked: Bool) {
        guard var updatedDetail = filterDetail else { return }
        
        let oldStatus = updatedDetail.is_liked
        updatedDetail.is_liked = isLiked
        
        // 좋아요 카운트 업데이트 (상태 변경 시에만)
        if oldStatus != isLiked {
            updatedDetail.like_count += isLiked ? 1 : -1
            print("🔵 FilterDetailViewModel: 좋아요 상태 업데이트 - 좋아요: \(isLiked), 카운트: \(updatedDetail.like_count)")
        }
        
        filterDetail = updatedDetail
    }
    
    // MARK: - Cleanup
    deinit {
        // 모든 진행 중인 작업 취소
        loadDetailTask?.cancel()
        likeTask?.cancel()
        cancellables.removeAll()
    }
}
