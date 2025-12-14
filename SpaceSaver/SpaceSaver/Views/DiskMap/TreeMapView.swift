//
//  TreeMapView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI
import UniformTypeIdentifiers

/// Interactive TreeMap visualization for disk space analysis
/// Implements the squarified treemap algorithm for optimal aspect ratios
struct TreeMapView: View {
    let segments: [DiskMapSegment]
    let onSegmentTap: (DiskMapSegment) -> Void
    
    @State private var hoveredSegment: DiskMapSegment?
    @State private var hoveredRect: CGRect?
    @State private var mouseLocation: CGPoint = .zero
    @State private var segmentRects: [UUID: CGRect] = [:]
    @State private var displayedSegments: [DiskMapSegment] = []
    
    private let minSegmentSize: CGFloat = 8 // Minimum size to display a segment
    private let minLabelSize: CGFloat = 40 // Minimum size to show labels
    private let borderWidth: CGFloat = 1
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background
                Color(nsColor: .controlBackgroundColor)
                
                // TreeMap canvas
                Canvas { context, size in
                    let layout = calculateSquarifiedLayout(
                        segments: displayedSegments,
                        rect: CGRect(origin: .zero, size: size)
                    )
                    
                    // Store rects for interaction
                    DispatchQueue.main.async {
                        var newRects: [UUID: CGRect] = [:]
                        for (segment, rect) in layout {
                            newRects[segment.id] = rect
                        }
                        if segmentRects != newRects {
                            segmentRects = newRects
                        }
                    }
                    
                    // Draw all segments
                    for (segment, rect) in layout {
                        drawSegment(context: context, segment: segment, rect: rect)
                    }
                }
                
