//
//  FilterManagementViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 7/13/25.
//

import Foundation
import Combine

@MainActor
final class FilterManagementViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var myFilters: [FilterItem] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Private Properties
    private let filterUseCase: FilterUseCase
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(filterUseCase: FilterUseCase = FilterUseCaseImpl()) {
        self.filterUseCase = filterUseCase
    }
    
    // MARK: - Public Methods
    
    /// 내 필터 목록 로드
    func loadMyFilters(userId: String) async {
        print("📋 FilterManagementViewModel: 내 필터 로드 시작 - userId: \(userId)")
        
        isLoading = true
        errorMessage = ""
        
        do {
            let filters = try await filterUseCase.getUserFilters(userId: userId)
            
            myFilters = filters
            isLoading = false
            
            print("✅ FilterManagementViewModel: 내 필터 로드 성공 - \(filters.count)개")
            
        } catch {
            isLoading = false
            errorMessage = "필터 목록을 불러오는데 실패했습니다."
            
            print("❌ FilterManagementViewModel: 내 필터 로드 실패 - \(error)")
            
            // 에러 타입별 세분화 처리
            if let filterError = error as? FilterDeleteError {
                errorMessage = filterError.localizedDescription
            } else if let networkError = error as? NetworkError {
                switch networkError {
               
                default:
                    errorMessage = "네트워크 오류가 발생했습니다."
                }
            }
        }
    }
    
    /// 필터 삭제 (Optimistic Update 방식 - 내부에서 UI 업데이트하지 않음)
    func deleteFilter(filterId: String) async -> Bool {
        print("🗑️ FilterManagementViewModel: 필터 삭제 시작 - filterId: \(filterId)")
        
        errorMessage = ""
        
        do {
            let success = try await filterUseCase.deleteFilter(filterId: filterId)
            
            if success {
                print("✅ FilterManagementViewModel: 서버에서 필터 삭제 성공")
                return true
            } else {
                print("❌ FilterManagementViewModel: 서버에서 필터 삭제 실패")
                errorMessage = "필터 삭제에 실패했습니다."
                return false
            }
            
        } catch {
            print("❌ FilterManagementViewModel: 필터 삭제 에러 - \(error)")
            
            // 에러 타입별 세분화 처리
            if let filterError = error as? FilterDeleteError {
                errorMessage = filterError.localizedDescription
            } else if let networkError = error as? NetworkError {
                switch networkError {
             
             
                case .forbidden:
                    errorMessage = "구매자가 있어 제거할 수 없습니다"
             
                default:
                    errorMessage = "필터 삭제 중 오류가 발생했습니다."
                }
            } else {
                errorMessage = "알 수 없는 오류가 발생했습니다."
            }
            
            return false
        }
    }
    
    /// 특정 필터를 로컬 목록에서 제거 (UI 즉시 업데이트용)
    func removeFilterFromList(filterId: String) {
        myFilters.removeAll { $0.filter_id == filterId }
        print("🔄 FilterManagementViewModel: UI에서 필터 제거 - filterId: \(filterId)")
    }
    
    /// 필터 목록 복원 (삭제 실패 시 롤백용)
    func restoreFilters(_ filters: [FilterItem]) {
        myFilters = filters
        print("🔄 FilterManagementViewModel: 필터 목록 복원 완료")
    }
    
    /// 에러 메시지 초기화
    func clearErrorMessage() {
        errorMessage = ""
    }
    
    // MARK: - Private Methods
    
    deinit {
        print("🗑️ FilterManagementViewModel: 메모리 해제")
        cancellables.removeAll()
    }
}
