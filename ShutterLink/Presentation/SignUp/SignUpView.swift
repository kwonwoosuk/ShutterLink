//
//  SignUpView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // 이메일 입력
                    VStack(alignment: .leading, spacing: 8) {
                        Text("이메일")
                            .font(.headline)
                        
                        HStack {
                            TextField("이메일을 입력하세요", text: $viewModel.email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            Button("중복확인") {
                                Task {
                                    await viewModel.validateEmail()
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(viewModel.isEmailValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .disabled(!viewModel.isEmailValid)
                        }
                        
                        if !viewModel.email.isEmpty {
                            if !viewModel.isEmailValid {
                                Text("유효한 이메일 형식이 아닙니다.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else if viewModel.isEmailAvailable {
                                Text("사용 가능한 이메일입니다.")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    // 비밀번호 입력
                    VStack(alignment: .leading, spacing: 8) {
                        Text("비밀번호")
                            .font(.headline)
                        
                        SecureField("비밀번호를 입력하세요", text: $viewModel.password)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        if !viewModel.password.isEmpty && !viewModel.isPasswordValid {
                            Text("비밀번호는 8자 이상이며, 영문자, 숫자, 특수문자(@$!%*#?&)를 각각 1개 이상 포함해야 합니다.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // 비밀번호 확인
                    VStack(alignment: .leading, spacing: 8) {
                        Text("비밀번호 확인")
                            .font(.headline)
                        
                        SecureField("비밀번호를 다시 입력하세요", text: $viewModel.confirmPassword)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        if !viewModel.confirmPassword.isEmpty && !viewModel.isPasswordMatching {
                            Text("비밀번호가 일치하지 않습니다.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // 닉네임
                    VStack(alignment: .leading, spacing: 8) {
                        Text("닉네임 (영문)")
                            .font(.headline)
                        
                        TextField("영문 닉네임을 입력하세요", text: $viewModel.nickname)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // 이름
                    VStack(alignment: .leading, spacing: 8) {
                        Text("이름 (한글)")
                            .font(.headline)
                        
                        TextField("한글 이름을 입력하세요", text: $viewModel.name)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // 소개
                    VStack(alignment: .leading, spacing: 8) {
                        Text("소개")
                            .font(.headline)
                        
                        TextField("자기소개를 입력하세요", text: $viewModel.introduction)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // 전화번호
                    VStack(alignment: .leading, spacing: 8) {
                        Text("전화번호")
                            .font(.headline)
                        
                        TextField("전화번호를 입력하세요", text: $viewModel.phoneNumber)
                            .keyboardType(.phonePad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // 해시태그
                    VStack(alignment: .leading, spacing: 8) {
                        Text("해시태그 (쉼표로 구분)")
                            .font(.headline)
                        
                        TextField("관심사를 입력하세요 (예: 사진,여행,음식)", text: $viewModel.hashtags)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // 오류 메시지
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    // 가입 버튼
                    Button {
                        Task {
                            await viewModel.signUp()
                        }
                    } label: {
                        Text("회원가입")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isFormValid || viewModel.isLoading)
                    
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
                .padding()
            }
            .navigationTitle("회원가입")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
            .onChange(of: viewModel.isSignUpComplete) { newValue in
                if newValue {
                    dismiss()
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        return viewModel.isEmailValid &&
        viewModel.isEmailAvailable &&
        viewModel.isPasswordValid &&
        viewModel.isPasswordMatching &&
        viewModel.isNicknameValid &&
        viewModel.isNameValid
    }
}
