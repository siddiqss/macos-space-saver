//
//  CategoryManager.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation
import OSLog

class CategoryManager {
    private let logger = Logger.category
    private let preferences: ScanPreferences
    private let duplicateDetector: DuplicateDetector
    
    // File extension mappings (reused from TreeMapView)
    private let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "svg", "heic", "heif", "raw", "cr2", "nef", "ico"]
    private let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "3gp", "ogv", "m2ts", "mts"]
    private let audioExtensions: Set<String> = ["mp3", "wav", "aac", "flac", "m4a", "wma", "ogg", "opus", "alac", "ape", "aiff", "mid", "midi"]
    private let documentExtensions: Set<String> = ["pdf", "doc", "docx", "txt", "rtf", "pages", "key", "numbers", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "odp", "epub", "mobi"]
    private let archiveExtensions: Set<String> = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "pkg", "deb", "rpm", "sit", "sitx", "cab"]
    private let codeExtensions: Set<String> = ["swift", "js", "ts", "py", "java", "cpp", "c", "h", "m", "mm", "go", "rs", "php", "rb", "pl", "sh", "bash", "css", "html", "xml", "json", "yaml", "yml"]
    private let temporaryExtensions: Set<String> = ["tmp", "temp", "cache", "crdownload", "part", "download"]
    
    init(preferences: ScanPreferences = .shared) {
        self.preferences = preferences
        self.duplicateDetector = DuplicateDetector(minFileSize: preferences.duplicateMinSize)
    }
    
    /// Categorizes file nodes into smart categories
    func categorize(files: [FileNode]) async -> [SmartCategory] {
        logger.info("Categorizing \(files.count) files with enhanced detection")
        
        var categoryFiles: [CategoryType: [FileNode]] = [:]
        var duplicateGroups: [DuplicateGroup] = []
        
        // Step 1: Detect duplicates if enabled
        if preferences.enableDuplicateDetection {
            logger.info("Running duplicate detection...")
            do {
                duplicateGroups = try await duplicateDetector.detectDuplicates(in: files)
                logger.info("Found \(duplicateGroups.count) duplicate groups")
                
                // Add duplicate files to category
                let duplicateFiles = duplicateGroups.flatMap { $0.duplicateFiles }
                if !duplicateFiles.isEmpty {
                    categoryFiles[.duplicates] = duplicateFiles
                }
            } catch {
                logger.error("Duplicate detection failed: \(error.localizedDescription)")
            }
        }
        
        // Step 2: Categorize all files by type/location
        let duplicateFileIds = Set(categoryFiles[.duplicates]?.map { $0.id } ?? [])
        
        for file in files {
            // Skip directories for categorization
            if file.isDirectory {
                continue
            }
            
            // Skip files already categorized as duplicates (unless they fit other categories too)
            // We'll keep duplicates separate for cleaner reporting
            if duplicateFileIds.contains(file.id) {
                continue
            }
            
            // Determine category with priority-based logic
            let category = determineCategory(for: file)
            categoryFiles[category, default: []].append(file)
        }
        
        // Step 3: Build SmartCategory objects with statistics
        var smartCategories: [SmartCategory] = []
        
        for (type, items) in categoryFiles {
            let category = await buildCategory(type: type, items: items, duplicateGroups: type == .duplicates ? duplicateGroups : [])
            smartCategories.append(category)
        }
        
        // Sort by size (largest first)
        let sorted = smartCategories.sorted { $0.totalSize > $1.totalSize }
        
        logger.info("Categorization complete: \(sorted.count) categories")
        for cat in sorted {
            logger.info("  \(cat.title): \(cat.itemCount) items, \(cat.totalSize) bytes")
        }
        
        return sorted
    }
    
    /// Determines the category for a file using priority-based logic
    private func determineCategory(for file: FileNode) -> CategoryType {
        let path = file.path.path.lowercased()
        let name = file.name.lowercased()
        let ext = getFileExtension(name)
        
        // Priority 1: Applications (.app bundles)
        if name.hasSuffix(".app") || path.contains(".app/") {
            return .applications
        }
        
        // Priority 2: System files - anything in /System, /Library (not user Library)
        if path.hasPrefix("/system/") || 
           (path.hasPrefix("/library/") && !path.hasPrefix("/library/caches") && !path.hasPrefix("/library/logs")) ||
           path.contains("/system/library/") ||
           path.contains("/corestorage/") ||
           name.hasSuffix(".framework") ||
           name.hasSuffix(".dylib") ||
           name.hasSuffix(".kext") ||
           name.hasSuffix(".plugin") ||
           name.hasSuffix(".bundle") ||
           ext == "plist" && (path.contains("/system/") || path.contains("/library/")) {
            return .system
        }
        
        // Priority 3: System locations (caches, logs, backups)
        if path.contains("/library/caches") || path.contains("/.cache") {
            return .caches
        }
        
        if path.contains("/library/logs") || path.contains("/.log") || ext == "log" {
            return .logs
        }
        
        if path.contains("/backups") || path.contains("/time machine") || 
           path.contains("/mobile backup") || path.contains(".backup") {
            return .backups
        }
        
        if temporaryExtensions.contains(ext) || path.contains("/tmp/") || path.contains("/.tmp") {
            return .temporaryFiles
        }
        
        // Priority 4: Special locations
        if path.contains("/downloads/screenshot") || name.hasPrefix("screen shot ") || 
           name.hasPrefix("screenshot ") {
            return .screenshots
        }
        
        if path.contains("/mail downloads") || path.contains("/mail attachments") {
            return .mailAttachments
        }
        
        // Priority 5: Developer files
        if isDeveloperFile(path: path, name: name) {
            return .developer
        }
        
        // Priority 5: File type based on extension
        if imageExtensions.contains(ext) {
            return .images
        }
        
        if videoExtensions.contains(ext) {
            return .videos
        }
        
        if audioExtensions.contains(ext) {
            return .audio
        }
        
        if documentExtensions.contains(ext) {
            return .documents
        }
        
        if archiveExtensions.contains(ext) {
            return .archives
        }
        
        // Priority 6: Age-based (old downloads)
        if path.contains("/downloads") {
            let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            if file.dateModified < threeMonthsAgo {
                return .oldDownloads
            }
        }
        
        // Priority 7: Size-based fallback (large files > 1GB)
        if file.size > 1_000_000_000 {
            return .largeFiles
        }
        
        // Default: categorize by file type if identifiable, otherwise large files
        return .largeFiles
    }
    
    /// Checks if a file is developer-related
    private func isDeveloperFile(path: String, name: String) -> Bool {
        // Common developer paths
        let devPaths = [
            "node_modules", ".git", "build/", "deriveddata",
            ".gradle", ".maven", "target/", "dist/",
            "__pycache__", ".pytest_cache", "venv/", ".venv/",
            "vendor/", "packages/", ".nuget", "bin/debug", "bin/release"
        ]
        
        for devPath in devPaths {
            if path.contains(devPath) {
                return true
            }
        }
        
        // Common developer files
        let devFiles = [
            "package-lock.json", "yarn.lock", "gemfile.lock",
            "composer.lock", "podfile.lock", ".DS_Store",
            ".gitignore", ".gitattributes", "makefile",
            "dockerfile", "docker-compose.yml"
        ]
        
        return devFiles.contains(name)
    }
    
    /// Builds a SmartCategory with detailed statistics
    private func buildCategory(type: CategoryType, items: [FileNode], duplicateGroups: [DuplicateGroup]) async -> SmartCategory {
        let totalSize = items.reduce(0) { $0 + $1.size }
        let itemCount = items.count
        
        // Find largest file
        let largestFile = items.max(by: { $0.size < $1.size })
        
        // Find oldest file
        let oldestFile = items.min(by: { $0.dateCreated < $1.dateCreated })
        
        // Calculate average size
        let averageFileSize = itemCount > 0 ? totalSize / Int64(itemCount) : 0
        
        // Build file type breakdown
        var fileTypeBreakdown: [String: Int] = [:]
        if preferences.detailedFileTypeAnalysis {
            for file in items {
                let ext = getFileExtension(file.name.lowercased())
                if !ext.isEmpty {
                    fileTypeBreakdown[ext.uppercased(), default: 0] += 1
                }
            }
        }
        
        // Calculate potential savings for duplicates
        let potentialSavings: Int64? = type == .duplicates 
            ? duplicateGroups.reduce(0) { $0 + $1.totalWastedSpace }
            : nil
        
        // Build subcategories (size breakdown by file type)
        var subcategories: [String: Int64]?
        if preferences.detailedFileTypeAnalysis && !fileTypeBreakdown.isEmpty {
            var sizeByType: [String: Int64] = [:]
            for file in items {
                let ext = getFileExtension(file.name.lowercased())
                if !ext.isEmpty {
                    sizeByType[ext.uppercased(), default: 0] += file.size
                }
            }
            subcategories = sizeByType
        }
        
        return SmartCategory(
            type: type,
            totalSize: totalSize,
            itemCount: itemCount,
            items: items,
            lastScanned: Date(),
            largestFile: largestFile,
            oldestFile: oldestFile,
            averageFileSize: averageFileSize,
            fileTypeBreakdown: fileTypeBreakdown,
            potentialSavings: potentialSavings,
            subcategories: subcategories
        )
    }
    
    /// Extracts file extension from filename
    private func getFileExtension(_ filename: String) -> String {
        let components = filename.split(separator: ".")
        guard components.count > 1 else { return "" }
        return String(components.last ?? "").lowercased()
    }
}
