//
//  AppRowView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI
import AppKit
import Foundation

struct AppRowView: View {
    let app: AppInfo
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // App Icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
                    .frame(width: 48, height: 48)
            }
            
            // App Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(app.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let version = app.version {
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                // Usage info
                HStack(spacing: 12) {
                    // Usage status
                    HStack(spacing: 4) {
                        Image(systemName: app.usageStatus.icon)
                            .font(.caption2)
                        Text(app.usageStatus.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(statusColor(for: app.usageStatus))
                    
                    if let days = app.daysSinceLastUsed {
                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                        
                        Text("\(days) days ago")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Size Info
            VStack(alignment: .trailing, spacing: 4) {
                // App size
                HStack(spacing: 4) {
                    Image(systemName: "app.badge")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(FileSizeFormatter.format(bytes: app.size))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // Associated files size (if any)
                if !app.associatedFiles.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(FileSizeFormatter.format(bytes: app.totalSize - app.size))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Total size badge
                if app.totalSize > app.size {
                    Text("Total: \(FileSizeFormatter.format(bytes: app.totalSize))")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.purple.opacity(0.8))
                        )
                }
            }
            
            // Quick action button (visible on hover)
            if isHovered {
                Button(action: {}) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.gray.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private func statusColor(for status: UsageStatus) -> Color {
        switch status {
        case .active: return .green
        case .recentlyUsed: return .blue
        case .seldomUsed: return .orange
        case .unused: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    List {
        AppRowView(
            app: AppInfo(
                name: "Xcode",
                bundleIdentifier: "com.apple.dt.Xcode",
                bundlePath: "/Applications/Xcode.app",
                version: "15.0",
                size: 5_000_000_000,
                lastUsedDate: Date().addingTimeInterval(-86400 * 60),
                icon: NSWorkspace.shared.icon(forFile: "/Applications/Xcode.app"),
                associatedFiles: [
                    AssociatedFile(
                        path: "~/Library/Developer",
                        size: 10_000_000_000,
                        type: .applicationSupport
                    )
                ]
            )
        )
        
        AppRowView(
            app: AppInfo(
                name: "Safari",
                bundleIdentifier: "com.apple.Safari",
                bundlePath: "/Applications/Safari.app",
                version: "17.0",
                size: 200_000_000,
                lastUsedDate: Date(),
                icon: NSWorkspace.shared.icon(forFile: "/Applications/Safari.app"),
                associatedFiles: []
            )
        )
    }
    .listStyle(.inset)
}

