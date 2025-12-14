//
//  ScanPreferences.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation

struct ScanPreferences {
    var enableDuplicateDetection: Bool = true
    var duplicateMinSize: Int64 = 1_000_000  // 1MB
    var categoryFilters: Set<CategoryType> = []
    var showEmptyCategories: Bool = false
    var detailedFileTypeAnalysis: Bool = true
    var maxScanDepth: Int? = nil  // nil = unlimited
    
    // Singleton for global access
    static var shared = ScanPreferences()
    
    // UserDefaults keys
    private enum Keys {
        static let enableDuplicateDetection = "scanPrefs.enableDuplicateDetection"
        static let duplicateMinSize = "scanPrefs.duplicateMinSize"
        static let showEmptyCategories = "scanPrefs.showEmptyCategories"
        static let detailedFileTypeAnalysis = "scanPrefs.detailedFileTypeAnalysis"
        static let maxScanDepth = "scanPrefs.maxScanDepth"
    }
    
    // Load from UserDefaults
    static func load() -> ScanPreferences {
        let defaults = UserDefaults.standard
        return ScanPreferences(
            enableDuplicateDetection: defaults.bool(forKey: Keys.enableDuplicateDetection) || !defaults.objectIsSaved(forKey: Keys.enableDuplicateDetection),
            duplicateMinSize: defaults.object(forKey: Keys.duplicateMinSize) as? Int64 ?? 1_000_000,
            categoryFilters: [],
            showEmptyCategories: defaults.bool(forKey: Keys.showEmptyCategories),
            detailedFileTypeAnalysis: defaults.bool(forKey: Keys.detailedFileTypeAnalysis) || !defaults.objectIsSaved(forKey: Keys.detailedFileTypeAnalysis),
            maxScanDepth: defaults.object(forKey: Keys.maxScanDepth) as? Int
        )
    }
    
    // Save to UserDefaults
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(enableDuplicateDetection, forKey: Keys.enableDuplicateDetection)
        defaults.set(duplicateMinSize, forKey: Keys.duplicateMinSize)
        defaults.set(showEmptyCategories, forKey: Keys.showEmptyCategories)
        defaults.set(detailedFileTypeAnalysis, forKey: Keys.detailedFileTypeAnalysis)
        if let maxScanDepth = maxScanDepth {
            defaults.set(maxScanDepth, forKey: Keys.maxScanDepth)
        } else {
            defaults.removeObject(forKey: Keys.maxScanDepth)
        }
    }
}

// Helper extension for UserDefaults
private extension UserDefaults {
    func objectIsSaved(forKey key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

