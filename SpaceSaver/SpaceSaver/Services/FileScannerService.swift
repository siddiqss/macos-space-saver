//
//  FileScannerService.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation
import OSLog
import Combine

class FileScannerService: ObservableObject {
    @MainActor @Published var isScanning: Bool = false
    @MainActor @Published var progress: Double = 0.0
    @MainActor @Published var currentPath: String = ""
    @MainActor @Published var filesScanned: Int = 0
    @MainActor @Published var bytesScanned: Int64 = 0
    @MainActor @Published var totalFilesToScan: Int = 0
    
    private var scanTask: Task<[FileNode], Error>?
    private let logger = Logger.scanner
    private let exclusionManager = PathExclusionManager.shared
    
    /// Scans a directory and returns file nodes
    func scan(directory: URL, mode: ScanMode = .entireDisk) async throws -> [FileNode] {
        guard !isScanning else {
            throw AppError.scanCancelled
        }
        
        // Check permissions first
        try checkPermissions(for: directory)
        
        // Check for network volumes
        let volumeType = VolumeDetector.getVolumeType(url: directory)
        if volumeType == .network {
            logger.warning("Scanning network volume: \(directory.path)")
        }
        
        isScanning = true
        progress = 0.0
        filesScanned = 0
        bytesScanned = 0
        totalFilesToScan = 0
        
        // Create and store the scan task for cancellation
        scanTask = Task {
            do {
                // Perform the scan
                let startTime = Date()
                let result = try await performScan(directory: directory, mode: mode)
                _ = Date().timeIntervalSince(startTime)  // Track duration for future use
                
                // Update final state
                await MainActor.run {
                    isScanning = false
                    progress = 1.0
                }
                return result
            } catch {
                await MainActor.run {
                    isScanning = false
                }
                if error is CancellationError {
                    throw AppError.scanCancelled
                } else {
                    throw error
                }
            }
        }
        
        // Wait for the task and return result
        do {
            let result = try await scanTask!.value
            return result
        } catch AppError.scanCancelled {
            await MainActor.run {
                isScanning = false
            }
            throw AppError.scanCancelled
        } catch {
            await MainActor.run {
                isScanning = false
            }
            throw error
        }
    }
    
    /// Checks if we have permission to access the directory
    private func checkPermissions(for directory: URL) throws {
        let fileManager = FileManager.default
        
        // Check if path exists
        guard fileManager.fileExists(atPath: directory.path) else {
            throw AppError.invalidPath(directory)
        }
        
        // Try to access the directory
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) else {
            throw AppError.permissionDenied
        }
        
