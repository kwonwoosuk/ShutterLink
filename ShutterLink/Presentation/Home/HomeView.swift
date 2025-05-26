//
//  HomeView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var hasAppeared = false
    @State private var selectedFilterId: String? = nil
    
    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                NavigationStack {
                    homeContent
                        .navigationDestination(item: Binding<FilterNavigationItemCompat?>(
                            get: { selectedFilterId.map { FilterNavigationItemCompat(filterId: $0) } },
                            set: { selectedFilterId = $0?.filterId }
                        )) { item in
                            FilterDetailView(filterId: item.filterId)
                        }
                }
            } else if #available(iOS 16.0, *) {
                NavigationStack {
                    homeContent
                        .background(
                            NavigationLink(
                                destination: Group {
                                    if let filterId = selectedFilterId {
                                        FilterDetailView(filterId: filterId)
                                    } else {
                                        EmptyView()
                                    }
                                },
                                isActive: Binding<Bool>(
                                    get: { selectedFilterId != nil },
                                    set: { if !$0 { selectedFilterId = nil } }
                                )
                            ) {
                                EmptyView()
                            }
                            .opacity(0)
                        )
                }
            } else {
                NavigationView {
                    homeContent
                        .background(
                            NavigationLink(
                                destination: Group {
                                    if let filterId = selectedFilterId {
                                        FilterDetailView(filterId: filterId)
                                    } else {
                                        EmptyView()
                                    }
                                },
                                isActive: Binding<Bool>(
                                    get: { selectedFilterId != nil },
                                    set: { if !$0 { selectedFilterId = nil } }
                                )
                            ) {
                                EmptyView()
                            }
                            .opacity(0)
                        )
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }
    
    @ViewBuilder
    private var homeContent: some View {
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
                        TodayFilterIntroSection(
                            filter: viewModel.todayFilter,
                            onFilterTap: { filterId in
                                selectedFilterId = filterId
                            }
                        )
                        
                        // 섹션 2: 광고 배너 (별도 섹션)
                        AdBannerSection()
                        
                        // 섹션 3: 핫트랜드 (무한 스크롤)
                        HotTrendSection(
                            filters: viewModel.hotTrendFilters,
                            onFilterTap: { filterId in
                                selectedFilterId = filterId
                            }
                        )
                        
                        // 섹션 4: 오늘의 작가 소개
                        TodayAuthorSection(authorData: viewModel.todayAuthor)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 120) // 탭바와 여유 공간
                }
            }
            .opacity(viewModel.isLoading ? 0.7 : 1.0)
            
            // 로딩 인디케이터 - 중앙 작은 크기로 변경
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("로딩 중...")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                .padding(20)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            }
        }
        .onAppear {
            // 탭 전환 완료 후 로딩 시작
            if !hasAppeared {
                hasAppeared = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🔵 HomeView: 홈 데이터 로딩 시작")
                    viewModel.loadHomeData()
                }
            } else {
                // 화면 복귀 시 데이터 새로고침
                print("🔵 HomeView 화면 복귀 - 데이터 새로고침")
                viewModel.loadHomeData()
            }
        }
        .refreshable {
            // refreshable은 자동으로 메인스레드에서 실행됨
            viewModel.loadHomeData()
        }
    }
}

// 네비게이션을 위한 헬퍼 구조체
struct FilterNavigationItemCompat: Identifiable, Hashable {
    let id = UUID()
    let filterId: String
}
