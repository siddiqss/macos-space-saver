//
//  DeletionConfirmationView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI

struct DeletionConfirmationView: View {
    let preview: DeletionPreview
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var showDryRunDetails = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with icon
            safetyIcon
                .font(.system(size: 48))
                .padding(.top)
            
            // Title
            Text("Confirm Deletion")
                .font(.title2)
                .fontWeight(.bold)
            
            // Safety level warning
            safetyWarning
            
            // Statistics
            VStack(spacing: 12) {
                statisticRow(
                    icon: "doc.fill",
                    label: "Items to delete",
                    value: "\(preview.itemCount)"
                )
                
                statisticRow(
                    icon: "externaldrive.fill",
                    label: "Total size",
                    value: preview.totalSize.formattedFileSize
                )
                
                if preview.sipProtectedCount > 0 {
                    statisticRow(
                        icon: "exclamationmark.shield.fill",
                        label: "SIP Protected (will be skipped)",
                        value: "\(preview.sipProtectedCount)",
                        color: .orange
                    )
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Dry run details toggle
            if !preview.items.isEmpty {
                DisclosureGroup(
                    isExpanded: $showDryRunDetails,
                    content: {
                        dryRunDetails
                    },
                    label: {
                        Text("Show items to be deleted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
                .padding(.horizontal)
            }
            
            // Safety notice
            Text("Files will be moved to Trash and can be recovered")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(action: onConfirm) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Move to Trash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(safetyColor)
                .disabled(!preview.canDelete)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom)
        }
        .frame(width: 450)
        .padding()
    }
    
    // MARK: - Subviews
    
    private var safetyIcon: some View {
        Image(systemName: safetyIconName)
            .foregroundColor(safetyColor)
    }
    
    private var safetyWarning: some View {
        Group {
            switch preview.safetyLevel {
            case .safe:
                Text("These items are safe to delete")
                    .foregroundColor(.green)
            case .caution:
                Text("⚠️ Review carefully before deleting")
                    .foregroundColor(.orange)
            case .dangerous:
                Text("⛔️ Warning: System files detected!")
                    .foregroundColor(.red)
            }
        }
        .font(.subheadline)
        .fontWeight(.medium)
    }
    
    private var dryRunDetails: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(preview.items.prefix(20)) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.isSIPProtected ? "lock.shield.fill" : "doc.fill")
                            .font(.caption2)
                            .foregroundColor(item.isSIPProtected ? .orange : .secondary)
                        
                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(item.size.formattedFileSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if preview.items.count > 20 {
                    Text("... and \(preview.items.count - 20) more items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .frame(maxHeight: 200)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
    
    private func statisticRow(icon: String, label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
    
    // MARK: - Computed Properties
    
    private var safetyIconName: String {
        switch preview.safetyLevel {
        case .safe:
            return "checkmark.shield.fill"
        case .caution:
            return "exclamationmark.triangle.fill"
        case .dangerous:
            return "xmark.shield.fill"
        }
    }
    
    private var safetyColor: Color {
        switch preview.safetyLevel {
        case .safe:
            return .green
        case .caution:
            return .orange
        case .dangerous:
            return .red
        }
    }
}

// MARK: - Preview
#Preview {
    DeletionConfirmationView(
        preview: DeletionPreview(
            items: [
                FileNode(
                    path: URL(fileURLWithPath: "/Users/test/Downloads/large-file.mp4"),
                    name: "large-file.mp4",
                    size: 1_000_000_000,
                    isDirectory: false,
                    dateModified: Date(),
                    dateCreated: Date(),
                    isSIPProtected: false
                ),
                FileNode(
                    path: URL(fileURLWithPath: "/Users/test/Library/Caches/cache.db"),
                    name: "cache.db",
                    size: 50_000_000,
                    isDirectory: false,
                    dateModified: Date(),
                    dateCreated: Date(),
                    isSIPProtected: false
                )
            ],
            totalSize: 1_050_000_000,
            itemCount: 2,
            sipProtectedCount: 0,
            safetyLevel: .caution
        ),
        onConfirm: {},
        onCancel: {}
    )
}

