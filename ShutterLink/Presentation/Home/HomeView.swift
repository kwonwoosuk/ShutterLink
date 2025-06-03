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
        }
    }
    
    @ViewBuilder
    private var homeContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        HeaderView()
                            .id("top") // 스크롤 참조점
                        
                        LazyVStack(spacing: 32) {
                            TodayFilterIntroSection(
                                filter: viewModel.todayFilter,
                                onFilterTap: { filterId in
                                    router.pushToFilterDetail(filterId: filterId, from: .home)
                                }
                            )
                            
                            AdBannerSection()
                            
                            HotTrendSection(
                                filters: viewModel.hotTrendFilters,
                                onFilterTap: { filterId in
                                    router.pushToFilterDetail(filterId: filterId, from: .home)
                                }
                            )
                            
                            TodayAuthorSection(authorData: viewModel.todayAuthor)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                }
                .onReceive(router.homeScrollToTop) { _ in
                    print("🔄 HomeView: 상단으로 스크롤")
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
            
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
