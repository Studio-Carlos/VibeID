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

struct ContentView: View {
    @StateObject private var viewModel = RecognitionViewModel()
    @State private var manualPromptText: String = ""
    @State private var showingSettings: Bool = false
    
    // Access to network environment manager
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    
    // State to display OSC status
    @State private var showOscStatus = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                // Main VStack that contains ALL scrolling content
                VStack(spacing: 20) {

                    // --- Start/Stop Button & Status ---
                    VStack(spacing: 5) {
                        Button {
                            // ---> ADDED: Log to confirm action entry
                            print("[ContentView] Main button touched!")
                            // Correct action
                            viewModel.toggleListening()
                        } label: {
                            Text(viewModel.isListening ? "Stop ID" : "Start Vibe ID")
                                .fontWeight(.bold)
                                .padding(.vertical, 22)
                                .frame(maxWidth: .infinity)
                                .background(viewModel.isListening ? Color.red : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                        }
                        .padding(.horizontal)
                        // Animation always removed
                        .disabled(viewModel.isPerformingIdentification) // Disabled modifier is present

                        // Main Status
                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 5)

                        // Countdown
                        if viewModel.isListening && !viewModel.isPerformingIdentification && viewModel.timeUntilNextIdentification != nil {
                            Text("Next ID in: \(viewModel.timeUntilNextIdentification ?? 0)s")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.top, 30) // Space after navigation bar

                    // --- VSTACK FOR TRACK INFO - VERIFIED PRESENT ---
                    VStack(spacing: 15) {
                        // Album Cover
                        AsyncImage(url: viewModel.latestTrack?.artworkURL) { phase in
                             if let image = phase.image { image.resizable().aspectRatio(contentMode: .fit) }
                             else if phase.error != nil { Image(systemName: "photo").resizable().aspectRatio(contentMode: .fit).padding(40).foregroundColor(.gray.opacity(0.5)) }
                             else { Image(systemName: "music.note").resizable().aspectRatio(contentMode: .fit).padding(50).foregroundColor(.gray.opacity(0.5)) }
                        }
                        .frame(width: 200, height: 200)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                        // Text
                        Text(viewModel.latestTrack?.title ?? "Waiting...")
                            .font(.title2).fontWeight(.bold).multilineTextAlignment(.center)
                        Text(viewModel.latestTrack?.artist ?? "-")
                            .font(.title3).foregroundColor(.gray).multilineTextAlignment(.center)

                        // Track Metadata (Genre, BPM, Energy, Danceability)
                        VStack(spacing: 8) {
                            // Genre & BPM
                            HStack(spacing: 15) {
                                if let genre = viewModel.latestTrack?.genre, !genre.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "music.note.list")
                                            .font(.caption2)
                                        Text(genre)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                }
                                
                                if let bpm = viewModel.latestTrack?.bpm {
                                    HStack(spacing: 4) {
                                        Image(systemName: "metronome")
                                            .font(.caption2)
                                        Text("\(String(format: "%.0f", bpm)) BPM")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                }
                            }
                            
                            // Energy & Danceability if available
                            if viewModel.latestTrack?.energy != nil || viewModel.latestTrack?.danceability != nil {
                                HStack(spacing: 15) {
                                    if let energy = viewModel.latestTrack?.energy {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bolt.fill")
                                                .font(.caption2)
                                            Text("Energy: \(String(format: "%.0f", energy * 100))%")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                    }
                                    
                                    if let danceability = viewModel.latestTrack?.danceability {
                                        HStack(spacing: 4) {
                                            Image(systemName: "figure.dance")
                                                .font(.caption2)
                                            Text("Dance: \(String(format: "%.0f", danceability * 100))%")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(.top, 5)
                    } // --- END VSTACK TRACK INFO ---
                    .padding(.horizontal, 30)
                    .padding(.top, 30)

                } // End main VStack
                .padding(.bottom, 20) // Space at bottom of scrollable content

            } // End ScrollView
            // Toolbar
            .toolbar {
                ToolbarItem(placement: .principal) { // Centered stylized title
                    Text("Vibe ID")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(
                            LinearGradient( colors: [.blue, .purple.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                         )
                }
                ToolbarItem(placement: .navigationBarTrailing) { // Settings Button
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape.fill").foregroundColor(.gray)
                    }
                }
            }
            // Prompt Bar at bottom (outside ScrollView, INSIDE safeAreaInset)
            .safeAreaInset(edge: .bottom) {
                 HStack {
                      TextField("Send a manual prompt...", text: $manualPromptText, axis: .vertical)
                          .lineLimit(1...3).textFieldStyle(.plain).padding(12)
                          .background(Color(uiColor: .systemGray5)).cornerRadius(10)
                      Button {
                           viewModel.sendManualPrompt(prompt: manualPromptText)
                           manualPromptText = ""
                           UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                      } label: {
                           Image(systemName: "paperplane.fill")
                                .resizable().scaledToFit().frame(width: 22, height: 22)
                                .foregroundColor(manualPromptText.isEmpty ? .gray : .blue)
                                .padding(.horizontal, 10)
                      }
                      .disabled(manualPromptText.isEmpty)
                 }
                 .padding(.horizontal).padding(.vertical, 8).background(.thinMaterial)
            }
            // Modal Sheet for Settings
            .sheet(isPresented: $showingSettings) { SettingsView() }

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
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// --- Preview ---
#Preview {
    ContentView()
        .environmentObject(NetworkMonitor()) // Add for preview
}
