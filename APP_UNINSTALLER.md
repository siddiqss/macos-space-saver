# App Uninstaller - Implementation Summary

## Overview

The App Uninstaller is a comprehensive feature that allows users to discover, analyze, and uninstall applications along with their associated files. It provides detailed insights into app usage, size breakdown, and safe removal options.

## Features

### 1. App Discovery & Enumeration
- **Multi-directory scanning**: Scans `/Applications`, `/System/Applications`, `/System/Applications/Utilities`, and `~/Applications`
- **Bundle analysis**: Extracts app name, version, bundle identifier, and icon
- **Size calculation**: Recursively calculates app bundle size
- **Progress tracking**: Real-time progress updates during scanning

### 2. Usage Tracking
- **Last used detection**: Tracks last access/modification dates
- **Days since last use**: Calculates time since app was last opened
- **Usage status badges**:
  - **Active**: Used within 7 days (green)
  - **Recently Used**: Used within 30 days (blue)
  - **Seldom Used**: Used within 90 days (orange)
  - **Unused**: Not used in 90+ days (red)
  - **Unknown**: No usage data available (gray)

### 3. Associated File Detection
Automatically discovers related files in common locations:
- `~/Library/Application Support` - App data and support files
- `~/Library/Caches` - Cached data
- `~/Library/Preferences` - Preference files (.plist)
- `~/Library/Logs` - Application logs
- `~/Library/Saved Application State` - Saved state data

**Matching Strategy**:
- Matches files/folders by bundle identifier (e.g., `com.apple.dt.Xcode`)
- Matches by app name (case-insensitive, ignoring spaces)

### 4. Search & Filter
- **Search**: Filter apps by name or bundle identifier
- **Filter by usage status**: Quick filter chips for Active, Recently Used, Seldom Used, Unused
- **Visual feedback**: Shows app count for each filter category

### 5. Sorting Options
Sort apps by:
- **Name**: Alphabetical (A-Z / Z-A)
- **Size**: App bundle size only
- **Last Used**: Most/least recently used
- **Total Size**: App + associated files combined

### 6. Multi-Select & Bulk Actions
- **Native selection**: List-based multi-select with checkboxes
- **Select All/Deselect All**: Quick selection buttons
- **Bulk uninstall**: Uninstall multiple apps at once
- **Confirmation dialog**: Shows total apps and associated files to be removed

### 7. Detailed App View
Sheet presentation with:
- **App header**: Large icon, name, version, bundle ID, usage badge
- **Storage stats**: App size, associated files size, total size breakdown
- **Last used date**: Formatted date/time with days ago
- **Associated files list**: 
  - Up to 10 files shown with full details
  - Search functionality for large file lists
  - Files grouped by type with counts
  - Reveal in Finder button for each file
- **Uninstall options**: Toggle to include/exclude associated files
- **Safety warning**: Clear message about Trash recovery

### 8. Safe Uninstall
- **Trash integration**: Uses `NSWorkspace.shared.trashItem` for safe removal
- **Recoverable**: All items moved to Trash (not permanently deleted)
- **Permission handling**: Proper error handling for protected files
- **Progress feedback**: Real-time uninstall progress

## User Interface Components

### AppUninstallerView
Main view with three states:
1. **Empty state**: Animated icon with "Scan Applications" call-to-action
2. **Scanning state**: Progress bar with file count and percentage
3. **App list state**: Searchable list with filters and actions

**Toolbar Actions**:
- Sort menu (dropdown with sort options)
- Uninstall Selected (appears when items selected)
- Scan/Rescan button

**Stats Bar**:
- Total app count
- Total size of filtered apps
- Select All/Deselect All buttons (when items selected)

### AppRowView
Compact row component displaying:
- App icon (48x48, rounded)
- App name with version badge
- Bundle identifier (truncated)
- Usage status badge with color coding
- Days since last used
- App size with blue badge
- Associated files size with orange badge (if any)
- Total size badge (purple capsule, if > app size)
- Info button (appears on hover)

**Interactions**:
- Tap to show detail sheet
- Context menu for quick actions
- Hover effect with background highlight

### AppDetailSheet
Full-screen detail sheet with sections:

1. **App Header**:
   - Large icon (80x80)
   - App name, version, bundle ID
   - Usage status badge

2. **Storage Information**:
   - Three stat cards: App Size, Associated Files, Total Size
   - Last used date with days ago

3. **Associated Files** (if any):
   - Search bar (for 3+ files)
   - File list with icon, name, path, type badge, size
   - Show in Finder button per file
   - File type summary grid (counts by category)

4. **Uninstall Options**:
   - Toggle for associated files inclusion
   - Warning message about Trash recovery
   - Red uninstall button

**Toolbar**:
- Close button
- Show in Finder button

### FilterChip
Reusable filter chip component:
- Icon + label + count
- Selected state with color background
- Border highlight when active
- Tap to filter

### StatCard
Visual stat display component:
- Icon (color-coded)
- Value (large, bold)
- Label (small, gray)
- Colored background (10% opacity)

## Technical Architecture

### Models

