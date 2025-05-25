//
//  MainTabView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/21/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 콘텐츠 영역
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                
                FeedView()
                    .tag(1)
                
                Text("필터 화면")
                    .tag(2)
                
                Text("검색 화면")
                    .tag(3)
                
                ProfileView()
                    .tag(4)
            }
            .toolbar(.hidden, for: .tabBar)
            
            // 커스텀 탭바
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
