//
//  ProfileView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/21/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authState: AuthState
    @State private var showEditProfile = false
    
    var body: some View {
        ZStack {
            // 다크 모드 배경
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 프로필 헤더
                    HStack(alignment: .top) {
                        // 프로필 이미지
                        Image("profile_placeholder") // 실제 구현에서는 사용자 이미지 사용
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        
                        Spacer()
                        
                        // 프로필 수정 버튼
                        Button(action: {
                            showEditProfile = true
                        }) {
                            Text("프로필 수정")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.85))
                                .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 사용자 이름
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authState.currentUser?.nickname ?? "윤새싹")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("SESAC YOON")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // 해시태그
                    HStack(spacing: 8) {
                        ForEach(["#새싹", "#자연", "#미니멀"], id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)
                    
                    // 갤러리 그리드
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 4) {
                        ForEach(1...6, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .padding(.top)
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            Text("프로필 편집 화면")
        }
    }
}
