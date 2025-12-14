//
//  DiskMapView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI
import SwiftData

enum VisualizationType: String, CaseIterable {
    case treemap = "TreeMap"
    case sunburst = "Sunburst"
    
    var icon: String {
        switch self {
        case .treemap: return "square.grid.3x3.fill"
        case .sunburst: return "circle.hexagonpath.fill"
        }
    }
}

struct DiskMapView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var scanner = FileScannerService()
    private let categoryManager = CategoryManager()
    
    @State private var categories: [SmartCategory] = []
    @State private var rootSegments: [DiskMapSegment] = []
    @State private var currentSegments: [DiskMapSegment] = []
    @State private var navigationStack: [DiskMapSegment] = []
    @State private var selectedSegment: DiskMapSegment?
    @State private var visualizationType: VisualizationType = .treemap
    
    @State private var hasData = false
    @State private var isLoading = false
    @State private var showScanProgress = false
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !hasData {
                    emptyStateView
                } else {
                    // Controls bar
                    controlsBar
                    
                    // Breadcrumb navigation
                    if !navigationStack.isEmpty {
                        breadcrumbBar
                    }
                    
                    // Main visualization
                    visualizationView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Bottom info bar
                    infoBar
                }
            }
            .navigationTitle("Disk Map")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: startScan) {
                        Label("Scan", systemImage: "magnifyingglass")
                    }
                    .disabled(scanner.isScanning || isLoading)
                }
            }
            .sheet(isPresented: $showScanProgress) {
                ScanProgressView(scanner: scanner)
            }
            .sheet(item: $selectedSegment) { segment in
                SegmentDetailSheet(segment: segment)
            }
            .alert("Scan Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .onAppear {
                loadCachedData()
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 30) {
            AnimatedIconView()
                .frame(width: 120, height: 120)
            
            VStack(spacing: 12) {
                Text("Visualize Your Disk Space")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Scan your Mac to see an interactive visual map of what's taking up space")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Controls Bar
    private var controlsBar: some View {
        HStack(spacing: 16) {
            // Visualization type picker
            Picker("Visualization", selection: $visualizationType) {
                ForEach(VisualizationType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.icon)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
            
            Spacer()
            
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                TextField("Search files or folders...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .frame(width: 280)
            
            // Back to root button
            if !navigationStack.isEmpty {
                Button(action: navigateToRoot) {
                    Label("Back to Root", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }
    
    // MARK: - Breadcrumb Bar
    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Root
                Button(action: navigateToRoot) {
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 11))
                        Text("Root")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                ForEach(Array(navigationStack.enumerated()), id: \.element.id) { index, segment in
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Button(action: { navigateToSegment(at: index) }) {
                            Text(segment.name)
                                .font(.system(size: 12))
                                .foregroundColor(index == navigationStack.count - 1 ? .primary : .blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }
    
    // MARK: - Visualization View
    private var visualizationView: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Processing data...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else if filteredSegments.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            } else {
                switch visualizationType {
                case .treemap:
                    TreeMapView(
                        segments: filteredSegments,
                        onSegmentTap: handleSegmentTap
                    )
                case .sunburst:
                    SunburstView(
                        segments: filteredSegments,
                        onSegmentTap: handleSegmentTap
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: visualizationType)
    }
    
    // MARK: - Info Bar
    private var infoBar: some View {
        HStack(spacing: 20) {
            // Total items
            Label("\(currentSegments.count) items", systemImage: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            // Total size
            let totalSize = currentSegments.reduce(0) { $0 + $1.size }
            Label(FileSizeFormatter.format(bytes: totalSize), systemImage: "internaldrive.fill")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Legend
            HStack(spacing: 16) {
                ForEach(CategoryType.allCases, id: \.self) { category in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(DiskMapSegment.colorForCategory(category))
                            .frame(width: 10, height: 10)
                        Text(category.rawValue)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Divider(),
            alignment: .top
        )
    }
    
    // MARK: - Computed Properties
    private var filteredSegments: [DiskMapSegment] {
        guard !searchText.isEmpty else { return currentSegments }
        
        return currentSegments.filter { segment in
            segment.name.localizedCaseInsensitiveContains(searchText) ||
            segment.path.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Actions
    private func loadCachedData() {
        Task { @MainActor in
            isLoading = true
            
            let cacheService = ScanResultCacheService(modelContext: modelContext)
            let cachedResult = cacheService.getLatestScanResult()
            
            if let cachedResult = cachedResult, !cachedResult.categories.isEmpty {
                categories = cachedResult.categories
                buildSegments()
            }
            
            isLoading = false
        }
    }
    
    private func startScan() {
        errorMessage = nil
        scanner.progress = 0.0
        scanner.filesScanned = 0
        scanner.bytesScanned = 0
        scanner.totalFilesToScan = 0
        scanner.currentPath = ""
        
        showScanProgress = true
        
        Task {
            do {
                let rootURL = URL(fileURLWithPath: "/")
                let files = try await scanner.scan(directory: rootURL, mode: .entireDisk)
                let categorized = await categoryManager.categorize(files: files)
                
                // Save to cache
                Task.detached(priority: .utility) {
                    let totalSize = files.reduce(0) { $0 + $1.size }
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
                
                await MainActor.run {
                    categories = categorized
                    buildSegments()
                    showScanProgress = false
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
    
    private func buildSegments() {
        isLoading = true
        
        Task { @MainActor in
            let totalSize = categories.reduce(0) { $0 + $1.totalSize }
            let segments = categories.map { category in
                DiskMapSegment.fromCategory(category, totalSize: totalSize)
            }.sorted { $0.size > $1.size }
            
            rootSegments = segments
            currentSegments = segments
            navigationStack = []
            hasData = !segments.isEmpty
            isLoading = false
        }
    }
    
    private func handleSegmentTap(_ segment: DiskMapSegment) {
        // If segment has children, navigate into it
        if !segment.children.isEmpty {
            withAnimation(.easeInOut(duration: 0.3)) {
                navigationStack.append(segment)
                currentSegments = segment.children
            }
        } else {
            // Show detail sheet for leaf segments
            selectedSegment = segment
        }
    }
    
    private func navigateToRoot() {
        withAnimation(.easeInOut(duration: 0.3)) {
            navigationStack = []
            currentSegments = rootSegments
        }
    }
    
    private func navigateToSegment(at index: Int) {
        guard index < navigationStack.count else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            navigationStack = Array(navigationStack.prefix(index + 1))
            if let lastSegment = navigationStack.last {
                currentSegments = lastSegment.children
            }
        }
    }
}

// MARK: - Segment Detail Sheet
private struct SegmentDetailSheet: View {
    let segment: DiskMapSegment
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with icon and name
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(segment.color.opacity(0.2))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: segment.isDirectory ? "folder.fill" : "doc.fill")
                                .font(.system(size: 28))
                                .foregroundColor(segment.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(segment.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            if let category = segment.category {
                                Text(category.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRow(
                            icon: "internaldrive.fill",
                            label: "Size",
                            value: FileSizeFormatter.format(bytes: segment.size)
                        )
                        
                        DetailRow(
                            icon: "chart.pie.fill",
                            label: "Percentage",
                            value: String(format: "%.2f%%", segment.percentage)
                        )
                        
                        DetailRow(
                            icon: "folder.fill",
                            label: "Path",
                            value: segment.path
                        )
                        
                        if !segment.children.isEmpty {
                            DetailRow(
                                icon: "list.bullet",
                                label: "Items",
                                value: "\(segment.children.count)"
                            )
                        }
                    }
                    
                    // Actions
                    if !segment.children.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top Items")
                                .font(.headline)
                            
                            ForEach(segment.children.prefix(5)) { child in
                                HStack {
                                    Image(systemName: child.isDirectory ? "folder.fill" : "doc.fill")
                                        .foregroundColor(child.color)
                                        .frame(width: 20)
                                    
                                    Text(child.name)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text(FileSizeFormatter.format(bytes: child.size))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
    }
}

#Preview {
    DiskMapView()
        .frame(width: 1000, height: 700)
}

