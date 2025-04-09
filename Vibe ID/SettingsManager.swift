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
    private let defaultAudDAPIKey = ""
    private let defaultDeepSeekAPIKey = ""

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
    @Published var selectedLLM: LLMType = .deepseek
    @Published var deepseekAPIKey: String = ""
    @Published var claudeAPIKey: String = ""
    @Published var chatGPTAPIKey: String = ""
    @Published var llmSystemPrompt: String = ""

    // Private initializer (Singleton pattern)
    private init() {
        // Load settings from UserDefaults
        let defaults = UserDefaults.standard
        
        // Initialize properties
        self.apiKey = defaults.string(forKey: apiKeyKey) ?? defaultAudDAPIKey
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
        
        selectedLLM = LLMType(rawValue: UserDefaults.standard.string(forKey: "selectedLLM") ?? "") ?? .deepseek
        deepseekAPIKey = UserDefaults.standard.string(forKey: "deepseekAPIKey") ?? defaultDeepSeekAPIKey
        claudeAPIKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        chatGPTAPIKey = UserDefaults.standard.string(forKey: "chatGPTAPIKey") ?? ""
        llmSystemPrompt = UserDefaults.standard.string(forKey: "llmSystemPrompt") ?? """
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
        
        // Settings initialized
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
        
        // Save LLM settings
        defaults.set(selectedLLM.rawValue, forKey: "selectedLLM")
        defaults.set(deepseekAPIKey, forKey: "deepseekAPIKey")
        defaults.set(claudeAPIKey, forKey: "claudeAPIKey")
        defaults.set(chatGPTAPIKey, forKey: "chatGPTAPIKey")
        defaults.set(llmSystemPrompt, forKey: "llmSystemPrompt")
        
        // Settings saved to UserDefaults
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
        apiKey = defaultAudDAPIKey
        oscHost = defaultOSCHost
        oscPort = defaultOSCPort
        recognitionFrequencyMinutes = defaultRecognitionFrequencyMinutes
        selectedLLM = .deepseek
        deepseekAPIKey = defaultDeepSeekAPIKey
        claudeAPIKey = ""
        chatGPTAPIKey = ""
        llmSystemPrompt = """
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
        // Settings reset to defaults
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
        case .claude:
            return claudeAPIKey
        case .chatGPT:
            return chatGPTAPIKey
        }
    }

} // End of SettingsManager class

// Recognition modes available
enum RecognitionMode: String, CaseIterable, Identifiable {
    case audd = "AudD API"
    case manual = "Manual Input"
    
    var id: String { self.rawValue }
}
