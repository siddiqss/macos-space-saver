//
//  DashboardView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var scanner = FileScannerService()
    private let categoryManager = CategoryManager()
    @State private var categories: [SmartCategory] = []
    @State private var hasScanned = false
    @State private var showScanProgress = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var lastScanDate: Date?
    @State private var isScanningBannerVisible = false
    @State private var selectedCategory: SmartCategory?
    @State private var showCategoryDetail = false
    @State private var isLoadingCache = false
    @State private var showDeletionHistory = false
    @State private var totalScannedSize: Int64 = 0
    
    // Filtering and Sorting
    @State private var searchText: String = ""
    @State private var selectedSafetyFilter: SafetyLevel?
    @State private var sortOption: SortOption = .sizeDescending
    @State private var showEmptyCategories: Bool = false
    
    enum SortOption: String, CaseIterable {
        case sizeDescending = "Size (Largest)"
        case sizeAscending = "Size (Smallest)"
        case nameAscending = "Name (A-Z)"
        case nameDescending = "Name (Z-A)"
        case itemCount = "Item Count"
    }
    
    private var filteredAndSortedCategories: [SmartCategory] {
        var filtered = categories
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { category in
                category.title.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply safety level filter
        if let safetyFilter = selectedSafetyFilter {
            filtered = filtered.filter { $0.safetyLevel == safetyFilter }
        }
        
        // Filter empty categories if needed
        if !showEmptyCategories {
            filtered = filtered.filter { $0.itemCount > 0 }
        }
        
        // Apply sorting
        switch sortOption {
        case .sizeDescending:
            filtered.sort { $0.totalSize > $1.totalSize }
        case .sizeAscending:
            filtered.sort { $0.totalSize < $1.totalSize }
        case .nameAscending:
            filtered.sort { $0.title < $1.title }
        case .nameDescending:
            filtered.sort { $0.title > $1.title }
        case .itemCount:
            filtered.sort { $0.itemCount > $1.itemCount }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
            VStack(spacing: 0) {
                    // Scanning Banner
                    if isScanningBannerVisible && !showScanProgress {
                        scanningBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                if !hasScanned {
                    // Welcome/Empty State
                    emptyStateView
                } else {
                    // Dashboard Grid
                    categoryGridView
                    }
                }
            }
            .navigationTitle("SpaceSaver")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        // Deletion History Button
                        Button(action: { showDeletionHistory = true }) {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }
                        .help("View and restore deleted files")
                        
                        // Scan Button
                    Button(action: startScan) {
                        Label("Scan", systemImage: "magnifyingglass")
                    }
                    .disabled(scanner.isScanning)
                    }
                }
            }
            .sheet(isPresented: $showScanProgress) {
                ScanProgressView(scanner: scanner)
            }
            .sheet(item: $selectedCategory) { category in
                CategoryDetailView(category: category)
            }
            .sheet(isPresented: $showDeletionHistory) {
                DeletionHistoryView()
            }
            .alert("Scan Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .onAppear {
                loadCachedResults()
            }
            .onChange(of: scanner.isScanning) { oldValue, newValue in
                withAnimation(.spring(response: 0.3)) {
                    isScanningBannerVisible = newValue
                }
            }
        }
        .preferredColorScheme(nil) // Respect system appearance
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 30) {
            // Animated Icon
            AnimatedIconView()
                .frame(width: 120, height: 120)
            
            VStack(spacing: 12) {
            Text("Ready to scan your Mac?")
                .font(.title2)
                .fontWeight(.semibold)
                    .foregroundColor(.primary)
            
            Text("Click the Scan button to find files taking up space")
                .font(.body)
                .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: startScan) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                    Text("Scan My Mac")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .scaleEffect(scanner.isScanning ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: scanner.isScanning)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    private var scanningBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Scanning in progress...")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if scanner.totalFilesToScan > 0 {
                    Text("\(scanner.filesScanned) of \(scanner.totalFilesToScan) files")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            Spacer()
            
            Text("\(Int(scanner.progress * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, y: 2)
    }
    
    private var categoryGridView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Dashboard Summary
                if !categories.isEmpty {
                    DashboardSummaryView(
                        categories: categories,
                        totalScannedSize: totalScannedSize
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Filters and Search Bar
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Search field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search categories...", text: $searchText)
                                .textFieldStyle(.plain)
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        
                        // Sort picker
                        Picker("Sort", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }
                    
                    // Safety level filters
                    HStack(spacing: 8) {
                        Text("Filter:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        FilterButton(
                            title: "Safe",
                            color: .green,
                            isSelected: selectedSafetyFilter == .safe,
                            action: {
                                selectedSafetyFilter = selectedSafetyFilter == .safe ? nil : .safe
                            }
                        )
                        
                        FilterButton(
                            title: "Caution",
                            color: .orange,
                            isSelected: selectedSafetyFilter == .caution,
                            action: {
                                selectedSafetyFilter = selectedSafetyFilter == .caution ? nil : .caution
                            }
                        )
                        
                        FilterButton(
                            title: "Dangerous",
                            color: .red,
                            isSelected: selectedSafetyFilter == .dangerous,
                            action: {
                                selectedSafetyFilter = selectedSafetyFilter == .dangerous ? nil : .dangerous
                            }
                        )
                        
                        Spacer()
                        
                        // Rescan button
                        Button(action: startScan) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Rescan")
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(scanner.isScanning)
                    }
                }
                .padding(.horizontal, 20)
                
                // Results count
                if hasScanned {
                    HStack {
                        Text("\(filteredAndSortedCategories.count) of \(categories.count) categories")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let lastScan = lastScanDate {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Last scanned: \(lastScan.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
                
                // Category Grid
                if filteredAndSortedCategories.isEmpty && hasScanned {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No categories match your filters")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Button("Clear Filters") {
                            searchText = ""
                            selectedSafetyFilter = nil
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20)
                    ], spacing: 20) {
                        ForEach(Array(filteredAndSortedCategories.enumerated()), id: \.element.id) { index, category in
                            CategoryCard(
                                category: category,
                                index: index,
                                onTap: {
                                    selectedCategory = category
                                    showCategoryDetail = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    private func loadCachedResults() {
        // Load cache asynchronously without blocking UI
        Task { @MainActor in
            isLoadingCache = true
            
            // Create cache service and fetch results
            let cacheService = ScanResultCacheService(modelContext: modelContext)
            let cachedResult = cacheService.getLatestScanResult()
            
            if let cachedResult = cachedResult {
                // Load categories from cached result
                categories = cachedResult.categories
                hasScanned = !categories.isEmpty
                lastScanDate = cachedResult.date
                totalScannedSize = cachedResult.totalScannedSize
            }
            isLoadingCache = false
        }
    }
    
    private func startScan() {
        errorMessage = nil
        
        // Reset scanner state first
        scanner.progress = 0.0
        scanner.filesScanned = 0
        scanner.bytesScanned = 0
        scanner.totalFilesToScan = 0
        scanner.currentPath = ""
        
        // Now show the progress sheet
        showScanProgress = true
        
        Task {
            do {
                let rootURL = URL(fileURLWithPath: "/")
                
                // Scan files (already async and yields for UI)
                let files = try await scanner.scan(directory: rootURL, mode: .entireDisk)
                
                // Calculate total scanned size
                let totalSize = files.reduce(0) { $0 + $1.size }
                
                // Categorize files (now async with duplicate detection)
                let categorized = await categoryManager.categorize(files: files)
                
                // Save to cache in background
                Task.detached(priority: .utility) {
                    let categoriesCopy = categorized // Copy to avoid main actor isolation
                    let currentDate = await MainActor.run { Date() }
                    let scanResult = ScanResult(
                        date: currentDate,
                        categories: categoriesCopy,
                        totalScannedSize: totalSize,
                        scanDuration: 0
                    )
                    
                    await MainActor.run {
                        let cacheService = ScanResultCacheService(modelContext: modelContext)
                        cacheService.saveScanResult(scanResult, mode: .entireDisk, scannedPath: "/")
                    }
                }
                
                // Update UI immediately without waiting for cache save
                await MainActor.run {
                    // Clear first to trigger animations
                    categories = []
                    totalScannedSize = totalSize
                    
                    // Small delay to ensure animations trigger
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        print("🎨 Updating dashboard with \(categorized.count) categories")
                        for cat in categorized {
                            print("  📦 \(cat.title): \(cat.itemCount) items, \(cat.items.count) in memory")
                        }
                        categories = categorized
                        hasScanned = true
                        lastScanDate = Date()
                        showScanProgress = false
                    }
                }
            } catch let error as AppError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    if let suggestion = error.recoverySuggestion {
                        errorMessage = (errorMessage ?? "") + "\n\n\(suggestion)"
                    }
                    showError = true
                    showScanProgress = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    showError = true
                    showScanProgress = false
                }
            }
        }
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? color.opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? color : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

