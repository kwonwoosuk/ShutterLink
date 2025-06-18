//
//  ProfileEditView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI

struct ProfileEditView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showImagePicker = false
    
    @State private var nickname = ""
    @State private var name = ""
    @State private var introduction = ""
    @State private var phoneNumber = ""
    @State private var hashtags = ""
    @State private var hasInitialized = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 프로필 이미지 섹션
                    VStack {
                        if let selectedImage = viewModel.selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else if let profileImageURL = viewModel.profile?.profileImage, !profileImageURL.isEmpty {
                            AuthenticatedImageView(
                                imagePath: profileImageURL,
                                contentMode: .fill
                            ) {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    )
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 100)
                        }
                        
                        Button("사진 변경") {
                            showImagePicker = true
                        }
                        .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                        .padding(.top, 8)
                    }
                    
                    // 입력 필드들
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
                            await handleSave()
                        }
                    } label: {
                        Text("저장")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(DesignSystem.Colors.Brand.brightTurquoise)
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
            .onAppear {
                print("🔵 ProfileEditView: 화면 나타남")
                loadProfileAndInitializeFields()
            }
            // 🆕 추가 - 프로필 데이터가 로드되면 필드 초기화
            .onChange(of: viewModel.profile) { newProfile in
                if !hasInitialized, let profile = newProfile {
                    initializeFields(with: profile)
                }
            }
        }
    }
    
    // MARK: - 🆕 추가 메서드들
    
    private func loadProfileAndInitializeFields() {
        // 프로필이 없으면 로드
        if viewModel.profile == nil {
            viewModel.loadProfile()
        } else {
            // 이미 로드된 경우 바로 초기화
            initializeFields(with: viewModel.profile!)
        }
    }
    
    private func initializeFields(with profile: ProfileResponse) {
        guard !hasInitialized else { return }
        
        print("🔵 ProfileEditView: 기존 정보로 필드 초기화")
        
        nickname = profile.nick
        name = profile.name ?? ""
        introduction = profile.introduction ?? ""
        phoneNumber = profile.phoneNum ?? ""
        
        // 해시태그에서 # 제거하고 쉼표로 연결
        let cleanHashtags = profile.hashTags.map {
            $0.replacingOccurrences(of: "#", with: "")
        }
        hashtags = cleanHashtags.joined(separator: ", ")
        
        hasInitialized = true
        print("✅ ProfileEditView: 필드 초기화 완료 - 닉네임: \(nickname)")
    }
    
    private func handleSave() async {
        print("🔵 ProfileEditView: 저장 시작")
        
        // 프로필 이미지 업로드 (있는 경우)
        if viewModel.selectedImage != nil {
            print("🔵 ProfileEditView: 이미지 업로드 시작")
            let imageUploadTask = viewModel.uploadProfileImage()
            let success = await imageUploadTask.value
            
            if !success {
                print("❌ ProfileEditView: 이미지 업로드 실패")
                return
            }
            print("✅ ProfileEditView: 이미지 업로드 완료")
        }
        
        // 프로필 정보 업데이트
        print("🔵 ProfileEditView: 프로필 정보 업데이트 시작")
        
        // 해시태그 처리 - 쉼표로 분리하고 # 추가
        let hashTagsList = hashtags
            .split(separator: ",")
            .map { "#" + String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0.count > 1 } // "#"만 있는 것 제외
        
        let updateTask = viewModel.updateProfile(
            nick: nickname,
            name: name,
            introduction: introduction,
            phoneNum: phoneNumber,
            hashTags: hashTagsList
        )
        
        let success = await updateTask.value
        
        if success {
            print("✅ ProfileEditView: 프로필 업데이트 완료")
            await MainActor.run {
                dismiss()
            }
        } else {
            print("❌ ProfileEditView: 프로필 업데이트 실패")
        }
    }
}
