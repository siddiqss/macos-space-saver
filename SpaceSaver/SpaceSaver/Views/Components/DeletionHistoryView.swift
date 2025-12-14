//
//  DeletionHistoryView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI
import OSLog

struct DeletionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var deletionService = DeletionService.shared
    @State private var selectedItems: Set<UUID> = []
    @State private var isRestoring = false
    @State private var showClearConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if deletionService.recentlyDeleted.isEmpty {
                emptyStateView
            } else {
                historyListView
            }
        }
        .frame(width: 600, height: 500)
        .alert("Clear Deletion History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                deletionService.clearUndoHistory()
            }
        } message: {
            Text("This will permanently clear all deletion history. You won't be able to restore any items after this.")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Deletion History")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Recently deleted items that can be restored")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if !deletionService.recentlyDeleted.isEmpty {
                    Button(action: { showClearConfirmation = true }) {
                        Text("Clear History")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Close")
            }
        }
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Deletion History")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Items you delete will appear here and can be restored")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - History List
    
    private var historyListView: some View {
        VStack(spacing: 0) {
            // Toolbar
            if !selectedItems.isEmpty {
                toolbarView
                Divider()
            }
            
            // List
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(deletionService.recentlyDeleted) { item in
                        historyRow(item: item)
                    }
                }
            }
        }
    }
    
    private var toolbarView: some View {
        HStack {
            Text("\(selectedItems.count) selected")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { restoreSelected() }) {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Restore")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRestoring)
                
                Button("Deselect All") {
                    selectedItems.removeAll()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.accentColor.opacity(0.1))
    }
    
    private func historyRow(item: DeletedItem) -> some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: { toggleSelection(item) }) {
                Image(systemName: selectedItems.contains(item.id) ? "checkmark.square.fill" : "square")
                    .foregroundColor(selectedItems.contains(item.id) ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            
            // Icon
            Image(systemName: "doc.fill")
                .foregroundColor(.secondary)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalPath.lastPathComponent)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(item.originalPath.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(item.deletedAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Size
            Text(item.size.formattedFileSize)
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
            
            // Restore button
            Button(action: { restoreItem(item) }) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.borderless)
            .help("Restore this item")
            .disabled(isRestoring)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(selectedItems.contains(item.id) ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(item)
        }
        .contextMenu {
            Button("Restore") {
                restoreItem(item)
            }
            
            Button("Show Original Location in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.originalPath.deletingLastPathComponent().path)
            }
            
            Button("Show in Trash") {
                NSWorkspace.shared.selectFile(item.trashedPath.path, inFileViewerRootedAtPath: "")
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleSelection(_ item: DeletedItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    private func restoreItem(_ item: DeletedItem) {
        isRestoring = true
        
        Task {
            do {
                try await deletionService.undoDelete(item)
                
                await MainActor.run {
                    isRestoring = false
                    selectedItems.remove(item.id)
                }
            } catch {
                Logger.deletion.error("Failed to restore item: \(error)")
                await MainActor.run {
                    isRestoring = false
                }
            }
        }
    }
    
    private func restoreSelected() {
        let itemsToRestore = deletionService.recentlyDeleted.filter { selectedItems.contains($0.id) }
        
        guard !itemsToRestore.isEmpty else { return }
        
        isRestoring = true
        
        Task {
            do {
                try await deletionService.undoDelete(itemsToRestore)
                
                await MainActor.run {
                    isRestoring = false
                    selectedItems.removeAll()
                }
            } catch {
                Logger.deletion.error("Failed to restore items: \(error)")
                await MainActor.run {
                    isRestoring = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    DeletionHistoryView()
}

