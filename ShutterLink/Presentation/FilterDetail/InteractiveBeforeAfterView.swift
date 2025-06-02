////
////  InteractiveBeforeAfterView.swift
////  ShutterLink
////
////  Created by 권우석 on 6/1/25.
////
//
//import SwiftUI
//
//struct InteractiveBeforeAfterView: View {
//    let imagePath: String
//    let filterValues: FilterValues
//    @State private var dividerPosition: CGFloat = 0.5
//    @State private var isDragging = false
//    
//    var body: some View {
//        VStack(spacing: 16) {
//            // 메인 이미지 영역
//            GeometryReader { geometry in
//                ZStack {
//                    // Before 이미지 (원본) - 전체 이미지
//                    if !imagePath.isEmpty {
//                        AuthenticatedImageView(
//                            imagePath: imagePath,
//                            contentMode: .fill
//                        ) {
//                            Rectangle()
//                                .fill(Color.gray.opacity(0.3))
//                                .overlay(
//                                    ProgressView()
//                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                )
//                        }
//                        .frame(width: geometry.size.width, height: geometry.size.height)
//                        .clipped()
//                    }
//                    
//                    // After 이미지 (필터 적용) - 디바이더 위치에 따라 표시
//                    if !imagePath.isEmpty {
//                        AuthenticatedImageView(
//                            imagePath: imagePath,
//                            contentMode: .fill
//                        ) {
//                            Rectangle()
//                                .fill(Color.gray.opacity(0.3))
//                        }
//                        .frame(width: geometry.size.width, height: geometry.size.height)
//                        .clipped()
//                        .overlay(
//                            LinearGradient(
//                                gradient: Gradient(colors: [
//                                    Color.blue.opacity(0.2 + filterValues.saturation * 0.15),
//                                    Color.cyan.opacity(0.1 + filterValues.contrast * 0.1)
//                                ]),
//                                startPoint: .topLeading,
//                                endPoint: .bottomTrailing
//                            )
//                            .blendMode(.multiply)
//                        )
//                        .brightness(filterValues.brightness * 0.3)
//                        .contrast(1 + filterValues.contrast * 0.5)
//                        .saturation(1 + filterValues.saturation)
//                        .mask(
//                            Rectangle()
//                                .frame(width: geometry.size.width * dividerPosition, height: geometry.size.height)
//                                .position(x: geometry.size.width * dividerPosition / 2, y: geometry.size.height / 2)
//                        )
//                    }
//                }
//            }
//            .cornerRadius(16)
//            .frame(height: 400)
//            
//            // 통합된 디바이더 컨트롤
//            ConnectedControlView(
//                dividerPosition: $dividerPosition,
//                isDragging: $isDragging
//            )
//        }
//        .padding(.horizontal, 20)
//    }
//}
