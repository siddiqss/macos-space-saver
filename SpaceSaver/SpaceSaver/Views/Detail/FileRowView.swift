//
//  FileRowView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI
import AppKit
import OSLog


struct FileRowView: View {
    let file: FileNode
    let isSelected: Bool
    let onQuickLook: () -> Void
    let onDelete: (() -> Void)?
    
    @State private var isHovered = false
    @State private var fileIcon: NSImage?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    
    @StateObject private var deletionService = DeletionService.shared
    
    init(file: FileNode, isSelected: Bool, onQuickLook: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.file = file
        self.isSelected = isSelected
        self.onQuickLook = onQuickLook
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // File Icon
            iconView
                .frame(width: 32, height: 32)
            
            // File Name
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(file.path.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // File Size
            Text(file.size.formattedFileSize)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(width: 100, alignment: .trailing)
            
            // Date Modified
            Text(file.dateModified.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .trailing)
            
            // Quick Look Button
            if isHovered && !isDeleting {
                Button(action: onQuickLook) {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                .transition(.opacity)
                .help("Quick Look")
            }
            
            // Open Folder Button
            if isHovered && !isDeleting {
                Button(action: { openFolder() }) {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                .transition(.opacity)
                .help("Show in Finder")
            }
            
            // Delete Button
            if isHovered && !isDeleting && onDelete != nil {
                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash.fill")
                        .font(.caption)
                        .foregroundColor(file.isSIPProtected ? .gray : .red)
                }
                .buttonStyle(.borderless)
                .transition(.opacity)
                .disabled(file.isSIPProtected)
                .help(file.isSIPProtected ? "Cannot delete SIP-protected file" : "Move to Trash")
            }
            
            // Deleting indicator
            if isDeleting {
                ProgressView()
                    .scaleEffect(0.5)
                    .transition(.opacity)
            }
            
            // SIP Protection Indicator
            if file.isSIPProtected {
                Image(systemName: "lock.shield.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .help("This file is protected by System Integrity Protection")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(file.path.path, inFileViewerRootedAtPath: "")
            }
            
            Button("Quick Look") {
                onQuickLook()
            }
            
            Divider()
            
            Button("Copy Path") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(file.path.path, forType: .string)
            }
            
            if onDelete != nil {
                Divider()
                
                Button("Move to Trash") {
                    showDeleteConfirmation = true
                }
                .disabled(file.isSIPProtected)
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            deletionConfirmationSheet
        }
    }
    
    // MARK: - Deletion Confirmation Sheet
    
    private var deletionConfirmationSheet: some View {
        let preview = deletionService.previewDeletion(items: [file])
        
        return DeletionConfirmationView(
            preview: preview,
            onConfirm: {
                showDeleteConfirmation = false
                performDeletion()
            },
            onCancel: {
                showDeleteConfirmation = false
            }
        )
    }
    
    // MARK: - Actions
    
    private func openFolder() {
        let parentPath = file.path.deletingLastPathComponent().path
        NSWorkspace.shared.selectFile(file.path.path, inFileViewerRootedAtPath: parentPath)
    }
    
    private func performDeletion() {
        isDeleting = true
        
        Task {
            do {
                _ = try await deletionService.deleteItem(file)
                
                // Notify parent
                await MainActor.run {
                    onDelete?()
                    isDeleting = false
                }
            } catch {
                Logger.deletion.error("Failed to delete item: \(error)")
                await MainActor.run {
                    isDeleting = false
                }
            }
        }
    }
    
    private var iconView: some View {
        Group {
            if let icon = fileIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundColor(.secondary)
            }
        }
        .task {
            // Load icon asynchronously
            fileIcon = await IconCache.shared.icon(for: file.path.path)
        }
    }
}

