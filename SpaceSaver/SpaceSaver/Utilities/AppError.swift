//
//  AppError.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation

enum AppError: LocalizedError {
    case permissionDenied
    case permissionDeniedForPath(URL)
    case scanCancelled
    case fileNotFound(URL)
    case deletionFailed(URL, Error)
    case sipProtected(URL)
    case networkVolumeSlow(URL)
    case invalidPath(URL)
    case enumerationFailed(URL, Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Full Disk Access is required to scan your system. Please grant permission in System Settings."
        case .permissionDeniedForPath(let url):
            return "Permission denied for path: \(url.path). Full Disk Access may be required."
        case .scanCancelled:
            return "Scan was cancelled by user."
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        case .deletionFailed(let url, let error):
            return "Failed to delete \(url.lastPathComponent): \(error.localizedDescription)"
        case .sipProtected(let url):
            return "This file is protected by System Integrity Protection: \(url.path)"
        case .networkVolumeSlow(let url):
            return "Scanning network volumes can be very slow: \(url.path)"
        case .invalidPath(let url):
            return "Invalid path: \(url.path)"
        case .enumerationFailed(let url, let error):
            return "Failed to enumerate directory \(url.path): \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Go to System Settings > Privacy & Security > Full Disk Access and enable SpaceSaver."
        case .permissionDeniedForPath:
            return "Go to System Settings > Privacy & Security > Full Disk Access and enable SpaceSaver. The path may require additional permissions."
        case .scanCancelled:
            return nil
        case .fileNotFound:
            return "The file may have been moved or deleted."
        case .deletionFailed:
            return "Make sure you have permission to delete this file."
        case .sipProtected:
            return "SIP-protected files cannot be deleted for system security."
        case .networkVolumeSlow:
            return "Consider scanning local files instead, or be patient as network scans can take a long time."
        case .invalidPath:
            return "Please select a valid directory to scan."
        case .enumerationFailed:
            return "Check that you have permission to access this directory. You may need to grant Full Disk Access."
        }
    }
    
    /// Checks if an NSError is a permission-related error
    static func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.code == NSFileReadNoPermissionError ||
               nsError.code == NSFileWriteNoPermissionError ||
               nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError
    }
}

