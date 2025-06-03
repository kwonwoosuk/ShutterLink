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
                .navigationBarHidden(true)
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
                                filter: viewModel.todayFilter, geometry: geometry,
                                onFilterTap: { filterId in
                                    router.pushToFilterDetail(filterId: filterId, from: .home)
                                }
                            )
                            .id("top")

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
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo("top", anchor: .top)
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
        .refreshable {
            print("🔵 HomeView: Pull-to-refresh")
            viewModel.refreshData()
        }
    }
}
