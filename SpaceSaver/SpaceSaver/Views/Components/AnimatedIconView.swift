//
//  AnimatedIconView.swift
//  SpaceSaver
//
//  Created on 2025
//

import SwiftUI

struct AnimatedIconView: View {
    @State private var isPulsing = false
    @State private var isRotating = false
    
    var body: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 120, height: 120)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0 : 1)
            
            // Middle ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 100, height: 100)
                .scaleEffect(isPulsing ? 1.15 : 1.0)
                .opacity(isPulsing ? 0.5 : 1)
            
            // Main icon
            Image(systemName: "externaldrive.badge.checkmark")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(isRotating ? 360 : 0))
        }
        .onAppear {
            // Pulsing animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            
            // Slow rotation
            withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
                isRotating = true
            }
        }
    }
}

