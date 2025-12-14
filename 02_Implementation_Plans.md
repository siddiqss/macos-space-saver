---

### File 3: `02_Implementation_Steps.md` (Updated)
*Context: Building the UI for approachability.*

```markdown
# Implementation Roadmap

## Phase 0: Project Foundation & Setup
- [ ] Create Xcode project with proper bundle ID (e.g., `com.yourname.space-saver`)
- [ ] Configure minimum deployment target (macOS 13.0+), target macOS 26.0 (Tahoe)
- [ ] Set up entitlements for Full Disk Access
- [ ] **No App Sandbox** - Will request Full Disk Access from user instead
- [ ] Set up basic project structure (Models, Views, Services, Utilities)
- [ ] Create error handling framework
- [ ] Set up logging system
- [ ] Add basic app icon and assets

## Phase 1: The "Smart" Scanner Backend
- [ ] Create `FileScannerService` with async/await support
- [ ] Implement streaming file enumeration (avoid loading all files into memory)
- [ ] Add progress reporting (bytes scanned, files found, current path)
- [ ] Implement scan cancellation support
- [ ] **Volume Type Detection:** Implement `getVolumeType()` using `URLResourceKey` to detect internal/external/network drives
- [ ] **Network Drive Handling:** Default network drives to OFF, show warning if user manually selects
- [ ] **SIP Detection:** Implement pre-flight blacklist for SIP-protected paths (`/System`, `/usr`, `/bin`, `/sbin`)
- [ ] **SIP Flag Check:** Use `stat` C-function to check for `SF_RESTRICTED` flag
- [ ] Create `CategoryManager`: A logic layer that takes raw files and sorts them into `SmartCategory` buckets
- [ ] **Developer Detection:** Write a function `checkForDevTools()` that checks for Xcode/Docker/Node.js presence
- [ ] **Scanning Modes:** Support both "Entire Disk" (targets `/` but skips `/Volumes`) and "Specific Folder" modes
- [ ] Add path exclusion list support
- [ ] Implement scan result caching (SwiftData or Core Data)

## Phase 2: The Dashboard UI (Priority: Friendliness)
- [ ] **Welcome View:** A friendly "Scan my Mac" button (pulsing animation)
- [ ] **Empty State:** Show when no scan has been performed yet
- [ ] **Dashboard Grid:** A 2x2 grid of cards (System, Downloads, Large Files, Developer)
    -   *Design Note:* Use colorful SF Symbols. Make it look native but modern
    -   *State:* Cards show "Scanning..." then animate to show the Size (e.g., "14 GB Found")
- [ ] **Scan Progress Indicator:** Show progress during scanning (progress bar + current directory)
- [ ] **Last Scanned Timestamp:** Display "Last scanned: X minutes ago"
- [ ] **Card Animations:** Smooth SwiftUI transitions when data loads
- [ ] **Dark Mode Support:** Automatic with SwiftUI, but verify all assets

## Phase 3: The Detail Views
- [ ] **Drill-down:** Clicking a card (e.g., "Large Files") slides in a list view of just those files
- [ ] **Search/Filter:** Add search bar to filter files within category
- [ ] **Sorting Options:** Sort by size, date modified, name (ascending/descending)
- [ ] **Multi-select:** Support selecting multiple files with keyboard shortcuts (Cmd+A, Shift+Click)
- [ ] **Quick Actions:** Add "Select Oldest" or "Select All" buttons for easy selection
- [ ] **Preview Pane:** Quick Look integration to preview files before deletion
- [ ] **File Details:** Show file path, size, date modified, date created

## Phase 4: The Uninstaller (The High-Value Feature)
- [ ] **App Enumerator:** List all apps in `/Applications` and `/Applications/Utilities`
- [ ] **App Size Calculation:** Calculate total size including app bundle + associated files
- [ ] **Associated File Finder:** When an app is clicked, search `~/Library` for matching Bundle IDs
- [ ] **Last Used Detection:** Check LaunchServices database for last opened date
- [ ] **UI:** Show the App Icon + a list of "Leftovers" to be deleted
- [ ] **Filtering:** "Recently Used" vs "Never Used" vs "All Apps"
- [ ] **Bulk Uninstall:** Select multiple apps for batch removal

## Phase 5: Onboarding & Permissions
- [ ] **Permission View:** Explain *why* we need Full Disk Access in simple English
- [ ] **Permission Handling:** Graceful fallback if permission denied (allow folder selection)
- [ ] **Tutorial:** A 3-slide intro: "Scan", "Review", "Clean"
- [ ] **First Launch Experience:** Welcome screen with app value proposition
- [ ] **Accessibility:** VoiceOver support, Dynamic Type, keyboard navigation
- [ ] **Help System:** Tooltips and help buttons for key features

## Phase 6: Visual Disk Map (Required Feature)
- [ ] **Visual Disk Map:** Sunburst or treemap visualization (like DaisyDisk) - **Required, not optional**
- [ ] **Rendering Engine:** Implement using SwiftUI Canvas or Core Graphics
- [ ] **Interactive Segments:** Click segments to drill down into directories
- [ ] **Progressive Rendering:** Render as scan completes to show progress
- [ ] **Toggle View:** Allow switching between Dashboard and Visual Map views
- [ ] **Color Coding:** Use colors to represent different file types/categories
- [ ] **Size Representation:** Segment size proportional to disk space used

## Phase 7: Safety & Deletion Features ✅ COMPLETE
- ✅ **Safe Deletion:** Always use trash/recycle, never permanent delete
- ✅ **Undo Support:** Implement undo functionality using `NSFileManager.trashItem`
- ✅ **Confirmation Dialogs:** Warn before deleting large amounts of data
- ✅ **Dry Run Mode:** Preview what would be deleted without actually deleting
- ✅ **Safety Levels:** Visual indicators (safe/caution/dangerous) for each category
- ✅ **SIP Protection UI:** Show "Lock" icon and disable Delete button for SIP-protected files
- ✅ **SIP Tooltip:** Show "This file is protected by System Integrity Protection" message
- ✅ **Exclusion List:** Let users exclude specific folders from scans

### Implementation Details:
- Created `DeletionService` with trash-based deletion and undo support (tracks up to 100 items)
- Implemented `DeletionConfirmationView` with rich preview and safety warnings
- Created `SafetyLevelIndicator` component for consistent safety level display
- Built `ExclusionListView` for managing scan exclusions
- Added `DeletionHistoryView` for viewing and restoring deleted items
- Enhanced `FileRowView` with delete button, SIP indicators, and confirmation dialogs
- Enhanced `CategoryDetailView` with batch deletion support
- All deletions use `FileManager.trashItem` - no permanent deletions
- Comprehensive documentation in `SAFE_DELETION_GUIDE.md`

## Phase 8: Advanced Features (Post-MVP)
- [ ] **Duplicate Finder:** Find and remove duplicate files
- [ ] **Scan History:** Track space saved over time with charts
- [ ] **Scheduled Scans:** Optional automatic scanning
- [ ] **Export Reports:** Export scan results as CSV/JSON

## Phase 9: Monetization & Polish
- [ ] **StoreKit 2 Integration:** In-app purchase for Pro features
- [ ] **Feature Flags:** Enable/disable Pro features based on purchase status
- [ ] **Analytics:** Privacy-respecting analytics (optional, with user consent)
- [ ] **App Store Assets:** Screenshots, descriptions, keywords
- [ ] **Beta Testing:** TestFlight setup and beta distribution
- [ ] **Performance Optimization:** Profile and optimize slow operations
- [ ] **Error Reporting:** Crash reporting (e.g., Sentry) for production