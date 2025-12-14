//
//  AppInfo.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation
import AppKit

/// Represents an installed application with metadata
struct AppInfo: Identifiable, Hashable {
    let id: UUID
    let name: String
    let bundleIdentifier: String
    let bundlePath: String
    let version: String?
    let size: Int64
    let lastUsedDate: Date?
    let icon: NSImage?
    let associatedFiles: [AssociatedFile]
    let isCurrentlyRunning: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        bundlePath: String,
        version: String? = nil,
        size: Int64 = 0,
        lastUsedDate: Date? = nil,
        icon: NSImage? = nil,
        associatedFiles: [AssociatedFile] = [],
        isCurrentlyRunning: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.bundlePath = bundlePath
        self.version = version
        self.size = size
        self.lastUsedDate = lastUsedDate
        self.icon = icon
        self.associatedFiles = associatedFiles
        self.isCurrentlyRunning = isCurrentlyRunning
    }
    
    /// Total size including app bundle and associated files
    var totalSize: Int64 {
        size + associatedFiles.reduce(0) { $0 + $1.size }
    }
    
    /// Number of days since last used
    var daysSinceLastUsed: Int? {
        guard let lastUsed = lastUsedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastUsed, to: Date()).day
    }
    
    /// Usage status for display
    var usageStatus: UsageStatus {
        // Priority 1: If currently running, always show as active
        if isCurrentlyRunning {
            return .active
        }
        
        // Priority 2: Check days since last used
        guard let days = daysSinceLastUsed else { return .unknown }
        
        // If last used is within the last hour, consider it active
        if let lastUsed = lastUsedDate, Date().timeIntervalSince(lastUsed) < 3600 {
            return .active
        }
        
        // Otherwise use day-based categorization
        if days == 0 {
            return .active
        } else if days < 7 {
            return .active
        } else if days < 30 {
            return .recentlyUsed
        } else if days < 90 {
            return .seldomUsed
        } else {
            return .unused
        }
    }
    
    /// Hash implementation for Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(bundleIdentifier)
    }
    
    /// Equality check for Equatable conformance
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id && lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

/// Usage status of an application
enum UsageStatus: String, CaseIterable {
    case active = "Active"
    case recentlyUsed = "Recently Used"
    case seldomUsed = "Seldom Used"
    case unused = "Unused"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .active: return "app.badge.checkmark.fill"
        case .recentlyUsed: return "clock.fill"
        case .seldomUsed: return "clock.badge.exclamationmark.fill"
        case .unused: return "xmark.app.fill"
        case .unknown: return "questionmark.app.fill"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "green"
        case .recentlyUsed: return "blue"
        case .seldomUsed: return "orange"
        case .unused: return "red"
        case .unknown: return "gray"
        }
    }
}

/// Associated file found for an application
struct AssociatedFile: Identifiable, Hashable {
    let id: UUID
    let path: String
    let size: Int64
    let type: AssociatedFileType
    let modifiedDate: Date?
    
    init(
        id: UUID = UUID(),
        path: String,
        size: Int64,
        type: AssociatedFileType,
        modifiedDate: Date? = nil
    ) {
        self.id = id
        self.path = path
        self.size = size
        self.type = type
        self.modifiedDate = modifiedDate
    }
    
    var url: URL {
        URL(fileURLWithPath: path)
    }
    
    var fileName: String {
        (path as NSString).lastPathComponent
    }
}

/// Type of associated file
enum AssociatedFileType: String, CaseIterable {
    case applicationSupport = "Application Support"
    case preferences = "Preferences"
    case caches = "Caches"
    case logs = "Logs"
    case savedState = "Saved State"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .applicationSupport: return "folder.fill"
        case .preferences: return "gearshape.fill"
        case .caches: return "externaldrive.fill"
        case .logs: return "doc.text.fill"
        case .savedState: return "bookmark.fill"
        case .other: return "doc.fill"
        }
    }
    
    var safetyLevel: SafetyLevel {
        switch self {
        case .caches, .logs, .savedState:
            return .safe
        case .preferences, .applicationSupport:
            return .caution
        case .other:
            return .dangerous
        }
    }
}

/// Sort options for app list
enum AppSortOption: String, CaseIterable {
    case name = "Name"
    case size = "Size"
    case lastUsed = "Last Used"
    case totalSize = "Total Size"
    
    var icon: String {
        switch self {
        case .name: return "textformat"
        case .size: return "arrow.up.arrow.down"
        case .lastUsed: return "clock"
        case .totalSize: return "chart.bar"
        }
    }
}

