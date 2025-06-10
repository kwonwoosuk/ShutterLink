//
//  MakeOnboardingView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/8/25.
//

import SwiftUI

struct MakeOnboardingView: View {
    @EnvironmentObject private var router: NavigationRouter
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // 메인 타이틀과 설명
                VStack(spacing: 16) {
                    Text("새로운 필터를 만들어보세요")
                        .font(.hakgyoansim(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("사진을 선택하고 편집하여\n나만의 필터를 제작할 수 있습니다")
                        .font(.pretendard(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                // 필터 생성 버튼
                Button {
                    router.pushToCreateFilter()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                        
                        Text("새로운 필터 생성하기")
                            .font(.pretendard(size: 16, weight: .semiBold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DesignSystem.Colors.Brand.brightTurquoise)
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("MAKE")
                    .font(.hakgyoansim(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MakeOnboardingView()
            .environmentObject(NavigationRouter.shared)
    }
    .preferredColorScheme(.dark)
}
