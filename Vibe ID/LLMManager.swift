// LLMManager.swift
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

enum LLMType: String, CaseIterable {
    case deepseek = "DeepSeek"
    case groq = "Groq"
    case gemini = "Gemini"
    case chatGPT = "ChatGPT"
}

struct LLMPrompt: Identifiable, Equatable {
    let id = UUID()
    let prompt: String
    let timestamp: TimeInterval
    let parameters: [String: Double]
    
    init(prompt: String, timestamp: TimeInterval = Date().timeIntervalSince1970, parameters: [String: Double]) {
        self.prompt = prompt
        self.timestamp = timestamp
        self.parameters = parameters
    }
    
    // Constructor to accept integers in parameters
    init(prompt: String, parameters: [String: Int]) {
        self.prompt = prompt
        self.timestamp = Date().timeIntervalSince1970
        self.parameters = parameters.mapValues { Double($0) }
    }
    
    static func == (lhs: LLMPrompt, rhs: LLMPrompt) -> Bool {
        return lhs.prompt == rhs.prompt && 
               lhs.timestamp == rhs.timestamp &&
               lhs.parameters == rhs.parameters
    }
}

class LLMManager: ObservableObject {
    static let shared = LLMManager()
    
    @Published var isGenerating = false
    @Published var currentPrompts: [LLMPrompt] = []
    @Published var errorMessage: String?
    
    private var displayTimer: Timer?
    private var currentPromptIndex = 0
    
    private init() {}
    
    @MainActor
    func generatePrompts(for track: TrackInfo) async {
        guard SettingsManager.shared.hasValidLLMConfig else {
            // Invalid configuration, cannot generate prompts
            return
        }
        
        // Reset state
        isGenerating = true
        errorMessage = nil
        currentPrompts = []
        
        do {
            // Generate prompts from API
            currentPrompts = try await fetchPromptsFromAPI(track: track)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isGenerating = false
    }
    
    private func fetchPromptsFromAPI(track: TrackInfo) async throws -> [LLMPrompt] {
        let settings = await SettingsManager.shared
        let apiKey = await settings.getCurrentLLMAPIKey()
        let systemPrompt = await settings.llmSystemPrompt
        let selectedLLM = await settings.selectedLLM
        
        // First part of the prompt (template with placeholders)
        let partOne = """
        **Role:** You are an expert AI assistant specializing in musical information research and creative visual concept generation for VJing. Your goal is to create image prompts for Stable Diffusion 1.5.

        **Context:** These prompts will be used to generate real-time visuals projected behind a DJ while they are playing a specific track. The visuals must be deeply connected to the essence of the track.

        **Input Information (Variables to be injected by the calling program):**

        * Track Title: \(track.title ?? "Unknown")
        * Artist: \(track.artist ?? "Unknown")
        * Music Genre: \(track.genre ?? "Unknown")
        * (Optional) BPM: \(track.bpm != nil ? String(format: "%.0f", track.bpm!) : "N/A")
        * (Optional) Energy (e.g., low, medium, high): \(energyLevelString(from: track.energy))
        * (Optional) Danceability (e.g., low, medium, high): \(danceabilityLevelString(from: track.danceability))

        **Detailed Instructions:**

        1. **Deep Web Research:** Using your web search capabilities, gather as much relevant information as possible about the track "\(track.title ?? "Unknown")" by \(track.artist ?? "Unknown").
        """
        
        // Second part (customizable system prompt)
        let partTwo = systemPrompt
        
        // Third part (expected JSON output format)
        let partThree = """
        **Strict Output Format:** Your response MUST be ONLY a valid JSON object. Do NOT include ANY text before or after the JSON (no introduction, explanation, greeting, list of sources, or keywords outside the JSON). The exact JSON structure must be:

        {
          "prompts": [
            {
              "track": "\(track.title ?? "Unknown")",
              "artist": "\(track.artist ?? "Unknown")",
              "prompt_number": 1,
              "prompt": "Your generated prompt number 1 here, detailed and stylized for Stable Diffusion 1.5..."
            },
            {
              "track": "\(track.title ?? "Unknown")",
              "artist": "\(track.artist ?? "Unknown")",
              "prompt_number": 2,
              "prompt": "Your generated prompt number 2 here, different from the first but artistically coherent..."
            },
            // ... Repeat for prompts 3 through 9 ...
            {
              "track": "\(track.title ?? "Unknown")",
              "artist": "\(track.artist ?? "Unknown")",
              "prompt_number": 10,
              "prompt": "Your generated prompt number 10 here, completing the set with a relevant variation..."
            }
          ]
        }
        """
        
        // Concatenate the three parts with a line break between each part
        let fullPrompt = "\(partOne)\n\n\(partTwo)\n\n\(partThree)"
        
        // Call the appropriate API based on the selected LLM
        switch selectedLLM {
        case .deepseek:
            return try await callDeepSeekAPI(apiKey: apiKey, fullPrompt: fullPrompt, track: track)
        case .gemini:
            return try await callGeminiAPI(apiKey: apiKey, fullPrompt: fullPrompt, track: track)
        case .groq:
            return try await callGroqAPI(apiKey: apiKey, fullPrompt: fullPrompt, track: track)
        case .chatGPT:
            return try await callChatGPTAPI(apiKey: apiKey, fullPrompt: fullPrompt, track: track)
        }
    }
    
    // Method to call DeepSeek API
    private func callDeepSeekAPI(apiKey: String, fullPrompt: String, track: TrackInfo) async throws -> [LLMPrompt] {
        // Call to the DeepSeek API
        let url = URL(string: "https://api.deepseek.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "user", "content": fullPrompt]
            ],
            "temperature": 0.85,
            "max_tokens": 1500
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "LLMManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "DeepSeek API Error"])
        }
        
        // Decode the response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let content = choices?.first?["message"] as? [String: String]
        let promptText = content?["content"] ?? ""
        
        return try parsePromptsFromResponse(promptText: promptText, track: track)
    }
    
