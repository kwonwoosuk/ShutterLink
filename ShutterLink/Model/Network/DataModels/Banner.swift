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
struct BannerItem: Decodable, Identifiable {
    let banner_id: String
    let title: String
    let subtitle: String?
    let image: String
    let payload: BannerPayload
    let createdAt: String
    let updatedAt: String
    
    var id: String { banner_id }
}

// MARK: - 배너 페이로드 모델
struct BannerPayload: Decodable {
    let type: String
    let value: String
}

// MARK: - 이미지 URL 유틸리티 확장
extension BannerItem {
    var fullImageURL: String {
        if image.isEmpty {
            return ""
        }
        return APIConstants.baseURL + "/v1" + image
    }
}
