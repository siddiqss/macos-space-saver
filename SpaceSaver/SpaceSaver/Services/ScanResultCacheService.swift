//
//  ScanResultCacheService.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation
import SwiftData
import OSLog

/// Service for managing scan result caching with SwiftData
class ScanResultCacheService {
    private let logger = Logger(subsystem: "com.spacesaver", category: "cache")
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Saves a scan result to cache
    func saveScanResult(_ result: ScanResult, mode: ScanMode, scannedPath: String) {
        
        // Convert to cached models
        let cachedCategories = result.categories.map { category in
            // Limit cached items to top 1000 by size for performance
            // We keep the total stats but not all file items
            let topItems = category.items
                .sorted { $0.size > $1.size }
                .prefix(1000)
            
            let cachedItems = topItems.map { fileNode in
                CachedFileNode(
                    id: fileNode.id,
                    path: fileNode.path.path,
                    name: fileNode.name,
                    size: fileNode.size,
                    isDirectory: fileNode.isDirectory,
                    dateModified: fileNode.dateModified,
                    dateCreated: fileNode.dateCreated,
                    isSIPProtected: fileNode.isSIPProtected,
                    category: fileNode.category?.rawValue
                )
            }
            
            // Encode file type breakdown
            let fileTypeBreakdownData: Data?
            if !category.fileTypeBreakdown.isEmpty {
                fileTypeBreakdownData = try? JSONEncoder().encode(category.fileTypeBreakdown)
            } else {
                fileTypeBreakdownData = nil
            }
            
            // Encode subcategories
            let subcategoriesData: Data?
            if let subcats = category.subcategories, !subcats.isEmpty {
                subcategoriesData = try? JSONEncoder().encode(subcats)
            } else {
                subcategoriesData = nil
            }
            
            return CachedCategory(
                id: category.id,
                type: category.type.rawValue,
                title: category.title,
                icon: category.icon,
                safetyLevel: category.safetyLevel.description,
                totalSize: category.totalSize,
                itemCount: category.itemCount,
                lastScanned: category.lastScanned,
                largestFileName: category.largestFile?.name,
                largestFileSize: category.largestFile?.size,
                largestFilePath: category.largestFile?.path.path,
                oldestFileName: category.oldestFile?.name,
                oldestFileDate: category.oldestFile?.dateCreated,
                oldestFilePath: category.oldestFile?.path.path,
                averageFileSize: category.averageFileSize,
                fileTypeBreakdownData: fileTypeBreakdownData,
                potentialSavings: category.potentialSavings,
                subcategoriesData: subcategoriesData,
                items: Array(cachedItems)
            )
        }
        
        let modeString: String
        switch mode {
        case .entireDisk:
            modeString = "entireDisk"
        case .specificFolder:
            modeString = "specificFolder"
        }
        
        let cachedResult = CachedScanResult(
            id: result.id,
            date: result.date,
            totalScannedSize: result.totalScannedSize,
            scanDuration: result.scanDuration,
            scanMode: modeString,
            scannedPath: scannedPath,
            categories: cachedCategories
        )
        
        modelContext.insert(cachedResult)
        
        do {
            try modelContext.save()
            logger.info("Scan result cached successfully: \(result.id)")
        } catch {
            logger.error("Failed to save scan result: \(error.localizedDescription)")
        }
    }
    
    /// Retrieves the most recent scan result
    func getLatestScanResult() -> ScanResult? {
        let descriptor = FetchDescriptor<CachedScanResult>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let results = try modelContext.fetch(descriptor)
            return results.first?.toScanResult()
        } catch {
            logger.error("Failed to fetch latest scan result: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Retrieves all cached scan results
    func getAllScanResults() -> [ScanResult] {
        let descriptor = FetchDescriptor<CachedScanResult>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let results = try modelContext.fetch(descriptor)
            return results.map { $0.toScanResult() }
        } catch {
            logger.error("Failed to fetch scan results: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Deletes a specific scan result
    func deleteScanResult(id: UUID) {
        let descriptor = FetchDescriptor<CachedScanResult>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            let results = try modelContext.fetch(descriptor)
            for result in results {
                modelContext.delete(result)
            }
            try modelContext.save()
            logger.info("Deleted scan result: \(id)")
        } catch {
            logger.error("Failed to delete scan result: \(error.localizedDescription)")
        }
    }
    
    /// Clears all cached scan results
    func clearAllCache() {
        let descriptor = FetchDescriptor<CachedScanResult>()
        
        do {
            let results = try modelContext.fetch(descriptor)
            for result in results {
                modelContext.delete(result)
            }
            try modelContext.save()
            logger.info("Cleared all cached scan results")
        } catch {
            logger.error("Failed to clear cache: \(error.localizedDescription)")
        }
    }
    
    /// Gets cache statistics
    func getCacheStats() -> (count: Int, totalSize: Int64, oldestDate: Date?, newestDate: Date?) {
        let descriptor = FetchDescriptor<CachedScanResult>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let results = try modelContext.fetch(descriptor)
            let count = results.count
            let totalSize = results.reduce(0) { $0 + $1.totalScannedSize }
            let oldestDate = results.last?.date
            let newestDate = results.first?.date
            
            return (count, totalSize, oldestDate, newestDate)
        } catch {
            logger.error("Failed to get cache stats: \(error.localizedDescription)")
            return (0, 0, nil, nil)
        }
    }
    
    /// Loads file items for a specific category (lazy loading)
    func loadCategoryItems(categoryId: UUID) -> [FileNode] {
        let descriptor = FetchDescriptor<CachedCategory>(
            predicate: #Predicate { $0.id == categoryId }
        )
        
        do {
            let results = try modelContext.fetch(descriptor)
            if let category = results.first {
                return category.loadFileItems()
            }
            return []
        } catch {
            logger.error("Failed to load category items: \(error.localizedDescription)")
            return []
        }
    }
}

