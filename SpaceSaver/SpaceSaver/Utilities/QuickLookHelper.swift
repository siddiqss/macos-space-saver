//
//  QuickLookHelper.swift
//  SpaceSaver
//
//  Created on 2025
//

import AppKit
import QuickLookUI

class QuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookHelper()
    
    private var previewURLs: [URL] = []
    private var currentIndex: Int = 0
    
    private override init() {
        super.init()
    }
    
    func preview(url: URL) {
        previewURLs = [url]
        currentIndex = 0
        
        if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.makeKeyAndOrderFront(nil)
        }
    }
    
    func preview(urls: [URL], currentIndex: Int = 0) {
        previewURLs = urls
        self.currentIndex = max(0, min(currentIndex, urls.count - 1))
        
        if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.currentPreviewItemIndex = self.currentIndex
            panel.makeKeyAndOrderFront(nil)
        }
    }
    
    // MARK: - QLPreviewPanelDataSource
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return previewURLs.count
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index >= 0 && index < previewURLs.count else {
            return nil
        }
        return previewURLs[index] as QLPreviewItem
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // Handle keyboard events
        if event.type == .keyDown {
            switch event.keyCode {
            case 36: // Enter
                panel.close()
                return true
            case 53: // Escape
                panel.close()
                return true
            default:
                break
            }
        }
        return false
    }
}

