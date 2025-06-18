//
//  PaymentManager.swift
//  ShutterLink
//
//  Created by 권우석 on 6/19/25.
//

import Foundation
import SwiftUI
import WebKit
import iamport_ios

final class PaymentManager: ObservableObject {
    static let shared = PaymentManager()
    
    @Published var isPaymentInProgress = false
    @Published var paymentResult: PaymentResult?
    
    private var paymentCompletion: ((Result<String, PaymentError>) -> Void)?
    
    private init() {}
    
    enum PaymentResult {
        case success(impUid: String)
        case failed(error: String)
        case cancelled
    }
    
    enum PaymentError: Error, LocalizedError {
        case userCancelled
        case paymentFailed(String)
        case invalidResponse
        case networkError
        
        var errorDescription: String? {
            switch self {
            case .userCancelled:
                return "결제가 취소되었습니다."
            case .paymentFailed(let message):
                return "결제 실패: \(message)"
            case .invalidResponse:
                return "결제 응답이 올바르지 않습니다."
            case .networkError:
                return "네트워크 오류가 발생했습니다."
            }
        }
    }
    
    func createPaymentData(
        orderCode: String,
        amount: Int,
        filterTitle: String
    ) -> IamportPayment {
        
        let payment = IamportPayment(
            pg: PG.html5_inicis.makePgRawName(pgId: APIConstants.Payment.pgId),
            merchant_uid: orderCode,
            amount: "\(amount)"
        ).then {
            $0.pay_method = PayMethod.card.rawValue
            $0.name = filterTitle
            $0.buyer_name = "권우석"
            $0.app_scheme = APIConstants.Payment.appScheme
        }
        
        return payment
    }
    
    func processPayment(
        orderCode: String,
        amount: Int,
        filterTitle: String,
        webView: WKWebView
    ) async throws -> String {
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: PaymentError.networkError)
                    return
                }
                
                self.isPaymentInProgress = true
                
                let payment = self.createPaymentData(
                    orderCode: orderCode,
                    amount: amount,
                    filterTitle: filterTitle
                )
                
                // 결제 완료 콜백 설정
                self.paymentCompletion = { result in
                    switch result {
                    case .success(let impUid):
                        continuation.resume(returning: impUid)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                // Portone SDK로 결제 실행
                Iamport.shared.paymentWebView(
                    webViewMode: webView,
                    userCode: APIConstants.Payment.userCode,
                    payment: payment
                ) { [weak self] iamportResponse in
                    print("💳 PaymentManager: 결제 응답 수신")
                    print("💳 PaymentManager: \(String(describing: iamportResponse))")
                    
                    DispatchQueue.main.async {
                        self?.isPaymentInProgress = false
                        self?.handlePaymentResponse(iamportResponse)
                    }
                }
            }
        }
    }
    
    private func handlePaymentResponse(_ response: IamportResponse?) {
        guard let response = response else {
            paymentResult = .failed(error: "결제 응답을 받지 못했습니다.")
            paymentCompletion?(.failure(.invalidResponse))
            return
        }
        
        if response.success == true {
            if let impUid = response.imp_uid {
                print("✅ PaymentManager: 결제 성공 - imp_uid: \(impUid)")
                paymentResult = .success(impUid: impUid)
                paymentCompletion?(.success(impUid))
            } else {
                print("❌ PaymentManager: imp_uid가 없습니다.")
                paymentResult = .failed(error: "결제 ID를 받지 못했습니다.")
                paymentCompletion?(.failure(.invalidResponse))
            }
        } else {
            let errorMessage = response.error_msg ?? "알 수 없는 오류가 발생했습니다."
            print("❌ PaymentManager: 결제 실패 - \(errorMessage)")
            
            // 사용자 취소 여부 확인
            if errorMessage.contains("취소") || errorMessage.contains("cancel") {
                paymentResult = .cancelled
                paymentCompletion?(.failure(.userCancelled))
            } else {
                paymentResult = .failed(error: errorMessage)
                paymentCompletion?(.failure(.paymentFailed(errorMessage)))
            }
        }
        
        // 완료 콜백 초기화
        paymentCompletion = nil
    }
}
