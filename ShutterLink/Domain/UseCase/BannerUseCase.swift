//
//  BannerUseCase.swift
//  ShutterLink
//
//  Created by 권우석 on 7/18/25.
//

import Foundation

protocol BannerUseCase {
    func getMainBanners() async throws -> [BannerItem]
}

final class BannerUseCaseImpl: BannerUseCase {
    private let networkManager = NetworkManager.shared
    
    func getMainBanners() async throws -> [BannerItem] {
        print("📡 BannerUseCase: 메인 배너 조회 시작")
        let router = BannerRouter.getMainBanners
        let response = try await networkManager.request(router, type: BannerListResponse.self)
        print("✅ BannerUseCase: 메인 배너 조회 성공 - 배너 개수: \(response.data.count)")
        return response.data
    }
}
