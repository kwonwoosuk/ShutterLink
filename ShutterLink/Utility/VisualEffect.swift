//
//  VisualEffect.swift
//  ShutterLink
//
//  Created by 권우석 on 6/6/25.
//

import SwiftUI

// MARK: - iOS 16 호환 VisualEffect
struct VisualEffect: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    init(style: UIBlurEffect.Style = .systemUltraThinMaterial) {
        self.style = style
    }
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: style)
        let visualEffectView = UIVisualEffectView(effect: blurEffect)
        return visualEffectView
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        let blurEffect = UIBlurEffect(style: style)
        uiView.effect = blurEffect
    }
}
