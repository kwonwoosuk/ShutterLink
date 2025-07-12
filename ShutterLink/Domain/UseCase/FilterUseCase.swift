//
//  FilterUseCase.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import Foundation

protocol FilterUseCase {
    func getTodayFilter() async throws -> TodayFilterResponse
    func getHotTrendFilters() async throws -> [FilterItem]
    func getFilters(next: String, limit: Int, category: String?, orderBy: String) async throws -> FilterListResponse
    func likeFilter(filterId: String, likeStatus: Bool) async throws -> Bool
    func getFilterDetail(filterId: String) async throws -> FilterDetailResponse
    func getLikedFilters(next: String, limit: Int, category: String?) async throws -> FilterListResponse
    func uploadFilterFiles(originalData: Data, filteredData: Data) async throws -> [String]
    func createFilter(request: FilterCreateRequest) async throws -> FilterDetailResponse
    func getUserFilters(userId: String) async throws -> [FilterItem]
    func deleteFilter(filterId: String) async throws -> Bool

}

final class FilterUseCaseImpl: FilterUseCase {
    private let networkManager = NetworkManager.shared
    
    func getTodayFilter() async throws -> TodayFilterResponse {
        let router = FilterRouter.getTodayFilter
        return try await networkManager.request(router, type: TodayFilterResponse.self)
    }
    
    func getHotTrendFilters() async throws -> [FilterItem] {
        let router = FilterRouter.getHotTrendFilters
        let response = try await networkManager.request(router, type: HotTrendFiltersResponse.self)
        return response.data
    }
    
    func getFilters(next: String, limit: Int, category: String?, orderBy: String) async throws -> FilterListResponse {
        let router = FilterRouter.getFilters(next: next, limit: limit, category: category, orderBy: orderBy)
        return try await networkManager.request(router, type: FilterListResponse.self)
    }
    
    func likeFilter(filterId: String, likeStatus: Bool) async throws -> Bool {
        let router = FilterRouter.likeFilter(filterId: filterId, likeStatus: likeStatus)
        let response = try await networkManager.request(router, type: LikeResponse.self)
        return response.like_status
    }
    
    func getFilterDetail(filterId: String) async throws -> FilterDetailResponse {
        let router = FilterRouter.getFilterDetail(filterId: filterId)
        return try await networkManager.request(router, type: FilterDetailResponse.self)
    }
    
    func getLikedFilters(next: String, limit: Int, category: String?) async throws -> FilterListResponse {
        let router = FilterRouter.getLikedFilters(next: next, limit: limit, category: category)
        return try await networkManager.request(router, type: FilterListResponse.self)
    }
    
    func uploadFilterFiles(originalData: Data, filteredData: Data) async throws -> [String] {
            let router = FilterRouter.uploadFilterFiles(originalImage: originalData, filteredImage: filteredData)
            
            // multipart/form-data 업로드를 위한 특별한 처리
            let uploadData = try await networkManager.uploadMultipleImages(
                router,
                images: [
                    ("files", filteredData, "filtered.jpg"),
                    ("files", originalData, "original.jpg")
                  
                ]
            )
            
            let response = try JSONDecoder().decode(FilterFilesUploadResponse.self, from: uploadData)
            return response.files
        }
        
        func createFilter(request: FilterCreateRequest) async throws -> FilterDetailResponse {
            let router = FilterRouter.createFilter(request: request)
            return try await networkManager.request(router, type: FilterDetailResponse.self)
        }
    
    func getUserFilters(userId: String) async throws -> [FilterItem] {
            print("📡 FilterUseCase: 사용자 필터 조회 시작 - userId: \(userId)")
            let router = FilterRouter.getUserFilter(userId: userId)
            let response = try await networkManager.request(router, type: FilterListResponse.self)
            print("✅ FilterUseCase: 사용자 필터 조회 성공 - 필터 개수: \(response.data.count)")
            return response.data
        }
        
        func deleteFilter(filterId: String) async throws -> Bool {
            print("🗑️ FilterUseCase: 필터 삭제 시작 - filterId: \(filterId)")
            let router = FilterRouter.deleteFilter(filterId: filterId)
            
            do {
                let _ = try await networkManager.request(router, type: EmptyResponse.self)
                print("✅ FilterUseCase: 필터 삭제 성공")
                return true
            } catch {
                print("❌ FilterUseCase: 필터 삭제 실패 - \(error)")
                if let networkError = error as? NetworkError {
                                switch networkError {
                                case .invalidSesacKey:
                                    throw FilterDeleteError.unauthorized
                                case .forbidden:
                                    throw FilterDeleteError.noPermission
                                default:
                                    throw FilterDeleteError.networkError
                                }
                            }
                            
                            throw FilterDeleteError.unknown
            }
            
        }
}

struct EmptyResponse: Codable {
    // 빈 응답용 구조체
}

enum FilterDeleteError: LocalizedError {
    case notFound
    case noPermission
    case hasPurchasers
    case unauthorized
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "필터를 찾을 수 없습니다."
        case .noPermission:
            return "구매자가 있어 제거할 수 없습니다"
        case .hasPurchasers:
            return "구매자가 있어 제거할 수 없습니다"
        case .unauthorized:
            return "로그인이 필요합니다."
        case .networkError:
            return "네트워크 오류가 발생했습니다."
        case .unknown:
            return "알 수 없는 오류가 발생했습니다."
        }
    }
}
