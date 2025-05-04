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
        static let musicIDProvider = "musicIDProvider"
        
        // Keychain keys
        static let auddAPIKey = "auddAPIKey"
        static let acrHost = "acrHost"
        static let acrAccessKey = "acrAccessKey"
        static let acrSecretKey = "acrSecretKey"
        static let deepseekAPIKey = "deepseekAPIKey"
        static let geminiAPIKey = "geminiAPIKey"
        static let groqAPIKey = "groqAPIKey"
        static let chatGPTAPIKey = "chatGPTAPIKey"
    }
    
    // MARK: - Keychain configuration
    private let keychain = Keychain(service: "studio.carlos.vibeid")

    // Default values
    private let defaultOSCHost = "127.0.0.1"
    private let defaultOSCPort = 8000
    private let defaultOscListenPort = 9000
    private let defaultRecognitionFrequencyMinutes = 5
    private let defaultAuddAPIKey = "Enter your AudD API Key"
    private let defaultAcrHost = "identify-eu-west-1.acrcloud.com"
    private let defaultAcrAccessKey = "Enter your ACRCloud Access Key"
    private let defaultAcrSecretKey = "Enter your ACRCloud Secret Key"
    private let defaultDeepSeekAPIKey = "Enter your DeepSeek API Key"
    private let defaultGroqAPIKey = "Enter your Groq API Key"
    private let defaultMusicIDProvider: MusicIDProvider = .acrCloud
    
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
    
    // Music ID Provider Selection
    @Published var musicIDProvider: MusicIDProvider {
        didSet {
            saveToUserDefaults(Keys.musicIDProvider, musicIDProvider.rawValue)
        }
    }
    
    // AudD API Key (Secret - Keychain)
    @Published var auddAPIKey: String {
        didSet {
            // Redact key in logs
            print("SettingsManager: AudD Key did set (value redacted)")
            saveToKeychain(Keys.auddAPIKey, auddAPIKey)
        }
    }
    
    // ACRCloud Host (Secret - Keychain)
    @Published var acrHost: String {
         didSet {
             // Okay to log host
             print("SettingsManager: ACR Host did set to \(acrHost)")
             saveToKeychain(Keys.acrHost, acrHost)
         }
     }
    
    // ACRCloud Access Key (Secret - Keychain)
    @Published var acrAccessKey: String {
         didSet {
             print("SettingsManager: ACR Access Key did set (value redacted)")
             saveToKeychain(Keys.acrAccessKey, acrAccessKey)
         }
     }
     
    // ACRCloud Secret Key (Secret - Keychain)
    @Published var acrSecretKey: String {
         didSet {
             print("SettingsManager: ACR Secret Key did set (value redacted)")
             saveToKeychain(Keys.acrSecretKey, acrSecretKey)
         }
     }
    
    // LLM Selection
    @Published var selectedLLM: LLMType {
        didSet {
            saveToUserDefaults(Keys.selectedLLM, selectedLLM.rawValue)
        }
    }
    
    // LLM API Keys (Secrets - Keychain)
    @Published var deepseekAPIKey: String {
        didSet {
            print("SettingsManager: Deepseek Key did set (value redacted)")
            saveToKeychain(Keys.deepseekAPIKey, deepseekAPIKey)
        }
    }
    @Published var geminiAPIKey: String {
        didSet {
            print("SettingsManager: Gemini Key did set (value redacted)")
            saveToKeychain(Keys.geminiAPIKey, geminiAPIKey)
        }
    }
    @Published var groqAPIKey: String {
        didSet {
            print("SettingsManager: Groq Key did set (value redacted)")
            saveToKeychain(Keys.groqAPIKey, groqAPIKey)
        }
    }
    @Published var chatGPTAPIKey: String {
        didSet {
            print("SettingsManager: ChatGPT Key did set (value redacted)")
            saveToKeychain(Keys.chatGPTAPIKey, chatGPTAPIKey)
        }
    }
    
    // LLM System Prompt
    @Published var llmSystemPrompt: String {
        didSet {
            if llmSystemPrompt.isEmpty {
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
        musicIDProvider = defaultMusicIDProvider
        auddAPIKey = defaultAuddAPIKey
        acrHost = defaultAcrHost
        acrAccessKey = defaultAcrAccessKey
        acrSecretKey = defaultAcrSecretKey
        selectedLLM = .deepseek
        deepseekAPIKey = defaultDeepSeekAPIKey
        geminiAPIKey = ""
        groqAPIKey = defaultGroqAPIKey
        chatGPTAPIKey = ""
        llmSystemPrompt = defaultSystemPrompt
        
        // Now that all properties are initialized, load values from persistent storage
        loadSavedValues()
        
        // Inject ACRCloud credentials from prompt if keychain is empty
        // Important: Do this *after* loadSavedValues
        injectInitialACRCredentials()

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
        
        // Load Music ID Provider
        if let providerString = defaults.string(forKey: Keys.musicIDProvider),
           let provider = MusicIDProvider(rawValue: providerString) {
            musicIDProvider = provider
        } else {
             musicIDProvider = defaultMusicIDProvider // Ensure default if not set
        }
        
        // Load LLM type from UserDefaults
        if let llmTypeString = defaults.string(forKey: Keys.selectedLLM),
           let llmType = LLMType(rawValue: llmTypeString) {
            selectedLLM = llmType
        }
        
        // Load system prompt
        llmSystemPrompt = defaults.string(forKey: Keys.llmSystemPrompt) ?? defaultSystemPrompt
        
        // Load API keys from Keychain
        auddAPIKey = loadFromKeychain(Keys.auddAPIKey) ?? defaultAuddAPIKey
        acrHost = loadFromKeychain(Keys.acrHost) ?? defaultAcrHost
        acrAccessKey = loadFromKeychain(Keys.acrAccessKey) ?? defaultAcrAccessKey
        acrSecretKey = loadFromKeychain(Keys.acrSecretKey) ?? defaultAcrSecretKey
        deepseekAPIKey = loadFromKeychain(Keys.deepseekAPIKey) ?? defaultDeepSeekAPIKey
        geminiAPIKey = loadFromKeychain(Keys.geminiAPIKey) ?? ""
        groqAPIKey = loadFromKeychain(Keys.groqAPIKey) ?? defaultGroqAPIKey
        chatGPTAPIKey = loadFromKeychain(Keys.chatGPTAPIKey) ?? ""
        
        print("SettingsManager: Loaded saved values.")
        // Redact keys when printing loaded values
        print("  - Music Provider: \(musicIDProvider.displayName)")
        print("  - AudD Key Loaded: \(!auddAPIKey.isEmpty)")
        print("  - ACR Host: \(acrHost)")
        print("  - ACR Access Key Loaded: \(!acrAccessKey.isEmpty)")
        print("  - ACR Secret Key Loaded: \(!acrSecretKey.isEmpty)")
        print("  - Selected LLM: \(selectedLLM.displayName)")
    }
    
    // Inject initial ACR credentials if they are not already set in Keychain
    private func injectInitialACRCredentials() {
        let hostInKeychain = loadFromKeychain(Keys.acrHost)
        let keyInKeychain = loadFromKeychain(Keys.acrAccessKey)
        let secretInKeychain = loadFromKeychain(Keys.acrSecretKey)
        
        // Only inject if *all* ACR keychain entries are currently empty/nil
        if (hostInKeychain == nil || hostInKeychain?.isEmpty == true) &&
           (keyInKeychain == nil || keyInKeychain?.isEmpty == true) &&
           (secretInKeychain == nil || secretInKeychain?.isEmpty == true) {
            
            print("SettingsManager: Keychain empty for ACR, injecting credentials from prompt...")
            // Use values provided in the initial prompt
            let initialHost = "identify-eu-west-1.acrcloud.com"
            let initialKey = "1c5f463140cd1c69c1adb13021391edd"
            let initialSecret = "Os7kP4TanetTwe8gTknibpA5glX4Qi9Zh9xqrDTU"
            
            saveToKeychain(Keys.acrHost, initialHost)
            saveToKeychain(Keys.acrAccessKey, initialKey)
            saveToKeychain(Keys.acrSecretKey, initialSecret)
            
            // Update the @Published properties to reflect the injection
            // This ensures the UI shows the injected values immediately
            self.acrHost = initialHost
            self.acrAccessKey = initialKey
            self.acrSecretKey = initialSecret
            
            print("SettingsManager: ACR Credentials Injected.")
        } else {
            print("SettingsManager: ACR Credentials already exist in Keychain, skipping injection.")
        }
    }

    // MARK: - Persistence methods
    
    /// Save a value to UserDefaults
    private func saveToUserDefaults<T>(_ keyName: String, _ value: T) {
        UserDefaults.standard.set(value, forKey: keyName)
    }
    
    /// Save a string value to Keychain
    private func saveToKeychain(_ key: String, _ value: String?) {
        guard let valueToSave = value, !valueToSave.isEmpty else {
            // If value is nil or empty, remove the key
            do {
                try keychain.remove(key)
                print("SettingsManager: Removed '\(key)' from keychain.")
            } catch {
                // Log error only if it's not a 'not found' error during removal
                if let keychainError = error as? KeychainAccess.Status, keychainError != .itemNotFound {
                     print("SettingsManager: Error removing '\(key)' from keychain: \(error.localizedDescription)")
                } else if !(error is KeychainAccess.Status) {
                     print("SettingsManager: Error removing '\(key)' from keychain: \(error.localizedDescription)")
                }
            }
            return
        }

        // Save the non-empty value
        do {
            try keychain.set(valueToSave, key: key)
            // Avoid logging sensitive keys directly
            if key == Keys.acrHost { // Host is okay to log
                 print("SettingsManager: Saved '\(key)' = \(valueToSave) to keychain.")
            } else {
                 print("SettingsManager: Saved '\(key)' (value redacted) to keychain.")
            }
        } catch {
            print("SettingsManager: Error saving '\(key)' to keychain: \(error.localizedDescription)")
        }
    }
    
    /// Load a string value from Keychain
    private func loadFromKeychain(_ key: String) -> String? {
        do {
            let value = try keychain.getString(key)
            // Avoid logging sensitive keys directly
//            if let retrievedValue = value {
//                if key == Keys.acrHost { // Host okay to log
//                    print("SettingsManager: Loaded '\(key)' = \(retrievedValue) from keychain.")
//                } else {
//                    print("SettingsManager: Loaded '\(key)' (value redacted) from keychain.")
//                }
//            } else {
//                print("SettingsManager: No value found for '\(key)' in keychain.")
//            }
            return value
        } catch let error {
            // Don't log 'itemNotFound' as an error, it's expected
            if let keychainError = error as? KeychainAccess.Status, keychainError == .itemNotFound {
                // print("SettingsManager: Key '\(key)' not found in keychain (normal)." )
                return nil
            }
            // Log other keychain errors
            print("SettingsManager: Error loading '\(key)' from keychain: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Public methods
    
    // Returns true if the app has a valid API key configured for the *selected* provider
    var hasValidMusicIDKeys: Bool {
        switch musicIDProvider {
        case .audd:
            return !auddAPIKey.isEmpty
        case .acrCloud:
            return !acrHost.isEmpty && !acrAccessKey.isEmpty && !acrSecretKey.isEmpty
        }
    }
    
    // Convenience getter for ACR Credentials struct
    var acrCreds: ACRCreds {
        return ACRCreds(host: acrHost, key: acrAccessKey, secret: acrSecretKey)
    }
    
    // Returns true if the app has a valid API key configured
    var hasValidAPIKey: Bool {
        return hasValidLLMConfig
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
        musicIDProvider = defaultMusicIDProvider
        selectedLLM = .deepseek
        llmSystemPrompt = defaultSystemPrompt
        
        // Clear API keys in keychain
        saveToKeychain(Keys.auddAPIKey, nil)
        saveToKeychain(Keys.acrHost, nil)
        saveToKeychain(Keys.acrAccessKey, nil)
        saveToKeychain(Keys.acrSecretKey, nil)
        saveToKeychain(Keys.deepseekAPIKey, defaultDeepSeekAPIKey)
        saveToKeychain(Keys.geminiAPIKey, nil)
        saveToKeychain(Keys.groqAPIKey, nil)
        saveToKeychain(Keys.chatGPTAPIKey, nil)
        
        // Update published properties to reflect keychain changes
        auddAPIKey = defaultAuddAPIKey
        acrHost = defaultAcrHost
        acrAccessKey = defaultAcrAccessKey
        acrSecretKey = defaultAcrSecretKey
        deepseekAPIKey = defaultDeepSeekAPIKey
        geminiAPIKey = ""
        groqAPIKey = ""
        chatGPTAPIKey = ""
        
        print("SettingsManager: Reset all settings to defaults.")
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
        case .groq:
            return groqAPIKey
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

// Add this extension to LLMType to provide displayName property
extension LLMType {
    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .groq: return "Groq"
        case .gemini: return "Gemini"
        case .chatGPT: return "ChatGPT"
        }
    }
}
