//
//  HotTrendCardView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/8/25.
//

import SwiftUI

// MARK: - 심플한 카드 뷰
struct HotTrendCardView: View {
    let filter: FilterItem
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            // 메인 이미지
            mainImageView
            
            overlayView
        }
        .clipped()
        .cornerRadius(20)
    }
    
    @ViewBuilder
    private var mainImageView: some View {
        GeometryReader { geometry in
            if !filter.files.isEmpty {
                AuthenticatedImageView(
                    imagePath: filter.files.first ?? "",
                    contentMode: .fill
                ) {
                    placeholderView
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .clipped()
            } else {
                placeholderView
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
            }
        }
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            )
    }
    
    private var overlayView: some View {
        VStack {
            HStack {
                Text(filter.title)
                    .font(.hakgyoansim(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)
            
            Spacer()
            
            HStack {
                Spacer()
                
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .medium))
                    
                    Text("\(filter.like_count)")
                        .font(.pretendard(size: 12, weight: .semiBold))
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 12)
            .padding(.horizontal, 12)
        }
    }
}
