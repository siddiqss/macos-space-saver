//
//  AppDetailSheet.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI
import AppKit

struct AppDetailSheet: View {
    let app: AppInfo
    let onUninstall: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var includeAssociatedFiles = true
    @State private var showUninstallConfirmation = false
    @State private var selectedFiles = Set<AssociatedFile>()
    @State private var searchText = ""
    @State private var showError = false
    @State private var errorMessage: String?
    @StateObject private var appService = AppEnumerationService()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Header
                    appHeaderSection
                    
                    Divider()
                    
                    // Stats Section
                    statsSection
                    
                    Divider()
                    
                    // Associated Files Section
                    if !app.associatedFiles.isEmpty {
                        associatedFilesSection
                    }
                    
                    // Uninstall Section
                    uninstallSection
                }
                .padding(24)
            }
            .navigationTitle("App Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        NSWorkspace.shared.selectFile(app.bundlePath, inFileViewerRootedAtPath: "")
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                }
            }
            .alert("Uninstall \(app.name)", isPresented: $showUninstallConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Uninstall", role: .destructive) {
                    performUninstall()
                }
            } message: {
                Text("Are you sure you want to uninstall \(app.name)?\(includeAssociatedFiles ? "\n\nThis will remove the app and \(app.associatedFiles.count) associated file(s)." : "\n\nThis will only remove the app bundle.")")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    // MARK: - App Header Section
    
    private var appHeaderSection: some View {
        HStack(spacing: 20) {
            // Icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                    .frame(width: 80, height: 80)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(app.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                if let version = app.version {
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Version \(version)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(app.bundleIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Usage badge
                HStack(spacing: 6) {
                    Image(systemName: app.usageStatus.icon)
                        .font(.caption)
                    Text(app.usageStatus.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor(for: app.usageStatus).opacity(0.15))
                .foregroundColor(statusColor(for: app.usageStatus))
                .cornerRadius(6)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage Information")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatCard(
                    title: "App Size",
                    value: FileSizeFormatter.format(bytes: app.size),
                    icon: "app.badge",
                    color: .blue
                )
                
                StatCard(
                    title: "Associated Files",
                    value: FileSizeFormatter.format(bytes: app.totalSize - app.size),
                    icon: "doc.badge.plus",
                    color: .orange
                )
                
                StatCard(
                    title: "Total Size",
                    value: FileSizeFormatter.format(bytes: app.totalSize),
                    icon: "externaldrive.fill",
                    color: .purple
                )
            }
            
            if let lastUsed = app.lastUsedDate, let days = app.daysSinceLastUsed {
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(lastUsed.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(days) days ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Associated Files Section
    
    private var associatedFilesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Associated Files")
                    .font(.headline)
                
                Spacer()
                
                Text("\(filteredAssociatedFiles.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Search
            if app.associatedFiles.count > 3 {
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            
            // File list
            VStack(spacing: 0) {
                ForEach(Array(filteredAssociatedFiles.prefix(10))) { file in
                    AssociatedFileRow(file: file, isSelected: selectedFiles.contains(file)) {
                        if selectedFiles.contains(file) {
                            selectedFiles.remove(file)
                        } else {
                            selectedFiles.insert(file)
                        }
                    }
                    
                    if file.id != filteredAssociatedFiles.prefix(10).last?.id {
                        Divider()
                    }
                }
                
                if filteredAssociatedFiles.count > 10 {
                    Text("+ \(filteredAssociatedFiles.count - 10) more files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 12)
                }
            }
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            
            // Group by type summary
            if !searchText.isEmpty || app.associatedFiles.count > 10 {
                fileTypeSummary
            }
        }
    }
    
    private var fileTypeSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Files by Type")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(AssociatedFileType.allCases, id: \.self) { type in
                    let files = app.associatedFiles.filter { $0.type == type }
                    if !files.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.caption2)
                            Text(type.rawValue)
                                .font(.caption2)
                            Spacer()
                            Text("\(files.count)")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    // MARK: - Uninstall Section
    
    private var uninstallSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Uninstall Options")
                .font(.headline)
            
            Toggle(isOn: $includeAssociatedFiles) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remove associated files")
                        .font(.subheadline)
                    Text("This will delete \(app.associatedFiles.count) related file(s) and free up \(FileSizeFormatter.format(bytes: app.totalSize - app.size))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            
            // Warning
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Warning")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("This action will move the app to Trash. You can restore it from Trash if needed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(10)
            
            // Uninstall button
            Button(action: { showUninstallConfirmation = true }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Uninstall \(app.name)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(Color.red)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredAssociatedFiles: [AssociatedFile] {
        if searchText.isEmpty {
            return app.associatedFiles
        }
        return app.associatedFiles.filter {
            $0.path.localizedCaseInsensitiveContains(searchText) ||
            $0.fileName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Actions
    
    private func performUninstall() {
        Task {
            do {
                try await appService.uninstallApp(app, includeAssociatedFiles: includeAssociatedFiles)
                await MainActor.run {
                    dismiss()
                    onUninstall()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func statusColor(for status: UsageStatus) -> Color {
        switch status {
        case .active: return .green
        case .recentlyUsed: return .blue
        case .seldomUsed: return .orange
        case .unused: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Associated File Row

struct AssociatedFileRow: View {
    let file: AssociatedFile
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.type.icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(file.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 8) {
                    Text(file.type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    if let modDate = file.modifiedDate {
                        Text(modDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Text(FileSizeFormatter.format(bytes: file.size))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Button {
                NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#Preview {
    AppDetailSheet(
        app: AppInfo(
            name: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            bundlePath: "/Applications/Xcode.app",
            version: "15.0",
            size: 5_000_000_000,
            lastUsedDate: Date().addingTimeInterval(-86400 * 60),
            icon: NSWorkspace.shared.icon(forFile: "/Applications/Xcode.app"),
            associatedFiles: [
                AssociatedFile(
                    path: "~/Library/Developer/Xcode",
                    size: 10_000_000_000,
                    type: .applicationSupport,
                    modifiedDate: Date()
                ),
                AssociatedFile(
                    path: "~/Library/Caches/com.apple.dt.Xcode",
                    size: 2_000_000_000,
                    type: .caches,
                    modifiedDate: Date()
                ),
                AssociatedFile(
                    path: "~/Library/Preferences/com.apple.dt.Xcode.plist",
                    size: 50_000,
                    type: .preferences,
                    modifiedDate: Date()
                )
            ]
        ),
        onUninstall: {}
    )
}

