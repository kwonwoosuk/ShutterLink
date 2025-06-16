//
//  MainTabView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/21/25.
//

import SwiftUI
import Combine

struct MainTabView: View {
    @EnvironmentObject private var router: NavigationRouter
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 콘텐츠 영역
            TabView(selection: $router.selectedTab) {
                LazyView(HomeView())
                    .tag(Tab.home)
                
                LazyView(FeedView())
                    .tag(Tab.feed)
             
                LazyView(MakeView())
                    .tag(Tab.filter)
                
                LazyView(SearchView())
                    .tag(Tab.search)
                
                LazyView(ProfileView())
                    .tag(Tab.profile)
            }
            .toolbar(.hidden, for: .tabBar)
            
            // 🆕 수정 - 조건부 커스텀 탭바 표시
            if !router.isTabBarHidden {
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .bottom)
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
