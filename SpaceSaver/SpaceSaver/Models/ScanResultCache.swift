//
//  ScanResultCache.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation
import SwiftData

/// SwiftData model for caching scan results
@Model
final class CachedScanResult {
    @Attribute(.unique) var id: UUID
    var date: Date
    var totalScannedSize: Int64
    var scanDuration: TimeInterval
    var scanMode: String // "entireDisk" or "specificFolder"
    var scannedPath: String
    
    @Relationship(deleteRule: .cascade) var categories: [CachedCategory]?
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        totalScannedSize: Int64 = 0,
        scanDuration: TimeInterval = 0,
        scanMode: String = "entireDisk",
        scannedPath: String = "/",
        categories: [CachedCategory] = []
    ) {
        self.id = id
        self.date = date
        self.totalScannedSize = totalScannedSize
        self.scanDuration = scanDuration
        self.scanMode = scanMode
        self.scannedPath = scannedPath
        self.categories = categories
    }
    
    /// Converts to domain model (without loading file items for performance)
    func toScanResult(includeFileItems: Bool = false) -> ScanResult {
        let smartCategories = (categories ?? []).map { $0.toSmartCategory(includeItems: includeFileItems) }
        return ScanResult(
            id: id,
            date: date,
            categories: smartCategories,
            totalScannedSize: totalScannedSize,
            scanDuration: scanDuration
        )
    }
}

/// SwiftData model for cached categories
@Model
final class CachedCategory {
    @Attribute(.unique) var id: UUID
    var type: String // CategoryType rawValue
    var title: String
    var icon: String
    var safetyLevel: String // SafetyLevel description
    var totalSize: Int64
    var itemCount: Int
    var lastScanned: Date?
    
    // Enhanced Statistics
    var largestFileName: String?
    var largestFileSize: Int64?
    var largestFilePath: String?
    var oldestFileName: String?
    var oldestFileDate: Date?
    var oldestFilePath: String?
    var averageFileSize: Int64? // Make optional for migration
    var fileTypeBreakdownData: Data? // Encoded [String: Int]
    var potentialSavings: Int64?
    var subcategoriesData: Data? // Encoded [String: Int64]
    
    @Relationship(deleteRule: .cascade) var items: [CachedFileNode]?
    
    init(
        id: UUID = UUID(),
        type: String,
        title: String,
        icon: String,
        safetyLevel: String,
        totalSize: Int64 = 0,
        itemCount: Int = 0,
        lastScanned: Date? = nil,
        largestFileName: String? = nil,
        largestFileSize: Int64? = nil,
        largestFilePath: String? = nil,
        oldestFileName: String? = nil,
        oldestFileDate: Date? = nil,
        oldestFilePath: String? = nil,
        averageFileSize: Int64? = nil,
        fileTypeBreakdownData: Data? = nil,
        potentialSavings: Int64? = nil,
        subcategoriesData: Data? = nil,
        items: [CachedFileNode] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.icon = icon
        self.safetyLevel = safetyLevel
        self.totalSize = totalSize
        self.itemCount = itemCount
        self.lastScanned = lastScanned
        self.largestFileName = largestFileName
        self.largestFileSize = largestFileSize
        self.largestFilePath = largestFilePath
        self.oldestFileName = oldestFileName
        self.oldestFileDate = oldestFileDate
        self.oldestFilePath = oldestFilePath
        self.averageFileSize = averageFileSize
        self.fileTypeBreakdownData = fileTypeBreakdownData
        self.potentialSavings = potentialSavings
        self.subcategoriesData = subcategoriesData
        self.items = items
    }
    
    /// Converts to domain model (without loading file items)
    func toSmartCategory(includeItems: Bool = false) -> SmartCategory {
        let categoryType = CategoryType(rawValue: type) ?? .largeFiles
        let safety: SafetyLevel
        switch safetyLevel {
        case "safe": safety = .safe
        case "caution": safety = .caution
        case "dangerous": safety = .dangerous
        default: safety = .caution
        }
        
        // Only load file items if explicitly requested (for detail views)
        let fileNodes = includeItems ? (items ?? []).map { $0.toFileNode() } : []
        
        // Decode file type breakdown
        var fileTypeBreakdown: [String: Int] = [:]
        if let data = fileTypeBreakdownData,
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            fileTypeBreakdown = decoded
        }
        
        // Decode subcategories
        var subcategories: [String: Int64]? = nil
        if let data = subcategoriesData,
           let decoded = try? JSONDecoder().decode([String: Int64].self, from: data) {
            subcategories = decoded
        }
        
        // Reconstruct largest file
        var largestFile: FileNode? = nil
        if let name = largestFileName,
           let size = largestFileSize,
           let path = largestFilePath {
            largestFile = FileNode(
                path: URL(fileURLWithPath: path),
                name: name,
                size: size,
                isDirectory: false,
                dateModified: Date(),
                dateCreated: Date()
            )
        }
        
        // Reconstruct oldest file
        var oldestFile: FileNode? = nil
        if let name = oldestFileName,
           let date = oldestFileDate,
           let path = oldestFilePath {
            oldestFile = FileNode(
                path: URL(fileURLWithPath: path),
                name: name,
                size: 0,
                isDirectory: false,
                dateModified: date,
                dateCreated: date
            )
        }
        
        return SmartCategory(
            id: id,
            type: categoryType,
            title: title,
            icon: icon,
            safetyLevel: safety,
            totalSize: totalSize,
            itemCount: itemCount,
            items: fileNodes,
            lastScanned: lastScanned,
            largestFile: largestFile,
            oldestFile: oldestFile,
            averageFileSize: averageFileSize ?? 0, // Default to 0 if not set
            fileTypeBreakdown: fileTypeBreakdown,
            potentialSavings: potentialSavings,
            subcategories: subcategories
        )
    }
    
    /// Loads file items for this category (lazy loading for detail views)
    func loadFileItems() -> [FileNode] {
        return (items ?? []).map { $0.toFileNode() }
    }
}

/// SwiftData model for cached file nodes
@Model
final class CachedFileNode {
    @Attribute(.unique) var id: UUID
    var path: String
    var name: String
    var size: Int64
    var isDirectory: Bool
    var dateModified: Date
    var dateCreated: Date
    var isSIPProtected: Bool
    var category: String? // CategoryType rawValue
    
    init(
        id: UUID = UUID(),
        path: String,
        name: String,
        size: Int64,
        isDirectory: Bool,
        dateModified: Date,
        dateCreated: Date,
        isSIPProtected: Bool = false,
        category: String? = nil
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.dateModified = dateModified
        self.dateCreated = dateCreated
        self.isSIPProtected = isSIPProtected
        self.category = category
    }
    
    /// Converts to domain model
    func toFileNode() -> FileNode {
        let categoryType = category.flatMap { CategoryType(rawValue: $0) }
        return FileNode(
            id: id,
            path: URL(fileURLWithPath: path),
            name: name,
            size: size,
            isDirectory: isDirectory,
            dateModified: dateModified,
            dateCreated: dateCreated,
            category: categoryType,
            isSIPProtected: isSIPProtected
        )
    }
}

// MARK: - SafetyLevel Extension
extension SafetyLevel {
    var description: String {
        switch self {
        case .safe: return "safe"
        case .caution: return "caution"
        case .dangerous: return "dangerous"
        }
    }
}

