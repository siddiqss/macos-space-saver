//
//  CategoryDetailView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI
import SwiftData
import AppKit
import OSLog

// Lightweight Logger wrapper to avoid build errors when a global Logger isn't defined.
// Uses os.Logger on supported platforms and falls back to print() otherwise.
private enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "SpaceSaver"
    private static let category = "CategoryDetailView"
    @available(macOS 11.0, *)
    private static let oslogger = os.Logger(subsystem: subsystem, category: category)

    static func info(_ message: String) {
        if #available(macOS 11.0, *) {
            oslogger.info("\(message, privacy: .public)")
        } else {
            print("ℹ️ [INFO] \(message)")
        }
    }

    static func warning(_ message: String) {
        if #available(macOS 11.0, *) {
            oslogger.warning("\(message, privacy: .public)")
        } else {
            print("⚠️ [WARN] \(message)")
        }
    }

    static func error(_ message: String) {
        if #available(macOS 11.0, *) {
            oslogger.error("\(message, privacy: .public)")
        } else {
            print("🛑 [ERROR] \(message)")
        }
    }
}

struct CategoryDetailView: View {
    let category: SmartCategory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var sortOption: FileSortOption = .sizeDescending
    @State private var selectedFiles: Set<UUID> = []
    @State private var showQuickLook = false
    @State private var quickLookURL: URL?
    @State private var cachedFilteredFiles: [FileNode] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isLoading = true
    @State private var loadedItems: [FileNode] = []
    @State private var showBatchDeleteConfirmation = false
    @State private var isDeletingBatch = false
    @State private var deletionErrorMessage: String?
    @State private var showDeletionError = false
    
    @StateObject private var deletionService = DeletionService.shared
    
    enum FileSortOption: String, CaseIterable {
        case sizeDescending = "Size (Largest)"
        case sizeAscending = "Size (Smallest)"
        case nameAscending = "Name (A-Z)"
        case nameDescending = "Name (Z-A)"
        case dateModifiedDescending = "Date Modified (Newest)"
        case dateModifiedAscending = "Date Modified (Oldest)"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Stats
                headerStatsView
                
                // Toolbar
                toolbarView
                
