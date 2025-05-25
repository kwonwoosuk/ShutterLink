//
//  HeaderView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import SwiftUI

// MARK: - 헤더 뷰
struct HeaderView: View {
    var body: some View {
        HStack {
            Text("ShutterLink")
                .font(.hakgyoansim(size: 20, weight: .regular))
                .foregroundColor(.gray45)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "bell")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}
