//
//  PaymentWebView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/19/25.
//

import SwiftUI
import WebKit

struct PaymentWebView: UIViewRepresentable {
    @Binding var webView: WKWebView?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = UIColor.clear
        
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        
    }
}

struct PaymentProgressView: View {
    let isVisible: Bool
    let message: String
    
    var body: some View {
        if isVisible {
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.Brand.brightTurquoise))
                    .scaleEffect(1.2)
                
                Text(message)
                    .font(.pretendard(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
            .transition(.scale.combined(with: .opacity))
        }
    }
}
