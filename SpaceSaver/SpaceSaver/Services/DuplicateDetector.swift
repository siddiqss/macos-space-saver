//
//  DuplicateDetector.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation
import CryptoKit
import OSLog

class DuplicateDetector {
    private let logger = Logger.duplicates
    private let minFileSize: Int64
    
    init(minFileSize: Int64 = 1_000_000) {  // Default 1MB
        self.minFileSize = minFileSize
    }
    
    /// Detects duplicate files and returns groups of duplicates
    func detectDuplicates(in files: [FileNode]) async throws -> [DuplicateGroup] {
        logger.info("Starting duplicate detection for \(files.count) files")
        
        // Filter by size threshold and non-directories
        let eligibleFiles = files.filter { !$0.isDirectory && $0.size >= minFileSize }
        logger.info("Filtered to \(eligibleFiles.count) eligible files (>= \(self.minFileSize) bytes)")
        
        if eligibleFiles.isEmpty {
            return []
        }
        
        // Step 1: Group by exact size
        var sizeGroups: [Int64: [FileNode]] = [:]
        for file in eligibleFiles {
            sizeGroups[file.size, default: []].append(file)
        }
        
        // Keep only groups with 2+ files
        let potentialDuplicates = sizeGroups.filter { $0.value.count > 1 }
        logger.info("Found \(potentialDuplicates.count) size groups with potential duplicates")
        
        if potentialDuplicates.isEmpty {
            return []
        }
        
        // Step 2: Compute partial hashes for files with same size
        var partialHashGroups: [String: [FileNode]] = [:]
        var processedCount = 0
        
        for (_, filesGroup) in potentialDuplicates {
            for file in filesGroup {
                try Task.checkCancellation()
                
                if let partialHash = try? await computePartialHash(for: file.path) {
                    partialHashGroups[partialHash, default: []].append(file)
                }
                
                processedCount += 1
                if processedCount % 10 == 0 {
                    await Task.yield()
                }
            }
        }
        
        // Keep only groups with 2+ files with same partial hash
        let partialMatches = partialHashGroups.filter { $0.value.count > 1 }
        logger.info("Found \(partialMatches.count) partial hash groups with potential duplicates")
        
        if partialMatches.isEmpty {
            return []
        }
        
        // Step 3: Compute full hashes for final verification
        var fullHashGroups: [String: [FileNode]] = [:]
        processedCount = 0
        
        for (_, filesGroup) in partialMatches {
            for file in filesGroup {
                try Task.checkCancellation()
                
                if let fullHash = try? await computeFullHash(for: file.path) {
                    fullHashGroups[fullHash, default: []].append(file)
                }
                
                processedCount += 1
                if processedCount % 5 == 0 {
                    await Task.yield()
                }
            }
        }
        
        // Step 4: Create duplicate groups
        let duplicateGroups = fullHashGroups
            .filter { $0.value.count > 1 }
            .map { hash, files in
                DuplicateGroup(
                    hash: hash,
                    files: files,
                    fileSize: files.first?.size ?? 0
                )
            }
            .sorted { $0.totalWastedSpace > $1.totalWastedSpace }
        
        logger.info("Found \(duplicateGroups.count) duplicate groups")
        let totalWasted = duplicateGroups.reduce(0) { $0 + $1.totalWastedSpace }
        logger.info("Total wasted space: \(totalWasted) bytes")
        
        return duplicateGroups
    }
    
    /// Computes partial hash (first 4KB) for quick comparison
    private func computePartialHash(for url: URL) async throws -> String {
        let bytesToRead = 4096  // 4KB
        
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            throw DuplicateError.cannotReadFile(url)
        }
        
        defer {
            try? fileHandle.close()
        }
        
        guard let data = try? fileHandle.read(upToCount: bytesToRead), !data.isEmpty else {
            throw DuplicateError.cannotReadFile(url)
        }
        
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Computes full file hash for definitive duplicate detection
    private func computeFullHash(for url: URL) async throws -> String {
        guard let data = try? Data(contentsOf: url) else {
            throw DuplicateError.cannotReadFile(url)
        }
        
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Duplicate Group Model

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let hash: String
    let files: [FileNode]
    let fileSize: Int64
    
    var duplicateCount: Int {
        files.count
    }
    
    var totalWastedSpace: Int64 {
        // Keep one copy, waste is (n-1) * size
        fileSize * Int64(max(0, files.count - 1))
    }
    
    var originalFile: FileNode? {
        // Return oldest file as "original"
        files.min(by: { $0.dateCreated < $1.dateCreated })
    }
    
    var duplicateFiles: [FileNode] {
        // All files except the original
        guard let original = originalFile else { return files }
        return files.filter { $0.id != original.id }
    }
}

// MARK: - Errors

enum DuplicateError: Error, LocalizedError {
    case cannotReadFile(URL)
    
    var errorDescription: String? {
        switch self {
        case .cannotReadFile(let url):
            return "Cannot read file: \(url.path)"
        }
    }
}

// MARK: - Logger Extension

extension Logger {
    static let duplicates = Logger(subsystem: "com.spacesaver", category: "duplicates")
}

