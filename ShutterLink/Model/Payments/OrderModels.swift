//
//  OrderModels.swift
//  ShutterLink
//
//  Created by 권우석 on 6/18/25.
//

import Foundation

// MARK: - 주문 생성 요청
struct OrderRequest: Codable {
    let filter_id: String
    let total_price: Int
}

// MARK: - 주문 생성 응답
struct OrderResponse: Decodable {
    let order_id: String
    let order_code: String
    let total_price: Int
    let createdAt: String
    let updatedAt: String
}

// MARK: - 결제 검증 요청
struct PaymentValidationRequest: Codable {
    let imp_uid: String
}

// MARK: - 결제 검증 응답
struct PaymentValidationResponse: Decodable {
    let payment_id: String
    let order_item: OrderItem
    let createdAt: String
    let updatedAt: String
}

// MARK: - 주문 아이템
struct OrderItem: Decodable {
    let order_id: String
    let order_code: String
    let filter: FilterInOrder  // 별도 모델 사용
    let paidAt: String
    let createdAt: String
    let updatedAt: String
}

// MARK: - 주문 내 필터 정보 (서버 응답 구조에 맞춘 별도 모델)
struct FilterInOrder: Decodable {
    let id: String  // filter_id가 아니라 id
    let category: String
    let title: String
    let description: String
    let files: [String]
    let price: Int
    let creator: CreatorInfo
    let filterValues: FilterValues
    let createdAt: String
    let updatedAt: String
    
    // FilterDetailResponse로 변환하는 computed property
    var asFilterDetailResponse: FilterDetailResponse {
        return FilterDetailResponse(
            filter_id: id,  // id를 filter_id로 매핑
            category: category,
            title: title,
            description: description,
            files: files,
            price: price,
            creator: creator,
            photoMetadata: nil,  // 주문 응답에는 포함되지 않음
            filterValues: filterValues,
            is_liked: false,  // 기본값
            is_downloaded: true,  // 결제 완료된 상태이므로 true
            like_count: 0,  // 기본값
            buyer_count: 0,  // 기본값
            comments: [],  // 기본값
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - 결제 영수증 응답
struct PaymentReceiptResponse: Decodable {
    let imp_uid: String
    let merchant_uid: String
    let amount: Int
    let currency: String
    let status: String

    let pay_method: String?
    let channel: String?
    let pg_provider: String?
    let emb_pg_provider: String?
    let pg_tid: String?
    let pg_id: String?
    let escrow: Bool?
    let apply_num: String?
    let bank_code: String?
    let bank_name: String?
    let card_code: String?
    let card_name: String?
    let card_issuer_code: String?
    let card_issuer_name: String?
    let card_publisher_code: String?
    let card_publisher_name: String?
    let card_quota: Int?
    let card_number: String?
    let card_type: Int?
    let vbank_code: String?
    let vbank_name: String?
    let vbank_num: String?
    let vbank_holder: String?
    let vbank_date: Int?
    let vbank_issued_at: Int?
    let name: String?
    let buyer_name: String?
    let buyer_email: String?
    let buyer_tel: String?
    let buyer_addr: String?
    let buyer_postcode: String?
    let custom_data: String?
    let user_agent: String?
    let startedAt: String?
    let paidAt: String?
    let receipt_url: String?
    let createdAt: String?
    let updatedAt: String?
}
