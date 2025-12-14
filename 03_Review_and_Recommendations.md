# Project Review & Recommendations

## Overall Assessment
Your plan is well-structured with a clear vision for a user-friendly disk space analyzer. The "Progressive Disclosure" philosophy and smart developer detection are excellent differentiators.

## Strengths ✅

1. **Clear Product Vision**: The freemium model with smart categorization is well thought out
2. **User-Centric Design**: Dashboard-first approach is much more approachable than raw file trees
3. **Smart Developer Detection**: Automatic feature discovery is a great UX touch
4. **Modern Tech Stack**: Swift 6.0 + SwiftUI is the right choice for native macOS apps
5. **Phased Implementation**: Good breakdown into manageable phases

## Critical Issues & Recommendations

### 1. macOS Version Clarification ✅
**Confirmed**: macOS 26 (Tahoe) is the current latest version as of 2025
- Target the latest macOS 26 APIs and features
- Ensure your minimum deployment target is appropriate (recommend macOS 13+ for Swift 6.0 features)
- Update your tech stack to specify minimum macOS version

**Recommendation**: 
- Set minimum deployment target to **macOS 13.0** (Ventura) or **macOS 14.0** (Sonoma) for broad compatibility
- Target macOS 26 (Tahoe) for latest features and APIs
- This ensures compatibility with Swift 6.0 features while maintaining broad user base

### 2. Missing Technical Components

#### A. File System Access & Permissions
**Missing**: Detailed permission strategy
- Full Disk Access is required for system-wide scanning
- Need to handle permission denial gracefully
- Consider using `FileManager` with proper error handling
- May need `NSOpenPanel` for user-selected directory scanning as fallback

#### B. Performance & Memory Management
**Missing**: Strategy for handling large scans
- For multi-TB drives, you'll need:
  - Streaming file enumeration (avoid loading all files into memory)
  - Progress reporting with cancellation support
  - Background scanning with `Task` and proper cancellation tokens
  - Consider using `FileManager.enumerator(at:includingPropertiesForKeys:options:)` with async/await

#### C. Data Persistence
**Missing**: How to store scan results
- Consider Core Data or SwiftData for scan history
- Cache recent scans to avoid re-scanning on app launch
- Store user preferences (excluded paths, favorite categories)

#### D. Safety & Undo
**Missing**: Critical for a disk cleaner
- Implement trash/recycle instead of permanent delete
- Add undo functionality (macOS supports this via `NSFileManager.trashItem`)
- Confirmation dialogs for large deletions
- "Dry run" mode to preview what would be deleted

### 3. Enhanced Data Models

Your current `SmartCategory` model is good, but consider:

```swift
// Enhanced FileNode
struct FileNode: Identifiable {
    let id: UUID
    let path: URL
    let name: String
    let size: Int64
    let isDirectory: Bool
    let dateModified: Date
    let dateCreated: Date
    var children: [FileNode]? // For directories
    var category: CategoryType?
}

// Add safety levels
enum SafetyLevel {
    case safe      // System caches, logs
    case caution   // Downloads, large files
    case dangerous // System files, app bundles
}

struct SmartCategory {
    let type: CategoryType
    let title: String
    let icon: String
    let safetyLevel: SafetyLevel
    var totalSize: Int64
    var itemCount: Int
    var items: [FileNode]
    var lastScanned: Date?
}
```

### 4. Missing Features from DaisyDisk

