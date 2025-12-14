//
//  DiskMapSegment.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation
import SwiftUI

/// Represents a segment in the disk map visualization
struct DiskMapSegment: Identifiable, Hashable {
    let id: UUID
    let name: String
    let path: String
    let size: Int64
    let percentage: Double // Percentage of parent
    let depth: Int
    let children: [DiskMapSegment]
    let category: CategoryType?
    let color: Color
    let isDirectory: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        size: Int64,
        percentage: Double,
        depth: Int,
        children: [DiskMapSegment] = [],
        category: CategoryType? = nil,
        color: Color? = nil,
        isDirectory: Bool = true
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.percentage = percentage
        self.depth = depth
        self.children = children
        self.category = category
        self.isDirectory = isDirectory
        
        // Auto-assign color based on category or depth
        if let color = color {
            self.color = color
        } else if let category = category {
            self.color = Self.colorForCategory(category)
        } else {
            self.color = Self.colorForDepth(depth)
        }
    }
    
    /// Create segments from FileNode hierarchy
    static func fromFileNode(_ node: FileNode, totalSize: Int64, depth: Int = 0) -> DiskMapSegment {
        let percentage = totalSize > 0 ? Double(node.size) / Double(totalSize) * 100 : 0
        
        let childSegments = node.children?.compactMap { child -> DiskMapSegment? in
            guard child.size > 0 else { return nil }
            return fromFileNode(child, totalSize: node.size, depth: depth + 1)
        }.sorted { $0.size > $1.size } ?? []
        
        return DiskMapSegment(
            name: node.name,
            path: node.path.path,
            size: node.size,
            percentage: percentage,
            depth: depth,
            children: childSegments,
            category: node.category,
            isDirectory: node.isDirectory
        )
    }
    
    /// Create segments from SmartCategory
    static func fromCategory(_ category: SmartCategory, totalSize: Int64) -> DiskMapSegment {
        let percentage = totalSize > 0 ? Double(category.totalSize) / Double(totalSize) * 100 : 0
        
        // Group files by parent directory for better visualization
        let groupedFiles = Dictionary(grouping: category.items) { file in
            file.path.deletingLastPathComponent().path
        }
        
        let childSegments = groupedFiles.map { (dirPath, files) -> DiskMapSegment in
            let dirSize = files.reduce(0) { $0 + $1.size }
            let dirPercentage = category.totalSize > 0 ? Double(dirSize) / Double(category.totalSize) * 100 : 0
            let dirName = URL(fileURLWithPath: dirPath).lastPathComponent
            
            let fileSegments = files.map { file in
                let filePercentage = dirSize > 0 ? Double(file.size) / Double(dirSize) * 100 : 0
                return DiskMapSegment(
                    name: file.name,
                    path: file.path.path,
                    size: file.size,
                    percentage: filePercentage,
                    depth: 2,
                    children: [],
                    category: category.type,
                    isDirectory: file.isDirectory
                )
            }.sorted { $0.size > $1.size }
            
            return DiskMapSegment(
                name: dirName,
                path: dirPath,
                size: dirSize,
                percentage: dirPercentage,
                depth: 1,
                children: fileSegments,
                category: category.type,
                isDirectory: true
            )
        }.sorted { $0.size > $1.size }
        
        return DiskMapSegment(
            name: category.title,
            path: category.type.rawValue,
            size: category.totalSize,
            percentage: percentage,
            depth: 0,
            children: childSegments,
            category: category.type,
            isDirectory: true
        )
    }
    
    /// Get color for category
    static func colorForCategory(_ category: CategoryType) -> Color {
        switch category {
        // Media Categories
        case .images:
            return Color(red: 0.2, green: 0.7, blue: 0.9) // Light blue
        case .videos:
            return Color(red: 0.9, green: 0.3, blue: 0.5) // Pink/Red
        case .audio:
            return Color(red: 0.6, green: 0.4, blue: 0.9) // Purple
        
        // Document Categories
        case .documents:
            return Color(red: 0.95, green: 0.6, blue: 0.2) // Orange
        case .archives:
            return Color(red: 0.7, green: 0.7, blue: 0.3) // Yellow
        
        // Application Category
        case .applications:
            return Color(red: 0.5, green: 0.5, blue: 0.8) // Blue-purple
        
        // System & Cleanup Categories
        case .system:
            return Color(red: 0.6, green: 0.6, blue: 0.6) // Gray
        case .caches:
            return Color(red: 0.3, green: 0.8, blue: 0.5) // Green
        case .logs:
            return Color(red: 0.9, green: 0.7, blue: 0.3) // Gold
        case .temporaryFiles:
            return Color(red: 0.85, green: 0.45, blue: 0.25) // Brown
        case .backups:
            return Color(red: 0.4, green: 0.6, blue: 0.9) // Blue
        case .duplicates:
            return Color(red: 0.95, green: 0.3, blue: 0.3) // Red
        
        // Special Location Categories
        case .oldDownloads:
            return Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
        case .mailAttachments:
            return Color(red: 0.5, green: 0.7, blue: 0.95) // Light blue
        case .screenshots:
            return Color(red: 0.7, green: 0.5, blue: 0.9) // Lavender
        
        // Developer Category
        case .developer:
            return Color(red: 0.4, green: 0.8, blue: 0.4) // Green
        
        // Legacy/Fallback Categories
        case .largeFiles:
            return Color(red: 0.2, green: 0.6, blue: 0.95) // Blue
        case .unusedApps:
            return Color(red: 0.8, green: 0.4, blue: 0.95) // Purple
        }
    }
    
    /// Get color for depth (fallback)
    static func colorForDepth(_ depth: Int) -> Color {
        let colors: [Color] = [
            Color(red: 0.3, green: 0.6, blue: 0.95),  // Blue
            Color(red: 0.4, green: 0.8, blue: 0.6),   // Teal
            Color(red: 1.0, green: 0.7, blue: 0.3),   // Yellow
            Color(red: 0.95, green: 0.5, blue: 0.3),  // Orange
            Color(red: 0.8, green: 0.4, blue: 0.95),  // Purple
        ]
        return colors[depth % colors.count]
    }
    
    /// Get all segments flattened (for search/filtering)
    func flattenedSegments() -> [DiskMapSegment] {
        var result = [self]
        for child in children {
            result.append(contentsOf: child.flattenedSegments())
        }
        return result
    }
    
    /// Get top N largest segments at any depth
    func topSegments(count: Int) -> [DiskMapSegment] {
        return flattenedSegments()
            .sorted { $0.size > $1.size }
            .prefix(count)
            .map { $0 }
    }
}

