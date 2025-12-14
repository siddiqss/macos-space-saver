//
//  AppEnumerationService.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation
import AppKit
import OSLog
import Combine

/// Service for enumerating installed applications and finding associated files
@MainActor
final class AppEnumerationService: ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var progress: Double = 0.0
    @Published var currentApp: String = ""
    @Published var appsFound: Int = 0
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.spacesaver.app", category: "AppEnumeration")
    private let fileManager = FileManager.default
    
    // Common application directories
    private let appDirectories = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        "~/Applications"
    ]
    
    // Common associated file locations
    private let associatedFilePaths = [
        "~/Library/Application Support",
        "~/Library/Caches",
        "~/Library/Preferences",
        "~/Library/Logs",
        "~/Library/Saved Application State"
    ]
    
    // MARK: - Public Methods
    
    /// Scan for all installed applications
    func scanApplications() async throws -> [AppInfo] {
        isScanning = true
        progress = 0.0
        appsFound = 0
        
        defer {
            isScanning = false
            progress = 1.0
        }
        
        logger.info("🔍 Starting application scan...")
        
        var allApps: [AppInfo] = []
        let expandedDirs = appDirectories.map { NSString(string: $0).expandingTildeInPath }
        
        // Phase 1: Find all .app bundles (20% progress)
        var appPaths: [String] = []
        for directory in expandedDirs {
            let url = URL(fileURLWithPath: directory)
            guard fileManager.fileExists(atPath: directory) else { continue }
            
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                
                let apps = contents.filter { $0.pathExtension == "app" }
                appPaths.append(contentsOf: apps.map { $0.path })
            } catch {
                logger.warning("⚠️ Could not scan directory \(directory): \(error.localizedDescription)")
            }
        }
        
        progress = 0.2
        logger.info("📦 Found \(appPaths.count) application bundles")
        
        // Phase 2: Process each app (20% to 100%)
        let totalApps = appPaths.count
        for (index, appPath) in appPaths.enumerated() {
            do {
                if let appInfo = try await processApplication(at: appPath) {
                    allApps.append(appInfo)
                    appsFound = allApps.count
                    currentApp = appInfo.name
                }
            } catch {
                logger.warning("⚠️ Could not process app at \(appPath): \(error.localizedDescription)")
            }
            
            // Update progress
            let denominator = max(totalApps, 1)
            progress = 0.2 + (0.8 * Double(index + 1) / Double(denominator))
            
            // Yield periodically for UI responsiveness
            if index % 10 == 0 {
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
        }
        
        logger.info("✅ Scan complete. Found \(allApps.count) applications")
        return allApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Process a single application and find its associated files
    private func processApplication(at path: String) async throws -> AppInfo? {
        let url = URL(fileURLWithPath: path)
        
        // Get bundle
        guard let bundle = Bundle(url: url) else {
            logger.warning("⚠️ Could not create bundle for \(path)")
            return nil
        }
        
        // Get app name
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        
        // Get bundle identifier
        guard let bundleID = bundle.bundleIdentifier else {
            logger.warning("⚠️ No bundle identifier for \(appName)")
            return nil
        }
        
        // Get version
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        
        // Get app size
        let appSize = try? directorySize(at: url)
        
        // Get icon
        let icon = getAppIcon(for: url)
        
        // Check if app is currently running
        let isRunning = isAppCurrentlyRunning(bundleID: bundleID)
        
        // Get last used date (will return Date() if currently running)
        let lastUsed = getLastUsedDate(for: path, bundleID: bundleID)
        
        // Find associated files
        let associatedFiles = await findAssociatedFiles(for: bundleID, appName: appName)
        
        return AppInfo(
            name: appName,
            bundleIdentifier: bundleID,
            bundlePath: path,
            version: version,
            size: appSize ?? 0,
            lastUsedDate: lastUsed,
            icon: icon,
            associatedFiles: associatedFiles,
            isCurrentlyRunning: isRunning
        )
    }
    
    /// Find associated files for an application
    func findAssociatedFiles(for bundleID: String, appName: String) async -> [AssociatedFile] {
        var files: [AssociatedFile] = []
        let expandedPaths = associatedFilePaths.map { NSString(string: $0).expandingTildeInPath }
        
        for basePath in expandedPaths {
            guard fileManager.fileExists(atPath: basePath) else { continue }
            
            let baseURL = URL(fileURLWithPath: basePath)
            let fileType = determineFileType(from: basePath)
            
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: baseURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
                
                // Look for files/folders matching bundle ID or app name
                for item in contents {
                    let itemName = item.lastPathComponent.lowercased()
                    let matchesBundleID = itemName.contains(bundleID.lowercased())
                    let matchesAppName = itemName.contains(appName.lowercased().replacingOccurrences(of: " ", with: ""))
                    
                    if matchesBundleID || matchesAppName {
                        let size = try? directorySize(at: item)
                        let modifiedDate = try? item.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                        
                        let associatedFile = AssociatedFile(
                            path: item.path,
                            size: size ?? 0,
                            type: fileType,
                            modifiedDate: modifiedDate
                        )
                        
                        files.append(associatedFile)
                    }
                }
            } catch {
                logger.warning("⚠️ Could not scan \(basePath): \(error.localizedDescription)")
            }
        }
        
        return files
    }
    
    // MARK: - Helper Methods
    
    /// Calculate directory size recursively
    private func directorySize(at url: URL) throws -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            
            if resourceValues.isDirectory == false {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }
        
        return totalSize
    }
    
    /// Get app icon
    private func getAppIcon(for url: URL) -> NSImage? {
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    /// Get last used date for an app using multiple reliable sources
    private func getLastUsedDate(for path: String, bundleID: String) -> Date? {
        // Priority 1: Check if app is currently running (most reliable)
        if isAppCurrentlyRunning(bundleID: bundleID) {
            return Date() // Currently running = active now
        }
        
        // Priority 2: Check Saved Application State (updated when app runs)
        if let savedStateDate = getSavedStateDate(for: bundleID) {
            return savedStateDate
        }
        
        // Priority 3: Check preferences file modification date (updated when app runs)
        if let prefsDate = getPreferencesDate(for: bundleID) {
            return prefsDate
        }
        
        // Priority 4: Check Launch Services for recently used apps
        if let launchServicesDate = getLaunchServicesDate(for: bundleID) {
            return launchServicesDate
        }
        
        // Priority 5: Check app bundle modification date (least reliable, but as fallback)
        let url = URL(fileURLWithPath: path)
        if let resourceValues = try? url.resourceValues(forKeys: [.contentAccessDateKey, .contentModificationDateKey]) {
            return resourceValues.contentAccessDate ?? resourceValues.contentModificationDate
        }
        
        return nil
    }
    
    /// Check if an app is currently running
    private func isAppCurrentlyRunning(bundleID: String) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == bundleID
        }
    }
    
    /// Get the most recent modification date from Saved Application State
    private func getSavedStateDate(for bundleID: String) -> Date? {
        let savedStatePath = NSString(string: "~/Library/Saved Application State").expandingTildeInPath
        let savedStateURL = URL(fileURLWithPath: savedStatePath)
        
        guard fileManager.fileExists(atPath: savedStatePath) else { return nil }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: savedStateURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            // Find folders matching bundle ID
            let matchingFolders = contents.filter { url in
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
                return resourceValues?.isDirectory == true && 
                       url.lastPathComponent.contains(bundleID)
            }
            
            // Get the most recent modification date
            var mostRecentDate: Date?
            for folder in matchingFolders {
                if let resourceValues = try? folder.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modDate = resourceValues.contentModificationDate {
                    if mostRecentDate == nil || modDate > mostRecentDate! {
                        mostRecentDate = modDate
                    }
                }
            }
            
            return mostRecentDate
        } catch {
            logger.debug("Could not check saved state for \(bundleID): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get preferences file modification date
    private func getPreferencesDate(for bundleID: String) -> Date? {
        let prefsPath = NSString(string: "~/Library/Preferences").expandingTildeInPath
        let prefsURL = URL(fileURLWithPath: prefsPath)
        
        guard fileManager.fileExists(atPath: prefsPath) else { return nil }
        
        // Check for .plist file matching bundle ID
        let plistName = "\(bundleID).plist"
        let plistURL = prefsURL.appendingPathComponent(plistName)
        
        if fileManager.fileExists(atPath: plistURL.path) {
            if let resourceValues = try? plistURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = resourceValues.contentModificationDate {
                return modDate
            }
        }
        
        return nil
    }
    
    /// Get date from Launch Services (recently used apps)
    private func getLaunchServicesDate(for bundleID: String) -> Date? {
        // Use NSWorkspace to get recently used applications
        // This is a fallback method - Launch Services doesn't provide exact dates
        // but we can check if the app appears in recent items
        
        // For now, we'll use a simpler approach: check if there's a recent
        // reference to the app in the system. This is less reliable but better than nothing.
        
        // Note: macOS doesn't provide a direct API for this, so we'll rely on
        // the other methods (saved state, preferences) which are more reliable
        
        return nil
    }
    
    /// Determine file type from path
    private func determineFileType(from path: String) -> AssociatedFileType {
        let lowercasedPath = path.lowercased()
        
        if lowercasedPath.contains("application support") {
            return .applicationSupport
        } else if lowercasedPath.contains("preferences") {
            return .preferences
        } else if lowercasedPath.contains("caches") {
            return .caches
        } else if lowercasedPath.contains("logs") {
            return .logs
        } else if lowercasedPath.contains("saved application state") {
            return .savedState
        } else {
            return .other
        }
    }
    
    /// Delete application and its associated files
    func uninstallApp(_ app: AppInfo, includeAssociatedFiles: Bool = true) async throws {
        logger.info("🗑️ Uninstalling \(app.name)...")
        
        // Move app bundle to trash
        try await moveToTrash(path: app.bundlePath)
        
        // Move associated files to trash if requested
        if includeAssociatedFiles {
            for file in app.associatedFiles {
                do {
                    try await moveToTrash(path: file.path)
                } catch {
                    logger.warning("⚠️ Could not move associated file to trash: \(file.path)")
                    // Continue with other files even if one fails
                }
            }
        }
        
        logger.info("✅ Successfully uninstalled \(app.name)")
    }
    
    /// Move item to trash
    private func moveToTrash(path: String) async throws {
        let url = URL(fileURLWithPath: path)
        return try await Task.detached {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        }.value
    }
    
    /// Bulk uninstall multiple apps
    func bulkUninstall(apps: [AppInfo], includeAssociatedFiles: Bool = true) async throws {
        logger.info("🗑️ Bulk uninstalling \(apps.count) apps...")
        
        for app in apps {
            do {
                try await uninstallApp(app, includeAssociatedFiles: includeAssociatedFiles)
            } catch {
                logger.error("❌ Failed to uninstall \(app.name): \(error.localizedDescription)")
                throw error
            }
        }
        
        logger.info("✅ Bulk uninstall complete")
    }
}

