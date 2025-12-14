# App Uninstaller - Component Architecture

## Component Hierarchy

```
ContentView (TabView)
├── DashboardView (Tab 1)
└── AppUninstallerView (Tab 2)
    ├── Empty State
    │   └── AnimatedIconView
    ├── Scanning State
    │   └── Progress Indicators
    └── App List State
        ├── Stats Bar
        ├── Filter Chips Bar
        │   └── FilterChip × N
        └── List
            └── AppRowView × N
                └── (tap) → AppDetailSheet
                    ├── App Header
                    ├── Stats Section (StatCard × 3)
                    ├── Associated Files
                    │   └── AssociatedFileRow × N
                    └── Uninstall Section
```

## Data Flow

```
User Action: "Scan Apps"
    ↓
AppUninstallerView.startScan()
    ↓
AppEnumerationService.scanApplications()
    ↓
    ├─→ Phase 1: Find .app bundles in directories
    │   ├─ /Applications
    │   ├─ /System/Applications
    │   ├─ /System/Applications/Utilities
    │   └─ ~/Applications
    │
    └─→ Phase 2: Process each app
        ├─ Extract metadata (name, version, icon)
        ├─ Calculate app size
        ├─ Get last used date
        └─ Find associated files
            ├─ ~/Library/Application Support
            ├─ ~/Library/Caches
            ├─ ~/Library/Preferences
            ├─ ~/Library/Logs
            └─ ~/Library/Saved Application State
    ↓
Return [AppInfo]
    ↓
Update UI with results
```

## Uninstall Flow

```
User Action: "Uninstall App"
    ↓
Confirmation Dialog
    ├─ Show app name
    ├─ Show associated files count (if included)
    └─ User confirms
        ↓
AppEnumerationService.uninstallApp()
    ↓
    ├─→ Move app bundle to Trash
    │   └─ NSWorkspace.shared.trashItem()
    │
    └─→ If includeAssociatedFiles == true
        └─ Move each associated file to Trash
    ↓
Update UI (remove from list)
```

## State Management

### AppEnumerationService (@MainActor, ObservableObject)
```swift
@Published var isScanning: Bool = false
@Published var progress: Double = 0.0
@Published var currentApp: String = ""
@Published var appsFound: Int = 0
```

### AppUninstallerView (@State)
```swift
@State var apps: [AppInfo] = []
@State var searchText: String = ""
@State var selectedSortOption: AppSortOption = .name
@State var sortAscending: Bool = true
@State var selectedApps: Set<AppInfo> = []
@State var selectedAppForDetail: AppInfo? = nil
@State var filterStatus: UsageStatus? = nil
```

## UI States

### Empty State
- **Condition**: `!isScanning && apps.isEmpty`
- **Display**: AnimatedIconView + "Scan Applications" button

### Scanning State
- **Condition**: `isScanning`
- **Display**: Progress bar + stats (apps found, percentage)

### App List State
- **Condition**: `!isScanning && !apps.isEmpty`
- **Display**: Stats bar + filter chips + list of apps

## Filtering & Sorting Pipeline

```
Original apps array
    ↓
Apply search filter (if searchText not empty)
    ├─ Match app.name
    └─ Match app.bundleIdentifier
    ↓
Apply status filter (if filterStatus selected)
    └─ Match app.usageStatus
    ↓
Apply sort
    ├─ .name → alphabetical
    ├─ .size → by app size
    ├─ .lastUsed → by last used date
    └─ .totalSize → by app + associated files
    ↓
Apply sort direction (ascending/descending)
    ↓
filteredAndSortedApps (displayed in list)
```

## Associated File Matching Algorithm

```
For each base path in:
    - ~/Library/Application Support
    - ~/Library/Caches
    - ~/Library/Preferences
    - ~/Library/Logs
    - ~/Library/Saved Application State

List contents of directory
    ↓
For each item in directory:
    ↓
    Check if item name contains:
        ├─ Bundle ID (e.g., "com.apple.dt.Xcode")
        └─ App name (lowercase, no spaces)
    ↓
    If match found:
        ├─ Calculate size
        ├─ Get modification date
        ├─ Determine file type from path
        └─ Create AssociatedFile
    ↓
Return array of AssociatedFile
```

## Safety Mechanisms

1. **Confirmation Dialogs**
   - Single uninstall: Shows app name + file count
   - Bulk uninstall: Shows app count + total files

2. **Trash Integration**
   - All deletions use `NSWorkspace.shared.trashItem()`
   - Items can be restored from Trash
   - Never uses `FileManager.removeItem()` for permanent deletion

3. **Error Handling**
   - Try/catch around all file operations
   - Continue bulk uninstall even if one fails
   - Display user-friendly error messages
   - Log errors for debugging

4. **Permission Handling**
   - Requires Full Disk Access
   - Graceful handling of permission errors
   - Clear error messages guide user to System Settings

## Performance Optimizations

1. **Async/Await**
   - All scanning operations are async
   - UI remains responsive during scan
   - Progress updates in real-time

2. **Yielding**
   - Scanner yields every 10 apps
   - 1ms sleep allows UI updates
   - Prevents UI freezing

3. **Lazy Evaluation**
   - Associated files loaded per-app
   - Not all files loaded upfront
   - Reduces memory usage

4. **Caching**
   - NSWorkspace caches app icons
   - File sizes calculated once
   - Results stored in memory

## Integration Points

### ContentView
```swift
TabView(selection: $selectedTab) {
    DashboardView()
        .tabItem { Label("Dashboard", systemImage: "chart.pie.fill") }
    
    AppUninstallerView()
        .tabItem { Label("App Uninstaller", systemImage: "trash.fill") }
}
```

### Shared Components
- `AnimatedIconView` - Used in empty state
- `FileSizeFormatter` - Format bytes for display
- Error handling via `AppError` enum

## Testing Strategy

### Unit Tests (Future)
- AppInfo computed properties (totalSize, daysSinceLastUsed, usageStatus)
- Associated file type detection
- File matching algorithm

### Integration Tests (Future)
- Full scan with mock file system
- Uninstall with mock Trash
- Search/filter/sort correctness

### Manual Testing
- Scan on clean system
- Scan on system with many apps
- Test with apps that have no associated files
- Test with apps that have many associated files
- Test uninstall (check Trash)
- Test bulk uninstall
- Test search and filters
- Test sorting options

## Accessibility Considerations

- All icons have text labels
- Color is not the only indicator (usage badges have icons)
- Keyboard navigation supported (List native support)
- VoiceOver friendly (semantic SwiftUI views)

## Dark Mode Support

- Uses system colors (`.primary`, `.secondary`)
- Custom colors with opacity (works in both modes)
- Icons automatically adapt
- All backgrounds use `.controlBackgroundColor` or adaptive colors

## Localization Ready

All user-facing strings are ready for localization:
- View titles and labels
- Button text
- Alert messages
- Status descriptions
- File type names

## Memory Management

- `@StateObject` for service (owned by view)
- `@State` for local view state
- `Set<AppInfo>` for efficient selection lookups
- Computed properties for derived data (no storage overhead)

## Thread Safety

- Service marked `@MainActor` (all UI updates on main thread)
- File operations run on background threads via `async/await`
- SwiftUI property wrappers ensure thread-safe UI updates