                // Interaction overlay
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            mouseLocation = location
                            updateHoveredSegment(at: location)
                        case .ended:
                            hoveredSegment = nil
                            hoveredRect = nil
                        }
                    }
                    .onTapGesture { location in
                        if let segment = findSegment(at: location) {
                            onSegmentTap(segment)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Track mouse for hover
                                mouseLocation = value.location
                                updateHoveredSegment(at: value.location)
                            }
                    )
                
                // Tooltip overlay
                if let hoveredSegment = hoveredSegment, let hoveredRect = hoveredRect {
                    TooltipView(segment: hoveredSegment, segmentRect: hoveredRect)
                        .position(x: mouseLocation.x, y: max(50, mouseLocation.y - 50))
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.15), value: hoveredSegment.id)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            loadSegmentsProgressively()
        }
        .onChange(of: segments) { oldValue, newValue in
            if oldValue != newValue {
                displayedSegments = []
                loadSegmentsProgressively()
            }
        }
    }
    
    // MARK: - Segment Loading
    
    private func loadSegmentsProgressively() {
        // For responsive UI, load segments in batches
        let sortedSegments = segments.sorted { $0.size > $1.size }
        
        if sortedSegments.count < 100 {
            // For small datasets, load immediately
            displayedSegments = sortedSegments
        } else {
            // For large datasets, progressive loading
            let batchSize = 25
            for (index, segment) in sortedSegments.enumerated() {
                let delay = Double(index / batchSize) * 0.03
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    displayedSegments.append(segment)
                }
            }
        }
    }
    
    // MARK: - Interaction Handling
    
    private func updateHoveredSegment(at location: CGPoint) {
        if let segment = findSegment(at: location) {
            hoveredSegment = segment
            hoveredRect = segmentRects[segment.id]
        } else {
            hoveredSegment = nil
            hoveredRect = nil
        }
    }
    
    private func findSegment(at location: CGPoint) -> DiskMapSegment? {
        // Find the smallest (most specific) segment at this location
        var foundSegment: DiskMapSegment?
        var smallestArea: CGFloat = .infinity
        
        for (id, rect) in segmentRects {
            if rect.contains(location) {
                let area = rect.width * rect.height
                if area < smallestArea {
                    smallestArea = area
                    if let segment = displayedSegments.first(where: { $0.id == id }) {
                        foundSegment = segment
                    }
                }
            }
        }
        
        return foundSegment
    }
    
    // MARK: - Drawing
    
    private func drawSegment(context: GraphicsContext, segment: DiskMapSegment, rect: CGRect) {
        // Skip if too small
        guard rect.width >= minSegmentSize && rect.height >= minSegmentSize else { return }
        
        let isHovered = hoveredSegment?.id == segment.id
        let cornerRadius: CGFloat = 2
        
        // Create path
        let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
        
        // Determine color based on size and category
        let baseColor = getSegmentColor(segment)
        let fillColor = baseColor.opacity(isHovered ? 0.9 : 0.8)
        
        // Fill
        context.fill(path, with: .color(fillColor))
        
        // Border - darker for hover, subtle otherwise
        let borderColor = isHovered ? Color.white.opacity(0.9) : Color.black.opacity(0.15)
        let borderWidth: CGFloat = isHovered ? 2.5 : self.borderWidth
        context.stroke(path, with: .color(borderColor), lineWidth: borderWidth)
        
        // Draw nested grid pattern for directories with children
        if segment.isDirectory && !segment.children.isEmpty && rect.width > 80 && rect.height > 80 {
            drawGridPattern(context: context, rect: rect, color: baseColor)
        }
        
        // Draw label if enough space
        if rect.width > minLabelSize && rect.height > minLabelSize {
            drawLabel(context: context, segment: segment, rect: rect, isHovered: isHovered)
        }
    }
    
    private func drawGridPattern(context: GraphicsContext, rect: CGRect, color: Color) {
        // Subtle grid pattern to indicate nested content
        let gridColor = Color.black.opacity(0.05)
        let spacing: CGFloat = max(20, rect.width / 4)
        
        let gridCount = Int(rect.width / spacing)
        for i in 1..<gridCount {
            let x = rect.minX + CGFloat(i) * spacing
            if x < rect.maxX {
                let verticalPath = Path { path in
                    path.move(to: CGPoint(x: x, y: rect.minY))
                    path.addLine(to: CGPoint(x: x, y: rect.maxY))
                }
                context.stroke(verticalPath, with: .color(gridColor), lineWidth: 0.5)
            }
        }
    }
    
    private func drawLabel(context: GraphicsContext, segment: DiskMapSegment, rect: CGRect, isHovered: Bool) {
        let textColor = contrastingTextColor(for: getSegmentColor(segment))
        let padding: CGFloat = 6
        
        // Draw name
        var nameContext = context
        nameContext.translateBy(x: rect.minX + padding, y: rect.minY + padding)
        
        let fontSize: CGFloat = min(12, max(9, rect.height / 5))
        let fontWeight: Font.Weight = isHovered ? .bold : .semibold
        
        let name = segment.name.count > 25 ? String(segment.name.prefix(22)) + "..." : segment.name
        
        nameContext.draw(
            Text(name)
                .font(.system(size: fontSize, weight: fontWeight))
                .foregroundColor(textColor),
            at: .zero,
            anchor: .topLeading
        )
        
        // Draw size if enough space
        if rect.height > 60 {
            let sizeText = FileSizeFormatter.format(bytes: segment.size)
            var sizeContext = context
            sizeContext.translateBy(x: rect.minX + padding, y: rect.minY + padding + fontSize + 4)
            sizeContext.draw(
                Text(sizeText)
                    .font(.system(size: fontSize - 1))
                    .foregroundColor(textColor.opacity(0.85)),
                at: .zero,
                anchor: .topLeading
            )
        }
        
        // Draw file count for directories
        if segment.isDirectory && !segment.children.isEmpty && rect.height > 80 {
            let itemText = "\(segment.children.count) items"
            var itemContext = context
            itemContext.translateBy(x: rect.minX + padding, y: rect.maxY - padding - fontSize)
            itemContext.draw(
                Text(itemText)
                    .font(.system(size: fontSize - 1))
                    .foregroundColor(textColor.opacity(0.7)),
                at: .zero,
                anchor: .bottomLeading
            )
        }
    }
    
    // MARK: - Color Management
    
    private func getSegmentColor(_ segment: DiskMapSegment) -> Color {
        if let category = segment.category {
            return DiskMapSegment.colorForCategory(category)
        }
        
        // Color by file type if no category
        if !segment.isDirectory {
            return colorForFileExtension(segment.name)
        }
        
        // Default depth-based color for directories
        return DiskMapSegment.colorForDepth(segment.depth)
    }
    
    private func colorForFileExtension(_ filename: String) -> Color {
        let ext = (filename as NSString).pathExtension.lowercased()
        
        switch ext {
        // Images
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "svg", "heic":
            return Color(red: 0.2, green: 0.7, blue: 0.9) // Light blue
        // Videos
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v":
            return Color(red: 0.9, green: 0.3, blue: 0.5) // Pink/Red
        // Audio
        case "mp3", "wav", "aac", "flac", "m4a", "wma", "ogg":
            return Color(red: 0.6, green: 0.4, blue: 0.9) // Purple
        // Documents
        case "pdf", "doc", "docx", "txt", "rtf", "pages":
            return Color(red: 0.95, green: 0.6, blue: 0.2) // Orange
        // Code
        case "swift", "js", "ts", "py", "java", "cpp", "c", "h", "m", "go", "rs":
            return Color(red: 0.3, green: 0.8, blue: 0.5) // Green
        // Archives
        case "zip", "rar", "7z", "tar", "gz", "bz2", "dmg":
            return Color(red: 0.7, green: 0.7, blue: 0.3) // Yellow
        // Disk images
        case "iso", "img", "vdi", "vmdk":
            return Color(red: 0.5, green: 0.5, blue: 0.8) // Blue-purple
        default:
            return Color(red: 0.6, green: 0.6, blue: 0.6) // Gray
        }
    }
    
    private func contrastingTextColor(for backgroundColor: Color) -> Color {
        // Use white text for better contrast on colored backgrounds
        return .white
    }
    
    // MARK: - Squarified Treemap Algorithm
    // Based on the algorithm by Mark Bruls, Kees Huizing, and Jarke J. van Wijk
    
    private func calculateSquarifiedLayout(segments: [DiskMapSegment], rect: CGRect) -> [(DiskMapSegment, CGRect)] {
        guard !segments.isEmpty else { return [] }
        
        let totalSize = segments.reduce(0) { $0 + $1.size }
        guard totalSize > 0 else { return [] }
        
        // Sort by size descending for better layout
        let sortedSegments = segments.sorted { $0.size > $1.size }
        
        return squarify(segments: sortedSegments, rect: rect, totalSize: totalSize)
    }
    
    private func squarify(segments: [DiskMapSegment], rect: CGRect, totalSize: Int64) -> [(DiskMapSegment, CGRect)] {
        guard !segments.isEmpty && rect.width > 0 && rect.height > 0 else { return [] }
        
        var layout: [(DiskMapSegment, CGRect)] = []
        var remainingSegments = segments
        var remainingRect = rect
        var currentTotalSize = totalSize
        
        while !remainingSegments.isEmpty {
            let result = layoutRow(
                segments: remainingSegments,
                rect: remainingRect,
                totalSize: currentTotalSize
            )
            
            layout.append(contentsOf: result.layout)
            remainingSegments = result.remainingSegments
            remainingRect = result.remainingRect
            
            // Update total size for remaining segments
            currentTotalSize = remainingSegments.reduce(0) { $0 + $1.size }
            
            // Safety check
            if result.layout.isEmpty {
                break
            }
        }
        
        return layout
    }
    
    private func layoutRow(
        segments: [DiskMapSegment],
        rect: CGRect,
        totalSize: Int64
    ) -> (layout: [(DiskMapSegment, CGRect)], remainingSegments: [DiskMapSegment], remainingRect: CGRect) {
        guard !segments.isEmpty && totalSize > 0 else {
            return ([], [], rect)
        }
        
        let isHorizontal = rect.width >= rect.height
        var row: [DiskMapSegment] = []
        var remainingSegments = segments
        
        // Find optimal row using aspect ratio
        while !remainingSegments.isEmpty {
            let candidate = remainingSegments[0]
            let testRow = row + [candidate]
            
            let rowSize = testRow.reduce(0) { $0 + $1.size }
            let worstAspect = calculateWorstAspectRatio(
                segments: testRow,
                rowSize: rowSize,
                rect: rect,
                totalSize: totalSize,
                isHorizontal: isHorizontal
            )
            
            // If adding this segment improves or maintains aspect ratio, add it
            if row.isEmpty {
                row.append(candidate)
                remainingSegments.removeFirst()
            } else {
                let currentRowSize = row.reduce(0) { $0 + $1.size }
                let currentWorstAspect = calculateWorstAspectRatio(
                    segments: row,
                    rowSize: currentRowSize,
                    rect: rect,
                    totalSize: totalSize,
                    isHorizontal: isHorizontal
                )
                
                if worstAspect <= currentWorstAspect {
                    row.append(candidate)
                    remainingSegments.removeFirst()
                } else {
                    break
                }
            }
            
            // Limit row size for performance
            if row.count >= 20 {
                break
            }
        }
        
        // Layout the row
        let rowLayout = layoutRowSegments(
            segments: row,
            rect: rect,
            totalSize: totalSize,
            isHorizontal: isHorizontal
        )
        
        return (rowLayout.layout, remainingSegments, rowLayout.remainingRect)
    }
    
    private func calculateWorstAspectRatio(
        segments: [DiskMapSegment],
        rowSize: Int64,
        rect: CGRect,
        totalSize: Int64,
        isHorizontal: Bool
    ) -> Double {
        guard rowSize > 0 && totalSize > 0 else { return .infinity }
        
        let rowRatio = Double(rowSize) / Double(totalSize)
        let rowBreadth = isHorizontal ? rect.height * rowRatio : rect.width * rowRatio
        
        guard rowBreadth > 0 else { return .infinity }
        
        var worstAspect: Double = 0
        
        for segment in segments {
            let segmentRatio = Double(segment.size) / Double(rowSize)
            let segmentLength = (isHorizontal ? rect.width : rect.height) * segmentRatio
            
            let aspect = max(segmentLength / rowBreadth, rowBreadth / segmentLength)
            worstAspect = max(worstAspect, aspect)
        }
        
        return worstAspect
    }
    
    private func layoutRowSegments(
        segments: [DiskMapSegment],
        rect: CGRect,
        totalSize: Int64,
        isHorizontal: Bool
    ) -> (layout: [(DiskMapSegment, CGRect)], remainingRect: CGRect) {
        guard !segments.isEmpty && totalSize > 0 else {
            return ([], rect)
        }
        
        let rowSize = segments.reduce(0) { $0 + $1.size }
        let rowRatio = Double(rowSize) / Double(totalSize)
        
        var layout: [(DiskMapSegment, CGRect)] = []
        var position: CGFloat = isHorizontal ? rect.minX : rect.minY
        
        let rowBreadth = isHorizontal ? rect.height * rowRatio : rect.width * rowRatio
        
        for segment in segments {
            let segmentRatio = Double(segment.size) / Double(rowSize)
            
            let segmentRect: CGRect
            if isHorizontal {
                let width = rect.width * segmentRatio
                segmentRect = CGRect(
                    x: position,
                    y: rect.minY,
                    width: width,
                    height: rowBreadth
                )
                position += width
            } else {
                let height = rect.height * segmentRatio
                segmentRect = CGRect(
                    x: rect.minX,
                    y: position,
                    width: rowBreadth,
                    height: height
                )
                position += height
            }
            
            layout.append((segment, segmentRect))
        }
        
        // Calculate remaining rectangle
        let remainingRect: CGRect
        if isHorizontal {
            remainingRect = CGRect(
                x: rect.minX,
                y: rect.minY + rowBreadth,
                width: rect.width,
                height: rect.height - rowBreadth
            )
        } else {
            remainingRect = CGRect(
                x: rect.minX + rowBreadth,
                y: rect.minY,
                width: rect.width - rowBreadth,
                height: rect.height
            )
        }
        
        return (layout, remainingRect)
    }
}

