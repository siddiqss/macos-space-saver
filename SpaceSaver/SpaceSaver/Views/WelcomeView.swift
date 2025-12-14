//
//  WelcomeView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI
import AppKit
import Combine

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPermissionsView = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Icon/Logo
            Image(systemName: "externaldrive.badge.checkmark")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            // Title
            Text("Welcome to SpaceSaver")
                .font(.system(size: 36, weight: .bold))
            
            // Subtitle
            Text("Find and clean up disk space on your Mac")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // CTA Button
            Button(action: {
                if appState.hasFullDiskAccess {
                    // Start scanning
                } else {
                    showPermissionsView = true
                }
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Get Started")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 15)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showPermissionsView) {
            PermissionsView()
        }
    }
}

