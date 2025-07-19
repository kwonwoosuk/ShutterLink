//
//  Banner.swift
//  ShutterLink
//
//  Created by 권우석 on 7/19/25.
//

import Foundation

// MARK: - 배너 응답 모델
struct BannerListResponse: Decodable {
    let data: [BannerItem]
}

// MARK: - 배너 아이템 모델
struct BannerItem: Decodable, Identifiable, Equatable {
    let name: String
    let imageUrl: String
    let payload: BannerPayload
    
    // Identifiable을 위한 computed property
    var id: String { name }
    
    // UI에서 사용하기 위한 computed properties
    var title: String { name }
    var subtitle: String? { nil } // 서버에서 subtitle을 제공하지 않음
    var image: String { imageUrl }
    
    // Equatable 구현
    static func == (lhs: BannerItem, rhs: BannerItem) -> Bool {
        return lhs.name == rhs.name &&
               lhs.imageUrl == rhs.imageUrl &&
               lhs.payload == rhs.payload
    }
}

// MARK: - 배너 페이로드 모델
struct BannerPayload: Decodable, Equatable {
    let type: String
    let value: String
    
    // Equatable 구현
    static func == (lhs: BannerPayload, rhs: BannerPayload) -> Bool {
        return lhs.type == rhs.type && lhs.value == rhs.value
    }
}


