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
}

class FilterUseCaseImpl: FilterUseCase {
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
}
