//
//  FilterDetailViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/26/25.
//

import SwiftUI
import Combine
import WebKit

final class FilterDetailViewModel: ObservableObject {
    // MARK: - Input
    struct Input {
        let loadFilterDetail = PassthroughSubject<String, Never>()
        let likeFilter = PassthroughSubject<(String, Bool), Never>()
        let refreshData = PassthroughSubject<String, Never>()
        let purchaseFilter = PassthroughSubject<String, Never>()
    }
    
    // MARK: - Output
    @Published var filterDetail: FilterDetailResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPurchasing = false
    @Published var paymentWebView: WKWebView?
    @Published var showPaymentSheet = false
    @Published var paymentProgress: String = ""
    
    let input = Input()
    private var cancellables = Set<AnyCancellable>()
    private let filterUseCase: FilterUseCase
    private let orderUseCase: OrderUseCase
    
    // Task 관리용
    private var loadDetailTask: Task<Void, Never>?
    private var likeTask: Task<Void, Never>?
    private var purchaseTask: Task<Void, Never>?
    
    init(filterUseCase: FilterUseCase = FilterUseCaseImpl(),
         orderUseCase: OrderUseCase = OrderUseCaseImpl()) {
        self.filterUseCase = filterUseCase
        self.orderUseCase = orderUseCase
        setupBindings()
    }
    
    private func setupBindings() {
        // 필터 상세 로드
        input.loadFilterDetail
            .sink { [weak self] filterId in
                print("🔵 FilterDetailViewModel: loadFilterDetail 신호 수신 - \(filterId)")
                self?.loadFilterDetail(filterId: filterId)
            }
            .store(in: &cancellables)
        
        // 필터 좋아요
        input.likeFilter
            .sink { [weak self] filterId, shouldLike in
                print("🔵 FilterDetailViewModel: likeFilter 신호 수신 - \(filterId), 새 상태: \(shouldLike)")
                self?.likeFilter(filterId: filterId, newLikeStatus: shouldLike)
            }
            .store(in: &cancellables)
        
        // 데이터 새로고침
        input.refreshData
            .sink { [weak self] filterId in
                print("🔵 FilterDetailViewModel: refreshData 신호 수신 - \(filterId)")
                self?.loadFilterDetail(filterId: filterId)
            }
            .store(in: &cancellables)
        
        // 결제 처리
        input.purchaseFilter
            .sink { [weak self] filterId in
                print("🔵 FilterDetailViewModel: purchaseFilter 신호 수신 - \(filterId)")
                self?.startPurchaseProcess(filterId: filterId)
            }
            .store(in: &cancellables)
    }
    
    private func loadFilterDetail(filterId: String) {
        // 기존 작업 취소
        loadDetailTask?.cancel()
        
        // 중복 요청 방지
        guard !isLoading else {
            print("🔄 FilterDetailViewModel: 이미 로딩 중이므로 중복 요청 무시")
            return
        }
        
        loadDetailTask = Task {
            print("🔵 FilterDetailViewModel: 필터 상세 로드 시작 - \(filterId)")
            
            // UI 상태 업데이트 (메인스레드)
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            do {
                // 네트워킹 작업 (백그라운드에서 실행)
                let detail = try await filterUseCase.getFilterDetail(filterId: filterId)
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                print("✅ FilterDetailViewModel: 필터 상세 로드 성공 - \(detail.title)")
                
                // UI 업데이트 (메인스레드에서 실행)
                await MainActor.run {
                    self.filterDetail = detail
                    self.isLoading = false
                }
                
            } catch is CancellationError {
                print("🔵 FilterDetailViewModel: 필터 상세 로드 작업 취소됨")
                await MainActor.run {
                    self.isLoading = false
                }
            } catch let error as NetworkError {
                print("❌ FilterDetailViewModel: 필터 상세 로드 실패 - \(error)")
                
                await MainActor.run {
                    self.isLoading = false
                    
                    switch error {
                    case .invalidStatusCode(404):
                        self.errorMessage = "필터를 찾을 수 없습니다."
                    case .invalidStatusCode(401):
                        self.errorMessage = "로그인이 필요합니다."
                    case .invalidStatusCode(500):
                        self.errorMessage = "서버 오류가 발생했습니다."
                    default:
                        self.errorMessage = "필터 로드에 실패했습니다."
                    }
                }
            } catch {
                print("❌ FilterDetailViewModel: 알 수 없는 오류 - \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "알 수 없는 오류가 발생했습니다."
                }
            }
        }
    }
    
