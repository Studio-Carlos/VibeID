// ContentView.swift
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
import AVFoundation

// DJ/Club style neon effect animation
struct NeonEffect: ViewModifier {
    @State private var isAnimating = false
    var color: Color
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isAnimating ? 0.7 : 0.3), radius: isAnimating ? 12 : 8, x: 0, y: 0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

// DJ style pulsing animations
struct PulsingAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// Visual equalizer effect to indicate activity
struct EqualizerBars: View {
    @State private var barHeights: [CGFloat] = [0.3, 0.5, 0.7, 0.4, 0.6, 0.8, 0.3, 0.5]
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<8) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .bottom, endPoint: .top))
                    .frame(width: 3, height: isActive ? (barHeights[index] * 20) : 3)
                    .animation(
                        isActive ? 
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(index) * 0.1) : 
                            .default, 
                        value: isActive
                    )
            }
        }
        .padding(.horizontal, 12)
        .onAppear {
            if isActive {
                animateBars()
            }
        }
        .onChange(of: isActive) { oldValue, newValue in
            if newValue {
                animateBars()
            }
        }
    }
    
    private func animateBars() {
        guard isActive else { return }
        
        // Randomly change the bar heights in a loop to simulate an equalizer
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if isActive {
                withAnimation(.easeInOut(duration: 0.4)) {
                    for i in 0..<barHeights.count {
                        barHeights[i] = CGFloat.random(in: 0.2...1.0)
                    }
                }
            } else {
                timer.invalidate()
            }
        }
    }
}

// Recognition animation for track identification
struct RecognitionRing: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.7
    let isActive: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(colors: [.purple, .blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 3
                )
                .opacity(isActive ? opacity : 0)
                .scaleEffect(isActive ? scale : 1.0)
                .rotationEffect(.degrees(isActive ? rotation : 0))
        }
        .onAppear {
            if isActive {
                withAnimation(Animation.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 1.1
                    opacity = 0.4
                }
            }
        }
        .onChange(of: isActive) { oldValue, newValue in
            if newValue {
                withAnimation(Animation.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 1.1
                    opacity = 0.4
                }
            }
        }
    }
}

// Futuristic text styles for DJs
extension View {
    func neonEffect(color: Color = .blue) -> some View {
        self.modifier(NeonEffect(color: color))
    }
    
    func pulsingAnimation() -> some View {
        self.modifier(PulsingAnimation())
    }
    
    func futuristicText() -> some View {
        self.font(.system(.headline, design: .rounded))
            .fontWeight(.bold)
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue, .purple, .cyan.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    func techBadge() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
    }
}

// Identification animation
struct TrackIdentifiedAnimation: View {
    @State private var isAnimating = false
    let isShowing: Bool
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .scaleEffect(isAnimating ? 1.0 + CGFloat(i) * 0.2 : 0.0)
                    .opacity(isAnimating ? 0.0 : 0.7)
            }
        }
        .frame(width: 230, height: 230)
        .opacity(isShowing ? 1 : 0)
        .onChange(of: isShowing) { oldValue, newValue in
            if newValue {
                animateIdentification()
            }
        }
    }
    
    private func animateIdentification() {
        guard isShowing else { return }
        
        isAnimating = false
        
        withAnimation(.easeOut(duration: 1.5)) {
            isAnimating = true
        }
    }
}

// Add this subtle pulse animation modifier after the existing PulsingAnimation struct
struct SubtlePulseAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.02 : 1.0)
            .opacity(isPulsing ? 1.0 : 0.95)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// Animated placeholder for missing artwork
struct AlbumArtworkPlaceholder: View {
    @State private var rotation = 0.0
    @State private var scale: CGFloat = 1.0
    @State private var hueRotation = 0.0
    