    // Method to call Google Gemini API
    private func callGeminiAPI(apiKey: String, fullPrompt: String, track: TrackInfo) async throws -> [LLMPrompt] {
        // Call to the Gemini API
        let baseURL = "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent"
        let urlWithKey = "\(baseURL)?key=\(apiKey)"
        let url = URL(string: urlWithKey)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare the request body for Gemini
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        [
                            "text": fullPrompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.85,
                "maxOutputTokens": 1500,
                "topP": 0.95
            ],
            "systemInstruction": [
                "parts": [
                    [
                        "text": "You are an expert AI assistant that helps create detailed prompt descriptions for AI image generation based on music tracks. You have the ability to browse the web to gather information."
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "LLMManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Gemini API Error"])
        }
        
        // Decode the response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let textPart = parts?.first?["text"] as? String ?? ""
        
        return try parsePromptsFromResponse(promptText: textPart, track: track)
    }
    
    // Method to call Groq API
    private func callGroqAPI(apiKey: String, fullPrompt: String, track: TrackInfo) async throws -> [LLMPrompt] {
        // Call to the Groq API
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "llama-3.1-8b-instant",
            "messages": [
                ["role": "user", "content": fullPrompt]
            ],
            "temperature": 0.85,
            "max_tokens": 1100
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "LLMManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response from Groq API"])
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            // Try to parse error message from response
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorJson?["error"] as? [String: Any]
            let message = errorMessage?["message"] as? String ?? "Unknown error"
            
            print("LLMManager: Groq API Error - Status: \(httpResponse.statusCode), Message: \(message)")
            throw NSError(domain: "LLMManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Groq API Error: \(message)"])
        }
        
        // Decode the response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let messageData = choices?.first?["message"] as? [String: Any]
        let content = messageData?["content"] as? String ?? ""
        
        print("LLMManager: Groq API Response received - Content length: \(content.count)")
        
        return try parsePromptsFromResponse(promptText: content, track: track)
    }
    
    // Method to call ChatGPT (OpenAI) API
    private func callChatGPTAPI(apiKey: String, fullPrompt: String, track: TrackInfo) async throws -> [LLMPrompt] {
        // Call to the OpenAI API
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Using gpt-4o which has web browsing capabilities
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "You are an expert AI assistant that helps create detailed prompt descriptions for AI image generation based on music tracks. You have the ability to browse the web to gather information."],
                ["role": "user", "content": fullPrompt]
            ],
            "temperature": 0.85,
            "max_tokens": 1500,
            "response_format": ["type": "json_object"], // Ensure JSON response
            "tools": [
                [
                    "type": "web_search"
                ]
            ],
            "tool_choice": "auto" // Allow the model to decide when to use web search
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "LLMManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API Error"])
        }
        
        // Decode the response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let messageData = choices?.first?["message"] as? [String: Any]
        let content = messageData?["content"] as? String ?? ""
        
        return try parsePromptsFromResponse(promptText: content, track: track)
    }
    
    // Shared method to parse the response from any LLM
    private func parsePromptsFromResponse(promptText: String, track: TrackInfo) throws -> [LLMPrompt] {
        var generatedPrompts: [LLMPrompt] = []
        
        do {
            // Clean the response to ensure it's valid JSON
            let cleanedResponse = cleanJSONResponse(promptText)
            
            // Try to parse the JSON
            guard let responseData = cleanedResponse.data(using: .utf8) else {
                throw NSError(domain: "LLMManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to convert response to data"])
            }
            
            let parsedResponse = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any]
            guard let promptsArray = parsedResponse?["prompts"] as? [[String: Any]] else {
                throw NSError(domain: "LLMManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format"])
            }
            
            print("LLMManager: \(promptsArray.count) prompts found in JSON response")
            
            // Extract prompts and create LLMPrompt objects
            for (_, promptDict) in promptsArray.enumerated() {
                guard let promptText = promptDict["prompt"] as? String,
                      let promptNumber = promptDict["prompt_number"] as? Int else {
                    continue
                }
                
                print("LLMManager: Prompt \(promptNumber) complete:")
                print("--------- START OF PROMPT \(promptNumber) ---------")
                print(promptText)
                print("--------- END OF PROMPT \(promptNumber) ---------")
                
                let llmPrompt = LLMPrompt(
                    prompt: promptText,
                    timestamp: Date().timeIntervalSince1970,
                    parameters: [
                        "bpm": track.bpm ?? 0,
                        "energy": track.energy ?? 0,
                        "danceability": track.danceability ?? 0,
                        "prompt_number": Double(promptNumber)
                    ]
                )
                
                generatedPrompts.append(llmPrompt)
            }
        } catch {
            print("LLMManager: Error during JSON parsing: \(error.localizedDescription)")
            // In case of error, create a single prompt with the error message
            let errorPrompt = LLMPrompt(
                prompt: "Processing error: \(error.localizedDescription). Raw response: \(promptText.prefix(100))...",
                timestamp: Date().timeIntervalSince1970,
                parameters: [
                    "bpm": track.bpm ?? 0,
                    "energy": track.energy ?? 0,
                    "danceability": track.danceability ?? 0
                ]
            )
            generatedPrompts = [errorPrompt]
        }
        
        if generatedPrompts.isEmpty {
            let fallbackPrompt = LLMPrompt(
                prompt: "No prompts generated. LLM response: \(promptText.prefix(100))...",
                timestamp: Date().timeIntervalSince1970,
                parameters: [
                    "bpm": track.bpm ?? 0,
                    "energy": track.energy ?? 0,
                    "danceability": track.danceability ?? 0
                ]
            )
            generatedPrompts = [fallbackPrompt]
        }
        
        print("LLMManager: \(generatedPrompts.count) prompts generated successfully!")
        
        return generatedPrompts
    }
    
    // Function to clean JSON response
    private func cleanJSONResponse(_ response: String) -> String {
        // Look for the opening JSON brace
        if let jsonStartIndex = response.firstIndex(of: "{"),
           let jsonEndIndex = response.lastIndex(of: "}") {
            let jsonRange = jsonStartIndex...jsonEndIndex
            return String(response[jsonRange])
        }
        return response
    }
    
    // Helper functions to convert numeric values to text levels
    private func energyLevelString(from energy: Double?) -> String {
        guard let energy = energy else { return "N/A" }
        if energy < 0.33 {
            return "low"
        } else if energy < 0.66 {
            return "medium"
        } else {
            return "high"
        }
    }
    
    private func danceabilityLevelString(from danceability: Double?) -> String {
        guard let danceability = danceability else { return "N/A" }
        if danceability < 0.33 {
            return "low"
        } else if danceability < 0.66 {
            return "medium"
        } else {
            return "high"
        }
    }
    
    private func startPromptDisplay() {
        stopDisplayTimer()
        currentPromptIndex = 0
        
        displayTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.currentPromptIndex < self.currentPrompts.count - 1 {
                self.currentPromptIndex += 1
            } else {
                self.stopDisplayTimer()
            }
        }
    }
    
    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }
    
    /// Test the LLM API connection with dummy data
    func testLLMConnection() async throws {
        let track = TrackInfo(
            title: "Test",
            artist: "Test",
            genre: "Test",
            artworkURL: nil,
            bpm: 120,
            energy: 0.8,
            danceability: 0.7
        )
        
        // Use the private method to perform a real connection test
        let _ = try await fetchPromptsFromAPI(track: track)
        return
    }
} 
