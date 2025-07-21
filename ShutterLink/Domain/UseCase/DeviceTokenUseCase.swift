//
//  DeviceTokenUseCase.swift
//  ShutterLink
//
//  Created by 권우석 on 7/21/25.
//

import Foundation

protocol DeviceTokenUseCase {
    func updateDeviceToken(_ deviceToken: String) async throws
}

final class DeviceTokenUseCaseImpl: DeviceTokenUseCase {
    private let networkManager = NetworkManager.shared
    
    func updateDeviceToken(_ deviceToken: String) async throws {
        let router = UserRouter.updateDeviceToken(deviceToken: deviceToken)
        
        do {
            let _: EmptyResponse = try await networkManager.request(router, type: EmptyResponse.self)
            print("✅ 디바이스 토큰 서버 업데이트 성공: \(deviceToken)")
        } catch {
            print("❌ 디바이스 토큰 서버 업데이트 실패: \(error)")
            throw error
        }
    }
}

