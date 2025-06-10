//
//  AuthorFilterCard.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import SwiftUI

struct AuthorFilterCard: View {
    let filter: FilterItem
    let onTap: (() -> Void)?
    
    init(filter: FilterItem, onTap: (() -> Void)? = nil) {
        self.filter = filter
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let firstImagePath = filter.files.first {
                AuthenticatedImageView(
                    imagePath: firstImagePath,
                    contentMode: .fill
                ) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    onTap?()
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
                    .onTapGesture {
                        onTap?()
                    }
            }
            
            Text(filter.title)
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 120)
        }
    }
}
