//
//  SmartCategory.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation

enum CategoryType: String, CaseIterable {
    // Media Categories
    case images = "Images"
    case videos = "Videos"
    case audio = "Audio"
    
    // Documents
    case documents = "Documents"
    case archives = "Archives"
    
    // Applications
    case applications = "Applications"
    
    // System & Cleanup
    case system = "System Files"
    case caches = "Caches"
    case logs = "Logs"
    case temporaryFiles = "Temporary Files"
    case backups = "Backups"
    case duplicates = "Duplicates"
    
    // Special Locations
    case oldDownloads = "Old Downloads"
    case mailAttachments = "Mail Attachments"
    case screenshots = "Screenshots"
    
    // Developer (existing)
    case developer = "Developer"
    
    // Legacy/Fallback (keep for compatibility)
    case largeFiles = "Large Files"
    case unusedApps = "Unused Apps"
    
    var icon: String {
        switch self {
        // Media
        case .images: return "photo.fill"
        case .videos: return "video.fill"
        case .audio: return "music.note"
        
        // Documents
        case .documents: return "doc.text.fill"
        case .archives: return "archivebox.fill"
        
        // Applications
        case .applications: return "app.fill"
        
        // System & Cleanup
        case .system: return "gearshape.fill"
        case .caches: return "memorychip.fill"
        case .logs: return "doc.plaintext.fill"
        case .temporaryFiles: return "clock.arrow.circlepath"
        case .backups: return "externaldrive.fill"
        case .duplicates: return "doc.on.doc.fill"
        
        // Special Locations
        case .oldDownloads: return "arrow.down.circle.fill"
        case .mailAttachments: return "paperclip"
        case .screenshots: return "camera.viewfinder"
        
        // Developer
        case .developer: return "hammer.fill"
        
        // Legacy
        case .largeFiles: return "doc.fill"
        case .unusedApps: return "app.badge.fill"
        }
    }
    
    var defaultSafetyLevel: SafetyLevel {
        switch self {
        // Safe to delete
        case .caches, .logs, .temporaryFiles, .duplicates:
            return .safe
        
        // Review before deleting
        case .images, .videos, .audio, .documents, .archives,
             .oldDownloads, .mailAttachments, .screenshots, .largeFiles:
            return .caution
        
        // Use caution - dangerous to delete
        case .applications, .backups, .developer, .unusedApps, .system:
            return .dangerous
        }
    }
}

enum SafetyLevel {
    case safe      // System caches, logs
    case caution   // Downloads, large files
    case dangerous // System files, app bundles
}

struct SmartCategory: Identifiable {
    let id: UUID
    let type: CategoryType
    let title: String
    let icon: String
    let safetyLevel: SafetyLevel
    var totalSize: Int64
    var itemCount: Int
    var items: [FileNode]
    var lastScanned: Date?
    
    // Enhanced Statistics
    var largestFile: FileNode?
    var oldestFile: FileNode?
    var averageFileSize: Int64
    var fileTypeBreakdown: [String: Int]  // Extension -> count
    var potentialSavings: Int64?  // For duplicates
    var subcategories: [String: Int64]?  // Size breakdown by subtype
    
    init(
        id: UUID = UUID(),
        type: CategoryType,
        title: String? = nil,
        icon: String? = nil,
        safetyLevel: SafetyLevel? = nil,
        totalSize: Int64 = 0,
        itemCount: Int = 0,
        items: [FileNode] = [],
        lastScanned: Date? = nil,
        largestFile: FileNode? = nil,
        oldestFile: FileNode? = nil,
        averageFileSize: Int64 = 0,
        fileTypeBreakdown: [String: Int] = [:],
        potentialSavings: Int64? = nil,
        subcategories: [String: Int64]? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title ?? type.rawValue
        self.icon = icon ?? type.icon
        self.safetyLevel = safetyLevel ?? type.defaultSafetyLevel
        self.totalSize = totalSize
        self.itemCount = itemCount
        self.items = items
        self.lastScanned = lastScanned
        self.largestFile = largestFile
        self.oldestFile = oldestFile
        self.averageFileSize = averageFileSize
        self.fileTypeBreakdown = fileTypeBreakdown
        self.potentialSavings = potentialSavings
        self.subcategories = subcategories
    }
    
    // Computed properties for convenience
    var mostCommonFileType: String? {
        fileTypeBreakdown.max(by: { $0.value < $1.value })?.key
    }
    
    var hasDetailedStats: Bool {
        largestFile != nil || oldestFile != nil || !fileTypeBreakdown.isEmpty
    }
}

// MARK: - Scan Result
struct ScanResult: Identifiable {
    let id: UUID
    let date: Date
    let categories: [SmartCategory]
    let totalScannedSize: Int64
    let scanDuration: TimeInterval
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        categories: [SmartCategory] = [],
        totalScannedSize: Int64 = 0,
        scanDuration: TimeInterval = 0
    ) {
        self.id = id
        self.date = date
        self.categories = categories
        self.totalScannedSize = totalScannedSize
        self.scanDuration = scanDuration
    }
}

