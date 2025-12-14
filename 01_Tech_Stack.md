# Technical Specifications

## 1. Stack & Architecture
* **Language:** Swift 6.0
* **UI Framework:** SwiftUI (focus on Cards, Grids, and friendly iconography).
* **Concurrency:** Heavy use of `Task` and `async/await` to keep the UI buttery smooth while scanning GBs of data.
* **Minimum macOS Version:** macOS 13.0 (Ventura) - Required for Swift 6.0 features and modern SwiftUI APIs
* **Target macOS Version:** macOS 26.0 (Tahoe) - Latest macOS as of 2025
* **Architecture Pattern:** MVVM (Model-View-ViewModel) with SwiftUI

## 2. Data Models (Refined for "Categories")
We need a layer above raw files to group them into "Smart Categories."

```swift
enum CategoryType {
    case systemJunk
    case largeFiles
    case developer // The "Hidden" power feature
    case unusedApps
}

struct SmartCategory {
    let type: CategoryType
    let title: String
    let icon: String // SF Symbol name
    var totalSize: Int64
    var items: [FileNode]
}

// Additional Models Needed
struct FileNode: Identifiable {
    let id: UUID
    let path: URL
    let name: String
    let size: Int64
    let isDirectory: Bool
    let dateModified: Date
    var children: [FileNode]? // For directories
}

enum SafetyLevel {
    case safe      // System caches, logs
    case caution   // Downloads, large files
    case dangerous // System files, app bundles
}
```

## 3. Key Services & Components
* **FileScannerService**: Async file system enumeration with progress reporting
* **CategoryManager**: Logic layer that categorizes files into smart buckets
* **DeveloperDetector**: Checks for Xcode/Docker/Node.js to enable dev features
* **DeletionService**: Safe file deletion with trash support and undo capability
* **PermissionManager**: Handles Full Disk Access requests and fallbacks

## 4. Performance Considerations
* Use `FileManager.enumerator` with async/await for streaming file enumeration
* Implement scan cancellation with `Task` cancellation tokens
* Cache scan results using SwiftData or Core Data
* Background scanning to keep UI responsive
* Progress reporting: bytes scanned, files found, current directory

## 5. Permissions & Security
* **Full Disk Access**: Required for system-wide scanning - will request from user (no App Sandbox)
* **Graceful Fallback**: Allow user-selected directory scanning if permission denied
* **Privacy**: All processing local-only, no cloud uploads

## 6. Volume Type Detection & Network Drive Handling
**Critical**: Network drives can freeze the UI. Must detect volume type before scanning.

```swift
enum VolumeType {
    case internalSSD
    case externalUSB
    case network  // Risk of slow scan
}

// Helper to identify drive types
func getVolumeType(url: URL) -> VolumeType {
    let values = try? url.resourceValues(forKeys: [.volumeIsInternalKey, .volumeIsLocalKey])
    
    if values?.volumeIsInternalKey == true { 
        return .internalSSD 
    }
    
    if values?.volumeIsLocalKey == true { 
        return .externalUSB 
    }
    
    return .network // Risk of slow scan
}
```

**Implementation Rules**:
- **External USBs**: Treat as normal but add "Eject" warning
- **Network Drives**: Default to OFF. If user manually selects, show warning: "Scanning network volumes can be slow"

## 7. Scanning Modes
* **Entire Disk Mode**: Main "Scan" button targets `/` (root) but skips `/Volumes`
* **Specific Folder Mode**: Support drag-and-drop or folder picker for targeted scanning
* Essential for developers cleaning specific project folders

## 8. System Integrity Protection (SIP) Handling
**Critical**: Cannot delete SIP-protected files even with Full Disk Access.

**Pre-Flight Blacklist** (don't wait for error):
- Hardcode known SIP paths: `/System`, `/usr` (except `/usr/local`), `/bin`, `/sbin`
- Use `stat` C-function to check file flags for `SF_RESTRICTED` flag
- If file has `SF_RESTRICTED`, it's SIP-protected

**UI Feedback**:
- If user manually selects SIP-protected file, show "Lock" icon
- Disable Delete button for SIP-protected files
- Show tooltip: "This file is protected by System Integrity Protection"

## 9. Visual Disk Map (DaisyDisk-like)
* **Required Feature**: Sunburst or treemap visualization
* **Framework**: Consider using SwiftUI Canvas or Core Graphics for rendering
* **Interaction**: Click segments to drill down into directories
* **Performance**: Render progressively as scan completes