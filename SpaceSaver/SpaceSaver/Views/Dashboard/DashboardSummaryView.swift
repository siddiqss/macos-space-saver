//
//  DashboardSummaryView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI

struct DashboardSummaryView: View {
    let categories: [SmartCategory]
    let totalScannedSize: Int64
    @State private var isVisible = false
    
    private var totalFiles: Int {
        categories.reduce(0) { $0 + $1.itemCount }
    }
    
    private var topCategories: [SmartCategory] {
        Array(categories.prefix(3))
    }
    
    private var estimatedCleanableSpace: Int64 {
        categories
            .filter { $0.safetyLevel == .safe || $0.safetyLevel == .caution }
            .reduce(0) { $0 + ($1.potentialSavings ?? $1.totalSize) }
    }
    
    private var availableDiskSpace: Int64 {
        let url = URL(fileURLWithPath: "/")
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return Int64(values.volumeAvailableCapacity ?? 0)
        } catch {
            return 0
        }
    }
    
    private var totalDiskSpace: Int64 {
        let url = URL(fileURLWithPath: "/")
        do {
            let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey])
            return Int64(values.volumeTotalCapacity ?? 0)
        } catch {
            return 0
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Disk Analysis Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("\(totalFiles) files scanned across \(categories.count) categories")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Quick Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                DashboardStatCard(
                    title: "Scanned",
                    value: totalScannedSize.formattedFileSize,
                    icon: "doc.text.magnifyingglass",
                    color: .blue
                )
                
                DashboardStatCard(
                    title: "Available",
                    value: availableDiskSpace.formattedFileSize,
                    icon: "internaldrive",
                    color: .green
                )
                
                DashboardStatCard(
                    title: "Cleanable",
                    value: estimatedCleanableSpace.formattedFileSize,
                    icon: "trash",
                    color: .orange
                )
            }
            
            // Category Distribution Bar
            if !categories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Space Distribution")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    CategoryDistributionBar(categories: categories, totalSize: totalScannedSize)
                }
            }
            
            // Top Space Consumers
            if !topCategories.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Space Consumers")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(Array(topCategories.enumerated()), id: \.element.id) { index, category in
                            TopCategoryRow(
                                category: category,
                                rank: index + 1,
                                totalSize: totalScannedSize
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Stat Card

struct DashboardStatCard: View {
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
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Category Distribution Bar

struct CategoryDistributionBar: View {
    let categories: [SmartCategory]
    let totalSize: Int64
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(categories.prefix(8)) { category in
                    let percentage = totalSize > 0 ? Double(category.totalSize) / Double(totalSize) : 0
                    let width = geometry.size.width * CGFloat(percentage)
                    
                    if width > 1 {
                        Rectangle()
                            .fill(colorForCategory(category.type))
                            .frame(width: width)
                            .help("\(category.title): \(category.totalSize.formattedFileSize) (\(Int(percentage * 100))%)")
                    }
                }
            }
        }
        .frame(height: 24)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func colorForCategory(_ type: CategoryType) -> Color {
        switch type {
        case .images: return Color(red: 0.2, green: 0.7, blue: 0.9)
        case .videos: return Color(red: 0.9, green: 0.3, blue: 0.5)
        case .audio: return Color(red: 0.6, green: 0.4, blue: 0.9)
        case .documents: return Color(red: 0.95, green: 0.6, blue: 0.2)
        case .archives: return Color(red: 0.7, green: 0.7, blue: 0.3)
        case .system: return Color.gray
        case .caches: return Color.green
        case .logs: return Color.yellow
        case .duplicates: return Color.red
        default: return Color.gray
        }
    }
}

// MARK: - Top Category Row

struct TopCategoryRow: View {
    let category: SmartCategory
    let rank: Int
    let totalSize: Int64
    
    private var percentage: Double {
        totalSize > 0 ? Double(category.totalSize) / Double(totalSize) : 0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(rankColor)
                )
            
            // Category icon
            Image(systemName: category.icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            // Category name
            Text(category.title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Size and percentage
            VStack(alignment: .trailing, spacing: 2) {
                Text(category.totalSize.formattedFileSize)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(Int(percentage * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.05))
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)  // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)  // Silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)  // Bronze
        default: return Color.gray
        }
    }
    
    private var iconColor: Color {
        switch category.safetyLevel {
        case .safe: return .green
        case .caution: return .orange
        case .dangerous: return .red
        }
    }
}

