//
//  FilterManagementView.swift
//  ShutterLink
//
//  Created by 권우석 on 7/11/25.
//

import SwiftUI

struct FilterManagementView: View {
    @StateObject private var viewModel = FilterManagementViewModel()
    @EnvironmentObject private var router: NavigationRouter
    @EnvironmentObject private var authState: AuthState
    
    // 🆕 삭제 확인 관련 상태 추가
    @State private var showDeleteConfirmation = false
    @State private var filterToDelete: FilterItem?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // 🆕 토스트 메시지 관련 추가
    @State private var showSuccessToast = false
    @State private var showErrorToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.myFilters.isEmpty {
                    emptyStateView
                } else {
                    filterListView
                }
            }
            .background(Color.black)
            .navigationTitle("필터 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("새로고침") {
                        refreshFilters()
                    }
                    .foregroundColor(.blue)
                    .font(.pretendard(size: 14, weight: .medium))
                }
            }
            .onAppear {
                loadMyFilters()
            }
            
            // 🆕 성공 토스트
            if showSuccessToast {
                VStack {
                    Spacer()
                    successToast
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showSuccessToast)
            }
            
            // 🆕 오류 토스트
            if showErrorToast {
                VStack {
                    Spacer()
                    errorToast
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showErrorToast)
            }
        }
        // 🆕 삭제 확인 알림 다시 추가
        .confirmationDialog("필터 삭제", isPresented: $showDeleteConfirmation, presenting: filterToDelete) { filter in
            Button("삭제", role: .destructive) {
                deleteFilterOptimistic(filter)
            }
            Button("취소", role: .cancel) {
                filterToDelete = nil
            }
        } message: { filter in
            Text("'\(filter.title)' 필터를 정말 삭제하시겠습니까?\n구매자가 있는 경우 삭제할 수 없습니다.")
        }
        .alert("오류", isPresented: $showErrorAlert) {
            Button("확인") { }
        } message: {
            Text(errorMessage)
        }
        // 🆕 Pull to Refresh 추가
        .refreshable {
            refreshFilters()
        }
    }
    
    // MARK: - 로딩 뷰
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("필터를 불러오는 중...")
                .font(.pretendard(size: 16, weight: .regular))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 빈 상태 뷰
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("만든 필터가 없습니다")
                    .font(.pretendard(size: 18, weight: .semiBold))
                    .foregroundColor(.white)
                
                Text("필터를 만들어 다른 사용자들과 공유해보세요")
                    .font(.pretendard(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                // 필터 탭으로 이동
                router.selectTab(.filter)
            } label: {
                Text("필터 만들기")
                    .font(.pretendard(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.white)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - 필터 리스트 뷰
    
    @ViewBuilder
    private var filterListView: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("총 \(viewModel.myFilters.count)개의 필터")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("X 버튼 또는 스와이프로 삭제")
                    .font(.pretendard(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.gray.opacity(0.1))
            
            // 필터 목록
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.myFilters) { filter in
                        FilterManagementRow(
                            filter: filter,
                            onDelete: {
                                // 🆕 확인 알림 먼저 표시
                                showDeleteConfirmation(for: filter)
                            }
                        )
                        .background(Color.black)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }
    
    // MARK: - 🆕 토스트 뷰들
    
    @ViewBuilder
    private var successToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.green)
            
            Text("필터가 삭제되었습니다")
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.9))
                .shadow(radius: 8)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
    }
    
    @ViewBuilder
    private var errorToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(.red)
            
            Text(toastMessage)
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.9))
                .shadow(radius: 8)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
    }
    
    // MARK: - 헬퍼 메서드
    
    private func loadMyFilters() {
        print("📋 FilterManagementView: 내 필터 로드 시작")
        guard let userId = authState.currentUser?.id else {
            print("❌ FilterManagementView: 사용자 ID 없음")
            return
        }
        
        Task {
            await viewModel.loadMyFilters(userId: userId)
        }
    }
    
    private func refreshFilters() {
        print("🔄 FilterManagementView: 필터 새로고침")
        loadMyFilters()
    }
    
    // 🆕 삭제 확인 알림 표시
    private func showDeleteConfirmation(for filter: FilterItem) {
        print("⚠️ FilterManagementView: 삭제 확인 표시 - \(filter.title)")
        filterToDelete = filter
        showDeleteConfirmation = true
    }
    
    // 🆕 Optimistic Update 방식 삭제 (확인 후 실행)
    private func deleteFilterOptimistic(_ filter: FilterItem) {
        print("🗑️ FilterManagementView: Optimistic 삭제 시작 - \(filter.title)")
        
        // 1. 햅틱 피드백 제공
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 2. 즉시 UI에서 필터 제거 (백업용으로 원본 배열 저장)
        let originalFilters = viewModel.myFilters
        viewModel.removeFilterFromList(filterId: filter.filter_id)
        
        // 3. 백그라운드에서 서버 삭제 수행
        Task {
            let success = await viewModel.deleteFilter(filterId: filter.filter_id)
            
            await MainActor.run {
                if success {
                    // 삭제 성공 - 성공 토스트 표시 (추가 API 호출 없음)
                    SuccessToast()
                    filterToDelete = nil
                    print("✅ FilterManagementView: 필터 삭제 성공")
                } else {
                    // 삭제 실패 - UI 복원 및 오류 토스트 표시
                    print("❌ FilterManagementView: 필터 삭제 실패 - UI 복원")
                    viewModel.restoreFilters(originalFilters)
                    showErrorToast(viewModel.errorMessage)
                    filterToDelete = nil
                }
            }
        }
    }
    
    // 🆕 토스트 메시지 표시 메서드들
    private func SuccessToast() {
        showSuccessToast = true
        
        // 3초 후 자동 숨김
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showSuccessToast = false
        }
    }
    
    private func showErrorToast(_ message: String) {
        toastMessage = message
        showErrorToast = true
        
        // 4초 후 자동 숨김
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            showErrorToast = false
        }
    }
}

// MARK: - 필터 관리 행 뷰 (기존 유지, 스와이프 삭제만 제거)

struct FilterManagementRow: View {
    let filter: FilterItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 필터 이미지 (프로젝트의 AuthenticatedImageView 사용)
            if let firstImagePath = filter.files.first {
                AuthenticatedImageView(
                    imagePath: firstImagePath,
                    contentMode: .fill,
                    targetSize: CGSize(width: 160, height: 160)
                ) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.6)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    )
            }
            
            // 필터 정보
            VStack(alignment: .leading, spacing: 8) {
                Text(filter.title)
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(filter.category ?? "")
                    .font(.pretendard(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.2))
                    )
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        Text("\(filter.like_count)")
                            .font(.pretendard(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
           
                }
            }
            
            Spacer()
            
            // X 삭제 버튼
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
                    .background(Color.white, in: Circle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
        )
        // 🆕 스와이프 삭제 기능 유지 및 개선 (확인 알림 포함)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                // 스와이프 삭제도 확인 알림 표시
                onDelete()
            } label: {
                VStack {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                    Text("삭제")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
            }
            .tint(.red)
        }
    }
}
