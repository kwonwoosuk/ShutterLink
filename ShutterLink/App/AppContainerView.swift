//
//  ContentView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/10/25.
//

import SwiftUI

struct AppContainerView: View {
    @EnvironmentObject private var authState: AuthState
    
    var body: some View {
        if authState.isLoggedIn {
            MainTabView()
        } else {
            SignInView()
        }
    }
}
