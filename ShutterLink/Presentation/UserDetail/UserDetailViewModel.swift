//
//  UserDetailViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 6/2/25.
//

import SwiftUI
import Combine

class UserDetailViewModel: ObservableObject {
    struct Input {
        let loadUserDetail = PassthroughSubject<String, Never>()
        let refreshData = PassthroughSubject<String, Never>()
    }
    
    @Published var userDetail: UserInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    private let userUseCase: UserUseCase
    
    // Task 관리용
    private var loadDetailTask: Task<Void, Never>?
    
    init(userUseCase: UserUseCase = UserUseCaseImpl()) {
        self.userUseCase = userUseCase
        setupBindings()
    }
    
    private func setupBindings() {
        // 유저 상세 로드
        input.loadUserDetail
            .sink { [weak self] userId in
                print("🔵 UserDetailViewModel: loadUserDetail 신호 수신 - \(userId)")
                self?.loadUserDetail(userId: userId)
            }
            .store(in: &cancellables)
        
        // 데이터 새로고침
        input.refreshData
            .sink { [weak self] userId in
                print("🔵 UserDetailViewModel: refreshData 신호 수신 - \(userId)")
                self?.loadUserDetail(userId: userId)
            }
            .store(in: &cancellables)
    }
    
    private func loadUserDetail(userId: String) {
        // 기존 작업 취소
        loadDetailTask?.cancel()
        
        loadDetailTask = Task {
            print("🔵 UserDetailViewModel: 유저 상세 로드 시작 - \(userId)")
            
            // UI 상태 업데이트 (메인스레드)
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            do {
                // 현재는 검색 결과에서 받은 userInfo를 사용하므로 별도 API 호출 없이 처리
                // 필요 시 추가 유저 정보 API 호출 가능
                
                await MainActor.run {
                    self.isLoading = false
                }
                
                print("✅ UserDetailViewModel: 유저 상세 로드 완료")
                
            } catch is CancellationError {
                print("🔵 UserDetailViewModel: 유저 상세 로드 작업 취소됨")
                await MainActor.run {
                    self.isLoading = false
                }
            } catch let error as NetworkError {
                print("❌ UserDetailViewModel: 유저 상세 로드 실패 - \(error)")
                
                await MainActor.run {
                    self.isLoading = false
                    
                    switch error {
                    case .invalidStatusCode(404):
                        self.errorMessage = "사용자를 찾을 수 없습니다."
                    case .accessTokenExpired, .invalidAccessToken:
                        self.errorMessage = "로그인이 만료되었습니다. 다시 로그인해주세요."
                    default:
                        self.errorMessage = error.errorMessage
                    }
                }
            } catch {
                print("❌ UserDetailViewModel: 알 수 없는 에러 - \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "사용자 정보를 불러오는데 실패했습니다."
                }
            }
        }
    }
    
    deinit {
        loadDetailTask?.cancel()
        cancellables.removeAll()
    }
}
