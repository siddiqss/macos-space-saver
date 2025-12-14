//
//  ScanProgressView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI

struct ScanProgressView: View {
    @ObservedObject var scanner: FileScannerService
    @Environment(\.dismiss) var dismiss
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 30) {
            // Animated Icon
            if scanner.isScanning {
                ScanningIconView()
                    .frame(width: 80, height: 80)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .symbolEffect(.bounce, value: !scanner.isScanning)
            }
            
            // Status Text
            VStack(spacing: 12) {
                if scanner.isScanning {
                    Text("Scanning Your Mac")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(scanner.currentPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 450)
                        .padding(.horizontal)
                    
                    // Progress Stats
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(scanner.filesScanned)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Files")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        VStack(spacing: 4) {
                            Text(scanner.bytesScanned.formattedFileSize)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Scanned")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if scanner.totalFilesToScan > 0 {
                            Divider()
                                .frame(height: 30)
                            
                            VStack(spacing: 4) {
                                Text("\(Int(scanner.progress * 100))%")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .monospacedDigit()
                                Text("Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                } else {
                    Text("Scan Complete")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            // Enhanced Progress Indicator
            if scanner.isScanning {
                VStack(spacing: 8) {
                    ProgressView(value: animatedProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 400)
                        .tint(.blue)
                    
                    if scanner.totalFilesToScan > 0 {
                        Text("\(scanner.filesScanned) of \(scanner.totalFilesToScan) files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Cancel Button
            if scanner.isScanning {
                Button(action: {
                    scanner.cancel()
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Cancel Scan")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.red)
            } else {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(40)
        .frame(width: 550)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: scanner.progress) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.3)) {
                animatedProgress = newValue
    }
}
        .onAppear {
            animatedProgress = scanner.progress
        }
    }
}

// MARK: - Scanning Icon Animation
struct ScanningIconView: View {
    @State private var isRotating = false
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Pulsing background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.05)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
                .scaleEffect(isPulsing ? 1.1 : 1.0)
                .opacity(isPulsing ? 0.7 : 1.0)
            
            // Rotating icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 35))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                isRotating = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}


