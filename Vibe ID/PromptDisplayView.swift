// PromptDisplayView.swift
// Vibe ID
//
// Created by Studio Carlos in 2025.
// Copyright (C) 2025 Studio Carlos
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import SwiftUI

struct PromptDisplayView: View {
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var recognitionViewModel: RecognitionViewModel
    @State private var currentPromptIndex = 0
    @State private var isAnimating = false
    @State private var scrollText = false
    @State private var textWidth: CGFloat = .zero
    @State private var scrollViewWidth: CGFloat = .zero
    
    // Standard timer for automatic prompt change (replaces Timer.publish)
    @State private var autoAdvanceTimer: Timer?
    
    // Uniform duration for animation and timer (16 seconds)
    private let promptDuration: TimeInterval = 16.0
    
    var body: some View {
        promptContent
            .padding(.vertical)
            .onAppear {
                // Starts the timer when the view appears
                startAutoAdvanceTimer()
            }
            .onDisappear {
                // Invalidates the timer when the view disappears
                stopAutoAdvanceTimer()
            }
    }
    
    // Main content
    private var promptContent: some View {
        VStack(spacing: 12) {
            if recognitionViewModel.llmState == .generating {
                LoadingPromptView()
            } else if let currentPrompt = llmManager.currentPrompts[safe: currentPromptIndex] {
                scrollingPromptView(for: currentPrompt)
                
                // Interactive progress indicator
                if llmManager.currentPrompts.count > 1 {
                    progressIndicator
                }
            }
        }
    }
    
    // Scrolling banner view
    private func scrollingPromptView(for prompt: LLMPrompt) -> some View {
        ZStack {
            // Banner background
            promptBackground
            
            // Scrolling content
            scrollingContent(for: prompt)
                .id(currentPromptIndex) // Force view recreation on index change
        }
        .frame(height: 50)
        .padding(.horizontal, 16)
    }
    
    // Styled banner background
    private var promptBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.blue.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
    
    // Scrolling content with text
    private func scrollingContent(for prompt: LLMPrompt) -> some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // Prompt number with distinct effect
                    Text("PROMPT \(currentPromptIndex + 1): ")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 4)
                    
                    // Prompt text
                    Text(prompt.prompt)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .background(GeometryReader { geo in
                            Color.clear.onAppear {
                                textWidth = geo.size.width
                            }
                        })
                    
                    // Space and separator at the end of the text
                    Text("   •   ")
                        .foregroundColor(.cyan)
                        .fontWeight(.bold)
                    
                    // Empty space at the end (instead of repeating the text)
                    Text("")
                        .frame(width: containerWidth)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .offset(x: scrollText ? -textWidth - 60 : 0)
                .animation(
                    Animation.linear(duration: promptDuration)
                        .repeatForever(autoreverses: false),
                    value: scrollText
                )
            }
            .onAppear {
                scrollViewWidth = containerWidth
                // Reset animation state and start fresh
                scrollText = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scrollText = true
                }
            }
            .mask(
                // Mask with gradient at edges for fade effect
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.05),
                        .init(color: .white, location: 0.95),
                        .init(color: .clear, location: 1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // Indicate indicators (dots)
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<llmManager.currentPrompts.count, id: \.self) { index in
                Circle()
                    .fill(currentPromptIndex == index ? Color.blue : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .animation(.easeInOut, value: currentPromptIndex)
                    .onTapGesture {
                        changePrompt(to: index)
                    }
                    // Enlarge touch area for easier tapping
                    .contentShape(Rectangle().size(CGSize(width: 24, height: 24)))
                    .padding(9)
            }
        }
        .padding(.top, 8)
    }
    
    // Changes the prompt and resets animation and timer
    private func changePrompt(to index: Int) {
        // Stop animation before changing index
        scrollText = false
        
        withAnimation {
            // Change prompt
            currentPromptIndex = index
        }
        
        // Reset timer to ensure full duration for new prompt
        restartAutoAdvanceTimer()
    }
    
    // Handles timer tick
    private func handleTimerTick() {
        // Move to next prompt
        if llmManager.currentPrompts.count > 1 && recognitionViewModel.llmState != .generating {
            // Stop animation before changing index
            scrollText = false
            
            withAnimation {
                // Pass to next prompt
                currentPromptIndex = (currentPromptIndex + 1) % llmManager.currentPrompts.count
            }
            
            // Restart timer for next cycle
            restartAutoAdvanceTimer()
        }
    }
    
    // Starts auto-advance timer
    private func startAutoAdvanceTimer() {
        stopAutoAdvanceTimer() // Ensures existing timer is stopped
        
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: promptDuration, repeats: false) { _ in
            handleTimerTick()
        }
    }
    
    // Restarts auto-advance timer (after manual change)
    private func restartAutoAdvanceTimer() {
        startAutoAdvanceTimer()
    }
    
    // Stops auto-advance timer
    private func stopAutoAdvanceTimer() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }
}

// View for displaying a parameter
struct ParameterView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// Extension for safe access to arrays
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Futuristic loading animation view
struct LoadingPromptView: View {
    @State private var animationValue: CGFloat = 0
    @State private var pulseOpacity: Double = 0.7
    
    var body: some View {
        ZStack {
            // Background banner
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    // Pulsation effect
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(pulseOpacity), Color.purple.opacity(pulseOpacity)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .blur(radius: 3)
                )
            
            // Content
            HStack(spacing: 16) {
                // Simplified loading icon
                Circle()
                    .stroke(Color.cyan.opacity(0.8), lineWidth: 1)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                            .offset(x: 8 * cos(Double(animationValue)), y: 8 * sin(Double(animationValue)))
                    )
                    .frame(width: 30, height: 30)
                
                // Text
                Text("AI PROMPT GENERATION")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .kerning(0.5)
                
                // Simple indicator
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 6, height: 6)
                    .opacity(0.2 + 0.8 * sin(Double(animationValue)))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .frame(height: 50)
        .padding(.horizontal, 16)
        .onAppear {
            // Start animation
            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                animationValue = 2 * .pi
            }
            
            // Pulsation animation
            withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.3
            }
        }
    }
} 