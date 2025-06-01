////
////  ConnectedControlView.swift
////  ShutterLink
////
////  Created by 권우석 on 6/1/25.
////
//
//import SwiftUI
//
//struct ConnectedControlView: View {
//    @Binding var dividerPosition: CGFloat
//    @Binding var isDragging: Bool
//    @State private var dragOffset: CGFloat = 0
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                // 슬라이드 트랙
//                Capsule()
//                    .fill(.ultraThinMaterial)
//                    .opacity(0.9)
//                    .frame(width: geometry.size.width - 40, height: 44)
//                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
//                
//                // 통합된 After-Divider-Before 뷰
//                HStack(spacing: 0) {
//                    // After 버튼
//                    Text("After")
//                        .font(.pretendard(size: 16, weight: .medium))
//                        .foregroundColor(.white)
//                        .frame(width: 80, height: 44)
//                        .background(
//                            Capsule()
//                                .fill(.ultraThinMaterial)
//                                .opacity(0.9)
//                        )
//                    
//                    // 디바이더 버튼
//                    Image("DivideButton")
//                        .renderingMode(.template)
//                        .foregroundColor(.white)
//                        .frame(width: 44, height: 44)
//                        .scaleEffect(isDragging ? 1.1 : 1.0)
//                        .animation(.easeInOut(duration: 0.1), value: isDragging)
//                    
//                    // Before 버튼
//                    Text("Before")
//                        .font(.pretendard(size: 16, weight: .medium))
//                        .foregroundColor(.white)
//                        .frame(width: 80, height: 44)
//                        .background(
//                            Capsule()
//                                .fill(.ultraThinMaterial)
//                                .opacity(0.9)
//                        )
//                }
//                .offset(x: dragOffset)
//                .gesture(
//                    DragGesture()
//                        .onChanged { value in
//                            isDragging = true
//                            
//                            // 슬라이드 영역 중앙 기준으로 상대 위치 계산
//                            let trackWidth = geometry.size.width - 40
//                            let relativeX = value.location.x - (trackWidth / 2)
//                            
//                            // 슬라이드 범위 제한 (± (trackWidth - 버튼 전체 너비) / 2)
//                            let buttonGroupWidth: CGFloat = 80 + 44 + 80 // After + Divider + Before
//                            let maxOffset = (trackWidth - buttonGroupWidth) / 2
//                            dragOffset = max(-maxOffset, min(maxOffset, relativeX))
//                            
//                            // dragOffset을 dividerPosition으로 변환 (0.1 ~ 0.9)
//                            let normalizedPosition = (dragOffset + maxOffset) / (maxOffset * 2)
//                            dividerPosition = 0.1 + (normalizedPosition * 0.8)
//                        }
//                        .onEnded { _ in
//                            isDragging = false
//                        }
//                )
//            }
//        }
//        .frame(height: 44)
//        .onAppear {
//            // 초기 dragOffset 설정
//            let trackWidth = (UIScreen.main.bounds.width - 40) - 40 // GeometryReader 없이 초기값 계산
//            let buttonGroupWidth: CGFloat = 80 + 44 + 80
//            let maxOffset = (trackWidth - buttonGroupWidth) / 2
//            let normalizedPosition = (dividerPosition - 0.1) / 0.8
//            dragOffset = (normalizedPosition * (maxOffset * 2)) - maxOffset
//        }
//        .compatibleOnChange(of: dividerPosition) { newValue in
//            if !isDragging {
//                withAnimation(.easeInOut(duration: 0.3)) {
//                    let trackWidth = (UIScreen.main.bounds.width - 40) - 40
//                    let buttonGroupWidth: CGFloat = 80 + 44 + 80
//                    let maxOffset = (trackWidth - buttonGroupWidth) / 2
//                    let normalizedPosition = (newValue - 0.1) / 0.8
//                    dragOffset = (normalizedPosition * (maxOffset * 2)) - maxOffset
//                }
//            }
//        }
//    }
//}
