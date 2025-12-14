# SpaceSaver

A powerful, user-friendly macOS disk space analyzer and cleaner built with SwiftUI. SpaceSaver helps you visualize disk usage, identify large files, and safely clean up your Mac—similar to DaisyDisk but with modern macOS design and developer-friendly features.

## ✨ Features

### 🎯 Smart Dashboard
- **Intelligent Categorization**: Automatically categorizes files into easy-to-understand groups (System Junk, Large Files, Old Downloads, Developer files)
- **Safety Levels**: Three-tier classification (Safe/Caution/Dangerous) with visual indicators
- **Last Scanned Timestamp**: Track when your last scan was performed
- **Animated UI**: Smooth animations and transitions throughout

### 📊 Visual Disk Map
- **TreeMap Visualization**: Professional rectangle-based hierarchical visualization using the squarified algorithm (same as WinDirStat/TreeSize)
- **Sunburst View**: Radial/circular visualization with animated growth
- **Interactive Navigation**: Drill down into directories, navigate back with breadcrumbs
- **Rich Tooltips**: Hover-activated tooltips with comprehensive file/folder information
- **Color Coding**: Dual color system—category-based and file type-based
- **Search & Filter**: Real-time search across all segments

### 🗑️ Safe Deletion
- **Trash-Based Deletion**: Always uses trash, never permanent delete
- **Undo Functionality**: Track up to 100 recently deleted items with one-click restore
- **Confirmation Dialogs**: Rich preview dialogs showing what will be deleted
- **Batch Deletion**: Delete multiple files at once with progress tracking
- **Deletion History**: View and restore recently deleted items

### 🚀 App Uninstaller
- **Comprehensive App Detection**: Scans /Applications, /System/Applications, and ~/Applications
- **Associated File Finder**: Discovers related files in Library folders (Application Support, Caches, Preferences, Logs, Saved State)
- **Usage Tracking**: Tracks last access dates and categorizes apps (Active, Recently Used, Seldom Used, Unused)
- **Bulk Uninstall**: Multi-select with bulk uninstall confirmation
- **Search & Filter**: Search by app name/bundle ID, filter by usage status

### 🛡️ Safety Features
- **SIP Protection**: Automatically detects and skips System Integrity Protection files
- **Developer Detection**: Automatically detects and enables developer-specific cleaning features
- **Network Drive Handling**: Smart detection and warnings for network volumes
- **Path Exclusions**: Configurable exclusion system with default and user-defined paths
- **Safety Indicators**: Visual indicators throughout the app for protected files

### ⚡ Performance
- **Async Scanning**: Modern Swift concurrency with `async/await` for smooth UI performance
- **Progress Tracking**: Accurate two-pass progress calculation
- **Scan Result Caching**: SwiftData-based persistence for scan results
- **Progressive Rendering**: Intelligent batched loading for large datasets (100K+ segments)

## 📋 Requirements

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later
- **Swift**: 6.0

