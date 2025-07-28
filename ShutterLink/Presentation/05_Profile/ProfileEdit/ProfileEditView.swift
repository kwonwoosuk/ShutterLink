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
                    profileImageSection
                    inputFieldsSection
                    saveButtonSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color.black)
            .navigationTitle("프로필 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $viewModel.selectedImage)
            }
            .onAppear {
                handleViewAppear()
            }
            .onChange(of: viewModel.profile) { newProfile in
                handleProfileChange(newProfile)
            }
        }
    }
}

// MARK: - View Components

extension ProfileEditView {
    
    private var profileImageSection: some View {
        ProfileImageSectionView(
            selectedImage: viewModel.selectedImage,
            profileImageURL: viewModel.profile?.profileImage,
            onImageTap: { showImagePicker = true }
        )
    }
    
    private var inputFieldsSection: some View {
        VStack(spacing: 16) {
            InputFieldView(
                title: "닉네임",
                placeholder: "닉네임을 입력하세요",
                text: $nickname
            )
            
            InputFieldView(
                title: "이름",
                placeholder: "이름을 입력하세요",
                text: $name
            )
            
            InputFieldView(
                title: "소개",
                placeholder: "자기소개를 입력하세요",
                text: $introduction
            )
            
            InputFieldView(
                title: "전화번호",
                placeholder: "전화번호를 입력하세요",
                text: $phoneNumber
            )
            
            InputFieldView(
                title: "해시태그",
                placeholder: "쉼표로 구분하여 입력하세요",
                text: $hashtags
            )
        }
    }
    
    private var saveButtonSection: some View {
        VStack(spacing: 16) {
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
            }
            .disabled(viewModel.isLoading || viewModel.isImageUploading)
            
            if viewModel.isLoading || viewModel.isImageUploading {
                ProgressView()
                    .padding()
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("취소") {
                dismiss()
            }
            .foregroundColor(.white)
        }
    }
}

// MARK: - Logic & Actions

extension ProfileEditView {
    
    private func handleViewAppear() {
        print("🔵 ProfileEditView: 화면 나타남")
        loadProfileAndInitializeFields()
    }
    
    private func handleProfileChange(_ newProfile: ProfileResponse?) {
        if !hasInitialized, let profile = newProfile {
            initializeFields(with: profile)
        }
    }
    
    private func loadProfileAndInitializeFields() {
        if viewModel.profile == nil {
            viewModel.loadProfile()
        } else {
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

        let hashTagsList = hashtags
            .split(separator: ",")
            .map { "#" + String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0.count > 1 } 
        
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

// MARK: - Profile Image Section Component

struct ProfileImageSectionView: View {
    let selectedImage: UIImage?
    let profileImageURL: String?
    let onImageTap: () -> Void
    
    var body: some View {
        VStack {
            imageView
            
            Button("사진 변경") {
                onImageTap()
            }
            .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var imageView: some View {
        if let selectedImage = selectedImage {
            Image(uiImage: selectedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(Circle())
        } else if let profileImageURL = profileImageURL, !profileImageURL.isEmpty {
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
                .overlay(
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50)
                        .foregroundColor(.gray)
                )
        }
    }
}

// MARK: - Input Field Component

struct InputFieldView: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            TextField(placeholder, text: $text)
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileEditView()
}
