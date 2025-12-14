//
//  SIPDetector.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation

struct SIPDetector {
    /// Known SIP-protected paths that should be blacklisted
    private static let sipProtectedPaths: Set<String> = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/var/db",
        "/private/var/db"
    ]
    
    /// Paths that are exceptions to the SIP protection (allowed)
    private static let sipExceptions: Set<String> = [
        "/usr/local"  // User-installed software in /usr/local is allowed
    ]
    
    /// Checks if a path is in the pre-flight blacklist of known SIP-protected paths
    static func isSIPProtectedPath(_ url: URL) -> Bool {
        let path = url.path
        
        // Check exceptions first
        for exception in sipExceptions {
            if path.hasPrefix(exception) {
                return false
            }
        }
        
        // Check blacklist
        for protectedPath in sipProtectedPaths {
            if path.hasPrefix(protectedPath) {
                return true
            }
        }
        
        return false
    }
    
    /// Checks if a file has the SF_RESTRICTED flag using stat
    static func hasSIPRestrictedFlag(_ url: URL) -> Bool {
        let path = url.path
        
        // Use stat to check file flags
        var statInfo = stat()
        guard stat(path, &statInfo) == 0 else {
            return false
        }
        
        // Check for SF_RESTRICTED flag (0x00080000)
        let restrictedFlag: UInt32 = 0x00080000
        return (statInfo.st_flags & restrictedFlag) != 0
    }
    
    /// Comprehensive check: combines path blacklist and flag check
    static func isSIPProtected(_ url: URL) -> Bool {
        // First check the pre-flight blacklist
        if isSIPProtectedPath(url) {
            return true
        }
        
        // Then check the actual file flag
        return hasSIPRestrictedFlag(url)
    }
}