## 🚀 Getting Started

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/space-saver.git
   cd space-saver
   ```

2. **Open in Xcode**:
   ```bash
   open SpaceSaver/SpaceSaver/spacesaver.xcodeproj
   ```

3. **Configure the project**:
   - Select the project in Xcode
   - Go to "Signing & Capabilities"
   - Select your development team
   - Ensure App Sandbox is **disabled** (required for Full Disk Access)

4. **Build and run**:
   - Select "My Mac" as the target
   - Press `Cmd + R` to build and run

5. **Grant Full Disk Access**:
   - Go to **System Settings** → **Privacy & Security** → **Full Disk Access**
   - Enable **SpaceSaver**
   - Restart the app

## 📁 Project Structure

```
SpaceSaver/
├── App/
│   ├── SpaceSaverApp.swift          # Main app entry point
│   └── ContentView.swift            # Main content view with tab navigation
├── Models/
│   ├── AppInfo.swift                # App metadata model
│   ├── DiskMapSegment.swift         # Visualization segment model
│   ├── FileNode.swift               # File representation
│   ├── ScanPreferences.swift        # Scan configuration
│   ├── ScanResultCache.swift        # SwiftData cache models
│   ├── SmartCategory.swift          # Category model
│   └── VolumeType.swift             # Volume detection
├── Services/
│   ├── AppEnumerationService.swift  # App scanning and uninstallation
│   ├── CategoryManager.swift        # File categorization
│   ├── DeletionService.swift        # Safe deletion service
│   ├── DeveloperDetector.swift     # Developer tool detection
│   ├── DuplicateDetector.swift      # Duplicate file detection
│   ├── FileScannerService.swift     # File system scanning
│   ├── PathExclusionManager.swift   # Path exclusion management
│   └── ScanResultCacheService.swift # Scan result caching
├── Views/
│   ├── Components/
│   │   ├── AnimatedIconView.swift   # Animated icon component
│   │   ├── DeletionConfirmationView.swift # Deletion confirmation dialog
│   │   ├── DeletionHistoryView.swift # Deletion history UI
│   │   ├── ExclusionListView.swift  # Exclusion list management
│   │   └── SafetyLevelIndicator.swift # Safety level badge
│   ├── Dashboard/
│   │   ├── CategoryCard.swift       # Category card component
│   │   ├── DashboardSummaryView.swift # Dashboard summary
│   │   └── DashboardView.swift      # Main dashboard
│   ├── Detail/
│   │   ├── CategoryDetailView.swift # Category detail view
│   │   └── FileRowView.swift        # File row component
│   ├── DiskMap/
│   │   ├── DiskMapView.swift        # Main disk map view
│   │   ├── SunburstView.swift       # Sunburst visualization
│   │   └── TreeMapView.swift        # TreeMap visualization
│   ├── Onboarding/
│   │   └── PermissionsView.swift    # Permission request UI
│   ├── Scanner/
│   │   └── ScanProgressView.swift   # Scan progress indicator
│   ├── Uninstaller/
│   │   ├── AppDetailSheet.swift     # App detail sheet
│   │   ├── AppRowView.swift         # App row component
│   │   └── AppUninstallerView.swift # App uninstaller view
│   └── WelcomeView.swift            # Welcome screen
└── Utilities/
    ├── AppError.swift               # Error types
    ├── FileSizeFormatter.swift      # Size formatting
    ├── IconCache.swift              # Icon caching
    ├── Logger.swift                 # Logging utilities
    ├── QuickLookHelper.swift        # Quick Look integration
    └── SIPDetector.swift            # SIP protection detection
```

## 🎨 Features in Detail

### Smart Categorization
Files are automatically categorized into:
- **System Junk**: Caches, logs, temporary files
- **Large Files**: Files larger than 1GB
- **Old Downloads**: Files in Downloads folder older than 3 months
- **Developer Files**: `node_modules`, Docker images, build artifacts (only shown if developer tools detected)

### Visual Disk Map
- **TreeMap**: Professional squarified algorithm for optimal rectangle aspect ratios
- **Sunburst**: Radial visualization with animated arcs
- **Interactive**: Click to drill down, hover for details, breadcrumb navigation
- **Performance**: Handles 100K+ segments with progressive rendering

### Safe Deletion
- All deletions go to Trash (recoverable)
- Undo support for up to 100 items
- Rich confirmation dialogs with preview
- Batch operations with progress tracking
- Safety level indicators (Safe/Caution/Dangerous)

### App Uninstaller
- Finds apps in all standard locations
- Discovers associated files (preferences, caches, logs)
- Usage tracking and categorization
- Bulk uninstall support
- Search and filter capabilities

## 🔧 Development

### Architecture
- **SwiftUI**: Modern declarative UI framework
- **Swift Concurrency**: `async/await` for asynchronous operations
- **SwiftData**: Persistent storage for scan results
- **MVVM Pattern**: Clear separation of concerns

### Key Design Decisions
- **No App Sandbox**: Required for Full Disk Access
- **SIP Protection**: Automatically detects and skips protected files
- **Network Drive Detection**: Warns users about slow scanning on network volumes
- **Progressive Disclosure**: Simple dashboard with advanced features available on demand

## 📚 Documentation

- [Safe Deletion Guide](SAFE_DELETION_GUIDE.md) - Comprehensive guide to safe deletion features
- [TreeMap Feature Guide](TREEMAP_FEATURE_GUIDE.md) - Detailed documentation on TreeMap visualization
- [Visual Disk Map Guide](VISUAL_DISK_MAP_GUIDE.md) - Guide to disk map features
- [Implementation Status](IMPLEMENTATION_STATUS.md) - Current implementation status
- [Xcode Setup Guide](XCODE_SETUP_GUIDE.md) - Detailed setup instructions

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by DaisyDisk and similar disk space analyzers
- TreeMap algorithm based on the squarified algorithm by Bruls, Huizing, and van Wijk

## 📧 Contact

For questions, suggestions, or issues, please open an issue on GitHub.

---

**Note**: This app requires Full Disk Access to function properly. All deletions are sent to Trash and can be recovered. The app respects System Integrity Protection and will not attempt to delete protected system files.
