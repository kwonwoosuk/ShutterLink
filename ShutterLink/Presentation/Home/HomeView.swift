//
//  HomeView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var path: [FilterNavigationItem] = [] // 네비게이션 경로 관리
    
    var body: some View {
        NavigationStack(path: $path) {
            homeContent
                .navigationDestination(for: FilterNavigationItem.self) { item in
                    FilterDetailView(filterId: item.filterId)
                }
        }
    }
    
    @ViewBuilder
    private var homeContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    HeaderView()
                    
                    LazyVStack(spacing: 32) {
                        TodayFilterIntroSection(
                            filter: viewModel.todayFilter,
                            onFilterTap: { filterId in
                                path.append(FilterNavigationItem(filterId: filterId))
                            }
                        )
                        
                        AdBannerSection()
                        
                        HotTrendSection(
                            filters: viewModel.hotTrendFilters,
                            onFilterTap: { filterId in
                                path.append(FilterNavigationItem(filterId: filterId))
                            }
                        )
                        
                        TodayAuthorSection(authorData: viewModel.todayAuthor)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 120)
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
