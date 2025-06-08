//
//  NavigationLazyView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/9/25.
//

import SwiftUI

/// 성능 최적화를 위한 지연 로딩 뷰
/// Navigation 시 뷰가 실제로 필요할 때까지 생성을 지연시켜 메모리와 성능을 개선
struct NavigationLazyView<T: View>: View {
    let build: () -> T
    
    init(_ build: @autoclosure @escaping () -> T) {
        self.build = build
    }
    
    var body: some View {
        build()
    }
}
