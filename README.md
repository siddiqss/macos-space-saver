# SpaceSaver

A user-friendly macOS disk space analyzer and cleaner, similar to DaisyDisk.

## Features

- **Smart Dashboard**: Categorizes files into easy-to-understand groups (System Junk, Large Files, Old Downloads, Developer files)
- **Visual Disk Map**: Sunburst/treemap visualization (coming soon)
- **Safe Deletion**: Always uses trash, never permanent delete
- **Developer Detection**: Automatically detects and enables developer-specific cleaning features
- **Network Drive Handling**: Smart detection and warnings for network volumes
- **SIP Protection**: Automatically skips System Integrity Protection files

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Swift 6.0

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode
2. Create a new project:
   - Choose "macOS" → "App"
   - Product Name: `SpaceSaver`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Bundle Identifier: `com.yourname.space-saver` (or your preferred identifier)

### 2. Configure Project Settings

1. **Minimum Deployment Target**:
   - Select the project in Xcode
   - Go to "General" tab
   - Set "Minimum Deployments" to macOS 13.0

2. **Bundle Identifier**:
   - Set to your preferred identifier (e.g., `com.yourname.space-saver`)

3. **Add Source Files**:
   - Copy all files from `SpaceSaver/SpaceSaver/` into your Xcode project
   - Maintain the folder structure:
     - `App/`
     - `Models/`
     - `Services/`
     - `Views/` (with subfolders)
     - `Utilities/`

4. **Add Entitlements**:
   - In Xcode, go to "Signing & Capabilities"
   - Add the `SpaceSaver.entitlements` file
   - **Important**: Disable App Sandbox (the entitlements file already has this set to `false`)

5. **Info.plist**:
   - The `Info.plist` file is provided, but modern Xcode projects may use build settings instead
   - If needed, add it to your project and configure the bundle settings

### 3. Full Disk Access Permission

The app requires Full Disk Access to scan your system:

1. Build and run the app once
2. Go to **System Settings** → **Privacy & Security** → **Full Disk Access**
3. Enable **SpaceSaver**
4. Restart the app

### 4. Build and Run

1. Select your target device (My Mac)
2. Press `Cmd + R` to build and run

## Project Structure

```
SpaceSaver/
├── App/
│   └── SpaceSaverApp.swift          # Main app entry point
├── Models/
│   ├── FileNode.swift               # File representation
│   ├── SmartCategory.swift          # Category model
│   └── VolumeType.swift             # Volume detection
├── Services/
│   ├── FileScannerService.swift     # File system scanning
│   ├── CategoryManager.swift       # File categorization
│   └── DeveloperDetector.swift     # Developer tool detection
├── Views/
│   ├── Dashboard/
│   │   ├── DashboardView.swift     # Main dashboard
│   │   └── CategoryCard.swift      # Category card component
│   ├── Scanner/
│   │   └── ScanProgressView.swift  # Scan progress UI
│   ├── Onboarding/
│   │   └── PermissionsView.swift   # Permission request UI
│   └── WelcomeView.swift           # Welcome screen
└── Utilities/
    ├── AppError.swift              # Error types
    ├── Logger.swift                # Logging utilities
    ├── FileSizeFormatter.swift     # Size formatting
    └── SIPDetector.swift           # SIP protection detection
```

## Implementation Status

### ✅ Phase 0: Foundation (Complete)
- Project structure
- Basic models
- Service stubs
- Error handling
- Logging system
- Basic UI views

### 🚧 Phase 1: Scanner Backend (In Progress)
- File scanning service (basic implementation done)
- Volume detection (implemented)
- SIP detection (implemented)
- Category management (basic implementation done)

### 📋 Next Steps
- Complete scanner implementation
- Add visual disk map
- Implement deletion service
- Add detail views
- Implement app uninstaller

## Development Notes

- **No App Sandbox**: The app does not use App Sandbox to allow Full Disk Access
- **SIP Protection**: Automatically detects and skips SIP-protected files
- **Network Drives**: Detects network volumes and warns users about slow scanning
- **Async/Await**: Uses modern Swift concurrency for smooth UI performance

## License

Copyright © 2025. All rights reserved.

