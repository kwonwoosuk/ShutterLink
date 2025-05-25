//
//  ProfileView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/21/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authState: AuthState
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false
    @State private var showLogoutAlert = false // 로그아웃 확인 알림창 표시 여부
    @State private var hasAppeared = false
    
    var body: some View {
        ZStack {
            // 다크 모드 배경
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // 프로필 원형 이미지
                    HStack {
                        Spacer()
                        if let profileImageURL = viewModel.profile?.profileImage, !profileImageURL.isEmpty {
                            AuthenticatedImageView(
                                imagePath: profileImageURL,
                                contentMode: .fill
                            ) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50)
                                        .foregroundColor(.gray)
                                )
                        }
                        Spacer()
                    }
                    .padding(.top, 30)
                    
                    // 사용자 이름 및 프로필 수정 버튼
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.profile?.nick ?? authState.currentUser?.nickname ?? "")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(viewModel.profile?.name ?? "SESAC USER")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button {
                            showEditProfile = true
                        } label: {
                            Text("프로필 수정")
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 해시태그
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.profile?.hashTags ?? [], id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // 로그아웃 버튼 추가
                    Button {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("로그아웃")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // 사진 그리드
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                        ForEach(1...6, id: \.self) { _ in
                            Color.gray.opacity(0.2)
                                .aspectRatio(1, contentMode: .fill)
                                .overlay(
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30)
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .padding(.top, 20)
                }
                .padding(.bottom, 100) // 탭바 높이만큼 하단 패딩
            }
            .opacity(viewModel.isLoading ? 0.7 : 1.0)
            
            // 로딩 인디케이터 - 중앙 작은 크기로 변경
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("로딩 중...")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                .padding(20)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            }
        }
        .onAppear {
            // 탭 전환 완료 후 로딩 시작
            if !hasAppeared {
                hasAppeared = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🔵 ProfileView: 프로필 로딩 시작")
                    viewModel.loadProfile()
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            ProfileEditView()
        }
        // iOS 16 호환성을 위한 onChange 수정
        .compatibleOnChange(of: showEditProfile) { newValue in
            if newValue == false {
                // 프로필 수정 화면이 닫힌 후 프로필 다시 로드
                print("🔵 ProfileView: 프로필 수정 완료, 다시 로드")
                viewModel.loadProfile()
            }
        }
        // 로그아웃 확인 알림창
        .alert("로그아웃", isPresented: $showLogoutAlert) {
            Button("취소", role: .cancel) { }
            Button("로그아웃", role: .destructive) {
                // 로그아웃 처리 (메인스레드에서 실행됨)
                authState.logout()
            }
        } message: {
            Text("정말 로그아웃 하시겠습니까?")
        }
    }
}
