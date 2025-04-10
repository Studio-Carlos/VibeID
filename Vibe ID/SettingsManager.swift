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
import Network
import KeychainAccess

/// Manager that handles application settings and persistence
@MainActor
class SettingsManager: ObservableObject {

    // Singleton instance for access throughout the app
    static let shared = SettingsManager()

    // MARK: - Property aliases for compatibility
    // Note: These are provided to maintain compatibility with code that might
    // access properties using different naming conventions
    var oscInputEnabled: Bool { isOscInputEnabled }
    var oscReceivePort: Int { oscListenPort }

    // MARK: - Constants for UserDefaults keys
    private struct Keys {
        // UserDefaults keys
        static let oscHost = "oscHost"
        static let oscPort = "oscPort"
        static let oscListenPort = "oscListenPort"
        static let isOscInputEnabled = "isOscInputEnabled"
        static let recognitionFrequencyMinutes = "recognitionFrequencyMinutes"
        static let selectedLLM = "selectedLLM"
        static let llmSystemPrompt = "llmSystemPrompt"
        static let deviceIPAddress = "deviceIPAddress"
        
        // Keychain keys
        static let audDAPIKey = "audDAPIKey"
        static let deepseekAPIKey = "deepseekAPIKey"
        static let geminiAPIKey = "geminiAPIKey"
        static let claudeAPIKey = "claudeAPIKey"
        static let chatGPTAPIKey = "chatGPTAPIKey"
    }
    
    // MARK: - Keychain configuration
    private let keychain = Keychain(service: "com.studiocarlos.vibeid")

    // Default values
    private let defaultOSCHost = "127.0.0.1"
    private let defaultOSCPort = 8000
    private let defaultOscListenPort = 7401
    private let defaultRecognitionFrequencyMinutes = 5
    private let defaultAudDAPIKey = ""
    private let defaultDeepSeekAPIKey = ""
    
    // Default system prompt
    private let defaultSystemPrompt = """
Focus on:

    * Lyrics and their themes/meanings.

    * The visual aesthetics and content of the official music video (if one exists).

    * The design and style of the album/single cover art.

    * Visuals typically associated with the artist or this track during live performances (if information is available).

    * The overall mood ("vibe"), atmosphere, and emotion conveyed by the music.

    * What the track narrates or evokes (story, abstract concepts).

    * Common interpretations or notable analyses found in articles, reviews, or discussions.

    * The music genre and its associated visual codes.


2.  **Creative Synthesis:** Analyze and synthesize all the collected information to build a deep and nuanced understanding of the track's musical and visual identity.


3.  **Prompt Generation (Stable Diffusion 1.5):** Generate exactly 10 distinct image prompts suitable for Stable Diffusion 1.5. These prompts must strictly adhere to the following:

    * Be directly inspired by your research findings (lyrics, video, cover art, mood, etc.).

    * Explore different aspects, themes, or moments of the track.

    * Maintain a **coherent artistic direction** across all 10 prompts, aligned with the overall mood and aesthetics identified in your research.

    * Be **detailed and evocative**, using precise keywords to guide Stable Diffusion. Incorporate elements such as:

        * **Subject:** The central element of the image (characters, objects, abstract scenes...).

        * **Medium:** photograph, cinematic still, oil painting, illustration, 3D render, concept art, glitch art, abstract visualization, etc.

        * **Style:** hyperrealistic, surrealist, impressionist, cyberpunk, gothic, minimalist, psychedelic, noir, vintage, futuristic, [Relevant artist or movement name] style.

        * **Lighting:** dramatic lighting, soft lighting, neon glow, volumetric lighting, backlit, chiaroscuro.

        * **Color Palette:** vibrant colors, monochromatic, pastel palette, dark moody colors, saturated, desaturated.

        * **Additional Details:** detailed texture, bokeh, motion blur, wide angle shot, macro shot, epic scale, intricate details.

    * Vary the **core subject matter** from one prompt to the next while maintaining stylistic coherence.
"""

