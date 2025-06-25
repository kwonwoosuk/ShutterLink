//
//  SignInView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/16/25.
//

import SwiftUI
import KakaoSDKUser
import KakaoSDKAuth
import KakaoSDKCommon

struct SignInView: View {
    @StateObject private var viewModel = SignInViewModel()
    @State private var showSignUp = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        let mainView = NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
               
                Text("ShutterLink")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 이메일 입력
                TextField("이메일", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                // 비밀번호 입력
                SecureField("비밀번호", text: $viewModel.password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                // 오류 메시지
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                // 로그인 버튼
                Button {
                    Task {
                        await viewModel.signIn()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    } else {
                        Text("로그인")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .disabled(viewModel.isLoading)
                .padding(.horizontal)
                
                // 소셜 로그인 영역
                VStack(spacing: 16) {
                    Text("또는")
                        .foregroundColor(.gray)
                    
                    // 카카오 로그인
                    Button {
                        Task {
                            await viewModel.signInWithKakao()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "message.fill")
                                .foregroundColor(.black)
                            Text("카카오로 로그인")
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // 애플 로그인
                    Button {
                        Task {
                            await viewModel.signInWithApple()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "apple.logo")
                                .foregroundColor(.white)
                            Text("Apple로 로그인")
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // 회원가입 버튼
                HStack {
                    Text("계정이 없으신가요?")
                        .foregroundColor(.gray)
                    
                    Button("회원가입") {
                        showSignUp = true
                    }
                    .foregroundColor(.blue)
                }
                .padding(.bottom)
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
        }
        
        
        return mainView
            .onChange(of: viewModel.isSignInComplete) { newValue in
                if newValue {
                    dismiss()
                }
            }
    }
}
