//
//  DeveloperDetector.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation

class DeveloperDetector {
    /// Checks if developer tools are present on the system
    static func checkForDevTools() -> Bool {
        // Check for Xcode
        if FileManager.default.fileExists(atPath: "/Applications/Xcode.app") {
            return true
        }
        
        // Check for Docker
        if FileManager.default.fileExists(atPath: "/Applications/Docker.app") {
            return true
        }
        
        // Check for common developer directories
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let commonDevPaths = [
            homeDir.appendingPathComponent("node_modules"),
            homeDir.appendingPathComponent(".git"),
            homeDir.appendingPathComponent("Library/Developer")
        ]
        
        for path in commonDevPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return true
            }
        }
        
        return false
    }
    
    /// Checks if node_modules exist during a scan
    static func hasNodeModules(in files: [FileNode]) -> Bool {
        return files.contains { $0.path.path.contains("node_modules") }
    }
}

