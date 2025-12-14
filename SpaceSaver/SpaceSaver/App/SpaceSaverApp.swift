//
//  SpaceSaverApp.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI
import SwiftData
import Combine

@main
struct SpaceSaverApp: App {
    @StateObject private var appState = AppState()
    
    // SwiftData model container
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                CachedScanResult.self,
                CachedCategory.self,
                CachedFileNode.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to initialize SwiftData model container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
            
            // Custom commands for file management
            CommandMenu("File") {
                Button("View Deletion History...") {
                    NotificationCenter.default.post(name: .showDeletionHistory, object: nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            }
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var hasFullDiskAccess: Bool = false
    @Published var isFirstLaunch: Bool = true
    @Published var currentScanResult: ScanResult?
    
    init() {
        checkFullDiskAccess()
        checkFirstLaunch()
    }
    
    private func checkFullDiskAccess() {
        // Check if app has Full Disk Access
        // This is a placeholder - actual implementation will check system permissions
        hasFullDiskAccess = false
    }
    
    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        isFirstLaunch = !hasLaunchedBefore
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }
}



