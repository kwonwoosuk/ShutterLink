//
//  CustomTabBar.swift
//  ShutterLink
//
//  Created by 권우석 on 5/21/25.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var tabAnimation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<5) { index in
                TabBarButton(
                    selected: selectedTab == index,
                    iconName: getIconName(for: index, isSelected: selectedTab == index),
                    namespace: tabAnimation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
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

struct TabBarButton: View {
    var selected: Bool
    var iconName: String
    var namespace: Namespace.ID
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if selected {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 32, height: 3)
                        .matchedGeometryEffect(id: "selectedTab", in: namespace)
                        .padding(.bottom, 7)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 32, height: 3)
                        .padding(.bottom, 7)
                }
                
                Image(iconName)
                    .renderingMode(.template)
                    .foregroundColor(selected ? .white : DesignSystem.Colors.Gray.gray45)
            }
        }
    }
}