    private func likeFilter(filterId: String, newLikeStatus: Bool) {
        likeTask?.cancel()
        
        // 중복 요청 방지
        guard let currentDetail = filterDetail else {
            print("🔄 FilterDetailViewModel: 필터 상세가 없어서 좋아요 처리 불가")
            return
        }
        
        // 이미 같은 상태면 무시
        if currentDetail.is_liked == newLikeStatus {
            print("🔄 FilterDetailViewModel: 이미 같은 좋아요 상태이므로 무시")
            return
        }
        
        likeTask = Task {
            print("🔵 FilterDetailViewModel: 좋아요 처리 시작 - \(filterId), 새 상태: \(newLikeStatus)")
            
            await MainActor.run {
                self.updateFilterLikeStatus(isLiked: newLikeStatus)
            }
            
            do {
                try await filterUseCase.likeFilter(filterId: filterId, likeStatus: newLikeStatus)
                try Task.checkCancellation()
                
                print("✅ FilterDetailViewModel: 좋아요 처리 성공")
                
            } catch is CancellationError {
                print("🔵 FilterDetailViewModel: 좋아요 처리 작업 취소됨")
                await MainActor.run {
                    self.updateFilterLikeStatus(isLiked: !newLikeStatus)
                }
            } catch {
                print("❌ FilterDetailViewModel: 좋아요 처리 실패 - \(error)")
                
                await MainActor.run {
                    self.updateFilterLikeStatus(isLiked: !newLikeStatus)
                    self.errorMessage = "좋아요 처리에 실패했습니다."
                }
                
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        if self.errorMessage == "좋아요 처리에 실패했습니다." {
                            self.errorMessage = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 완전한 결제 프로세스 구현
    private func startPurchaseProcess(filterId: String) {
        purchaseTask?.cancel()
        
        // 중복 결제 방지
        guard !isPurchasing else {
            print("🔄 FilterDetailViewModel: 이미 결제 진행 중이므로 중복 요청 무시")
            return
        }
        
        // 이미 구매한 필터인지 확인
        if filterDetail?.is_downloaded == true {
            print("🔄 FilterDetailViewModel: 이미 구매한 필터이므로 결제 불가")
            return
        }
        
        purchaseTask = Task {
            print("🔵 FilterDetailViewModel: 결제 프로세스 시작 - \(filterId)")
            
            await MainActor.run {
                self.isPurchasing = true
                self.errorMessage = nil
                self.paymentProgress = "주문을 생성하고 있습니다..."
            }
            
            do {
                // 1️⃣ 주문 생성
                guard let filterDetail = filterDetail else {
                    throw PaymentManager.PaymentError.invalidResponse
                }
                
                let orderResponse = try await orderUseCase.createOrder(
                    filterId: filterId,
                    totalPrice: filterDetail.price
                )
                
                try Task.checkCancellation()
                print("✅ FilterDetailViewModel: 주문 생성 완료 - \(orderResponse.order_code)")
                
                await MainActor.run {
                    self.paymentProgress = "결제 페이지를 준비하고 있습니다..."
                    self.showPaymentSheet = true
                }
                
                // WebView 생성 대기
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5초
                
                // 2️⃣ 결제 실행
                await MainActor.run {
                    self.paymentProgress = "결제를 진행해주세요..."
                }
                
                guard let webView = paymentWebView else {
                    throw PaymentManager.PaymentError.invalidResponse
                }
                
                let impUid = try await PaymentManager.shared.processPayment(
                    orderCode: orderResponse.order_code,
                    amount: orderResponse.total_price,
                    filterTitle: filterDetail.title,
                    webView: webView
                )
                
                try Task.checkCancellation()
                print("✅ FilterDetailViewModel: 결제 완료 - imp_uid: \(impUid)")
                
                await MainActor.run {
                    self.paymentProgress = "결제를 검증하고 있습니다..."
                }
                
                // 3️⃣ 결제 검증
                let validationResponse = try await orderUseCase.validatePayment(impUid: impUid)
                
                try Task.checkCancellation()
                print("✅ FilterDetailViewModel: 결제 검증 완료")
                
                // 4️⃣ UI 업데이트 (결제 완료 상태로 변경)
                await MainActor.run {
                    // 기존 필터 정보를 유지하면서 구매 상태만 업데이트
                    if var updatedDetail = self.filterDetail {
                        updatedDetail.is_downloaded = true
                        updatedDetail.buyer_count += 1
                        self.filterDetail = updatedDetail
                        
                        print("🔵 FilterDetailViewModel: 결제 완료 - is_downloaded: \(updatedDetail.is_downloaded)")
                    }
                    
                    self.isPurchasing = false
                    self.showPaymentSheet = false
                    self.paymentProgress = ""
                    self.errorMessage = "결제가 완료되었습니다!"
                }
                
                // 성공 메시지 자동 제거
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        if self.errorMessage == "결제가 완료되었습니다!" {
                            self.errorMessage = nil
                        }
                    }
                }
                
            } catch is CancellationError {
                print("🔵 FilterDetailViewModel: 결제 프로세스 취소됨")
                await MainActor.run {
                    self.isPurchasing = false
                    self.showPaymentSheet = false
                    self.paymentProgress = ""
                }
                
            } catch PaymentManager.PaymentError.userCancelled {
                print("🔵 FilterDetailViewModel: 사용자가 결제 취소")
                await MainActor.run {
                    self.isPurchasing = false
                    self.showPaymentSheet = false
                    self.paymentProgress = ""
                    self.errorMessage = "결제가 취소되었습니다."
                }
                
                Task {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        if self.errorMessage == "결제가 취소되었습니다." {
                            self.errorMessage = nil
                        }
                    }
                }
                
            } catch {
                print("❌ FilterDetailViewModel: 결제 실패 - \(error)")
                await MainActor.run {
                    self.isPurchasing = false
                    self.showPaymentSheet = false
                    self.paymentProgress = ""
                    
                    // 더 구체적인 에러 메시지 처리
                    if let paymentError = error as? PaymentManager.PaymentError {
                        self.errorMessage = paymentError.localizedDescription
                    } else if let networkError = error as? NetworkError {
                        switch networkError {
                        case .invalidStatusCode(400):
                            self.errorMessage = "결제 정보가 올바르지 않습니다."
                        case .invalidStatusCode(404):
                            self.errorMessage = "주문 정보를 찾을 수 없습니다."
                        case .invalidStatusCode(409):
                            self.errorMessage = "이미 처리된 결제입니다."
                        case .invalidStatusCode(445):
                            self.errorMessage = "결제자 정보가 일치하지 않습니다."
                        default:
                            self.errorMessage = "결제 검증에 실패했습니다."
                        }
                    } else if error is DecodingError {
                        print("🔍 FilterDetailViewModel: JSON 디코딩 에러 상세 - \(error)")
                        self.errorMessage = "서버 응답 처리 중 오류가 발생했습니다."
                    } else {
                        self.errorMessage = "결제에 실패했습니다. 다시 시도해주세요."
                    }
                }
                
                Task {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    await MainActor.run {
                        if self.errorMessage?.contains("결제") == true || self.errorMessage?.contains("서버") == true {
                            self.errorMessage = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - UI 업데이트 헬퍼 메서드
    private func updateFilterLikeStatus(isLiked: Bool) {
        guard var updatedDetail = filterDetail else { return }
        
        let oldStatus = updatedDetail.is_liked
        updatedDetail.is_liked = isLiked
        
        if oldStatus != isLiked {
            updatedDetail.like_count += isLiked ? 1 : -1
            print("🔵 FilterDetailViewModel: 좋아요 상태 업데이트 - 좋아요: \(isLiked), 카운트: \(updatedDetail.like_count)")
        }
        
        filterDetail = updatedDetail
    }
    
    private func updateFilterPurchaseStatus(isPurchased: Bool) {
        guard var updatedDetail = filterDetail else { return }
        
        updatedDetail.is_downloaded = isPurchased
        
        if isPurchased {
            updatedDetail.buyer_count += 1
        }
        
        filterDetail = updatedDetail
        print("🔵 FilterDetailViewModel: 결제 상태 업데이트 - 구매완료: \(isPurchased), 구매자수: \(updatedDetail.buyer_count)")
    }
    
    // MARK: - 결제 시트 닫기
    func dismissPaymentSheet() {
        showPaymentSheet = false
        isPurchasing = false
        paymentProgress = ""
    }
    
    // MARK: - Cleanup
    deinit {
        loadDetailTask?.cancel()
        likeTask?.cancel()
        purchaseTask?.cancel()
        cancellables.removeAll()
    }
}
