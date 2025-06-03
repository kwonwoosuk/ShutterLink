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
                            // 오늘의 필터 헤더 이미지 (Stretch 효과)
                            TodayFilterIntroSection(
                                filter: viewModel.todayFilter, geometry: geometry,
                                onFilterTap: { filterId in
                                    router.pushToFilterDetail(filterId: filterId, from: .home)
                                }
                            )
                            .id("top") // 스크롤 참조점
                            
                           
                            // 나머지 콘텐츠
                            LazyVStack(spacing: 20) { // 32에서 20으로 줄임
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
                            .padding(.top, 12) // 20에서 12로 줄임
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
