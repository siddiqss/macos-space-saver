//
//  VolumeType.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation

enum VolumeType {
    case internalSSD
    case externalUSB
    case network  // Risk of slow scan
    
    var displayName: String {
        switch self {
        case .internalSSD: return "Internal Drive"
        case .externalUSB: return "External Drive"
        case .network: return "Network Drive"
        }
    }
    
    var warningMessage: String? {
        switch self {
        case .internalSSD: return nil
        case .externalUSB: return "Make sure to eject this drive safely after scanning."
        case .network: return "Scanning network volumes can be slow."
        }
    }
}

// MARK: - Volume Detection Helper
struct VolumeDetector {
    /// Identifies the type of volume at the given URL
    static func getVolumeType(url: URL) -> VolumeType {
        let values = try? url.resourceValues(forKeys: [.volumeIsInternalKey, .volumeIsLocalKey])
        
        if values?.volumeIsInternal == true {
            return .internalSSD
        }
        
        if values?.volumeIsLocal == true {
            return .externalUSB
        }
        
        return .network // Risk of slow scan
    }
    
    /// Checks if a URL is on a network volume
    static func isNetworkVolume(_ url: URL) -> Bool {
        return getVolumeType(url: url) == .network
    }
}

