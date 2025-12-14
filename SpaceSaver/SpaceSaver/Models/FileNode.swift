//
//  FileNode.swift
//  SpaceSaver
//
//  Created on 2025
//

import Foundation

struct FileNode: Identifiable, Hashable {
    let id: UUID
    let path: URL
    let name: String
    let size: Int64
    let isDirectory: Bool
    let dateModified: Date
    let dateCreated: Date
    var children: [FileNode]? // For directories
    var category: CategoryType?
    var isSIPProtected: Bool = false
    
    init(
        id: UUID = UUID(),
        path: URL,
        name: String,
        size: Int64,
        isDirectory: Bool,
        dateModified: Date,
        dateCreated: Date,
        children: [FileNode]? = nil,
        category: CategoryType? = nil,
        isSIPProtected: Bool = false
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.dateModified = dateModified
        self.dateCreated = dateCreated
        self.children = children
        self.category = category
        self.isSIPProtected = isSIPProtected
    }
}

