//
//  ShutterLinkApp.swift
//  ShutterLink
//
//  Created by 권우석 on 5/10/25.
//

import SwiftUI

@main
struct ShutterLinkApp: App {
    @StateObject private var authState = AuthState.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authState)
                .fullScreenCover(isPresented: $authState.showLoginModal) {
                    SignInView()
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var authState: AuthState
    
    var body: some View {
        if authState.isLoggedIn {
            HomeView()
        } else {
            SignInView()
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var authState: AuthState
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("환영합니다, \(authState.currentUser?.nickname ?? "사용자")님!")
                    .font(.title)
                    .padding()
                
                Button("로그아웃") {
                    authState.logout()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .navigationTitle("ShutterLink")
        }
    }
}
