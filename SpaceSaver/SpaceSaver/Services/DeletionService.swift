//
//  DeletionService.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation
import AppKit
import Combine
import OSLog

/// Represents an item that was deleted and can be undone
struct DeletedItem: Identifiable {
    let id = UUID()
    let originalPath: URL
    let trashedPath: URL
    let size: Int64
    let deletedAt: Date
}

/// Result of a deletion operation
enum DeletionResult {
    case success(items: [DeletedItem])
    case partialSuccess(succeeded: [DeletedItem], failed: [(URL, Error)])
    case failure(errors: [(URL, Error)])
    case cancelled
}

/// Preview of what will be deleted in dry run mode
struct DeletionPreview {
    let items: [FileNode]
    let totalSize: Int64
    let itemCount: Int
    let sipProtectedCount: Int
    let safetyLevel: SafetyLevel
    
    var canDelete: Bool {
        sipProtectedCount == 0
    }
}

/// Service for safely deleting files and folders
@MainActor
class DeletionService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var recentlyDeleted: [DeletedItem] = []
    @Published var isDeleting: Bool = false
    @Published var deletionProgress: Double = 0.0
    
    // MARK: - Configuration
    private let maxUndoHistory = 100 // Keep last 100 deletion operations
    private let fileManager = FileManager.default
    
    // MARK: - Singleton
    static let shared = DeletionService()
    
    private init() {}
    
    // MARK: - Dry Run Mode
    
    /// Preview what would be deleted without actually deleting
    func previewDeletion(items: [FileNode]) -> DeletionPreview {
        let totalSize = items.reduce(0) { $0 + $1.size }
        let sipProtectedCount = items.filter { $0.isSIPProtected }.count
        
        // Determine safety level based on content
        let safetyLevel = determineSafetyLevel(for: items)
        
        return DeletionPreview(
            items: items,
            totalSize: totalSize,
            itemCount: items.count,
            sipProtectedCount: sipProtectedCount,
            safetyLevel: safetyLevel
        )
    }
    
    // MARK: - Safe Deletion
    
    /// Safely delete items by moving them to trash
    func deleteItems(_ items: [FileNode], dryRun: Bool = false) async throws -> DeletionResult {
        guard !dryRun else {
            // In dry run mode, just return what would be deleted
            return .success(items: [])
        }
        
        isDeleting = true
        deletionProgress = 0.0
        defer {
            isDeleting = false
            deletionProgress = 0.0
        }
        
        var succeededItems: [DeletedItem] = []
        var failedItems: [(URL, Error)] = []
        
        let totalItems = Double(items.count)
        
        for (index, item) in items.enumerated() {
            // Check if SIP protected
            if item.isSIPProtected {
                let error = NSError(
                    domain: "DeletionService",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "File is protected by System Integrity Protection"]
                )
                failedItems.append((item.path, error))
                continue
            }
            
            // Note: We removed the pre-check here because fileExists() can return false
            // for permission issues, which would incorrectly skip valid files.
            // Let moveToTrash() handle the detailed checking with proper error messages.
            
            do {
                let deletedItem = try await moveToTrash(url: item.path)
                succeededItems.append(deletedItem)
            } catch {
                Logger.deletion.error("Failed to delete item: \(item.path.path) - \(error.localizedDescription)")
                failedItems.append((item.path, error))
            }
            
            // Update progress
            deletionProgress = Double(index + 1) / totalItems
        }
        
        // Add to undo history
        if !succeededItems.isEmpty {
            addToUndoHistory(succeededItems)
        }
        
        // Return appropriate result
        if succeededItems.isEmpty {
            return .failure(errors: failedItems)
        } else if failedItems.isEmpty {
            return .success(items: succeededItems)
        } else {
            return .partialSuccess(succeeded: succeededItems, failed: failedItems)
        }
    }
    
    /// Delete a single item safely
    func deleteItem(_ item: FileNode) async throws -> DeletedItem {
        if item.isSIPProtected {
            throw NSError(
                domain: "DeletionService",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "File is protected by System Integrity Protection"]
            )
        }
        
        let deletedItem = try await moveToTrash(url: item.path)
        addToUndoHistory([deletedItem])
        return deletedItem
    }
    
    // MARK: - Trash Operations
    
    /// Move a file or folder to trash
    private func moveToTrash(url: URL) async throws -> DeletedItem {
        // Resolve the URL to handle percent encoding and symlinks
        let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
        
        // Log original and resolved paths for debugging
        Logger.deletion.debug("Attempting to delete: original=\(url.path), resolved=\(resolvedURL.path)")
        
        // Try to get file attributes - this will tell us if it's a permission issue
        var targetURL = resolvedURL
        var fileExists = false
        var isPermissionIssue = false
        
        // Try resolved path first
        do {
            _ = try fileManager.attributesOfItem(atPath: resolvedURL.path)
            fileExists = true
            targetURL = resolvedURL
        } catch let error as NSError {
            // Check if it's a permission error
            if error.domain == NSCocoaErrorDomain && (error.code == NSFileReadNoPermissionError || error.code == NSFileNoSuchFileError) {
                if error.code == NSFileReadNoPermissionError {
                    isPermissionIssue = true
                }
                
                // Try original path
                do {
                    _ = try fileManager.attributesOfItem(atPath: url.path)
                    fileExists = true
                    targetURL = url
                    isPermissionIssue = false
                } catch let origError as NSError {
                    if origError.code == NSFileReadNoPermissionError {
                        isPermissionIssue = true
                        Logger.deletion.error("Permission denied accessing file: \(url.path)")
                    }
                    Logger.deletion.error("Cannot access file: \(origError.localizedDescription)")
                }
            }
        }
        
        // If we have a permission issue, throw appropriate error
        if isPermissionIssue {
            throw NSError(
                domain: "DeletionService",
                code: 1008,
                userInfo: [
                    NSLocalizedDescriptionKey: "Permission denied. The app may not have Full Disk Access permission.",
                    NSFilePathErrorKey: targetURL.path,
                    NSLocalizedRecoverySuggestionErrorKey: "Grant Full Disk Access in System Settings > Privacy & Security > Full Disk Access"
                ]
            )
        }
        
        // If file doesn't exist at all
        if !fileExists {
            Logger.deletion.warning("File does not exist at either path: original=\(url.path), resolved=\(resolvedURL.path)")
            throw NSError(
                domain: "DeletionService",
                code: 1006,
                userInfo: [
                    NSLocalizedDescriptionKey: "File does not exist. It may have been deleted, moved, or renamed.",
                    NSFilePathErrorKey: resolvedURL.path,
                    "originalPath": url.path,
                    "resolvedPath": resolvedURL.path
                ]
            )
        }
        
        var trashedURL: NSURL?
        
        // Get file size
        let size = try? fileManager.attributesOfItem(atPath: targetURL.path)[.size] as? Int64 ?? 0
        
        // Attempt deletion with error handling
        do {
            try fileManager.trashItem(at: targetURL, resultingItemURL: &trashedURL)
        } catch {
            Logger.deletion.error("Failed to trash item at \(targetURL.path): \(error.localizedDescription)")
            // Re-throw with more context
            throw NSError(
                domain: "DeletionService",
                code: 1007,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to move file to trash: \(error.localizedDescription)",
                    NSFilePathErrorKey: targetURL.path,
                    NSUnderlyingErrorKey: error
                ]
            )
        }
        
        guard let trashedPath = trashedURL as URL? else {
            throw NSError(
                domain: "DeletionService",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get trashed item path"]
            )
        }
        
        Logger.deletion.info("Moved to trash: \(targetURL.path) -> \(trashedPath.path)")
        
        return DeletedItem(
            originalPath: targetURL,
            trashedPath: trashedPath,
            size: size ?? 0,
            deletedAt: Date()
        )
    }
    
    // MARK: - Undo Support
    
    /// Add deleted items to undo history
    private func addToUndoHistory(_ items: [DeletedItem]) {
        recentlyDeleted.insert(contentsOf: items, at: 0)
        
        // Keep only the most recent deletions
        if recentlyDeleted.count > maxUndoHistory {
            recentlyDeleted = Array(recentlyDeleted.prefix(maxUndoHistory))
        }
    }
    
    /// Restore a deleted item from trash
    func undoDelete(_ item: DeletedItem) async throws {
        // Check if the trashed item still exists
        guard fileManager.fileExists(atPath: item.trashedPath.path) else {
            throw NSError(
                domain: "DeletionService",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Trashed item no longer exists"]
            )
        }
        
        // Check if original path is available
        if fileManager.fileExists(atPath: item.originalPath.path) {
            throw NSError(
                domain: "DeletionService",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "Original path is now occupied by another item"]
            )
        }
        
        // Move back from trash
        try fileManager.moveItem(at: item.trashedPath, to: item.originalPath)
        
        // Remove from undo history
        recentlyDeleted.removeAll { $0.id == item.id }
        
        Logger.deletion.info("Restored from trash: \(item.trashedPath.path) -> \(item.originalPath.path)")
    }
    
    /// Restore multiple items
    func undoDelete(_ items: [DeletedItem]) async throws {
        var errors: [Error] = []
        
        for item in items {
            do {
                try await undoDelete(item)
            } catch {
                errors.append(error)
                Logger.deletion.error("Failed to restore item: \(item.originalPath.path) - \(error.localizedDescription)")
            }
        }
        
        if !errors.isEmpty {
            throw NSError(
                domain: "DeletionService",
                code: 1005,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to restore \(errors.count) item(s)",
                    "errors": errors
                ]
            )
        }
    }
    
    /// Clear undo history
    func clearUndoHistory() {
        recentlyDeleted.removeAll()
    }
    
    // MARK: - Safety Level Determination
    
    /// Determine the overall safety level for a group of items
    private func determineSafetyLevel(for items: [FileNode]) -> SafetyLevel {
        // Check for dangerous patterns
        let hasSIPProtected = items.contains { $0.isSIPProtected }
        let hasSystemFiles = items.contains { item in
            item.path.path.hasPrefix("/System") ||
            item.path.path.hasPrefix("/Library/System") ||
            item.path.path.hasPrefix("/Applications") && item.path.pathExtension == "app"
        }
        
        if hasSIPProtected || hasSystemFiles {
            return .dangerous
        }
        
        // Check for caution patterns
        let hasLargeFiles = items.contains { $0.size > 100_000_000 } // > 100 MB
        let hasDocuments = items.contains { item in
            item.path.path.contains("/Documents/") ||
            item.path.path.contains("/Desktop/")
        }
        
        if hasLargeFiles || hasDocuments {
            return .caution
        }
        
        // Default to safe
        return .safe
    }
    
    // MARK: - Batch Operations
    
    /// Delete items in batches for better performance
    func deleteBatch(_ items: [FileNode], batchSize: Int = 10, dryRun: Bool = false) async throws -> DeletionResult {
        var allSucceeded: [DeletedItem] = []
        var allFailed: [(URL, Error)] = []
        
        // Split into batches
        let batches = stride(from: 0, to: items.count, by: batchSize).map {
            Array(items[$0..<min($0 + batchSize, items.count)])
        }
        
        for batch in batches {
            let result = try await deleteItems(batch, dryRun: dryRun)
            
            switch result {
            case .success(let items):
                allSucceeded.append(contentsOf: items)
            case .partialSuccess(let succeeded, let failed):
                allSucceeded.append(contentsOf: succeeded)
                allFailed.append(contentsOf: failed)
            case .failure(let errors):
                allFailed.append(contentsOf: errors)
            case .cancelled:
                return .cancelled
            }
        }
        
        // Return combined result
        if allSucceeded.isEmpty {
            return .failure(errors: allFailed)
        } else if allFailed.isEmpty {
            return .success(items: allSucceeded)
        } else {
            return .partialSuccess(succeeded: allSucceeded, failed: allFailed)
        }
    }
}

