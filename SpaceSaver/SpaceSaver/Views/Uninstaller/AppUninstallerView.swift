//
//  AppUninstallerView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI

struct AppUninstallerView: View {
    @StateObject private var appService = AppEnumerationService()
    @State private var apps: [AppInfo] = []
    @State private var searchText = ""
    @State private var selectedSortOption: AppSortOption = .name
    @State private var sortAscending = true
    @State private var selectedApps = Set<AppInfo>()
    @State private var selectedAppForDetail: AppInfo?
    @State private var showUninstallConfirmation = false
    @State private var showBulkUninstallConfirmation = false
    @State private var includeAssociatedFiles = true
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var filterStatus: UsageStatus?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !appService.isScanning && apps.isEmpty {
                    emptyStateView
                } else if appService.isScanning {
                    scanningView
                } else {
                    appListView
                }
            }
            .navigationTitle("App Uninstaller")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !apps.isEmpty && !appService.isScanning {
                        // Sort menu
                        Menu {
                            ForEach(AppSortOption.allCases, id: \.self) { option in
                                Button {
                                    if selectedSortOption == option {
                                        sortAscending.toggle()
                                    } else {
                                        selectedSortOption = option
                                        sortAscending = true
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: option.icon)
                                        Text(option.rawValue)
                                        if selectedSortOption == option {
                                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                        
                        // Selection actions
                        if !selectedApps.isEmpty {
                            Button(action: { showBulkUninstallConfirmation = true }) {
                                Label("Uninstall Selected (\(selectedApps.count))", systemImage: "trash")
                            }
                        }
                    }
                    
                    // Scan button
                    Button(action: startScan) {
                        Label("Scan", systemImage: "arrow.clockwise")
                    }
                    .disabled(appService.isScanning)
                }
            }
            .searchable(text: $searchText, prompt: "Search apps")
            .sheet(item: $selectedAppForDetail) { app in
                AppDetailSheet(app: app, onUninstall: {
                    selectedAppForDetail = nil
                    startScan() // Refresh list
                })
            }
            .alert("Uninstall Application", isPresented: $showUninstallConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Uninstall", role: .destructive) {
                    if let app = selectedAppForDetail {
                        uninstallSingleApp(app)
                    }
                }
            } message: {
                if let app = selectedAppForDetail {
                    Text("Are you sure you want to uninstall \(app.name)?\(includeAssociatedFiles ? "\n\nThis will also remove \(app.associatedFiles.count) associated file(s)." : "")")
                }
            }
            .alert("Bulk Uninstall", isPresented: $showBulkUninstallConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Uninstall All", role: .destructive) {
                    bulkUninstall()
                }
            } message: {
                let totalAssociated = selectedApps.reduce(0) { $0 + $1.associatedFiles.count }
                Text("Are you sure you want to uninstall \(selectedApps.count) application(s)?\(includeAssociatedFiles ? "\n\nThis will also remove ~\(totalAssociated) associated file(s)." : "")")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 30) {
            AnimatedIconView()
                .frame(width: 120, height: 120)
            
            VStack(spacing: 12) {
                Text("Scan for Installed Apps")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Find applications you no longer need and free up space")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: startScan) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                    Text("Scan Applications")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Scanning View
    
    private var scanningView: some View {
        VStack(spacing: 30) {
            ProgressView(value: appService.progress) {
                VStack(spacing: 8) {
                    Text("Scanning Applications...")
                        .font(.headline)
                    
                    if !appService.currentApp.isEmpty {
                        Text(appService.currentApp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .progressViewStyle(.linear)
            .frame(maxWidth: 400)
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(appService.appsFound)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    Text("Apps Found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Text("\(Int(appService.progress * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .monospacedDigit()
                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - App List View
    
    private var appListView: some View {
        VStack(spacing: 0) {
            // Stats bar
            statsBar
            
            // Filter chips
            filterChipsBar
            
            Divider()
            
            // List
            List(selection: $selectedApps) {
                ForEach(filteredAndSortedApps) { app in
                    AppRowView(app: app)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedAppForDetail = app
                        }
                        .contextMenu {
                            Button {
                                selectedAppForDetail = app
                                showUninstallConfirmation = true
                            } label: {
                                Label("Uninstall", systemImage: "trash")
                            }
                            
                            Button {
                                selectedAppForDetail = app
                            } label: {
                                Label("Show Details", systemImage: "info.circle")
                            }
                            
                            Button {
                                NSWorkspace.shared.selectFile(app.bundlePath, inFileViewerRootedAtPath: "")
                            } label: {
                                Label("Show in Finder", systemImage: "folder")
                            }
                        }
                }
            }
            .listStyle(.inset)
        }
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        HStack(spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: "app.badge")
                    .foregroundColor(.purple)
                Text("\(filteredAndSortedApps.count) apps")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Divider()
                .frame(height: 20)
            
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.blue)
                Text(FileSizeFormatter.format(bytes: totalSize))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            if !selectedApps.isEmpty {
                HStack(spacing: 8) {
                    Button("Select All") {
                        selectedApps = Set(filteredAndSortedApps)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    
                    Button("Deselect All") {
                        selectedApps.removeAll()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Filter Chips
    
    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "All Apps",
                    icon: "app.badge",
                    count: apps.count,
                    isSelected: filterStatus == nil,
                    color: .gray
                ) {
                    filterStatus = nil
                }
                
                ForEach([UsageStatus.unused, .seldomUsed, .recentlyUsed, .active], id: \.self) { status in
                    let count = apps.filter { $0.usageStatus == status }.count
                    if count > 0 {
                        FilterChip(
                            title: status.rawValue,
                            icon: status.icon,
                            count: count,
                            isSelected: filterStatus == status,
                            color: statusColor(for: status)
                        ) {
                            filterStatus = status
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Computed Properties
    
    private var filteredAndSortedApps: [AppInfo] {
        var filtered = apps
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply status filter
        if let status = filterStatus {
            filtered = filtered.filter { $0.usageStatus == status }
        }
        
        // Apply sort
        filtered.sort { app1, app2 in
            let comparison: Bool
            switch selectedSortOption {
            case .name:
                comparison = app1.name.localizedCaseInsensitiveCompare(app2.name) == .orderedAscending
            case .size:
                comparison = app1.size < app2.size
            case .lastUsed:
                comparison = (app1.lastUsedDate ?? .distantPast) < (app2.lastUsedDate ?? .distantPast)
            case .totalSize:
                comparison = app1.totalSize < app2.totalSize
            }
            return sortAscending ? comparison : !comparison
        }
        
        return filtered
    }
    
    private var totalSize: Int64 {
        filteredAndSortedApps.reduce(0) { $0 + $1.totalSize }
    }
    
    // MARK: - Actions
    
    private func startScan() {
        Task {
            do {
                apps = try await appService.scanApplications()
                selectedApps.removeAll()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func uninstallSingleApp(_ app: AppInfo) {
        Task {
            do {
                try await appService.uninstallApp(app, includeAssociatedFiles: includeAssociatedFiles)
                apps.removeAll { $0.id == app.id }
                selectedApps.remove(app)
            } catch {
                errorMessage = "Failed to uninstall \(app.name): \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func bulkUninstall() {
        Task {
            do {
                let appsToUninstall = Array(selectedApps)
                try await appService.bulkUninstall(apps: appsToUninstall, includeAssociatedFiles: includeAssociatedFiles)
                apps.removeAll { selectedApps.contains($0) }
                selectedApps.removeAll()
            } catch {
                errorMessage = "Bulk uninstall failed: \(error.localizedDescription)"
                showError = true
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

// MARK: - Filter Chip Component

struct FilterChip: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("(\(count))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? color.opacity(0.2)
                    : Color(nsColor: .controlBackgroundColor)
            )
            .foregroundColor(isSelected ? color : .primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppUninstallerView()
}

