//
//  ContentView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/10/25.
//

import SwiftUI

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
