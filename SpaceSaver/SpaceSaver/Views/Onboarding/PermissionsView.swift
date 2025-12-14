//
//  PermissionsView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI

struct PermissionsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 25) {
            // Icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            // Title
            Text("Full Disk Access Required")
                .font(.title)
                .fontWeight(.bold)
            
            // Explanation
            VStack(alignment: .leading, spacing: 15) {
                Text("To find hidden junk files and analyze your disk space, SpaceSaver needs Full Disk Access.")
                    .font(.body)
                
                Text("Here's how to enable it:")
                    .font(.headline)
                    .padding(.top, 5)
                
                VStack(alignment: .leading, spacing: 10) {
                    InstructionStep(number: "1", text: "Open System Settings")
                    InstructionStep(number: "2", text: "Go to Privacy & Security")
                    InstructionStep(number: "3", text: "Click on Full Disk Access")
                    InstructionStep(number: "4", text: "Enable SpaceSaver")
                }
                .padding(.leading, 20)
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            // Buttons
            HStack(spacing: 15) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Open System Settings") {
                    openSystemSettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(width: 500, height: 500)
    }
    
    private func openSystemSettings() {
        // Open System Settings to Full Disk Access
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct InstructionStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.body)
        }
    }
}

