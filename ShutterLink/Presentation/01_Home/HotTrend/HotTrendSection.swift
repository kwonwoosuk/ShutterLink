//
//  HotTrendSection.swift
//  ShutterLink
//
//  Created by 권우석 on 5/25/25.
//

import SwiftUI

struct HotTrendSection: View {
    let filters: [FilterItem]
    let onFilterTap: ((String) -> Void)?
    
    init(filters: [FilterItem], onFilterTap: ((String) -> Void)? = nil) {
        self.filters = filters
        self.onFilterTap = onFilterTap
    }
    
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
                // Modern UIKit CollectionView 사용으로 성능 최적화
                let limitedFilters = Array(filters.prefix(10))
                HotTrendCollectionView(
                    filters: limitedFilters,
                    onFilterTap: onFilterTap // 실제 onFilterTap 전달 (빈 클로저가 아님)
                ) { filter in
                    HotTrendCardView(filter: filter) {
                        // onTap 클로저는 더 이상 사용되지 않음 (UICollectionView에서 처리)
                    }
                }
                .frame(height: UIScreen.main.bounds.width * 0.45 * 4/3 + 20)
            } else {
                // 로딩 상태
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                }
                .frame(height: 240)
            }
        }
    }
}
