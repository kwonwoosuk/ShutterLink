//
//  ProfileEditView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProfileViewModel()
    @State private var nickname: String = ""
    @State private var name: String = ""
    @State private var introduction: String = ""
    @State private var phoneNumber: String = ""
    @State private var hashtags: String = ""
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 프로필 이미지 선택
                    Button {
                        showImagePicker = true
                    } label: {
                        ZStack {
                            if let selectedImage = viewModel.selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let profileImageURL = viewModel.profile?.profileImage, !profileImageURL.isEmpty {
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
                            
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .offset(x: 30, y: 30)
                        }
                    }
                    .padding(.top)
                    
                    // 입력 폼
                    VStack(spacing: 16) {
                        // 닉네임
                        VStack(alignment: .leading) {
                            Text("닉네임")
                                .font(.headline)
                                .foregroundColor(.white)
                            TextField("닉네임을 입력하세요", text: $nickname)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        // 이름
                        VStack(alignment: .leading) {
                            Text("이름")
                                .font(.headline)
                                .foregroundColor(.white)
                            TextField("이름을 입력하세요", text: $name)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        // 소개
                        VStack(alignment: .leading) {
                            Text("소개")
                                .font(.headline)
                                .foregroundColor(.white)
                            TextField("자기소개를 입력하세요", text: $introduction)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        // 전화번호
                        VStack(alignment: .leading) {
                            Text("전화번호")
                                .font(.headline)
                                .foregroundColor(.white)
                            TextField("전화번호를 입력하세요", text: $phoneNumber)
                                .keyboardType(.phonePad)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        // 해시태그
                        VStack(alignment: .leading) {
                            Text("해시태그 (쉼표로 구분)")
                                .font(.headline)
                                .foregroundColor(.white)
                            TextField("관심사를 입력하세요 (예: 새싹,자연,미니멀)", text: $hashtags)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 오류 메시지
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                    }
                    
                    // 저장 버튼
                    Button {
                        Task {
                            // 프로필 이미지 업로드
                            if viewModel.selectedImage != nil {
                                let success = await viewModel.uploadProfileImage()
                                if !success {
                                    return
                                }
                            }
                            
                            // 프로필 정보 업데이트
                            let hashTagsList = hashtags.split(separator: ",").map { "#" + String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                            let success = await viewModel.updateProfile(
                                nick: nickname,
                                name: name,
                                introduction: introduction,
                                phoneNum: phoneNumber,
                                hashTags: hashTagsList
                            )
                            
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        Text("저장")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    .disabled(viewModel.isLoading || viewModel.isImageUploading)
                    
                    if viewModel.isLoading || viewModel.isImageUploading {
                        ProgressView()
                            .padding()
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("프로필 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $viewModel.selectedImage)
            }
            .task {
                if viewModel.profile == nil {
                    await viewModel.loadProfile()
                    
                    // 프로필 데이터 로드 후 입력 필드 초기화
                    if let profile = viewModel.profile {
                        nickname = profile.nick
                        name = profile.name
                        introduction = profile.introduction
                        phoneNumber = profile.phoneNum
                        hashtags = profile.hashTags.map { $0.replacingOccurrences(of: "#", with: "") }.joined(separator: ",")
                    }
                }
            }
        }
    }
}
