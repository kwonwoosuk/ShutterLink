//
//  OrderRouter.swift
//  ShutterLink
//
//  Created by 권우석 on 6/19/25.
//

import Foundation

enum OrderRouter: APIRouter {
    case createOrder(OrderRequest)
    case getOrderHistory
    case validatePayment(PaymentValidationRequest)
    case getPaymentReceipt(orderCode: String)
    
    var path: String {
        switch self {
        case .createOrder, .getOrderHistory:
            return APIConstants.Path.orders
        case .validatePayment:
            return APIConstants.Path.paymentValidation
        case .getPaymentReceipt(let orderCode):
            return APIConstants.Path.paymentReceipt(orderCode)
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .createOrder, .validatePayment:
            return .post
        case .getOrderHistory, .getPaymentReceipt:
            return .get
        }
    }
    
    var body: Data? {
        switch self {
        case .createOrder(let request):
            return try? JSONEncoder().encode(request)
        case .validatePayment(let request):
            return try? JSONEncoder().encode(request)
        case .getOrderHistory, .getPaymentReceipt:
            return nil
        }
    }
    
    var authorizationType: AuthorizationType {
        return .accessToken
    }
}
