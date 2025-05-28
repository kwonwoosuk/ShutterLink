//
//  LoadingIndicatorView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/29/25.
//

import SwiftUI

struct LoadingIndicatorView: View {
    var body: some View {
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
