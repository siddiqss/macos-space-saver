# Adding App Uninstaller Files to Xcode Project

## Quick Start

### 1. New Files to Add

Add these files to your Xcode project in the appropriate groups:

#### Models Group
```
SpaceSaver/Models/
└── AppInfo.swift (NEW)
```

#### Services Group
```
SpaceSaver/Services/
└── AppEnumerationService.swift (NEW)
```

#### Views Group
```
SpaceSaver/Views/
└── Uninstaller/ (NEW FOLDER)
    ├── AppUninstallerView.swift (NEW)
    ├── AppRowView.swift (NEW)
    └── AppDetailSheet.swift (NEW)
```

#### Updated Files
```
SpaceSaver/App/
└── ContentView.swift (MODIFIED - now has TabView)
```

### 2. Xcode Project Setup

**Option A: Drag and Drop**
1. Open Xcode
2. Right-click on "Models" group → Add Files to "SpaceSaver"
3. Navigate to and select `AppInfo.swift`
4. Ensure "Copy items if needed" is checked
5. Click "Add"
6. Repeat for Services group with `AppEnumerationService.swift`
7. Create new group "Uninstaller" under Views
8. Add the three Uninstaller view files

**Option B: Manual Add**
1. In Xcode, right-click on "Models" → New File
2. Choose "Swift File"
3. Name it "AppInfo"
4. Replace contents with the file from your workspace
5. Repeat for all other files

### 3. Build and Run

1. Build the project (⌘B)
2. Fix any potential import issues
3. Run the app (⌘R)
4. You should see two tabs: "Dashboard" and "App Uninstaller"

### 4. Testing the Feature

1. Click on "App Uninstaller" tab
2. Click "Scan Applications"
3. Wait for scan to complete
4. Browse the list of installed apps
5. Try filtering by usage status
6. Try searching for an app
7. Click an app to see details
8. Try uninstalling a test app (it goes to Trash, so it's safe)

## Verification Checklist

After adding files, verify:

- [ ] Project builds without errors
- [ ] No missing import statements
- [ ] TabView appears with two tabs
- [ ] "App Uninstaller" tab is visible
- [ ] Empty state displays correctly
- [ ] Scan button works
- [ ] Progress tracking shows during scan
- [ ] App list populates after scan
- [ ] Search works
- [ ] Filters work
- [ ] Sort options work
- [ ] App detail sheet opens
- [ ] Uninstall moves items to Trash

## Common Issues and Solutions

### Issue: "No such module" errors
**Solution**: Ensure all files are added to the correct target (SpaceSaver)

### Issue: "Cannot find type 'AppInfo' in scope"
**Solution**: Make sure `AppInfo.swift` is in the Models group and added to target

### Issue: "Cannot find type 'AppEnumerationService' in scope"
**Solution**: Make sure `AppEnumerationService.swift` is in Services group and added to target

### Issue: TabView not showing
**Solution**: Check that `ContentView.swift` was updated with the new code

### Issue: Empty state not showing icon
**Solution**: Ensure `AnimatedIconView.swift` exists and is added to project

### Issue: Scanning doesn't start
**Solution**: Check Full Disk Access is granted in System Settings → Privacy & Security

### Issue: No apps found after scan
**Solution**: Verify permissions and check Console.app for error logs

## File Dependencies

```
AppInfo.swift
├── Imports: Foundation, AppKit
└── Dependencies: None

AppEnumerationService.swift
├── Imports: Foundation, AppKit, OSLog
└── Dependencies: AppInfo, AppError, Logger

AppUninstallerView.swift
├── Imports: SwiftUI
└── Dependencies: AppEnumerationService, AppInfo, AnimatedIconView, 
                  AppDetailSheet, AppRowView, FileSizeFormatter

AppRowView.swift
├── Imports: SwiftUI, AppKit
└── Dependencies: AppInfo, FileSizeFormatter

AppDetailSheet.swift
├── Imports: SwiftUI, AppKit
└── Dependencies: AppInfo, AppEnumerationService, FileSizeFormatter

ContentView.swift (updated)
├── Imports: SwiftUI
└── Dependencies: AppState, WelcomeView, DashboardView, AppUninstallerView
```

## Project Navigator Structure

After adding files, your project should look like:

```
SpaceSaver
├── SpaceSaverApp.swift
├── App
│   └── ContentView.swift (✏️ modified)
├── Models
│   ├── FileNode.swift
│   ├── SmartCategory.swift
│   ├── VolumeType.swift
│   ├── ScanResultCache.swift
│   └── AppInfo.swift (✨ new)
├── Services
│   ├── FileScannerService.swift
│   ├── CategoryManager.swift
│   ├── DeveloperDetector.swift
│   ├── PathExclusionManager.swift
│   ├── ScanResultCacheService.swift
│   └── AppEnumerationService.swift (✨ new)
├── Views
│   ├── WelcomeView.swift
│   ├── Dashboard
│   │   ├── DashboardView.swift
│   │   └── CategoryCard.swift
│   ├── Detail
│   │   ├── CategoryDetailView.swift
│   │   └── FileRowView.swift
│   ├── Scanner
│   │   └── ScanProgressView.swift
│   ├── Onboarding
│   │   └── PermissionsView.swift
│   ├── Components
│   │   └── AnimatedIconView.swift
│   └── Uninstaller (✨ new group)
│       ├── AppUninstallerView.swift (✨ new)
│       ├── AppRowView.swift (✨ new)
│       └── AppDetailSheet.swift (✨ new)
├── Utilities
│   ├── AppError.swift
│   ├── FileSizeFormatter.swift
│   ├── IconCache.swift
│   ├── Logger.swift
│   ├── QuickLookHelper.swift
│   └── SIPDetector.swift
└── Resources
    └── Assets.xcassets
```

## Build Settings

No changes needed to build settings. The feature uses only standard frameworks:
- Foundation
- SwiftUI
- AppKit
- OSLog

## Entitlements

Current entitlements should be sufficient:
- App Sandbox: NO (already disabled)
- Full Disk Access: Required (user must grant in System Settings)

## Testing in Xcode

### Debug Menu
While running:
1. Debug → View Debugging → Show View Frames
2. Verify TabView layout is correct
3. Verify all views are rendering

### Console Logging
Check Console for log messages:
- "🔍 Starting application scan..."
- "📦 Found X application bundles"
- "✅ Scan complete. Found X applications"
- "🗑️ Uninstalling AppName..."
- "✅ Successfully uninstalled AppName"

### Breakpoints
Useful breakpoints for debugging:
- `AppEnumerationService.scanApplications()` - Start of scan
- `AppEnumerationService.processApplication(at:)` - Processing each app
- `AppEnumerationService.findAssociatedFiles(for:appName:)` - Finding files
- `AppEnumerationService.uninstallApp(_:includeAssociatedFiles:)` - Uninstall

## Performance Testing

Monitor performance:
1. Open Instruments (⌘I)
2. Choose "Time Profiler"
3. Run app and start scan
4. Verify no long-running synchronous operations on main thread
5. Check memory usage stays reasonable (<500MB for large scans)

## Next Steps

After successfully integrating:
1. Test with a few apps first
2. Try uninstalling a test app (check Trash)
3. Verify associated files are found correctly
4. Test multi-select and bulk uninstall
5. Test search and filter functionality
6. Share with beta testers for feedback

## Support

If you encounter issues:
1. Check Console.app for detailed logs
2. Verify Full Disk Access permission
3. Try rebuilding (⌘⇧K, then ⌘B)
4. Check Xcode version compatibility (requires Xcode 15+)