**AppInfo**:
```swift
- id: UUID
- name: String
- bundleIdentifier: String
- bundlePath: String
- version: String?
- size: Int64
- lastUsedDate: Date?
- icon: NSImage?
- associatedFiles: [AssociatedFile]
- totalSize: Int64 (computed)
- daysSinceLastUsed: Int? (computed)
- usageStatus: UsageStatus (computed)
```

**AssociatedFile**:
```swift
- id: UUID
- path: String
- size: Int64
- type: AssociatedFileType
- modifiedDate: Date?
```

**UsageStatus** (enum):
- active, recentlyUsed, seldomUsed, unused, unknown
- Each with icon and color

**AssociatedFileType** (enum):
- applicationSupport, preferences, caches, logs, savedState, other
- Each with icon and safety level

### Services

**AppEnumerationService** (`@MainActor`, `ObservableObject`):
- `scanApplications()` - Enumerate all installed apps
- `processApplication(at:)` - Extract app metadata
- `findAssociatedFiles(for:appName:)` - Discover related files
- `uninstallApp(_:includeAssociatedFiles:)` - Remove single app
- `bulkUninstall(apps:includeAssociatedFiles:)` - Remove multiple apps
- `moveToTrash(path:)` - Safe file removal

**Published Properties**:
- `isScanning: Bool`
- `progress: Double`
- `currentApp: String`
- `appsFound: Int`

### Integration

**ContentView**:
- Added TabView with Dashboard and App Uninstaller tabs
- NavigationTab enum for tab definitions

## Performance Considerations

1. **Async/await**: All scanning operations use async/await for non-blocking UI
2. **Periodic yielding**: Scanner yields every 10 apps for UI responsiveness
3. **Progress tracking**: Two-phase scan (discovery + processing) for accurate progress
4. **Lazy loading**: Associated files loaded per-app, not all at once
5. **Cached icons**: Uses NSWorkspace icon caching

## Safety Features

1. **Trash recovery**: All deletions go to Trash, not permanent
2. **Confirmation dialogs**: Required for single and bulk uninstalls
3. **Associated file toggle**: Users can choose to keep or remove related files
4. **Clear warnings**: Orange warning boxes explain consequences
5. **Error handling**: Comprehensive error messages with user-friendly descriptions

## Future Enhancements

Potential improvements for future versions:
- [ ] App launch frequency tracking (requires additional permissions)
- [ ] Quarantine detection (downloaded apps)
- [ ] App Store vs manual install detection
- [ ] Dependency detection (helper tools, daemons)
- [ ] Export uninstall list
- [ ] Scheduled cleanups
- [ ] Disk space projections
- [ ] Smart recommendations based on usage patterns

## Testing Checklist

- [ ] Scan multiple directories successfully
- [ ] Handle missing directories gracefully
- [ ] Display correct app metadata (name, version, icon)
- [ ] Calculate app sizes accurately
- [ ] Find associated files correctly
- [ ] Filter by usage status works
- [ ] Search filters results properly
- [ ] Sorting works for all options
- [ ] Multi-select enables bulk actions
- [ ] Single uninstall moves to Trash
- [ ] Bulk uninstall handles errors gracefully
- [ ] Associated files toggle works
- [ ] Detail sheet displays all information
- [ ] Show in Finder works for apps and files
- [ ] Progress tracking shows accurate percentages
- [ ] Empty state displays correctly
- [ ] Scanning state updates in real-time

## Known Limitations

1. **Last used date**: Based on file system access dates, may not reflect actual app usage
2. **System apps**: Some system apps in `/System/Applications` cannot be uninstalled due to SIP
3. **Running apps**: Apps currently running will be closed when moved to Trash
4. **Associated file matching**: Uses heuristic matching, may miss some files or include false positives
5. **Permissions**: Requires Full Disk Access for complete scanning

## Usage Instructions

1. **First scan**: Click "Scan Applications" in the empty state
2. **Browse apps**: Scroll through the list, use search or filters
3. **View details**: Click any app row to see full information
4. **Uninstall single app**: 
   - Click app → Detail sheet → Uninstall button
   - Or right-click app → Uninstall
5. **Bulk uninstall**: 
   - Select multiple apps (checkboxes)
   - Click "Uninstall Selected" in toolbar
6. **Include/exclude associated files**: Toggle in detail sheet before uninstalling
7. **Rescan**: Click Scan button in toolbar to refresh list

## File Structure

```
SpaceSaver/SpaceSaver/
├── Models/
│   └── AppInfo.swift (new)
├── Services/
│   └── AppEnumerationService.swift (new)
└── Views/
    ├── App/
    │   └── ContentView.swift (updated)
    └── Uninstaller/ (new)
        ├── AppUninstallerView.swift
        ├── AppRowView.swift
        └── AppDetailSheet.swift
```

## Summary

The App Uninstaller feature provides a complete solution for managing installed applications with:
- Comprehensive app discovery across multiple directories
- Intelligent associated file detection
- Usage tracking and categorization
- Powerful search, filter, and sort capabilities
- Safe, reversible uninstall with Trash integration
- Beautiful, modern UI with animations and visual feedback
- Excellent performance with async operations and progress tracking

This feature significantly enhances SpaceSaver's value proposition by helping users reclaim disk space from unused applications and their accumulated data files.

