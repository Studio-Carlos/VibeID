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

    // Local state for API key SecureFields
    @State private var auddAPIKeyInput: String = ""
    @State private var acrHostInput: String = ""
    @State private var acrAccessKeyInput: String = ""
    @State private var acrSecretKeyInput: String = ""
    @State private var deepseekAPIKeyInput: String = ""
    @State private var geminiAPIKeyInput: String = ""
    @State private var groqAPIKeyInput: String = ""
    @State private var chatGPTAPIKeyInput: String = ""
    
    // States for OSC connection test management
    @State private var isTestingConnection: Bool = false
    @State private var connectionTestResult: Bool? = nil
    @State private var connectionTestMessage: String = ""
    
    // State for network diagnostic display
    @State private var showDiagnosticSheet: Bool = false
    @State private var diagnosticReport: String = ""
    @State private var isDiagnosing: Bool = false

    // State for LLM test alerts
    @State private var showingAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""

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
                // Section for Music ID Provider Selection & Keys
                Section(header: Text("Music Identification")) {
                    // Provider Picker
                    Picker("Provider", selection: $settings.musicIDProvider) {
                        ForEach(MusicIDProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Conditional Fields based on Provider
                    switch settings.musicIDProvider {
                    case .audd:
                        VStack(alignment: .leading) {
                             Text("AudD API Key")
                                 .font(.caption)
                                 .foregroundColor(.gray)
                             SecureField("Paste your AudD API key", text: $auddAPIKeyInput)
                                 .onChange(of: auddAPIKeyInput) {
                                     settings.auddAPIKey = auddAPIKeyInput
                                 }
                         }
                         .padding(.vertical, 4)
                         
                    case .acrCloud:
                         VStack(alignment: .leading) {
                             Text("ACRCloud Host")
                                 .font(.caption)
                                 .foregroundColor(.gray)
                             TextField("e.g., identify-eu-west-1.acrcloud.com", text: $acrHostInput)
                                 .onChange(of: acrHostInput) {
                                      settings.acrHost = acrHostInput
                                 }
                                 .keyboardType(.URL)
                                 .textContentType(.URL)
                                 .autocorrectionDisabled(true)
                                 .textInputAutocapitalization(.never)

                             Text("ACRCloud Access Key")
                                 .font(.caption)
                                 .foregroundColor(.gray)
                             SecureField("Paste your ACRCloud Access key", text: $acrAccessKeyInput)
                                 .onChange(of: acrAccessKeyInput) {
                                      settings.acrAccessKey = acrAccessKeyInput
                                 }
                                 
                             Text("ACRCloud Secret Key")
                                 .font(.caption)
                                 .foregroundColor(.gray)
                             SecureField("Paste your ACRCloud Secret key", text: $acrSecretKeyInput)
                                 .onChange(of: acrSecretKeyInput) {
                                      settings.acrSecretKey = acrSecretKeyInput
                                 }
                         }
                         .padding(.vertical, 4)
                    }
                    
                    // Identification Frequency (moved here)
                    VStack(alignment: .leading) {
                         Text("Identification Frequency")
                             .font(.caption)
                             .foregroundColor(.gray)
                         HStack {
                             Text("Every \(settings.recognitionFrequencyMinutes) min")
                             Slider(value: Binding(
                                 get: { Double(settings.recognitionFrequencyMinutes) },
                                 set: { settings.recognitionFrequencyMinutes = Int($0) }
                                ),
                                    in: 1...10, step: 1)
                         }
                     }
                     .padding(.top, 8)
                }

                // Section for OSC Configuration
                Section("OSC Output Configuration") {
                    TextField("Target IP Address", text: $settings.oscHost)
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
                
                // New section for OSC input configuration
                Section("OSC Input Configuration") {
                    Toggle("Enable OSC Input", isOn: $settings.isOscInputEnabled)
                        .tint(.blue)
                    
                    TextField("Listen Port (e.g.: 8000)", value: $settings.oscListenPort, format: .number)
                        .keyboardType(.numberPad)
                    
                    // Device IP display
                    if settings.deviceIPAddress != "N/A" && settings.deviceIPAddress != "Loading..." {
                        HStack {
                            Text("Device IP:")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text(settings.deviceIPAddress)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.cyan)
                            
                            Spacer()
                            
                            // Button to copy IP address to clipboard
                            Button(action: {
                                UIPasteboard.general.string = settings.deviceIPAddress
                                // Visual feedback
                                connectionTestMessage = "IP copied!"
                                connectionTestResult = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    if connectionTestMessage == "IP copied!" {
                                        connectionTestResult = nil
                                        connectionTestMessage = ""
                                    }
                                }
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text(settings.deviceIPAddress == "Loading..." ? "Loading IP address..." : "Cannot determine device IP")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Text("Format: /vibeid/external/track with value 'song:TITLE from:ARTIST'")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Section for LLM Configuration
                Section(header: Text("LLM CONFIGURATION").foregroundColor(.blue)) {
                    Picker("Model", selection: $settings.selectedLLM) {
                        ForEach(LLMType.allCases, id: \.self) { model in
                            Text(model.rawValue).tag(model)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // Use the appropriate SecureField based on selected LLM
                    switch settings.selectedLLM {
                    case .deepseek:
                        SecureField("Paste your DeepSeek API key", text: $deepseekAPIKeyInput)
                            .onChange(of: deepseekAPIKeyInput) {
                                settings.deepseekAPIKey = deepseekAPIKeyInput
                            }
                    case .gemini:
                        SecureField("Paste your Gemini API key", text: $geminiAPIKeyInput)
                            .onChange(of: geminiAPIKeyInput) {
                                settings.geminiAPIKey = geminiAPIKeyInput
                            }
                    case .groq:
                        SecureField("Paste your Groq API key", text: $groqAPIKeyInput)
                            .onChange(of: groqAPIKeyInput) {
                                settings.groqAPIKey = groqAPIKeyInput
                            }
                    case .chatGPT:
                        SecureField("Paste your OpenAI API key", text: $chatGPTAPIKeyInput)
                            .onChange(of: chatGPTAPIKeyInput) {
                                settings.chatGPTAPIKey = chatGPTAPIKeyInput
                            }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("System Prompt")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $settings.llmSystemPrompt)
                            .frame(minHeight: 250) // Increased height to see more content
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                            )
                    }
                    
                    Button(action: testLLMConnection) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Test connection")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!settings.hasValidLLMConfig)
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
            // Load initial keys into text fields when view appears
            .onAppear {
                // Synchronize all input fields with stored values
                auddAPIKeyInput = settings.auddAPIKey
                acrHostInput = settings.acrHost
                acrAccessKeyInput = settings.acrAccessKey
                acrSecretKeyInput = settings.acrSecretKey
                deepseekAPIKeyInput = settings.deepseekAPIKey
                geminiAPIKeyInput = settings.geminiAPIKey
                groqAPIKeyInput = settings.groqAPIKey
                chatGPTAPIKeyInput = settings.chatGPTAPIKey
            }
            // Update local input fields when provider or LLM type changes
            .onChange(of: settings.musicIDProvider) { oldValue, newValue in
                 syncInputFieldsForProvider(newValue)
            }
            .onChange(of: settings.selectedLLM) { oldValue, newValue in
                syncInputFieldsForLLM(newValue)
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
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    } // End body

    // Helper function to sync input fields when provider changes
    private func syncInputFieldsForProvider(_ provider: MusicIDProvider) {
        switch provider {
        case .audd:
            auddAPIKeyInput = settings.auddAPIKey
        case .acrCloud:
            acrHostInput = settings.acrHost
            acrAccessKeyInput = settings.acrAccessKey
            acrSecretKeyInput = settings.acrSecretKey
        }
    }
    
    // Helper function to sync input fields when LLM changes
    private func syncInputFieldsForLLM(_ llm: LLMType) {
        switch llm {
        case .deepseek:
            deepseekAPIKeyInput = settings.deepseekAPIKey
        case .gemini:
            geminiAPIKeyInput = settings.geminiAPIKey
        case .groq:
            groqAPIKeyInput = settings.groqAPIKey
        case .chatGPT:
            chatGPTAPIKeyInput = settings.chatGPTAPIKey
        }
    }

    // Helper function to test LLM connection
    private func testLLMConnection() {
        Task {
            do {
                // Use the public testLLMConnection method of LLMManager
                try await LLMManager.shared.testLLMConnection()
                
                await MainActor.run {
                    showingAlert = true
                    alertTitle = "Success"
                    alertMessage = "LLM API connection established successfully"
                }
            } catch {
                await MainActor.run {
                    showingAlert = true
                    alertTitle = "Error"
                    alertMessage = error.localizedDescription
                }
            }
        }
    }
}

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