    // Published properties to allow views to observe changes
    // Initialize all properties at declaration to fix compilation error
    @Published var oscHost: String {
        didSet {
            saveToUserDefaults(Keys.oscHost, oscHost)
        }
    }
    @Published var oscPort: Int {
        didSet {
            saveToUserDefaults(Keys.oscPort, oscPort)
        }
    }
    
    // Port for OSC listening (receiving)
    @Published var oscListenPort: Int = UserDefaults.standard.integer(forKey: Keys.oscListenPort) {
        didSet {
            if oscListenPort != oldValue {
                UserDefaults.standard.setValue(oscListenPort, forKey: Keys.oscListenPort)
                NotificationCenter.default.post(name: .oscInputSettingsChanged, object: nil)
                print("SettingsManager: OSC listen port changed to \(oscListenPort)")
            }
        }
    }
    
    // Enable/disable OSC reception
    @Published var isOscInputEnabled: Bool {
        didSet {
            saveToUserDefaults(Keys.isOscInputEnabled, isOscInputEnabled)
            // Notification to inform OSCManager to change server state
            NotificationCenter.default.post(
                name: .oscInputSettingsChanged,
                object: nil
            )
        }
    }
    
    @Published var recognitionFrequencyMinutes: Int {
        didSet {
            saveToUserDefaults(Keys.recognitionFrequencyMinutes, recognitionFrequencyMinutes)
        }
    }
    @Published var apiKey: String? {
        didSet {
            saveToKeychain(Keys.audDAPIKey, apiKey)
        }
    }
    @Published var selectedLLM: LLMType {
        didSet {
            saveToUserDefaults(Keys.selectedLLM, selectedLLM.rawValue)
        }
    }
    @Published var deepseekAPIKey: String {
        didSet {
            saveToKeychain(Keys.deepseekAPIKey, deepseekAPIKey)
        }
    }
    @Published var geminiAPIKey: String {
        didSet {
            saveToKeychain(Keys.geminiAPIKey, geminiAPIKey)
        }
    }
    @Published var claudeAPIKey: String {
        didSet {
            saveToKeychain(Keys.claudeAPIKey, claudeAPIKey)
        }
    }
    @Published var chatGPTAPIKey: String {
        didSet {
            saveToKeychain(Keys.chatGPTAPIKey, chatGPTAPIKey)
        }
    }
    @Published var llmSystemPrompt: String {
        didSet {
            if llmSystemPrompt.isEmpty {
                // Reset to default prompt if empty
                llmSystemPrompt = defaultSystemPrompt
            }
            saveToUserDefaults(Keys.llmSystemPrompt, llmSystemPrompt)
        }
    }
    
    // Property to get the device's IP address
    @Published var deviceIPAddress: String = "Loading..." {
        didSet {
            objectWillChange.send()
        }
    }

    // MARK: - Initialization
    private init() {
        // Initialize all properties with default values first
        oscHost = defaultOSCHost
        oscPort = defaultOSCPort
        oscListenPort = defaultOscListenPort
        isOscInputEnabled = false
        recognitionFrequencyMinutes = defaultRecognitionFrequencyMinutes
        selectedLLM = .deepseek
        apiKey = nil
        deepseekAPIKey = defaultDeepSeekAPIKey
        geminiAPIKey = ""
        claudeAPIKey = ""
        chatGPTAPIKey = ""
        llmSystemPrompt = defaultSystemPrompt
        
        // Now that all properties are initialized, load values from persistent storage
        loadSavedValues()
        
        // Update device IP address
        Task {
            await updateDeviceIPAddress()
        }
    }
    