        // Try to read directory contents (permission check)
        do {
            _ = try fileManager.contentsOfDirectory(atPath: directory.path)
        } catch {
            // Check if it's a permission error
            if (error as NSError).code == NSFileReadNoPermissionError ||
               (error as NSError).code == NSFileReadNoSuchFileError {
                logger.error("Permission denied for: \(directory.path)")
                throw AppError.permissionDenied
            }
            // Other errors might be okay (e.g., empty directory)
        }
    }
    
    /// Counts total files for progress calculation
    private func countFiles(in directory: URL, mode: ScanMode) async throws -> Int {
        let fileManager = FileManager.default
        var count = 0
        // Use a class wrapper to ensure the set is shared between closure and outer scope
        class SkippedPathsTracker {
            var paths = Set<String>()
        }
        let skippedPaths = SkippedPathsTracker()
        
        // Check if path should be excluded
        if exclusionManager.shouldExclude(directory) {
            return 0
        }
        
        // Skip SIP-protected paths
        if SIPDetector.isSIPProtected(directory) {
            return 0
        }
        
        // Handle /Volumes skipping in entire disk mode
        if mode == .entireDisk && directory.path == "/Volumes" {
            logger.info("Skipping /Volumes in entire disk mode")
            return 0
        }
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, error in
                let nsError = error as NSError
                // For permission errors, track the path and continue enumeration
                if nsError.code == NSFileReadNoPermissionError {
                    self.logger.warning("Permission denied while counting: \(url.path) - will skip")
                    skippedPaths.paths.insert(url.path)
                    return true // Continue enumeration, we'll skip this path in the loop
                }
                // For other errors, log and continue
                self.logger.debug("Error while counting \(url.path): \(error.localizedDescription)")
                skippedPaths.paths.insert(url.path)
                return true // Continue for all errors
            }
        ) else {
            return 0
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            
            // Yield every 100 files to keep UI responsive
            if count % 100 == 0 {
                await Task.yield()
            }
            
            // Skip paths that had errors
            if skippedPaths.paths.contains(fileURL.path) {
                enumerator.skipDescendants()
                continue
            }
            
            // Check if any parent path was skipped
            var shouldSkip = false
            for skippedPath in skippedPaths.paths {
                if fileURL.path.hasPrefix(skippedPath + "/") || fileURL.path == skippedPath {
                    shouldSkip = true
                    break
                }
            }
            if shouldSkip {
                continue
            }
            
            // Skip excluded paths
            if exclusionManager.shouldExclude(fileURL) {
                enumerator.skipDescendants()
                continue
            }
            
            // Skip SIP-protected paths
            if SIPDetector.isSIPProtected(fileURL) {
                enumerator.skipDescendants()
                continue
            }
            
            // Skip /Volumes in entire disk mode
            if mode == .entireDisk && fileURL.path.hasPrefix("/Volumes/") {
                enumerator.skipDescendants()
                continue
            }
            
            // Only count files, not directories
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues?.isDirectory != true {
                count += 1
            }
            
            // Update progress indicator during counting
            if count % 1000 == 0 {
                await MainActor.run {
                    currentPath = "Counting files... \(fileURL.path)"
                }
            }
        }
        
        return count
    }
    
    private func performScan(directory: URL, mode: ScanMode) async throws -> [FileNode] {
        var files: [FileNode] = []
        let fileManager = FileManager.default
        
        // Check if path is valid
        guard fileManager.fileExists(atPath: directory.path) else {
            throw AppError.invalidPath(directory)
        }
        
        // Check if path should be excluded
        if exclusionManager.shouldExclude(directory) {
            logger.info("Skipping excluded path: \(directory.path)")
            return []
        }
        
        // Skip SIP-protected paths
        if SIPDetector.isSIPProtected(directory) {
            logger.warning("Skipping SIP-protected path: \(directory.path)")
            return []
        }
        
        // Handle /Volumes skipping in entire disk mode
        if mode == .entireDisk && directory.path == "/Volumes" {
            logger.info("Skipping /Volumes in entire disk mode")
            return []
        }
        
        // Phase 1: Count files for accurate progress
        await MainActor.run {
            currentPath = "Counting files..."
        }
        logger.info("Starting file count phase")
        let totalFiles = try await countFiles(in: directory, mode: mode)
        await MainActor.run {
            totalFilesToScan = totalFiles
        }
        logger.info("Found \(totalFiles) files to scan")
        
        if totalFiles == 0 {
            logger.warning("No files found to scan")
            return []
        }
        
        // Phase 2: Actual scan
        await MainActor.run {
            currentPath = "Scanning files..."
        }
        logger.info("Starting scan phase")
        
        // Use a class wrapper to ensure the set is shared between closure and outer scope
        class SkippedPathsTracker {
            var paths = Set<String>()
        }
        let skippedPaths = SkippedPathsTracker()
        
        // Create enumerator with better error handling
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey, .creationDateKey, .isPackageKey],
            options: [.skipsHiddenFiles],  // Don't skip packages - we need to scan apps!
            errorHandler: { url, error in
                let nsError = error as NSError
                
                // Handle permission errors - track path and continue scanning
                if nsError.code == NSFileReadNoPermissionError {
                    self.logger.warning("Permission denied: \(url.path) - will skip")
                    skippedPaths.paths.insert(url.path)
                    return true // Continue enumeration, we'll skip this path in the loop
                }
                
                // Handle other errors - log but continue
                self.logger.debug("Error enumerating \(url.path): \(error.localizedDescription)")
                skippedPaths.paths.insert(url.path)
                return true // Continue enumeration for all errors
            }
        ) else {
            throw AppError.invalidPath(directory)
        }
        
        // Scan files
        var scannedCount = 0
        var totalBytesScanned: Int64 = 0  // Accumulate locally for performance
        var lastProgressUpdate = Date()
        let progressUpdateInterval: TimeInterval = 0.1 // Update every 100ms
        
        while let fileURL = enumerator.nextObject() as? URL {
            // Check for cancellation frequently
            try Task.checkCancellation()
            
            // Yield every 50 files to keep UI responsive
            if scannedCount % 50 == 0 {
                await Task.yield()
            }
            
            // Skip paths that had errors
            if skippedPaths.paths.contains(fileURL.path) {
                enumerator.skipDescendants()
                continue
            }
            
            // Check if any parent path was skipped
            var shouldSkip = false
            for skippedPath in skippedPaths.paths {
                if fileURL.path.hasPrefix(skippedPath + "/") || fileURL.path == skippedPath {
                    shouldSkip = true
                    break
                }
            }
            if shouldSkip {
                continue
            }
            
            // Skip excluded paths
            if exclusionManager.shouldExclude(fileURL) {
                enumerator.skipDescendants()
                continue
            }
            
            // Skip /Volumes in entire disk mode
            if mode == .entireDisk && fileURL.path.hasPrefix("/Volumes/") {
                enumerator.skipDescendants()
                continue
            }
            
            // Update progress
            scannedCount += 1
            
            // Get file attributes with error handling
            let resourceValues: URLResourceValues?
            do {
                resourceValues = try fileURL.resourceValues(forKeys: [
                    .fileSizeKey,
                    .isDirectoryKey,
                    .contentModificationDateKey,
                    .creationDateKey,
                    .isPackageKey,
                    .totalFileSizeKey
                ])
            } catch {
                // Skip files we can't read
                logger.debug("Cannot read resource values for \(fileURL.path): \(error.localizedDescription)")
                continue
            }
            
            let isDirectory = resourceValues?.isDirectory ?? false
            let isPackage = resourceValues?.isPackage ?? false
            let dateModified = resourceValues?.contentModificationDate ?? Date()
            let dateCreated = resourceValues?.creationDate ?? Date()
            let isSIPProtected = SIPDetector.isSIPProtected(fileURL)
            
            // For packages (.app, .framework, etc.), get total size and skip descendants
            var size: Int64
            if isPackage && isDirectory {
                // Get total package size (includes all contents)
                size = Int64(resourceValues?.totalFileSize ?? resourceValues?.fileSize ?? 0)
                
                // If totalFileSize is 0, calculate it manually
                if size == 0 {
                    size = calculateDirectorySize(at: fileURL)
                }
                
                // Skip descending into package
                enumerator.skipDescendants()
            } else {
                size = Int64(resourceValues?.fileSize ?? 0)
            }
            
            // Skip SIP-protected files
            if isSIPProtected {
                logger.debug("Skipping SIP-protected file: \(fileURL.path)")
                continue
            }
            
            let fileNode = FileNode(
                path: fileURL,
                name: fileURL.lastPathComponent,
                size: size,
                isDirectory: isDirectory,
                dateModified: dateModified,
                dateCreated: dateCreated,
                isSIPProtected: isSIPProtected
            )
            
            files.append(fileNode)
            
            // Accumulate bytes locally (fast, no MainActor overhead)
            totalBytesScanned += size
            
            // Update UI progress periodically (every 100ms or every 100 files)
            let now = Date()
            if now.timeIntervalSince(lastProgressUpdate) >= progressUpdateInterval || scannedCount % 100 == 0 {
                let currentBytesScanned = totalBytesScanned  // Capture for closure
                await MainActor.run {
                    currentPath = fileURL.path
                    filesScanned = scannedCount
                    bytesScanned = currentBytesScanned  // Sync accumulated total
                    
                    if totalFilesToScan > 0 {
                        progress = min(0.99, Double(scannedCount) / Double(totalFilesToScan))
                    } else {
                        // Fallback if count failed
                        progress = min(0.99, Double(scannedCount) / 10000.0)
                    }
                }
                lastProgressUpdate = now
            }
        }
        
        // Final sync - ensure bytesScanned is accurate
        await MainActor.run {
            bytesScanned = totalBytesScanned
            progress = 1.0
        }
        logger.info("Scan complete: \(files.count) files scanned")
        return files
    }
    
    /// Calculates total size of a directory (for packages like .app)
    private func calculateDirectorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  let isDirectory = resourceValues.isDirectory,
                  !isDirectory else {
                continue
            }
            totalSize += Int64(resourceValues.fileSize ?? 0)
        }
        
        return totalSize
    }
    
    func cancel() {
        logger.info("Cancelling scan...")
        scanTask?.cancel()
        scanTask = nil
        Task { @MainActor in
            isScanning = false
            progress = 0.0
        }
        logger.info("Scan cancelled")
    }
}

// MARK: - Scan Mode
enum ScanMode: Equatable {
    case entireDisk    // Scan root but skip /Volumes
    case specificFolder(URL)  // Scan specific folder
}

