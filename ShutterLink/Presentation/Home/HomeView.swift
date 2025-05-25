//
//  HomeView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        ZStack {
            // 다크 모드 배경
            Color.black.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // 헤더 영역
                    HeaderView()
                    
                    // 콘텐츠 영역
                    LazyVStack(spacing: 32) {
                        // 섹션 1: 오늘의 필터 소개 (필터 정보만)
                        TodayFilterIntroSection(filter: viewModel.todayFilter)
                        
                        // 섹션 2: 광고 배너 (별도 섹션)
                        AdBannerSection()
                        
                        // 섹션 3: 핫트랜드 (무한 스크롤)
                        HotTrendSection(filters: viewModel.hotTrendFilters)
                        
                        // 섹션 4: 오늘의 작가 소개
                        TodayAuthorSection(authorData: viewModel.todayAuthor)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 120) // 탭바와 여유 공간
                }
            }
            
            // 로딩 인디케이터
            if viewModel.isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("로딩 중...")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 16)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadHomeData()
            }
        }
        .refreshable {
            await viewModel.loadHomeData()
        }
    }
}


















