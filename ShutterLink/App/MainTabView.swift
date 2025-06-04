//
//  MainTabView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/21/25.
//

import SwiftUI
import Combine

struct MainTabView: View {
    @StateObject private var router = NavigationRouter.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 콘텐츠 영역
            TabView(selection: $router.selectedTab) {
                LazyView(HomeView())
                    .tag(Tab.home)
                
                LazyView(FeedView())
                    .tag(Tab.feed)
                
                LazyView(Text("필터 화면"))
                    .tag(Tab.filter)
                
                LazyView(SearchView())
                    .tag(Tab.search)
                
                LazyView(ProfileView())
                    .tag(Tab.profile)
            }
            .toolbar(.hidden, for: .tabBar)
            
            // 커스텀 탭바
            CustomTabBar(
                selectedTab: Binding(
                    get: { router.selectedTab.rawValue },
                    set: { _ in }
                ),
                onTabTapped: { tappedTab in
                    if let tab = Tab(rawValue: tappedTab) {
                        router.selectTab(tab)
                    }
                }
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .environmentObject(router)
        .sheet(item: $router.presentedSheet) { sheet in
            sheetView(for: sheet)
        }
    }
    
    @ViewBuilder
    private func sheetView(for sheet: PresentedSheet) -> some View {
        switch sheet {
        case .userFilters(let userId, let userNick):
            UserFiltersView(userId: userId, userNick: userNick)
        case .profileEdit:
            ProfileEditView()
        case .chatView:
            // 향후 채팅 뷰 구현
            NavigationStack {
                VStack {
                    Text("채팅 기능")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("곧 출시됩니다!")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .navigationTitle("채팅")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("닫기") {
                            router.dismissSheet()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}
