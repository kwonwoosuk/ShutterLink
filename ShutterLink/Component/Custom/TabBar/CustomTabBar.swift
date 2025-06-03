//
//  CustomTabBar.swift
//  ShutterLink
//
//  Created by 권우석 on 5/21/25.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let onTabTapped: (Int) -> Void
    @Namespace private var tabAnimation
    
    var body: some View {
        ZStack(alignment: .top) {
            // 배경
            Capsule()
                .fill(.ultraThinMaterial)
                .frame(height: 64)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            
            // 인디케이터 바 (상단에 위치)
            HStack(spacing: 0) {
                ForEach(0..<5) { index in
                    if selectedTab == index {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 30, height: 3)
                            .matchedGeometryEffect(id: "selectedTab", in: tabAnimation)
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 30, height: 3)
                    }
                    
                    if index < 4 {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 25)
            
            // 아이콘 버튼들
            HStack(spacing: 0) {
                ForEach(0..<5) { index in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onTabTapped(index)
                        }
                    } label: {
                        Image(getIconName(for: index, isSelected: selectedTab == index))
                            .renderingMode(.template)
                            .foregroundColor(selectedTab == index ? DesignSystem.Colors.Gray.gray15 : DesignSystem.Colors.Gray.gray45)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 64)
        }
        .padding(.horizontal, 11)
        .padding(.bottom, 40) // Safe Area 고려한 패딩
    }
    
    func getIconName(for index: Int, isSelected: Bool) -> String {
        let suffix = isSelected ? "Fill" : "Empty"
        switch index {
        case 0: return "Home_\(suffix)"
        case 1: return "Feed_\(suffix)"
        case 2: return "Filter_\(suffix)"
        case 3: return "Search_\(suffix)"
        case 4: return "Profile_\(suffix)"
        default: return ""
        }
    }
}