// MARK: - Tooltip View

private struct TooltipView: View {
    let segment: DiskMapSegment
    let segmentRect: CGRect
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with icon and name
            HStack(spacing: 6) {
                Image(systemName: segment.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 12))
                    .foregroundColor(segment.color)
                
                Text(segment.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 200)
            }
            
            Divider()
            
            // Stats
            HStack(spacing: 4) {
                Text("Size:")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(FileSizeFormatter.format(bytes: segment.size))
                    .font(.system(size: 10, weight: .medium))
            }
            
            HStack(spacing: 4) {
                Text("Percentage:")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f%%", segment.percentage))
                    .font(.system(size: 10, weight: .medium))
            }
            
            if segment.isDirectory && !segment.children.isEmpty {
                HStack(spacing: 4) {
                    Text("Items:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(segment.children.count)")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            
            if let category = segment.category {
                HStack(spacing: 4) {
                    Text("Category:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(segment.color)
                }
            }
            
            // Hint
            Divider()
            
            Text("Click to explore")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.8))
                .italic()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(segment.color.opacity(0.4), lineWidth: 1.5)
        )
    }
}

// MARK: - Preview

#Preview {
    TreeMapView(
        segments: [
            DiskMapSegment(
                name: "Documents",
                path: "/Users/test/Documents",
                size: 5_000_000_000,
                percentage: 40,
                depth: 0,
                category: .largeFiles
            ),
            DiskMapSegment(
                name: "Downloads",
                path: "/Users/test/Downloads",
                size: 3_000_000_000,
                percentage: 25,
                depth: 0,
                category: .oldDownloads
            ),
            DiskMapSegment(
                name: "Library",
                path: "/Users/test/Library",
                size: 2_000_000_000,
                percentage: 20,
                depth: 0,
                category: .caches
            ),
            DiskMapSegment(
                name: "Applications",
                path: "/Applications",
                size: 1_500_000_000,
                percentage: 15,
                depth: 0,
                category: .unusedApps
            ),
            DiskMapSegment(
                name: "Developer",
                path: "/Users/test/Developer",
                size: 1_200_000_000,
                percentage: 12,
                depth: 0,
                category: .developer
            ),
        ],
        onSegmentTap: { _ in }
    )
    .frame(width: 1000, height: 700)
}
