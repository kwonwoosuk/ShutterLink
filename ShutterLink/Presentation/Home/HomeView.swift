//
//  HomeView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI
import Combine

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var router: NavigationRouter
    
    var body: some View {
        NavigationStack(path: $router.homePath) {
            homeContent
                .navigationDestination(for: FilterRoute.self) { route in
                    // NavigationLazyView로 감싸서 메모리 최적화
                    NavigationLazyView(
                        destinationView(for: route)
                    )
                }
                .navigationBarHidden(true)
        }
    }
    
    // MARK: - Navigation Destination Builder (성능 최적화)
    @ViewBuilder
    private func destinationView(for route: FilterRoute) -> some View {
        switch route {
        case .filterDetail(let filterId):
            FilterDetailView(filterId: filterId)
        case .userDetail(let userId, let userInfo):
            UserDetailView(
                userId: userId,
                userInfo: UserInfo(
                    user_id: userInfo.user_id,
                    nick: userInfo.nick,
                    name: userInfo.name,
                    introduction: userInfo.introduction,
                    profileImage: userInfo.profileImage,
                    hashTags: userInfo.hashTags
                )
            )
        }
    }
    
    @ViewBuilder
    private var homeContent: some View {
        ZStack {
            Color.black.ignoresSafeArea(.all)
            
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            TodayFilterIntroSection(
                                filter: viewModel.todayFilter,
                                geometry: geometry,
                                onFilterTap: { filterId in
                                    router.pushToFilterDetail(filterId: filterId, from: .home)
                                }
                            )
                            .id("top") // 기존 id 이름 유지

                            LazyVStack(spacing: 20) {
                                AdBannerSection()
                                
                                HotTrendSection(
                                    filters: viewModel.hotTrendFilters,
                                    onFilterTap: { filterId in
                                        router.pushToFilterDetail(filterId: filterId, from: .home)
                                    }
                                )
                                
                                TodayAuthorSection(
                                    authorData: viewModel.todayAuthor,
                                    onFilterTap: { filterId in
                                        router.pushToFilterDetail(filterId: filterId, from: .home)
                                    }
                                )
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 120)
                            .background(Color.black)
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .ignoresSafeArea(.container, edges: .top)
                    .onReceive(router.homeScrollToTop) { _ in
                        print("🔄 HomeView: 상단으로 스크롤")
                        
                        // 애니메이션 최적화: 더 빠른 스크롤
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("top", anchor: .top)
                        }
                        
                        // 애니메이션 완료 후 리프레쉬 (캐시 활용을 위해 조금 더 지연)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            viewModel.refreshData()
                        }
                    }
                }
            }
            
            // 로딩 및 에러 상태
            if viewModel.isLoading &&
               viewModel.todayFilter == nil &&
               viewModel.hotTrendFilters.isEmpty &&
               viewModel.todayAuthor == nil {
                LoadingIndicatorView()
            }
            
            if let errorMessage = viewModel.errorMessage,
               viewModel.todayFilter == nil &&
               viewModel.hotTrendFilters.isEmpty &&
               viewModel.todayAuthor == nil {
                ErrorStateView(errorMessage: errorMessage) {
                    viewModel.refreshData()
                }
            }
        }
        .onAppear {
            print("🔵 HomeView: onAppear - 처음만 로딩")
            viewModel.loadDataOnceIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // 백그라운드에서 돌아올 때만 캐시 정리
            ImageLoader.shared.clearCache()
        }
    }
}
