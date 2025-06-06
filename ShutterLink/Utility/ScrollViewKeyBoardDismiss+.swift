//
//  ScrollViewKeyBoardDismiss+.swift
//  ShutterLink
//
//  Created by 권우석 on 6/6/25.
//

import SwiftUI

extension View {
    func dismissKeyboardOnScroll() -> some View {
        self
//            .gesture(
//                DragGesture()
//                    .onChanged { _ in
//                        // 스크롤(드래그) 시작 시 키보드 숨기기
//                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//                    }
//            )
            .onTapGesture {
                // 탭 시에도 키보드 숨기기 (추가적인 편의)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
}
