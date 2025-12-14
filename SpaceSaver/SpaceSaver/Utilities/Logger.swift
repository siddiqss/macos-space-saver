//
//  Logger.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation
import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.space-saver"
    
    static let scanner = Logger(subsystem: subsystem, category: "scanner")
    static let deletion = Logger(subsystem: subsystem, category: "deletion")
    static let category = Logger(subsystem: subsystem, category: "category")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let permission = Logger(subsystem: subsystem, category: "permission")
}

