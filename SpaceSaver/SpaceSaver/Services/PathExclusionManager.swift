//
//  PathExclusionManager.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation
import OSLog

/// Manages path exclusions for file scanning
class PathExclusionManager {
    static let shared = PathExclusionManager()
    
    private let logger = Logger(subsystem: "com.spacesaver", category: "exclusion")
    
    /// Default paths to exclude from scanning
    private let defaultExclusions: [String] = [
        "/Volumes",           // Mounted volumes (handled separately)
        "/System/Volumes",    // System volumes
        "/private/var/vm",    // Virtual memory
        "/private/var/folders", // Temporary folders
        "/.Spotlight-V100",   // Spotlight index
        "/.fseventsd",        // File system events
        "/.Trashes",          // Trash folders
        "/.DocumentRevisions-V100", // Document revisions
    ]
    
    /// User-configurable exclusions (stored in UserDefaults)
    private var userExclusions: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: "pathExclusions") ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "pathExclusions")
        }
    }
    
    /// All exclusions (default + user)
    var allExclusions: [String] {
        return defaultExclusions + userExclusions
    }
    
    /// Checks if a path should be excluded
    func shouldExclude(_ path: String) -> Bool {
        let normalizedPath = (path as NSString).standardizingPath
        
        for exclusion in allExclusions {
            let normalizedExclusion = (exclusion as NSString).standardizingPath
            
            // Exact match
            if normalizedPath == normalizedExclusion {
                logger.debug("Excluding exact match: \(path)")
                return true
            }
            
            // Prefix match (path starts with exclusion)
            if normalizedPath.hasPrefix(normalizedExclusion + "/") || 
               normalizedPath == normalizedExclusion {
                logger.debug("Excluding path prefix: \(path) (matches \(exclusion))")
                return true
            }
        }
        
        return false
    }
    
    /// Checks if a URL should be excluded
    func shouldExclude(_ url: URL) -> Bool {
        return shouldExclude(url.path)
    }
    
    /// Adds a user exclusion
    func addUserExclusion(_ path: String) {
        var exclusions = userExclusions
        if !exclusions.contains(path) {
            exclusions.append(path)
            userExclusions = exclusions
            logger.info("Added user exclusion: \(path)")
        }
    }
    
    /// Removes a user exclusion
    func removeUserExclusion(_ path: String) {
        var exclusions = userExclusions
        exclusions.removeAll { $0 == path }
        userExclusions = exclusions
        logger.info("Removed user exclusion: \(path)")
    }
    
    /// Clears all user exclusions
    func clearUserExclusions() {
        userExclusions = []
        logger.info("Cleared all user exclusions")
    }
}

