//
//  CategoryCard.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI

struct CategoryCard: View {
    let category: SmartCategory
    let index: Int
    @State private var isHovered = false
    @State private var isVisible = false
    var onTap: (() -> Void)? = nil
    
    init(category: SmartCategory, index: Int = 0, onTap: (() -> Void)? = nil) {
        self.category = category
        self.index = index
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Icon and Title
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .symbolEffect(.bounce, value: isHovered)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Potential savings badge for duplicates
                    if let savings = category.potentialSavings {
                        Text("Save \(savings.formattedFileSize)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
            }
            
            // Size
            Text(category.totalSize.formattedFileSize)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Item Count and Average
            HStack(spacing: 4) {
                Text("\(category.itemCount) items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if category.itemCount > 0 && category.averageFileSize > 0 {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("avg \(category.averageFileSize.formattedFileSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // File Type Breakdown (top 3 types)
            if !category.fileTypeBreakdown.isEmpty {
                fileTypeBreakdownView
            }
            
            // Largest File Info
            if let largest = category.largestFile {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Largest: \(largest.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Text(largest.size.formattedFileSize)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Safety Indicator
            HStack {
                Circle()
                    .fill(safetyColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: safetyColor.opacity(0.5), radius: 4)
                
                Text(safetyText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Tap hint
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1.0 : 0.5)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: shadowColor, radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            // Staggered animation - always trigger
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isVisible = true
                }
            }
        }
    }
    
    private var fileTypeBreakdownView: some View {
        HStack(spacing: 8) {
            let topTypes = category.fileTypeBreakdown
                .sorted { $0.value > $1.value }
                .prefix(3)
            
            ForEach(Array(topTypes), id: \.key) { ext, count in
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorForExtension(ext))
                        .frame(width: 6, height: 6)
                    
                    Text(ext)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("(\(count))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(colorForExtension(ext).opacity(0.15))
                )
            }
        }
    }
    
    private func colorForExtension(_ ext: String) -> Color {
        let lower = ext.lowercased()
        
        // Images
        if ["jpg", "jpeg", "png", "gif", "heic"].contains(lower) {
            return Color.blue
        }
        // Videos
        if ["mp4", "mov", "avi", "mkv"].contains(lower) {
            return Color.pink
        }
        // Audio
        if ["mp3", "wav", "m4a", "aac"].contains(lower) {
            return Color.purple
        }
        // Documents
        if ["pdf", "doc", "docx", "txt"].contains(lower) {
            return Color.orange
        }
        
        return Color.gray
    }
    
    private var iconColor: Color {
        switch category.safetyLevel {
        case .safe: return .green
        case .caution: return .orange
        case .dangerous: return .red
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
        case .safe: return "Safe to delete"
        case .caution: return "Review before deleting"
        case .dangerous: return "Use caution"
        }
    }
    
    // Dark mode aware colors
    private var cardBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    private var shadowColor: Color {
        #if os(macOS)
        return Color.black.opacity(0.1)
        #else
        return Color.black.opacity(0.1)
        #endif
    }
}

