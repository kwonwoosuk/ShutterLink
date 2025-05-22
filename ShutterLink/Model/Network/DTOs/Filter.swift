//
//  Filter.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import Foundation

// MARK: - 오늘의 필터 모델
struct TodayFilterResponse: Decodable {
    let filter_id: String
    let title: String
    let introduction: String
    let description: String
    let files: [String]
    let createdAt: String
    let updatedAt: String
}

// MARK: - 핫트랜드 필터 응답 모델
struct HotTrendFiltersResponse: Decodable {
    let data: [FilterItem]
}

// MARK: - 오늘의 작가 응답 모델
struct TodayAuthorResponse: Decodable {
    let author: AuthorInfo
    let filters: [FilterItem]
}

// MARK: - 공통 필터 아이템 모델
struct FilterItem: Decodable, Identifiable {
    let filter_id: String
    let category: String?
    let title: String
    let description: String
    let files: [String]
    let creator: CreatorInfo
    let is_liked: Bool
    let like_count: Int
    let buyer_count: Int
    let createdAt: String
    let updatedAt: String
    
    var id: String { filter_id }
}

// MARK: - 작가 정보 모델
struct AuthorInfo: Decodable {
    let user_id: String
    let nick: String
    let name: String
    let introduction: String
    let description: String
    let profileImage: String?
    let hashTags: [String]
}

// MARK: - 크리에이터 정보 모델
struct CreatorInfo: Decodable {
    let user_id: String
    let nick: String
    let name: String
    let introduction: String
    let profileImage: String?
    let hashTags: [String]
}

// MARK: - 이미지 URL 유틸리티
extension String {
    var fullImageURL: String {
        if self.isEmpty {
            return ""
        }
        return APIConstants.baseURL + "/v1" + self
    }
}
