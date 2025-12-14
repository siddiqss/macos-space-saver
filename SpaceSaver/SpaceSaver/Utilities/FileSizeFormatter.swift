//
//  FileSizeFormatter.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation

struct FileSizeFormatter {
    static let shared = FileSizeFormatter()
    
    private let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter
    }()
    
    func string(from bytes: Int64) -> String {
        return formatter.string(fromByteCount: bytes)
    }
    
    func string(from bytes: Int64, style: ByteCountFormatter.CountStyle) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = style
        return formatter.string(fromByteCount: bytes)
    }
    
    // Static convenience method
    static func format(bytes: Int64) -> String {
        return shared.string(from: bytes)
    }
}

extension Int64 {
    var formattedFileSize: String {
        return FileSizeFormatter.shared.string(from: self)
    }
}