    // Load values from UserDefaults and Keychain
    private func loadSavedValues() {
        let defaults = UserDefaults.standard
        
        // Load values from UserDefaults
        oscHost = defaults.string(forKey: Keys.oscHost) ?? defaultOSCHost
        oscPort = defaults.integer(forKey: Keys.oscPort) > 0 ? defaults.integer(forKey: Keys.oscPort) : defaultOSCPort
        oscListenPort = defaults.integer(forKey: Keys.oscListenPort) > 0 ? defaults.integer(forKey: Keys.oscListenPort) : defaultOscListenPort
        isOscInputEnabled = defaults.bool(forKey: Keys.isOscInputEnabled)
        recognitionFrequencyMinutes = defaults.integer(forKey: Keys.recognitionFrequencyMinutes) > 0 ? defaults.integer(forKey: Keys.recognitionFrequencyMinutes) : defaultRecognitionFrequencyMinutes
        
        // Load LLM type from UserDefaults
        if let llmTypeString = defaults.string(forKey: Keys.selectedLLM),
           let llmType = LLMType(rawValue: llmTypeString) {
            selectedLLM = llmType
        }
        
        // Load system prompt
        llmSystemPrompt = defaults.string(forKey: Keys.llmSystemPrompt) ?? defaultSystemPrompt
        
        // Load API keys from Keychain
        apiKey = loadFromKeychain(Keys.audDAPIKey)
        deepseekAPIKey = loadFromKeychain(Keys.deepseekAPIKey) ?? defaultDeepSeekAPIKey
        geminiAPIKey = loadFromKeychain(Keys.geminiAPIKey) ?? ""
        claudeAPIKey = loadFromKeychain(Keys.claudeAPIKey) ?? ""
        chatGPTAPIKey = loadFromKeychain(Keys.chatGPTAPIKey) ?? ""
    }
    
    // MARK: - Persistence methods
    
    /// Save a value to UserDefaults
    private func saveToUserDefaults<T>(_ keyName: String, _ value: T) {
        UserDefaults.standard.set(value, forKey: keyName)
    }
    
    /// Save a string value to Keychain
    private func saveToKeychain(_ key: String, _ value: String?) {
        do {
            if let value = value {
                if value.isEmpty {
                    // If the string is empty, remove the key from the keychain
                    try keychain.remove(key)
                } else {
                    // Otherwise save the value
                    try keychain.set(value, key: key)
                }
            } else {
                // If the value is nil, also remove the key
                try keychain.remove(key)
            }
        } catch {
            print("Error saving to keychain: \(error.localizedDescription)")
        }
    }
    
