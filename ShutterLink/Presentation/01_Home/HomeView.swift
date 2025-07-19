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
    
    // 출석 완료 알림 관련 State
    @State private var showAttendanceAlert = false
    @State private var attendanceCount = 0
    @State private var notificationObserver: NSObjectProtocol?
    
    var body: some View {
        NavigationStack(path: $router.homePath) {
            homeContent
                .navigationDestination(for: FilterRoute.self) { route in
                    NavigationLazyView(
                        destinationView(for: route)
                    )
                }
                .navigationBarHidden(true)
        }
        // 출석 완료 Alert 추가
        .alert("출석 완료", isPresented: $showAttendanceAlert) {
            Button("확인", role: .cancel) {
                showAttendanceAlert = false
            }
        } message: {
            if attendanceCount > 0 {
                Text("\(attendanceCount)번째 출석이 완료되었습니다! 🎉")
            } else {
                Text("출석이 완료되었습니다! 🎉")
            }
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
                            .id("top")

                            LazyVStack(spacing: 24) {
                                AdBannerSection(banners: viewModel.banners)
                                
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
            
            // 출석 완료 알림 구독
            print("📡 HomeView: NotificationCenter 구독 시작")
            notificationObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AttendanceCompleted"),
                object: nil,
                queue: .main
            ) { notification in
                print("📩 HomeView: NotificationCenter 알림 수신!")
                
                if let attendanceCount = notification.userInfo?["attendanceCount"] as? Int {
                    print("🎉 HomeView: 출석 완료 알림 수신 - \(attendanceCount)회")
                    self.attendanceCount = attendanceCount
                    self.showAttendanceAlert = true
                }
            }
            print("✅ HomeView: NotificationCenter 구독 완료")
        }
        .onDisappear {
            // NotificationCenter 구독 해제
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
                notificationObserver = nil
                print("🗑️ HomeView: NotificationCenter 구독 해제")
            }
        }
    }
}
