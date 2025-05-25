//
//  View+Extension.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import SwiftUI

// iOS 16 호환성을 위한 onChange extension
extension View {
    @ViewBuilder
    func compatibleOnChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value) { newValue in
                action(newValue)
            }
        }
    }
}
