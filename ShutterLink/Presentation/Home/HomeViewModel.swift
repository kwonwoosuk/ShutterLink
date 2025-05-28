//
//  HomeViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    // @Published 프로퍼티들은 자동으로 메인스레드에서 UI 업데이트
    @Published var todayFilter: TodayFilterResponse?
    @Published var hotTrendFilters: [FilterItem] = []
    @Published var todayAuthor: TodayAuthorResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let filterUseCase: FilterUseCase
    private let userUseCase: UserUseCase
    
    // Task 관리용
    private var loadDataTask: Task<Void, Never>?
    
    init(
        filterUseCase: FilterUseCase = FilterUseCaseImpl(),
        userUseCase: UserUseCase = UserUseCaseImpl()
    ) {
        self.filterUseCase = filterUseCase
        self.userUseCase = userUseCase
    }
    
    func loadHomeData() {
        // 기존 작업 취소
        loadDataTask?.cancel()
        
        loadDataTask = Task {
            print("🔵 HomeViewModel: 홈 데이터 로딩 시작")
            
            // UI 상태 업데이트 (메인스레드)
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            // 병렬로 모든 데이터 로드 (백그라운드에서 실행)
            await withTaskGroup(of: Void.self) { group in
                // 오늘의 필터 로드
                group.addTask { [weak self] in
                    await self?.loadTodayFilter()
                }
                
                // 핫트랜드 필터 로드
                group.addTask { [weak self] in
                    await self?.loadHotTrendFilters()
                }
                
                // 오늘의 작가 로드
                group.addTask { [weak self] in
                    await self?.loadTodayAuthor()
                }
            }
            
            // 모든 작업 완료 후 UI 업데이트 (메인스레드)
            await MainActor.run {
                self.isLoading = false
            }
            print("🔵 HomeViewModel: 홈 데이터 로딩 완료")
        }
    }
    
    private func loadTodayFilter() async {
        do {
            // 네트워킹 작업 (백그라운드에서 실행)
            let filter = try await filterUseCase.getTodayFilter()
            
            // Task가 취소되었는지 확인
            try Task.checkCancellation()
            
            // UI 업데이트만 메인스레드에서 실행
            await MainActor.run {
                self.todayFilter = filter
            }
            print("✅ HomeViewModel: 오늘의 필터 로드 성공 - \(filter.title)")
            
        } catch is CancellationError {
            print("🔵 HomeViewModel: 오늘의 필터 로드 작업 취소됨")
        } catch {
            print("❌ HomeViewModel: 오늘의 필터 로드 실패 - \(error)")
            
            // Mock 데이터로 대체 (메인스레드에서 UI 업데이트)
            await MainActor.run {
                self.todayFilter = TodayFilterResponse(
                    filter_id: "mock_filter_1",
                    title: "새싹을 담은 필터",
                    introduction: "자연의 섬세함을 담아내는 감성 필터",
                    description: "새싹이 돋아나는 계절의 따뜻함과 생명력을 표현한 필터입니다.",
                    files: ["/mock/today_filter.jpg"],
                    createdAt: "2025-05-22T00:00:00.000Z",
                    updatedAt: "2025-05-22T00:00:00.000Z"
                )
                
                if self.errorMessage == nil {
                    self.errorMessage = "오늘의 필터를 불러오는데 실패했습니다"
                }
            }
        }
    }
    
    private func loadHotTrendFilters() async {
        do {
            // 네트워킹 작업 (백그라운드에서 실행)
            let filters = try await filterUseCase.getHotTrendFilters()
            
            // Task가 취소되었는지 확인
            try Task.checkCancellation()
            
            // UI 업데이트만 메인스레드에서 실행
            await MainActor.run {
                self.hotTrendFilters = filters
            }
            print("✅ HomeViewModel: 핫트랜드 필터 로드 성공 - \(filters.count)개")
            
        } catch is CancellationError {
            print("🔵 HomeViewModel: 핫트랜드 필터 로드 작업 취소됨")
        } catch {
            print("❌ HomeViewModel: 핫트랜드 필터 로드 실패 - \(error)")
            
            // Mock 데이터로 대체 (메인스레드에서 UI 업데이트)
            await MainActor.run {
                self.hotTrendFilters = self.createMockHotTrendFilters()
                
                if self.errorMessage == nil {
                    self.errorMessage = "핫트랜드 필터를 불러오는데 실패했습니다"
                }
            }
        }
    }
    
    private func loadTodayAuthor() async {
        do {
            // 네트워킹 작업 (백그라운드에서 실행)
            let author = try await userUseCase.getTodayAuthor()
            
            // Task가 취소되었는지 확인
            try Task.checkCancellation()
            
            // UI 업데이트만 메인스레드에서 실행
            await MainActor.run {
                self.todayAuthor = author
            }
            print("✅ HomeViewModel: 오늘의 작가 로드 성공 - \(author.author.name)")
            
        } catch is CancellationError {
            print("🔵 HomeViewModel: 오늘의 작가 로드 작업 취소됨")
        } catch {
            print("❌ HomeViewModel: 오늘의 작가 로드 실패 - \(error)")
            
            // Mock 데이터로 대체하지 않고 nil로 유지 (AuthorMockView가 표시됨)
            await MainActor.run {
                self.todayAuthor = nil
                
                if self.errorMessage == nil {
                    self.errorMessage = "오늘의 작가를 불러오는데 실패했습니다"
                }
            }
        }
    }
    
    // MARK: - Mock 데이터 생성 (백그라운드에서 실행 가능)
    private func createMockHotTrendFilters() -> [FilterItem] {
        return [
            FilterItem(
                filter_id: "mock_1",
                category: "자연",
                title: "새싹 필터",
                description: "새로운 시작을 의미하는 필터",
                files: ["/mock/filter1.jpg"],
                creator: CreatorInfo(
                    user_id: "creator_1",
                    nick: "자연작가",
                    name: "김자연",
                    introduction: "자연을 사랑하는 작가",
                    profileImage: "/mock/profile1.jpg",
                    hashTags: ["#자연", "#새싹"]
                ),
                is_liked: false,
                like_count: 142,
                buyer_count: 23,
                createdAt: "2025-05-22T00:00:00.000Z",
                updatedAt: "2025-05-22T00:00:00.000Z"
            ),
            FilterItem(
                filter_id: "mock_2",
                category: "도시",
                title: "도시 감성",
                description: "도시의 세련된 느낌을 담은 필터",
                files: ["/mock/filter2.jpg"],
                creator: CreatorInfo(
                    user_id: "creator_2",
                    nick: "도시작가",
                    name: "이도시",
                    introduction: "도시를 담는 사진가",
                    profileImage: "/mock/profile2.jpg",
                    hashTags: ["#도시", "#세련"]
                ),
                is_liked: true,
                like_count: 89,
                buyer_count: 15,
                createdAt: "2025-05-21T00:00:00.000Z",
                updatedAt: "2025-05-21T00:00:00.000Z"
            ),
            FilterItem(
                filter_id: "mock_3",
                category: "빈티지",
                title: "따뜻한 추억",
                description: "따뜻한 빈티지 감성의 필터",
                files: ["/mock/filter3.jpg"],
                creator: CreatorInfo(
                    user_id: "creator_3",
                    nick: "빈티지작가",
                    name: "박빈티",
                    introduction: "추억을 담는 작가",
                    profileImage: "/mock/profile3.jpg",
                    hashTags: ["#빈티지", "#추억"]
                ),
                is_liked: false,
                like_count: 67,
                buyer_count: 12,
                createdAt: "2025-05-20T00:00:00.000Z",
                updatedAt: "2025-05-20T00:00:00.000Z"
            ),
            FilterItem(
                filter_id: "mock_4",
                category: "모던",
                title: "미니멀 라이프",
                description: "깔끔하고 모던한 느낌의 필터",
                files: ["/mock/filter4.jpg"],
                creator: CreatorInfo(
                    user_id: "creator_4",
                    nick: "모던작가",
                    name: "최모던",
                    introduction: "미니멀을 추구하는 작가",
                    profileImage: "/mock/profile4.jpg",
                    hashTags: ["#모던", "#미니멀"]
                ),
                is_liked: true,
                like_count: 156,
                buyer_count: 31,
                createdAt: "2025-05-19T00:00:00.000Z",
                updatedAt: "2025-05-19T00:00:00.000Z"
            ),
            FilterItem(
                filter_id: "mock_5",
                category: "밤",
                title: "야경의 마법",
                description: "밤의 신비로운 분위기를 담은 필터",
                files: ["/mock/filter5.jpg"],
                creator: CreatorInfo(
                    user_id: "creator_5",
                    nick: "야경작가",
                    name: "정야경",
                    introduction: "밤을 사랑하는 작가",
                    profileImage: "/mock/profile5.jpg",
                    hashTags: ["#야경", "#밤"]
                ),
                is_liked: false,
                like_count: 203,
                buyer_count: 45,
                createdAt: "2025-05-18T00:00:00.000Z",
                updatedAt: "2025-05-18T00:00:00.000Z"
            )
        ]
    }
    
    // MARK: - Cleanup
    deinit {
        loadDataTask?.cancel()
    }
}
