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
                    ("files", originalData, "original.jpg"),
                    ("files", filteredData, "filtered.jpg")
                ]
            )
            
            let response = try JSONDecoder().decode(FilterFilesUploadResponse.self, from: uploadData)
            return response.files
        }
        
        func createFilter(request: FilterCreateRequest) async throws -> FilterDetailResponse {
            let router = FilterRouter.createFilter(request: request)
            return try await networkManager.request(router, type: FilterDetailResponse.self)
        }
}
