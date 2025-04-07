// SettingsView.swift
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

struct SettingsView: View {
    // Access shared instance of SettingsManager
    @StateObject private var settings = SettingsManager.shared
    
    // Access OSCManager for connection testing
    private let oscManager = OSCManager()

    // Local state for API key SecureField
    @State private var apiKeyInput: String = ""
    
    // States for OSC connection test management
    @State private var isTestingConnection: Bool = false
    @State private var connectionTestResult: Bool? = nil
    @State private var connectionTestMessage: String = ""
    
    // State for network diagnostic display
    @State private var showDiagnosticSheet: Bool = false
    @State private var diagnosticReport: String = ""
    @State private var isDiagnosing: Bool = false

    // Environment to close modal sheet
    @Environment(\.dismiss) var dismiss
    
    // Function to test OSC connection
    private func testOSCConnection() {
        guard !settings.oscHost.isEmpty && settings.oscPort > 0 else {
            connectionTestResult = false
            connectionTestMessage = "Incomplete OSC configuration"
            return
        }
        
        isTestingConnection = true
        connectionTestResult = nil
        connectionTestMessage = "Testing..."
        
        // Perform connection test
        Task {
            let result = oscManager.testConnection(to: settings.oscHost, port: settings.oscPort)
            
            // Update UI on main thread
            await MainActor.run {
                isTestingConnection = false
                connectionTestResult = result
                connectionTestMessage = result ? "Connection successful!" : "Connection failed"
                
                // Hide message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if connectionTestMessage == "Connection successful!" || connectionTestMessage == "Connection failed" {
                        connectionTestResult = nil
                        connectionTestMessage = ""
                    }
                }
            }
        }
    }
    
    // Function to run network diagnostic
    private func runNetworkDiagnostic() {
        guard !settings.oscHost.isEmpty && settings.oscPort > 0 else {
            diagnosticReport = "Error: Incomplete OSC configuration"
            showDiagnosticSheet = true
            return
        }
        
        isDiagnosing = true
        
        // Run diagnostic in background
        Task {
            let report = oscManager.diagnosticNetwork(to: settings.oscHost, port: settings.oscPort)
            
            await MainActor.run {
                diagnosticReport = report
                isDiagnosing = false
                showDiagnosticSheet = true
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section for AudD API Key
                Section("AudD API Key") {
                    SecureField("Paste your AudD API key", text: $apiKeyInput)
                        // Using the new onChange syntax (iOS 14+ but mandatory in style for iOS 17+)
                        .onChange(of: apiKeyInput) {
                            // Read current value of bound state
                            let currentInputValue = apiKeyInput
                            // Update manager when field changes
                            if currentInputValue.isEmpty {
                                settings.apiKey = nil
                            } else {
                                settings.apiKey = currentInputValue
                            }
                        }
                }

                // Section for OSC Configuration
                Section("OSC Configuration") {
                    TextField("Target IP Address (e.g.: 192.168.1.100)", text: $settings.oscHost)
                        .keyboardType(.URL)
                        .autocorrectionDisabled(true) // Disable auto-correction for IPs
                        .textInputAutocapitalization(.never) // No auto caps

                    TextField("Target Port (e.g.: 9000)", value: $settings.oscPort, format: .number)
                        .keyboardType(.numberPad)
                        
                    // Button to test OSC connection
                    HStack {
                        Button(action: {
                            testOSCConnection()
                        }) {
                            HStack {
                                Image(systemName: "network")
                                Text("Test Connection")
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        
                        // Network diagnostic button
                        Button(action: {
                            runNetworkDiagnostic()
                        }) {
                            HStack {
                                Image(systemName: "stethoscope")
                                Text("Diagnostic")
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                    }
                    .padding(.top, 4)
                    
                    // Display test result
                    if isTestingConnection || connectionTestResult != nil {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 5)
                            } else if let result = connectionTestResult {
                                Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result ? .green : .red)
                            }
                            
                            Text(connectionTestMessage)
                                .font(.footnote)
                                .foregroundColor(connectionTestResult == true ? .green : 
                                                connectionTestResult == false ? .red : .primary)
                        }
                        .padding(.top, 2)
                    }
                }
                
                // Section for Identification Frequency
                Section("Identification") {
                    Text("Frequency: Every \(settings.recognitionFrequencyMinutes) minutes")
                    Slider(value: Binding(
                        get: { Double(settings.recognitionFrequencyMinutes) },
                        set: { settings.recognitionFrequencyMinutes = Int($0) }
                       ),
                           in: 1...10, // Range from 1 to 10
                           step: 1      // Step of 1
                    )
                }

            } // End Form
            .scrollContentBackground(.hidden) // Make form background transparent
            .background(
                // Dark gradient background similar to main view
                LinearGradient(
                    colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Vibe ID Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                // Button to close modal sheet
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") {
                        dismiss() // Close modal view
                    }
                    .fontWeight(.bold) // Make OK bold
                    .foregroundColor(.blue) // Highlight the OK button
                }
            }
            // Load initial API key into text field when view appears
            .onAppear {
                apiKeyInput = settings.apiKey ?? ""
            }
            // Add modal sheet for diagnostic report
            .sheet(isPresented: $showDiagnosticSheet) {
                NavigationStack {
                    VStack {
                        if isDiagnosing {
                            ProgressView("Diagnostic in progress...")
                                .padding()
                        } else {
                            ScrollView {
                                Text(diagnosticReport)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .navigationTitle("OSC Network Diagnostic")
                    .background(Color.black)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Close") {
                                showDiagnosticSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        } // End NavigationStack
        .preferredColorScheme(.dark)
    } // End body
} // End struct SettingsView

// Extension to configure the sheet presentation in dark mode
extension View {
    func darkModePresentationBackground() -> some View {
        self.presentationBackground(Color.black.gradient)
            .preferredColorScheme(.dark)
    }
}

// --- Preview ---
#Preview {
    SettingsView()
        .darkModePresentationBackground()
}