    /// Load a string value from Keychain
    private func loadFromKeychain(_ key: String) -> String? {
        do {
            let value = try keychain.getString(key)
            return value
        } catch {
            print("Error loading from keychain: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Public methods
    
    // Returns true if the app has a valid API key configured
    var hasValidAPIKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }
    
    // Returns true if OSC configuration is valid
    var hasValidOSCConfig: Bool {
        return !oscHost.isEmpty && oscPort > 0
    }
    
    // Returns true if OSC input configuration is valid
    var hasValidOSCInputConfig: Bool {
        return oscListenPort > 0 && oscListenPort <= 65535
    }

    /// Reset all settings to defaults
    func resetToDefaults() {
        oscHost = defaultOSCHost
        oscPort = defaultOSCPort
        oscListenPort = defaultOscListenPort
        isOscInputEnabled = false
        recognitionFrequencyMinutes = defaultRecognitionFrequencyMinutes
        selectedLLM = .deepseek
        
        // Clear API keys in keychain
        saveToKeychain(Keys.audDAPIKey, nil)
        saveToKeychain(Keys.deepseekAPIKey, defaultDeepSeekAPIKey)
        saveToKeychain(Keys.geminiAPIKey, nil)
        saveToKeychain(Keys.claudeAPIKey, nil)
        saveToKeychain(Keys.chatGPTAPIKey, nil)
        
        // Update published properties to reflect keychain changes
        apiKey = nil
        deepseekAPIKey = defaultDeepSeekAPIKey
        geminiAPIKey = ""
        claudeAPIKey = ""
        chatGPTAPIKey = ""
        
        llmSystemPrompt = defaultSystemPrompt
    }

    /// Resets the LLM system prompt to default, but only if current prompt is not empty
    func resetLLMSystemPrompt() {
        if !llmSystemPrompt.isEmpty {
            llmSystemPrompt = defaultSystemPrompt
        }
    }

    // Returns true if LLM configuration is valid
    var hasValidLLMConfig: Bool {
        let apiKey = getCurrentLLMAPIKey()
        return !apiKey.isEmpty && !llmSystemPrompt.isEmpty
    }

    // Returns the current LLM API key
    func getCurrentLLMAPIKey() -> String {
        switch selectedLLM {
        case .deepseek:
            return deepseekAPIKey
        case .gemini:
            return geminiAPIKey
        case .claude:
            return claudeAPIKey
        case .chatGPT:
            return chatGPTAPIKey
        }
    }

    // Method to get the device's IP address
    func updateDeviceIPAddress() async {
        do {
            deviceIPAddress = try await getDeviceIPAddress() ?? "No IP address found"
        } catch {
            deviceIPAddress = "Error: \(error.localizedDescription)"
        }
    }
    
    // Function to retrieve the device's IP address
    private func getDeviceIPAddress() async throws -> String? {
        let monitor = NWPathMonitor()
        
        return await withCheckedContinuation { continuation in
            // No need to declare foundIP here, we use ipAddressFound locally
            
            monitor.pathUpdateHandler = { path in
                // Check if we have a connection
                guard path.status == .satisfied else {
                    monitor.cancel()
                    continuation.resume(returning: "Not connected")
                    return
                }
                
                // Get the network interface (WiFi, Ethernet, etc.)
                if let interface = path.availableInterfaces.first(where: { 
                    // Filter to get relevant interfaces (WiFi/Ethernet)
                    $0.type == .wifi || $0.type == .wiredEthernet
                }) {
                    // Get the IP address for this interface
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    
                    let interfaceName = interface.name
                    
                    // Use getifaddrs to get the IP address
                    var ifaddr: UnsafeMutablePointer<ifaddrs>?
                    guard getifaddrs(&ifaddr) == 0 else {
                        monitor.cancel()
                        continuation.resume(returning: "getifaddrs error")
                        return
                    }
                    
                    // Loop through all interfaces
                    var currentIfaddr = ifaddr
                    var ipAddressFound: String? = nil
                    
                    while let addr = currentIfaddr {
                        let name = String(cString: addr.pointee.ifa_name)
                        
                        // Check if this is the interface we're interested in
                        if name == interfaceName && addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                            // Convert struct sockaddr to IP address
                            getnameinfo(
                                addr.pointee.ifa_addr,
                                socklen_t(addr.pointee.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, 0,
                                NI_NUMERICHOST
                            )
                            
                            ipAddressFound = String(cString: hostname)
                            break
                        }
                        
                        currentIfaddr = addr.pointee.ifa_next
                    }
                    
                    // Free memory allocated by getifaddrs
                    freeifaddrs(ifaddr)
                    
                    monitor.cancel()
                    continuation.resume(returning: ipAddressFound ?? "No IP address found")
                } else {
                    monitor.cancel()
                    continuation.resume(returning: "No network interface available")
                }
            }
            
            // Start monitoring
            monitor.start(queue: .global())
        }
    }

} // End of SettingsManager class

// Recognition modes available
enum RecognitionMode: String, CaseIterable, Identifiable {
    case audd = "AudD API"
    case manual = "Manual Input"
    
    var id: String { self.rawValue }
}

// Extension to define custom notification
extension Notification.Name {
    static let oscInputSettingsChanged = Notification.Name("oscInputSettingsChanged")
    static let oscReceiveSettingChanged = Notification.Name("oscReceiveSettingChanged")
}
