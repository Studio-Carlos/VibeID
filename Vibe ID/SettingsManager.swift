// SettingsManager.swift
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

import Foundation
import Combine
import SwiftUI

/// Manager that handles application settings and persistence
@MainActor
class SettingsManager: ObservableObject {

    // Singleton instance for access throughout the app
    static let shared = SettingsManager()

    // Default values
    private let defaultOSCHost = "127.0.0.1"
    private let defaultOSCPort = 9000
    private let defaultRecognitionFrequencyMinutes = 5

    // UserDefaults keys
    private let apiKeyKey = "audApiKey"
    private let oscHostKey = "oscHost"
    private let oscPortKey = "oscPort"
    private let recognitionFrequencyKey = "recognitionFrequency"

    // Published properties to allow views to observe changes
    // Initialize all properties at declaration to fix compilation error
    @Published var oscHost: String = ""
    @Published var oscPort: Int = 9000
    @Published var recognitionFrequencyMinutes: Int = 5
    @Published var apiKey: String? = nil

    // Private initializer (Singleton pattern)
    private init() {
        // Load settings from UserDefaults
        let defaults = UserDefaults.standard
        
        // Initialize properties
        self.apiKey = defaults.string(forKey: apiKeyKey)
        self.oscHost = defaults.string(forKey: oscHostKey) ?? defaultOSCHost
        self.oscPort = defaults.integer(forKey: oscPortKey)
        
        // If port is 0 (not set), use default
        if self.oscPort == 0 {
            self.oscPort = defaultOSCPort
        }
        
        // Get recognition frequency, use default if not set
        self.recognitionFrequencyMinutes = defaults.integer(forKey: recognitionFrequencyKey)
        if self.recognitionFrequencyMinutes == 0 {
            self.recognitionFrequencyMinutes = defaultRecognitionFrequencyMinutes
        }
        
        print("[SettingsManager] Initialized with OSC config: \(oscHost):\(oscPort)")
    }
    
    // Saves all settings to UserDefaults
    private func saveSettings() {
        let defaults = UserDefaults.standard
        
        // Save API key (can be nil)
        if let apiKey = apiKey {
            defaults.set(apiKey, forKey: apiKeyKey)
        } else {
            defaults.removeObject(forKey: apiKeyKey)
        }
        
        // Save OSC settings
        defaults.set(oscHost, forKey: oscHostKey)
        defaults.set(oscPort, forKey: oscPortKey)
        
        // Save recognition frequency
        defaults.set(recognitionFrequencyMinutes, forKey: recognitionFrequencyKey)
        
        print("[SettingsManager] Settings saved")
    }
    
    // Returns true if the app has a valid API key configured
    var hasValidAPIKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }
    
    // Returns true if OSC configuration is valid
    var hasValidOSCConfig: Bool {
        return !oscHost.isEmpty && oscPort > 0
    }

    // Reset all settings to defaults
    func resetToDefaults() {
        apiKey = nil
        oscHost = defaultOSCHost
        oscPort = defaultOSCPort
        recognitionFrequencyMinutes = defaultRecognitionFrequencyMinutes
        print("[SettingsManager] All settings reset to defaults")
    }

} // End of SettingsManager class

// Recognition modes available
enum RecognitionMode: String, CaseIterable, Identifiable {
    case audd = "AudD API"
    case manual = "Manual Input"
    
    var id: String { self.rawValue }
}
