//
//  SafetyLevelIndicator.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI

struct SafetyLevelIndicator: View {
    let safetyLevel: SafetyLevel
    let showLabel: Bool
    
    init(safetyLevel: SafetyLevel, showLabel: Bool = true) {
        self.safetyLevel = safetyLevel
        self.showLabel = showLabel
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundColor(color)
            
            if showLabel {
                Text(label)
                    .font(.caption)
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(6)
        .help(tooltip)
    }
    
    // MARK: - Computed Properties
    
    private var iconName: String {
        switch safetyLevel {
        case .safe:
            return "checkmark.shield.fill"
        case .caution:
            return "exclamationmark.triangle.fill"
        case .dangerous:
            return "xmark.shield.fill"
        }
    }
    
    private var label: String {
        switch safetyLevel {
        case .safe:
            return "Safe"
        case .caution:
            return "Caution"
        case .dangerous:
            return "Dangerous"
        }
    }
    
    private var color: Color {
        switch safetyLevel {
        case .safe:
            return .green
        case .caution:
            return .orange
        case .dangerous:
            return .red
        }
    }
    
    private var tooltip: String {
        switch safetyLevel {
        case .safe:
            return "These files are safe to delete - typically caches and temporary files"
        case .caution:
            return "Review carefully - may include downloads or large files you want to keep"
        case .dangerous:
            return "Dangerous - contains system files or applications that may break your system"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        SafetyLevelIndicator(safetyLevel: .safe)
        SafetyLevelIndicator(safetyLevel: .caution)
        SafetyLevelIndicator(safetyLevel: .dangerous)
        
        HStack {
            SafetyLevelIndicator(safetyLevel: .safe, showLabel: false)
            SafetyLevelIndicator(safetyLevel: .caution, showLabel: false)
            SafetyLevelIndicator(safetyLevel: .dangerous, showLabel: false)
        }
    }
    .padding()
}