                // File List
                fileListView
            }
            .navigationTitle(category.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        // Delete Selected Button
                        if !selectedFiles.isEmpty {
                            Button(action: { showBatchDeleteConfirmation = true }) {
                                Label("Delete Selected", systemImage: "trash")
                            }
                            .disabled(isDeletingBatch)
                        }
                        
                        // Sort Menu
                        Menu {
                            ForEach(FileSortOption.allCases, id: \.self) { option in
                                Button(option.rawValue) {
                                    sortOption = option
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search files...")
            .onChange(of: searchText) { oldValue, newValue in
                // Cancel previous search task
                searchTask?.cancel()
                
                // If search is cleared, update immediately
                if newValue.isEmpty {
                    Task {
                        await updateCachedFilesAsync()
                    }
                } else {
                    // Debounce search updates for performance
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
                        if !Task.isCancelled {
                            await updateCachedFilesAsync()
                        }
                    }
                }
            }
            .onChange(of: sortOption) { oldValue, newValue in
                Task {
                    await updateCachedFilesAsync()
                }
            }
            .task {
                // Always use category items if they exist (fresh scan)
                // Otherwise load from cache (app relaunch)
                print("📋 Category '\(category.title)' has \(category.items.count) items initially")
                
                if !category.items.isEmpty {
                    loadedItems = category.items
                    print("✅ Using \(loadedItems.count) items from category")
                } else {
                    await loadItemsFromCache()
                    print("💾 Loaded \(loadedItems.count) items from cache")
                }
                await updateCachedFilesAsync()
            }
            .onKeyPress(.space) {
                // Quick Look for selected files
                if !selectedFiles.isEmpty {
                    let selectedFileNodes = cachedFilteredFiles.filter { selectedFiles.contains($0.id) }
                    if let firstFile = selectedFileNodes.first {
                        Task { @MainActor in
                            if selectedFileNodes.count == 1 {
                                QuickLookHelper.shared.preview(url: firstFile.path)
                            } else {
                                let urls = selectedFileNodes.map { $0.path }
                                QuickLookHelper.shared.preview(urls: urls)
                            }
                        }
                    }
                }
                return .handled
            }
        }
    }
    
    private var headerStatsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 30) {
                // Total Size
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(category.totalSize.formattedFileSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                // File Count
                VStack(alignment: .leading, spacing: 4) {
                    Text("Files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(isLoading ? "..." : "\(cachedFilteredFiles.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .monospacedDigit()
                }
                
                // Safety Indicator
                SafetyLevelIndicator(safetyLevel: category.safetyLevel)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var toolbarView: some View {
        HStack {
            if !selectedFiles.isEmpty {
                HStack(spacing: 16) {
                    Text("\(selectedFiles.count) selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if isDeletingBatch {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Delete Selected") {
                        showBatchDeleteConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isDeletingBatch)
                    
                    Button("Deselect All") {
                        selectedFiles.removeAll()
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Text("Select files to manage")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Select All") {
                    selectedFiles = Set(cachedFilteredFiles.map { $0.id })
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private var fileListView: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading files...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cachedFilteredFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No files found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Debug: isLoading=\(isLoading.description), count=\(cachedFilteredFiles.count)")
                        .font(.caption)
                        .foregroundColor(.red)
                    if !searchText.isEmpty {
                        Text("Try adjusting your search")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(cachedFilteredFiles) { file in
                            FileRowView(
                                file: file,
                                isSelected: selectedFiles.contains(file.id),
                                onQuickLook: {
                                    QuickLookHelper.shared.preview(url: file.path)
                                },
                                onDelete: {
                                    // Remove from cache and update UI
                                    removeFile(file)
                                }
                            )
                            .onTapGesture {
                                toggleSelection(file)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showBatchDeleteConfirmation) {
            batchDeletionConfirmationSheet
        }
        .alert("Deletion Error", isPresented: $showDeletionError) {
            Button("OK", role: .cancel) {
                deletionErrorMessage = nil
            }
        } message: {
            if let message = deletionErrorMessage {
                Text(message)
            }
        }
    }
    
    private func updateCachedFilesAsync() async {
        print("🔄 updateCachedFilesAsync called with \(loadedItems.count) loaded items")
        
        // Show loading state immediately
        await MainActor.run {
            isLoading = true
        }
        
        // Yield to allow UI to update
        await Task.yield()
        
        let search = searchText
        let sort = sortOption
        var files = loadedItems  // Use loaded items instead of category.items
        
        print("🔍 Filtering \(files.count) items with search: '\(search)'")
        
        // Apply search filter
        if !search.isEmpty {
            let lowercasedSearch = search.lowercased()
            files = files.filter { file in
                file.name.lowercased().contains(lowercasedSearch) ||
                file.path.path.lowercased().contains(lowercasedSearch)
            }
        }
        
        // Apply sorting
        switch sort {
        case .sizeDescending:
            files.sort { $0.size > $1.size }
        case .sizeAscending:
            files.sort { $0.size < $1.size }
        case .nameAscending:
            files.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .nameDescending:
            files.sort { $0.name.localizedCompare($1.name) == .orderedDescending }
        case .dateModifiedDescending:
            files.sort { $0.dateModified > $1.dateModified }
        case .dateModifiedAscending:
            files.sort { $0.dateModified < $1.dateModified }
        }
        
        print("✅ Filtered to \(files.count) files")
        
        // Update UI on main thread
        await MainActor.run {
            cachedFilteredFiles = files
            isLoading = false
            print("🎯 UI updated with \(cachedFilteredFiles.count) files, isLoading=\(isLoading)")
            if let first = cachedFilteredFiles.first {
                print("   First file: \(first.name) at \(first.path.path)")
            }
        }
    }
    
    private func loadItemsFromCache() async {
        // SwiftData operations must be on MainActor, but we can yield to keep UI responsive
        await MainActor.run {
            let cacheService = ScanResultCacheService(modelContext: modelContext)
            let items = cacheService.loadCategoryItems(categoryId: category.id)
            loadedItems = items
            print("💾 Loaded \(items.count) items from cache, loadedItems now has \(loadedItems.count)")
        }
    }
    
    // MARK: - Batch Deletion
    
    private var batchDeletionConfirmationSheet: some View {
        let selectedFileNodes = cachedFilteredFiles.filter { selectedFiles.contains($0.id) }
        let preview = deletionService.previewDeletion(items: selectedFileNodes)
        
        return DeletionConfirmationView(
            preview: preview,
            onConfirm: {
                showBatchDeleteConfirmation = false
                performBatchDeletion(selectedFileNodes)
            },
            onCancel: {
                showBatchDeleteConfirmation = false
            }
        )
    }
    
    private func performBatchDeletion(_ files: [FileNode]) {
        isDeletingBatch = true
        
        Task {
            do {
                let result = try await deletionService.deleteItems(files)
                
                await MainActor.run {
                    // Handle result
                    switch result {
                    case .success(let items):
                        Logger.info("Successfully deleted \(items.count) items")
                        removeFiles(files)
                    case .partialSuccess(let succeeded, let failed):
                        Logger.warning("Partially deleted: \(succeeded.count) succeeded, \(failed.count) failed")
                        let succeededPaths = Set(succeeded.map { $0.originalPath })
                        let succeededFiles = files.filter { succeededPaths.contains($0.path) }
                        removeFiles(succeededFiles)
                        
                        // Show error message for failed items
                        if !failed.isEmpty {
                            let errorMessages = failed.map { url, error in
                                "\(url.lastPathComponent): \(error.localizedDescription)"
                            }
                            deletionErrorMessage = "\(failed.count) file(s) could not be deleted:\n\n" + errorMessages.joined(separator: "\n")
                            showDeletionError = true
                        }
                    case .failure(let errors):
                        Logger.error("Failed to delete items: \(errors.count) errors")
                        let errorMessages = errors.map { url, error in
                            "\(url.lastPathComponent): \(error.localizedDescription)"
                        }
                        deletionErrorMessage = "Failed to delete \(errors.count) file(s):\n\n" + errorMessages.joined(separator: "\n")
                        showDeletionError = true
                    case .cancelled:
                        Logger.info("Deletion cancelled")
                    }
                    
                    isDeletingBatch = false
                    selectedFiles.removeAll()
                }
            } catch {
                Logger.error("Batch deletion error: \(error)")
                await MainActor.run {
                    deletionErrorMessage = "An error occurred during deletion: \(error.localizedDescription)"
                    showDeletionError = true
                    isDeletingBatch = false
                }
            }
        }
    }
    
    // MARK: - File Management
    
    private func removeFile(_ file: FileNode) {
        loadedItems.removeAll { $0.id == file.id }
        cachedFilteredFiles.removeAll { $0.id == file.id }
        selectedFiles.remove(file.id)
    }
    
    private func removeFiles(_ files: [FileNode]) {
        let fileIds = Set(files.map { $0.id })
        loadedItems.removeAll { fileIds.contains($0.id) }
        cachedFilteredFiles.removeAll { fileIds.contains($0.id) }
        selectedFiles.subtract(fileIds)
    }
    
    private func toggleSelection(_ file: FileNode) {
        if selectedFiles.contains(file.id) {
            selectedFiles.remove(file.id)
        } else {
            selectedFiles.insert(file.id)
        }
    }
    
    private var safetyColor: Color {
        switch category.safetyLevel {
        case .safe: return .green
        case .caution: return .orange
        case .dangerous: return .red
        }
    }
    
    private var safetyText: String {
        switch category.safetyLevel {
        case .safe: return "Safe"
        case .caution: return "Caution"
        case .dangerous: return "Dangerous"
        }
    }
}

