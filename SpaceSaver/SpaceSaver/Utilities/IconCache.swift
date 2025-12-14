//
//  IconCache.swift
//  SpaceSaver
//
//  Created on 2025
//

import AppKit
import Foundation
import Combine

@MainActor
class IconCache: ObservableObject {
    static let shared = IconCache()
    
    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "com.spacesaver.iconcache", qos: .userInitiated)
    
    private init() {}
    
    func icon(for path: String) async -> NSImage? {
        // Check cache first
        if let cached = cache[path] {
            return cached
        }
        
        // Load icon asynchronously
        return await withCheckedContinuation { continuation in
            queue.async {
                // Check if file exists
                guard FileManager.default.fileExists(atPath: path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Load icon (this is still synchronous but on background queue)
                let icon = NSWorkspace.shared.icon(forFile: path)
                
                // Cache on main actor and return
                Task { @MainActor in
                    self.cache[path] = icon
                }
                continuation.resume(returning: icon)
            }
        }
    }
    
    func clearCache() {
        cache.removeAll()
    }
}

