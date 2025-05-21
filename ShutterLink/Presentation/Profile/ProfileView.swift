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
                            AsyncImage(url: URL(string: APIConstants.baseURL + profileImageURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
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
            
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadProfile()
            }
        }
        .sheet(isPresented: $showEditProfile) {
            ProfileEditView()
        }
    }
}