Consider adding:
- **Visual Disk Map**: Sunburst or treemap visualization (like DaisyDisk's signature feature)
- **Quick Preview**: Preview files before deletion
- **Duplicate Finder**: Find duplicate files (high-value feature)
- **Scan History**: Track space saved over time
- **Exclusions**: Let users exclude specific folders from scans

### 5. Implementation Plan Enhancements

#### Phase 0: Foundation (Add this)
- [ ] Set up Xcode project with proper bundle ID and entitlements
- [ ] Configure App Sandbox permissions (or document why not using sandbox)
- [ ] Set up proper error handling framework
- [ ] Create logging system for debugging

#### Phase 1: Enhanced Scanner
- [ ] Add cancellation support to `FileScannerService`
- [ ] Implement progress reporting (bytes scanned, files found)
- [ ] Add path exclusion list
- [ ] Implement scan caching/resume capability

#### Phase 2: Enhanced Dashboard
- [ ] Add empty state (when no scan performed)
- [ ] Add scan progress indicator
- [ ] Implement card animations (SwiftUI transitions)
- [ ] Add "Last scanned: X minutes ago" timestamp

#### Phase 3: Enhanced Detail Views
- [ ] Add search/filter within category
- [ ] Add sorting options (size, date, name)
- [ ] Add multi-select with keyboard shortcuts
- [ ] Add preview pane (Quick Look integration)

#### Phase 4: Enhanced Uninstaller
- [ ] Add app usage detection (last opened date)
- [ ] Show app size calculation (including associated files)
- [ ] Add "Recently Used" vs "Never Used" filtering
- [ ] Integration with LaunchServices database

#### Phase 5: Enhanced Onboarding
- [ ] Add accessibility support (VoiceOver, Dynamic Type)
- [ ] Add dark mode support (automatic with SwiftUI)
- [ ] Add keyboard navigation
- [ ] Add help/tooltips system

### 6. Security & Privacy Considerations

**Critical**:
- Never scan or access user's personal files without explicit permission
- Implement proper sandboxing where possible
- Encrypt any cached scan data
- Add privacy policy explaining data collection (if any)
- Consider local-only processing (no cloud uploads)

### 7. Testing Strategy (Missing)

Add:
- Unit tests for `FileScannerService`
- Unit tests for `CategoryManager`
- UI tests for critical user flows
- Performance tests for large directory scans
- Edge case testing (permission denied, network drives, etc.)

### 8. Monetization Technical Details

Consider:
- StoreKit 2 for in-app purchases
- License validation (if doing lifetime purchase)
- Feature flags to enable/disable Pro features
- Analytics (privacy-respecting) to understand feature usage

## Recommended File Structure

```
SpaceSaver/
├── SpaceSaver/
│   ├── App/
│   │   ├── SpaceSaverApp.swift
│   │   └── AppDelegate.swift (if needed)
│   ├── Models/
│   │   ├── FileNode.swift
│   │   ├── SmartCategory.swift
│   │   └── ScanResult.swift
│   ├── Services/
│   │   ├── FileScannerService.swift
│   │   ├── CategoryManager.swift
│   │   ├── DeveloperDetector.swift
│   │   └── DeletionService.swift
│   ├── Views/
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   └── CategoryCard.swift
│   │   ├── Scanner/
│   │   │   ├── ScannerView.swift
│   │   │   └── ProgressView.swift
│   │   ├── Detail/
│   │   │   ├── CategoryDetailView.swift
│   │   │   └── FileListView.swift
│   │   └── Onboarding/
│   │       ├── WelcomeView.swift
│   │       └── PermissionsView.swift
│   ├── Utilities/
│   │   ├── FileSizeFormatter.swift
│   │   ├── PathExtensions.swift
│   │   └── Constants.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── Localizable.strings
├── SpaceSaverTests/
└── SpaceSaverUITests/
```

## Next Steps

1. ✅ **macOS version confirmed** - Targeting macOS 26 (Tahoe)
2. **Add Phase 0** to implementation plan
3. **Expand data models** with safety levels
4. **Create detailed permission handling strategy**
5. **Design the visual disk map** (if including DaisyDisk-like visualization)
6. **Set up Xcode project** with proper configuration

## Design Decisions & Answers

1. **App Sandbox**: ❌ No. Will request Full Disk Access from user instead of using App Sandbox (which would limit Full Disk Access capabilities).

2. **Visual Disk Map**: ✅ Yes. Need visual disk map like DaisyDisk (sunburst/treemap visualization) in addition to the dashboard view.

3. **Network Drives & External Volumes**: 
   - **Risk**: Scanning network drives (NAS/SMB) is very slow and can freeze the UI
   - **Solution**: Detect volume type before scanning using `URLResourceKey` (`.volumeIsLocalKey`, `.volumeIsInternalKey`)
   - **External USBs**: Treat as normal but add "Eject" warning
   - **Network Drives**: Default to OFF. If user manually selects, show warning: "Scanning network volumes can be slow"
   - See implementation in `01_Tech_Stack.md` for `VolumeType` detection

4. **Scanning Modes**: ✅ Support both
   - **Entire Disk Mode**: Main "Scan" button targets `/` (root) but skips `/Volumes`
   - **Specific Folder Mode**: Essential for developers who want to clean specific project folders or external drives
   - Allow user to drag-and-drop folders or use folder picker

5. **System Integrity Protection (SIP)**:
   - **Hard Truth**: Cannot delete SIP-protected files (e.g., `/System/Applications/Safari.app`) even with Full Disk Access
   - **Strategy**: Pre-flight blacklist - detect SIP paths before showing to user
   - **Blacklist**: Hardcode known SIP paths: `/System`, `/usr` (except `/usr/local`), `/bin`, `/sbin`
   - **Pro Check**: Use `stat` C-function to check file flags. If file has `SF_RESTRICTED` flag, it's SIP-protected
   - **UI Feedback**: If user manually selects SIP-protected file, show "Lock" icon and disable Delete button

---

**Overall**: Great foundation! Focus on adding the missing technical details, especially around permissions, performance, and safety features.