    var body: some View {
        ZStack {
            // Background with animation
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [.blue, .purple, .cyan, .blue]),
                        center: .center
                    )
                )
                .blur(radius: 20)
                .scaleEffect(scale)
                .hueRotation(Angle(degrees: hueRotation))
            
            // Visual elements
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.7), lineWidth: 3)
                    .frame(width: 100, height: 100)
                    .rotationEffect(Angle(degrees: Double(i) * 30 + rotation))
                    .scaleEffect(1.0 - Double(i) * 0.15)
                    .blur(radius: 1)
            }
            
            // Pulsation animation
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.9))
                .rotationEffect(Angle(degrees: rotation * -0.5))
                .shadow(color: .white.opacity(0.5), radius: 5)
        }
        .frame(width: 200, height: 200)
        .clipped()
        .onAppear {
            // Animation of rotation
            withAnimation(Animation.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            // Animation of pulsation
            withAnimation(Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                scale = 1.15
            }
            
            // Animation of colors
            withAnimation(Animation.linear(duration: 15).repeatForever(autoreverses: false)) {
                hueRotation = 360
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = RecognitionViewModel()
    @State private var manualPromptText: String = ""
    @State private var showingSettings: Bool = false
    
    // Access to settings manager
    @StateObject private var settings = SettingsManager.shared
    
    // Animation states
    @State private var showIdentificationAnimation = false
    @State private var rotationDegrees = 0.0
    @State private var pulseOpacity = 0.6
    @State private var trackIdentified = false
    
    // Access to network environment manager
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    
    // State to display OSC status
    @State private var showOscStatus = false
    
    // Keyboard state tracking
    @State private var keyboardShown = false
    @FocusState private var isInputFocused: Bool
    
    // Toggle OSC reception
    private func toggleOscReceiver() {
        settings.isOscInputEnabled.toggle()
        
        // Visual feedback for temporary status
        let status = settings.isOscInputEnabled ? "OSC input enabled" : "OSC input disabled"
        viewModel.statusMessage = status
        
        // Reset message after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if viewModel.statusMessage == status {
                if viewModel.isListening {
                    viewModel.statusMessage = "Listening..."
                } else {
                    viewModel.statusMessage = "Ready"
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Futuristic gradient background
                LinearGradient(
                    colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Animated background circles
                Circle()
                    .fill(Color.blue.opacity(0.03))
                    .frame(width: 300, height: 300)
                    .offset(x: -100, y: -200)
                    .blur(radius: 60)
                
                Circle()
                    .fill(Color.purple.opacity(0.03))
                    .frame(width: 250, height: 250)
                    .offset(x: 120, y: 300)
                    .blur(radius: 50)
                
                // Main structure to ensure complete display without scrolling
                VStack(spacing: 0) {
                    // Space for status bar
                    Spacer()
                        .frame(height: 10)
                        
                    // VIBE ID title with settings button aligned
                    // Now using opacity animation based on keyboard visibility
                    ZStack {
                        // Perfectly centered title
                        HStack(spacing: 5) {
                            Text("VIBE")
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(red: 0.4, green: 0.7, blue: 1.0), Color(red: 0.2, green: 0.5, blue: 1.0)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("ID")
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(red: 0.6, green: 0.4, blue: 1.0), Color(red: 1.0, green: 0.4, blue: 0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .modifier(SubtlePulseAnimation())
                        .padding(.top, 10)
                        .opacity(keyboardShown ? 0 : 1) // Hide when keyboard is visible
                        .animation(.easeInOut(duration: 0.3), value: keyboardShown)
                        
                        // Left-aligned test button
                        HStack {
                            Button {
                                toggleOscReceiver()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            settings.isOscInputEnabled ? .cyan.opacity(0.8) : .gray.opacity(0.4),
                                                            settings.isOscInputEnabled ? .blue.opacity(0.8) : .gray.opacity(0.4)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1.5
                                                )
                                        )
                                        .shadow(color: settings.isOscInputEnabled ? .cyan.opacity(0.5) : .gray.opacity(0.2), radius: 4, x: 0, y: 0)
                                    
                                    Image(systemName: settings.isOscInputEnabled ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                        .font(.system(size: 18))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    settings.isOscInputEnabled ? .cyan : .gray.opacity(0.7),
                                                    settings.isOscInputEnabled ? .blue.opacity(0.9) : .gray.opacity(0.5)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .opacity(settings.isOscInputEnabled ? 1.0 : 0.7)
                                        .symbolEffect(.pulse, options: .repeating, value: settings.isOscInputEnabled)
                                }
                            }
                            .padding(.top, 10)
                            .padding(.leading, 15)
                            .buttonStyle(ScaleButtonStyle())
                            
                            Spacer()
                        }
                        
                        // Right-aligned settings button
                        HStack {
                            Spacer()
                            
                            Button {
                                showingSettings = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1.5
                                                )
                                        )
                                        .shadow(color: .blue.opacity(0.5), radius: 4, x: 0, y: 0)
                                    
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.gray, .white.opacity(0.7)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                            }
                            .padding(.top, 10)
                            .padding(.trailing, 15)
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .frame(height: 60)  // Fixed height for title area
                    
                    // Main content without scrolling, with complete display
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            // Adjustable space between title and main button
                            Spacer()
                                .frame(height: geometry.size.height * 0.07)
                            
                            // Main button and status
                            VStack(spacing: 5) {
                                ZStack {
                                    // Animated outer circle
                                    if viewModel.isListening {
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.red.opacity(0.7), .orange.opacity(0.7)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 3
                                            )
                                            .frame(width: 100, height: 100)
                                            .shadow(color: .red.opacity(0.5), radius: 10, x: 0, y: 0)
                                            .rotationEffect(.degrees(rotationDegrees))
                                            .onAppear {
                                                withAnimation(Animation.linear(duration: 6).repeatForever(autoreverses: false)) {
                                                    rotationDegrees = 360
                                                }
                                                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                                    pulseOpacity = 0.9
                                                }
                                            }
                                    }
                                    
                                    Button {
                                        print("[ContentView] Main button touched!")
                                        viewModel.toggleListening()
                                    } label: {
                                        ZStack {
                                            // Waiting pulse circle
                                            if !viewModel.isListening {
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 2
                                                    )
                                                    .frame(width: 105, height: 105)
                                                    .scaleEffect(pulseOpacity)
                                                    .opacity(pulseOpacity * 0.8)
                                                    .onAppear {
                                                        withAnimation(Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                                                            pulseOpacity = 0.7
                                                        }
                                                    }
                                            }
                                            
                                            Circle()
                                                .fill(
                                                    viewModel.isListening ?
                                                    LinearGradient(colors: [.red.opacity(0.8), .orange], startPoint: .top, endPoint: .bottom) :
                                                    LinearGradient(colors: [.blue.opacity(0.7), .purple], startPoint: .top, endPoint: .bottom)
                                                )
                                                .frame(width: 95, height: 95)
                                                .shadow(color: viewModel.isListening ? .red.opacity(0.5) : .blue.opacity(0.5), radius: 12, x: 0, y: 0)
                                            
                                            if viewModel.isListening {
                                                Image(systemName: "stop.fill")
                                                    .font(.system(size: 28, weight: .bold))
                                                    .foregroundColor(.white)
                                            } else {
                                                Image(systemName: "waveform")
                                                    .font(.system(size: 28, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            // Blue wave animations have been removed here
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .disabled(viewModel.isPerformingIdentification)
                                }
                                
                                // Status text with modern style
                                Text(viewModel.statusMessage)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.gray.opacity(0.9))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(20)
                                
                                // Countdown with pulsing effect
                                if viewModel.isListening && !viewModel.isPerformingIdentification && viewModel.timeUntilNextIdentification != nil {
                                    Text("Next ID in: \(viewModel.timeUntilNextIdentification ?? 0)s")
                                        .font(.system(.caption, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.4))
                                        .cornerRadius(15)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.orange.opacity(0.5), .red.opacity(0.5)],
                                                        startPoint: .leading, 
                                                        endPoint: .trailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .pulsingAnimation()
                                }
                            }
                            
                            // Adjustable space between main button section and track info section
                            Spacer()
                                .frame(height: geometry.size.height * 0.02)
                            
                            // Track information and album section - constrained height
                            VStack(spacing: 5) {
                                // Track info container
                                if let track = viewModel.latestTrack {
                                    VStack(spacing: 12) {
                                        // Album artwork with effect
                                        ZStack {
                                            // Identification animation
                                            TrackIdentifiedAnimation(isShowing: trackIdentified)
                                            
                                            // Recognition ring animation
                                            RecognitionRing(isActive: viewModel.isPerformingIdentification)
                                                .frame(width: 210, height: 210)
                                            
                                            // Album Cover with effects - slightly reduced size
                                            AsyncImage(url: viewModel.latestTrack?.artworkURL) { phase in
                                                if let image = phase.image { 
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .onAppear {
                                                            // Trigger identification animation when image loads
                                                            withAnimation {
                                                                trackIdentified = true
                                                                
                                                                // Reset animation after delay
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                                    trackIdentified = false
                                                                }
                                                            }
                                                        }
                                                }
                                                else {
                                                    // Animated placeholder for loading and error states
                                                    AlbumArtworkPlaceholder()
                                                }
                                            }
                                            .frame(width: 200, height: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: 15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 15)
                                                    .strokeBorder(
                                                        LinearGradient(
                                                            colors: [.blue.opacity(0.4), .purple.opacity(0.4)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1
                                                    )
                                            )
                                            .shadow(color: .blue.opacity(0.2), radius: 15, x: 0, y: 10)
                                        }
                                        
                                        // Song info with parameters
                                        VStack(spacing: 5) {
                                            VStack(spacing: 4) {
                                                Text(track.title ?? "Unknown")
                                                    .font(.system(.title2, design: .rounded))
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                                    .multilineTextAlignment(.center)
                                                    .frame(maxWidth: .infinity, alignment: .center)
                                                
                                                HStack(spacing: 6) {
                                                    Text(track.artist ?? "Unknown Artist")
                                                        .font(.system(.title3, design: .rounded))
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.gray)
                                                        .multilineTextAlignment(.center)
                                                    
                                                    // OSC source indicator
                                                    if track.source == .osc {
                                                        HStack(spacing: 2) {
                                                            Image(systemName: "antenna.radiowaves.left.and.right")
                                                                .font(.caption)
                                                            Text("OSC")
                                                                .font(.caption)
                                                                .fontWeight(.bold)
                                                        }
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.blue.opacity(0.3))
                                                        .cornerRadius(4)
                                                        .foregroundColor(.cyan)
                                                    }
                                                }
                                                .frame(maxWidth: .infinity, alignment: .center)
                                            }
                                            
                                            // Track metadata
                                            VStack(spacing: 5) {
                                                // Genre
                                                if let genre = track.genre, !genre.isEmpty {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "music.note.list")
                                                            .font(.system(size: 11, weight: .semibold))
                                                            .foregroundColor(.cyan)
                                                        Text(genre)
                                                            .font(.system(.caption2, design: .rounded))
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.white.opacity(0.9))
                                                    }
                                                    .techBadge()
                                                }
                                                
                                                // The BPM, Energy and Danceability indicators were removed
                                                // as the API doesn't provide this information reliably
                                                if viewModel.currentTrackInfo?.bpm != nil {
                                                    // BPM display disabled but condition preserved for future use
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Display prompts
                            if case .idle = viewModel.llmState {
                                // Don't display anything if in idle state
                            } else {
                                VStack(spacing: 8) {
                                    switch viewModel.llmState {
                                    case .generating:
                                        HStack {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                            Text("Generating prompts...")
                                                .foregroundColor(.blue)
                                        }
                                        .padding()
                                        
                                    case .error(let message):
                                        Text(message)
                                            .foregroundColor(.red)
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.red.opacity(0.1))
                                            )
                                            .padding(.horizontal)
                                            
                                    case .success:
                                        PromptDisplayView(llmManager: LLMManager.shared, recognitionViewModel: viewModel)
                                            .transition(.opacity)
                                            
                                    case .idle:
                                        EmptyView()
                                    }
                                }
                                .animation(.easeInOut, value: viewModel.llmState)
                            }
                            
                            // Spacer to push everything up and leave space before the text entry bar
                            Spacer()
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    
                    // Prompt Bar at bottom with futuristic style
                    .safeAreaInset(edge: .bottom) {
                        HStack {
                            TextField("Send a manual prompt...", text: $manualPromptText, axis: .vertical)
                                .lineLimit(1...3)
                                .padding(12)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .foregroundColor(.white)
                                .font(.system(.body, design: .rounded))
                                .focused($isInputFocused) // Track focus state
                                .onChange(of: isInputFocused) { _, newValue in
                                    withAnimation {
                                        keyboardShown = newValue
                                    }
                                }
                            
                            Button {
                                viewModel.sendManualPrompt(prompt: manualPromptText)
                                manualPromptText = ""
                                isInputFocused = false // Hide keyboard
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(
                                            manualPromptText.isEmpty ?
                                            LinearGradient(
                                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ) :
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(manualPromptText.isEmpty ? .gray : .white)
                                }
                            }
                            .disabled(manualPromptText.isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.95))
                    }
                }
            }
            // Modal Sheet for Settings with dark background
            .sheet(isPresented: $showingSettings) { 
                SettingsView()
                    .darkModePresentationBackground()
            }
            .navigationBarHidden(true)
            
        } // End NavigationStack
        .preferredColorScheme(.dark)
    } // End body
    
    // Get a textual description of network status
    private var networkStatusString: String {
        if !networkMonitor.isConnected {
            return "Disconnected"
        }
        
        switch networkMonitor.connectionType {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .unknown:
            return "Connected"
        }
    }
} // End struct ContentView

// Custom style for the main button with scale effect
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// --- Preview ---
#Preview {
    ContentView()
        .environmentObject(NetworkMonitor()) // Add for preview
}
