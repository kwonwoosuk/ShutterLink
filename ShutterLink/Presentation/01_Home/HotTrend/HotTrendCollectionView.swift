//
//  HotTrendCollectionView.swift
//  ShutterLink
//
//  Created by 권우석 on 6/8/25.
//

import SwiftUI
import UIKit

// MARK: - Modern UIKit CollectionView 래핑 (참고 코드 기반)
struct HotTrendCollectionView<Cell: View>: UIViewRepresentable {
    typealias DataSource = UICollectionViewDiffableDataSource<String, FilterItem>
    typealias Snapshot = NSDiffableDataSourceSnapshot<String, FilterItem>
    typealias Registration = UICollectionView.CellRegistration<UICollectionViewCell, FilterItem>
    
    private let filters: [FilterItem]
    private let cell: (FilterItem) -> Cell
    private let onFilterTap: ((String) -> Void)?
    
    init(filters: [FilterItem], onFilterTap: ((String) -> Void)? = nil, @ViewBuilder cell: @escaping (FilterItem) -> Cell) {
        self.filters = filters
        self.onFilterTap = onFilterTap
        self.cell = cell
    }
    
    func makeUIView(context: Context) -> UICollectionView {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: configureCompositionalLayout()
        )
        
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = context.coordinator
        
        configureDataSource(collectionView, coordinator: context.coordinator)
        applySnapshot(coordinator: context.coordinator)
        
        return collectionView
    }
    
    func updateUIView(_ uiView: UICollectionView, context: Context) {
        context.coordinator.onFilterTap = onFilterTap
        applySnapshot(coordinator: context.coordinator)
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(onFilterTap: onFilterTap)
    }
}

// MARK: - Coordinator
extension HotTrendCollectionView {
    final class Coordinator: NSObject, UICollectionViewDelegate {
        var dataSource: DataSource?
        var onFilterTap: ((String) -> Void)?
        
        init(onFilterTap: ((String) -> Void)?) {
            self.onFilterTap = onFilterTap
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard let item = dataSource?.itemIdentifier(for: indexPath) else { return }
            onFilterTap?(item.filter_id)
        }
    }
}

// MARK: - Configure Views
private extension HotTrendCollectionView {
    func configureDataSource(
        _ collectionView: UICollectionView,
        coordinator: Coordinator
    ) {
        let registration = Registration { cell, _, filter in
            cell.contentConfiguration = UIHostingConfiguration {
                self.cell(filter)
            }
            .margins(.all, 0) // 여백 제거로 정확한 크기 제어
        }
        
        coordinator.dataSource = DataSource(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(
                using: registration,
                for: indexPath,
                item: item
            )
        }
    }
    
    func configureCompositionalLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            self.configureSectionLayout()
        }
        return layout
    }
    
    func configureSectionLayout() -> NSCollectionLayoutSection {
        // 아이템 크기 설정
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        // 그룹 크기 설정 (카드 크기) - 정확한 3:4 비율
        let screenWidth = UIScreen.main.bounds.width
        let cardWidth: CGFloat = screenWidth * 0.45 // 화면의 45%
        let cardHeight: CGFloat = cardWidth * 4/3 // 3:4 비율 (세로가 더 김)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(cardWidth),
            heightDimension: .absolute(cardHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        
        // 중앙 정렬 페이징 (참고 코드의 핵심 기능)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        
        // 스크롤 시 알파 효과 (참고 코드의 시각적 효과)
        section.visibleItemsInvalidationHandler = { items, offset, environment in
            let containerWidth = environment.container.contentSize.width
            let maxDistance = containerWidth / 2
            
            for item in items {
                let itemCenterX = item.center.x - offset.x
                let distanceFromCenter = abs(containerWidth / 2 - itemCenterX)
                let normalizedDistance = min(distanceFromCenter / maxDistance, 1.0)
                
                // 중앙: 1.0, 가장자리: 0.6
                let minAlpha: CGFloat = 0.6
                let alpha = 1.0 - (normalizedDistance * (1.0 - minAlpha))
                item.alpha = alpha
                
                // 중앙: 1.0, 가장자리: 0.95 (스케일 효과 줄임)
                let minScale: CGFloat = 0.95
                let scale = 1.0 - (normalizedDistance * (1.0 - minScale))
                item.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
        }
        
        return section
    }
    
    func applySnapshot(coordinator: Coordinator) {
        var snapshot = Snapshot()
        snapshot.appendSections(["HotTrendSection"])
        snapshot.appendItems(filters, toSection: "HotTrendSection")
        coordinator.dataSource?.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - FilterItem Hashable 확장 (DiffableDataSource용)
extension FilterItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(filter_id)
    }
    
    static func == (lhs: FilterItem, rhs: FilterItem) -> Bool {
        return lhs.filter_id == rhs.filter_id
    }
}
