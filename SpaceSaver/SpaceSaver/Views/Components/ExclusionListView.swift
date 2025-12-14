//
//  ExclusionListView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI
import AppKit

struct ExclusionListView: View {
    @State private var userExclusions: [String] = []
    @State private var showingFolderPicker = false
    @State private var selectedExclusion: String?
    
    private let exclusionManager = PathExclusionManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Excluded Paths")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Folders excluded from scanning and deletion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingFolderPicker = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Folder")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            // Default exclusions (read-only)
            VStack(alignment: .leading, spacing: 8) {
                Text("System Exclusions (Default)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(exclusionManager.allExclusions.filter { !userExclusions.contains($0) }, id: \.self) { path in
                            exclusionRow(path: path, isUserExclusion: false)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
            
            Divider()
            
            // User exclusions (editable)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Your Exclusions")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !userExclusions.isEmpty {
                        Button("Clear All") {
                            clearAllExclusions()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
                
                if userExclusions.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(userExclusions, id: \.self) { path in
                                exclusionRow(path: path, isUserExclusion: true)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 600, height: 500)
        .onAppear {
            loadUserExclusions()
        }
        .sheet(isPresented: $showingFolderPicker) {
            FolderPickerView { selectedPath in
                addExclusion(selectedPath)
            }
        }
    }
    
    // MARK: - Subviews
    
    private func exclusionRow(path: String, isUserExclusion: Bool) -> some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
            
            Text(path)
                .font(.body)
                .lineLimit(1)
            
            Spacer()
            
            if isUserExclusion {
                Button(action: { removeExclusion(path) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Remove exclusion")
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .help("System exclusion (cannot be removed)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selectedExclusion == path ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.05))
        .cornerRadius(6)
        .onTapGesture {
            selectedExclusion = path
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No custom exclusions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add folders that you want to exclude from scanning")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Actions
    
    private func loadUserExclusions() {
        userExclusions = UserDefaults.standard.stringArray(forKey: "pathExclusions") ?? []
    }
    
    private func addExclusion(_ path: String) {
        exclusionManager.addUserExclusion(path)
        loadUserExclusions()
    }
    
    private func removeExclusion(_ path: String) {
        exclusionManager.removeUserExclusion(path)
        loadUserExclusions()
    }
    
    private func clearAllExclusions() {
        exclusionManager.clearUserExclusions()
        loadUserExclusions()
    }
}

// MARK: - Folder Picker View
struct FolderPickerView: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Folder to Exclude")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Choose a folder that should be excluded from scans")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Choose Folder") {
                    selectFolder()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 150)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to exclude from scanning"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                onSelect(url.path)
                dismiss()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ExclusionListView()
}

