//
//  OrderUseCase.swift
//  ShutterLink
//
//  Created by 권우석 on 6/19/25.
//

import Foundation

protocol OrderUseCase {
    func createOrder(filterId: String, totalPrice: Int) async throws -> OrderResponse
    func getOrderHistory() async throws -> [OrderItem]
    func validatePayment(impUid: String) async throws -> PaymentValidationResponse
    func getPaymentReceipt(orderCode: String) async throws -> PaymentReceiptResponse
}

final class OrderUseCaseImpl: OrderUseCase {
    private let networkManager = NetworkManager.shared
    
    func createOrder(filterId: String, totalPrice: Int) async throws -> OrderResponse {
        let request = OrderRequest(filter_id: filterId, total_price: totalPrice)
        let router = OrderRouter.createOrder(request)
        return try await networkManager.request(router, type: OrderResponse.self)
    }
    
    func getOrderHistory() async throws -> [OrderItem] {
        let router = OrderRouter.getOrderHistory
        let response = try await networkManager.request(router, type: OrderHistoryResponse.self)
        return response.data
    }
    
    func validatePayment(impUid: String) async throws -> PaymentValidationResponse {
        let request = PaymentValidationRequest(imp_uid: impUid)
        let router = OrderRouter.validatePayment(request)
        return try await networkManager.request(router, type: PaymentValidationResponse.self)
    }
    
    func getPaymentReceipt(orderCode: String) async throws -> PaymentReceiptResponse {
        let router = OrderRouter.getPaymentReceipt(orderCode: orderCode)
        return try await networkManager.request(router, type: PaymentReceiptResponse.self)
    }
}

// MARK: - 주문 내역 응답 모델 추가
struct OrderHistoryResponse: Decodable {
    let data: [OrderItem]
}
