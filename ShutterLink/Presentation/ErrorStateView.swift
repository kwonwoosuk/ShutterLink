//
//  ErrorStateView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/29/25.
//

import SwiftUI

struct ErrorStateView: View {
    let errorMessage: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text(errorMessage)
                .font(.pretendard(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Button("다시 시도") {
                onRetry()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(20)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
    }
}
