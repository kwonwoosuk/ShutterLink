//
//  HomeViewModel.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    // Output
    @Published var todayFilter: TodayFilterResponse?
    @Published var hotTrendFilters: [FilterItem] = []
    @Published var todayAuthor: TodayAuthorResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let filterUseCase: FilterUseCase
    private let userUseCase: UserUseCase
    
    init(
        filterUseCase: FilterUseCase = FilterUseCaseImpl(),
        userUseCase: UserUseCase = UserUseCaseImpl()
    ) {
        self.filterUseCase = filterUseCase
        self.userUseCase = userUseCase
    }
    
    func loadHomeData() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        await withTaskGroup(of: Void.self) { group in
            // 오늘의 필터 로드
            group.addTask {
                await self.loadTodayFilter()
            }
            
            // 핫트랜드 필터 로드
            group.addTask {
                await self.loadHotTrendFilters()
            }
            
            // 오늘의 작가 로드
            group.addTask {
                await self.loadTodayAuthor()
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func loadTodayFilter() async {
        do {
            let filter = try await filterUseCase.getTodayFilter()
            await MainActor.run {
                self.todayFilter = filter
                print("✅ 오늘의 필터 로드 성공: \(filter.title)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "오늘의 필터를 불러오는데 실패했습니다"
            }
            print("❌ 오늘의 필터 로드 실패: \(error)")
            
            // Mock 데이터로 대체
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
            }
        }
    }
    
    private func loadHotTrendFilters() async {
        do {
            let filters = try await filterUseCase.getHotTrendFilters()
            await MainActor.run {
                self.hotTrendFilters = filters
                print("✅ 핫트랜드 필터 로드 성공: \(filters.count)개")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "핫트랜드 필터를 불러오는데 실패했습니다"
            }
            print("❌ 핫트랜드 필터 로드 실패: \(error)")
            
            // Mock 데이터로 대체
            await MainActor.run {
                self.hotTrendFilters = createMockHotTrendFilters()
            }
        }
    }
    
    private func loadTodayAuthor() async {
        do {
            let author = try await userUseCase.getTodayAuthor()
            await MainActor.run {
                self.todayAuthor = author
                print("✅ 오늘의 작가 로드 성공: \(author.author.name)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "오늘의 작가를 불러오는데 실패했습니다"
            }
            print("❌ 오늘의 작가 로드 실패: \(error)")
            
            // Mock 데이터로 대체하지 않고 nil로 유지 (AuthorMockView가 표시됨)
            await MainActor.run {
                self.todayAuthor = nil
            }
        }
    }
    
    // MARK: - Mock 데이터 생성
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
}
