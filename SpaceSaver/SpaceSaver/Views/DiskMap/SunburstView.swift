//
//  SunburstView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI

struct SunburstView: View {
    let segments: [DiskMapSegment]
    let onSegmentTap: (DiskMapSegment) -> Void
    @State private var hoveredSegment: DiskMapSegment?
    @State private var displayedSegments: [DiskMapSegment] = []
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2 - 20
            
            ZStack {
                // Background
                Color(nsColor: .controlBackgroundColor)
                
                // Center circle (legend)
                centerCircle(hoveredSegment: hoveredSegment)
                    .frame(width: radius * 0.3, height: radius * 0.3)
                
                // Sunburst segments
                ForEach(Array(displayedSegments.enumerated()), id: \.element.id) { index, segment in
                    SunburstSegmentShape(
                        segment: segment,
                        center: center,
                        innerRadius: radius * 0.35,
                        outerRadius: radius,
                        startAngle: calculateStartAngle(for: segment, in: displayedSegments),
                        endAngle: calculateEndAngle(for: segment, in: displayedSegments),
                        animationProgress: animationProgress
                    )
                    .fill(segment.color.opacity(hoveredSegment?.id == segment.id ? 1.0 : 0.85))
                    .overlay(
                        SunburstSegmentShape(
                            segment: segment,
                            center: center,
                            innerRadius: radius * 0.35,
                            outerRadius: radius,
                            startAngle: calculateStartAngle(for: segment, in: displayedSegments),
                            endAngle: calculateEndAngle(for: segment, in: displayedSegments),
                            animationProgress: animationProgress
                        )
                        .stroke(
                            hoveredSegment?.id == segment.id ? Color.white : Color.black.opacity(0.2),
                            lineWidth: hoveredSegment?.id == segment.id ? 2 : 1
                        )
                    )
                    .onTapGesture {
                        onSegmentTap(segment)
                    }
                    .onHover { isHovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredSegment = isHovering ? segment : nil
                        }
                    }
                }
                
                // Labels for large segments
                ForEach(displayedSegments.filter { $0.percentage > 5 }) { segment in
                    sunburstLabel(
                        segment: segment,
                        center: center,
                        radius: radius,
                        startAngle: calculateStartAngle(for: segment, in: displayedSegments),
                        endAngle: calculateEndAngle(for: segment, in: displayedSegments)
                    )
                }
            }
        }
        .onAppear {
            progressivelyLoadSegments()
            
            // Animate the sunburst growth
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: segments) { _, _ in
            displayedSegments = []
            animationProgress = 0
            progressivelyLoadSegments()
            
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
    
    private func centerCircle(hoveredSegment: DiskMapSegment?) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .controlBackgroundColor),
                            Color(nsColor: .controlBackgroundColor).opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            if let hovered = hoveredSegment {
                VStack(spacing: 6) {
                    Text(hovered.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    Text(FileSizeFormatter.format(bytes: hovered.size))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(hovered.color)
                    
                    Text("\(String(format: "%.1f", hovered.percentage))%")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(20)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Disk Map")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text("Hover to explore")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
    }
    
    private func sunburstLabel(
        segment: DiskMapSegment,
        center: CGPoint,
        radius: CGFloat,
        startAngle: Angle,
        endAngle: Angle
    ) -> some View {
        let midAngle = (startAngle.radians + endAngle.radians) / 2
        let labelRadius = radius * 0.67
        let labelX = center.x + labelRadius * cos(midAngle)
        let labelY = center.y + labelRadius * sin(midAngle)
        
        return Text(segment.name)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            .position(x: labelX, y: labelY)
            .opacity(animationProgress)
    }
    
    private func calculateStartAngle(for segment: DiskMapSegment, in segments: [DiskMapSegment]) -> Angle {
        let totalSize = segments.reduce(0) { $0 + $1.size }
        guard totalSize > 0 else { return .degrees(0) }
        
        let precedingSize = segments.prefix(while: { $0.id != segment.id })
            .reduce(0) { $0 + $1.size }
        
        let ratio = Double(precedingSize) / Double(totalSize)
        return .degrees(ratio * 360 - 90) // Start from top (-90 degrees)
    }
    
    private func calculateEndAngle(for segment: DiskMapSegment, in segments: [DiskMapSegment]) -> Angle {
        let totalSize = segments.reduce(0) { $0 + $1.size }
        guard totalSize > 0 else { return .degrees(0) }
        
        let precedingSize = segments.prefix(while: { $0.id != segment.id })
            .reduce(0) { $0 + $1.size }
        let includingSize = precedingSize + segment.size
        
        let ratio = Double(includingSize) / Double(totalSize)
        return .degrees(ratio * 360 - 90) // Start from top (-90 degrees)
    }
    
    private func progressivelyLoadSegments() {
        // Sort segments by size for better visualization
        let sortedSegments = segments.sorted { $0.size > $1.size }
        
        // Progressive rendering: add segments in batches
        let batchSize = 10
        for (index, segment) in sortedSegments.enumerated() {
            let delay = Double(index / batchSize) * 0.05 // 50ms per batch
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.2)) {
                    displayedSegments.append(segment)
                }
            }
        }
    }
}

// MARK: - Sunburst Segment Shape
private struct SunburstSegmentShape: Shape {
    let segment: DiskMapSegment
    let center: CGPoint
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let startAngle: Angle
    let endAngle: Angle
    var animationProgress: CGFloat
    
    var animatableData: CGFloat {
        get { animationProgress }
        set { animationProgress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let currentOuterRadius = outerRadius * animationProgress
        let currentInnerRadius = innerRadius * animationProgress
        
        // Arc for outer radius
        path.addArc(
            center: center,
            radius: currentOuterRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        
        // Line to inner radius
        let innerEndX = center.x + currentInnerRadius * cos(endAngle.radians)
        let innerEndY = center.y + currentInnerRadius * sin(endAngle.radians)
        path.addLine(to: CGPoint(x: innerEndX, y: innerEndY))
        
        // Arc for inner radius (reverse direction)
        path.addArc(
            center: center,
            radius: currentInnerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )
        
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    SunburstView(
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
        ],
        onSegmentTap: { _ in }
    )
    .frame(width: 800, height: 600)
}

