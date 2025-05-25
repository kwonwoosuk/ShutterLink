//
//  HotTrendSection.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import SwiftUI
// MARK: - 섹션 3: 핫트랜드 (무한 스크롤 + 중앙 페이징)
struct HotTrendSection: View {
    let filters: [FilterItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 타이틀
            HStack {
                Text("핫 트렌드")
                    .font(.hakgyoansim(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 20)

            if !filters.isEmpty {
                // 10개 셀만 사용하도록 제한
                let limitedFilters = Array(filters.prefix(10))
                HotTrendCarouselView(filters: limitedFilters)
            } else {
                // 로딩 상태
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                }
                .frame(height: 280)
            }
        }
    }
}
