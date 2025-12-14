//
//  ContentView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI

enum NavigationTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case diskMap = "Disk Map"
    case uninstaller = "App Uninstaller"
    
    var icon: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .diskMap: return "map.fill"
        case .uninstaller: return "trash.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: NavigationTab = .dashboard
    @State private var showDeletionHistory = false
    
    var body: some View {
        if appState.isFirstLaunch {
            WelcomeView()
        } else {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label(NavigationTab.dashboard.rawValue, systemImage: NavigationTab.dashboard.icon)
                    }
                    .tag(NavigationTab.dashboard)
                
                DiskMapView()
                    .tabItem {
                        Label(NavigationTab.diskMap.rawValue, systemImage: NavigationTab.diskMap.icon)
                    }
                    .tag(NavigationTab.diskMap)
                
                AppUninstallerView()
                    .tabItem {
                        Label(NavigationTab.uninstaller.rawValue, systemImage: NavigationTab.uninstaller.icon)
                    }
                    .tag(NavigationTab.uninstaller)
            }
            .sheet(isPresented: $showDeletionHistory) {
                DeletionHistoryView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showDeletionHistory)) { _ in
                showDeletionHistory = true
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let showDeletionHistory = Notification.Name("showDeletionHistory")
}

