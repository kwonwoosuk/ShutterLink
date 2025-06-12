//
//  ChatComponents.swift
//  ShutterLink
//
//  Created by 권우석 on 6/11/25.
//

import SwiftUI

// MARK: - 채팅 시작 안내

struct ChatStartNotice: View {
    let participantName: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            Text("\(participantName)님과의 채팅을 시작합니다")
                .font(.pretendard(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            Text("서로 존중하며 대화해주세요")
                .font(.pretendard(size: 14, weight: .regular))
                .foregroundColor(.gray.opacity(0.8))
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 날짜 구분선

struct ChatDateSeparator: View {
    let date: Date
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 0.5)
            
            Text(formatDate(date))
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                )
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "오늘"
        } else if calendar.isDateInYesterday(date) {
            return "어제"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "M월 d일 EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "yyyy년 M월 d일 EEEE"
            return formatter.string(from: date)
        }
    }
}

// MARK: - 채팅 연결 상태 표시

struct ChatConnectionStatusView: View {
    let status: SocketConnectionStatus
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.2))
    }
    
    private var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        return status.description
    }
}

// MARK: - 채팅 입력 상태 표시

struct ChatTypingIndicator: View {
    let userName: String
    @State private var animationPhase: Int = 0
    
    var body: some View {
        HStack(spacing: 8) {
            // 프로필 이미지 영역 (36px)
            Color.clear
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(userName)
                    .font(.pretendard(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.leading, 4)
                
                HStack(spacing: 4) {
                    typingDots
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.gray.opacity(0.8))
                        )
                    
                    Spacer()
                }
            }
            
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear {
            startAnimation()
        }
    }
    
    private var typingDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .opacity(animationPhase == index ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: false),
                        value: animationPhase
                    )
            }
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            animationPhase = (animationPhase + 1) % 3
        }
    }
}

// MARK: - 미리보기

struct ChatComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ChatStartNotice(participantName: "김철수")
            
            ChatDateSeparator(date: Date())
            
            ChatConnectionStatusView(status: .connected)
            ChatConnectionStatusView(status: .connecting)
            ChatConnectionStatusView(status: .disconnected)
            
            ChatTypingIndicator(userName: "김철수")
            
            Spacer()
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
