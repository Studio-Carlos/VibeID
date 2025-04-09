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
    case claude = "Claude"
    case chatGPT = "Chat GPT"
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
    
    // Constructeur pour accepter des entiers dans les paramètres
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
        
        // Concaténation des trois parties avec un retour à la ligne entre chaque
        let fullPrompt = "\(partOne)\n\n\(partTwo)\n\n\(partThree)"
        
        // Call to the LLM API
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
            throw NSError(domain: "LLMManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "API Error"])
        }
        
        // Decode the response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let content = choices?.first?["message"] as? [String: String]
        let promptText = content?["content"] ?? ""
        
        // Parse the JSON content in the response
        var generatedPrompts: [LLMPrompt] = []
        
        do {
            // Nettoyer la réponse pour s'assurer qu'elle est un JSON valide
            let cleanedResponse = cleanJSONResponse(promptText)
            
            // Essayer de parser le JSON
            guard let responseData = cleanedResponse.data(using: .utf8) else {
                throw NSError(domain: "LLMManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to convert response to data"])
            }
            
            let parsedResponse = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any]
            guard let promptsArray = parsedResponse?["prompts"] as? [[String: Any]] else {
                throw NSError(domain: "LLMManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format"])
            }
            
            print("LLMManager: \(promptsArray.count) prompts trouvés dans la réponse JSON")
            
            // Extraire les prompts et créer des objets LLMPrompt
            for (_, promptDict) in promptsArray.enumerated() {
                guard let promptText = promptDict["prompt"] as? String,
                      let promptNumber = promptDict["prompt_number"] as? Int else {
                    continue
                }
                
                print("LLMManager: Prompt \(promptNumber) complet:")
                print("--------- DÉBUT DU PROMPT \(promptNumber) ---------")
                print(promptText)
                print("--------- FIN DU PROMPT \(promptNumber) ---------")
                
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
            print("LLMManager: Erreur lors du parsing JSON: \(error.localizedDescription)")
            // En cas d'erreur, créer un seul prompt avec le message d'erreur
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
        
        print("LLMManager: \(generatedPrompts.count) prompts générés avec succès!")
        
        // Supprimer le test explicite d'envoi des prompts via OSC pour éviter les duplications
        // Les prompts seront envoyés automatiquement via l'observer dans OSCManager
        
        return generatedPrompts
    }
    
    // Fonction pour nettoyer la réponse JSON
    private func cleanJSONResponse(_ response: String) -> String {
        // Chercher le début de l'accolade ouvrante JSON
        if let jsonStartIndex = response.firstIndex(of: "{"),
           let jsonEndIndex = response.lastIndex(of: "}") {
            let jsonRange = jsonStartIndex...jsonEndIndex
            return String(response[jsonRange])
        }
        return response
    }
    
    // Fonctions helpers pour convertir les valeurs numériques en niveaux textuels
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
    
    /// Teste la connexion à l'API LLM avec des données fictives
    func testLLMConnection() async throws {
        let track = TrackInfo(
            title: "Test",
            artist: "Test",
            artworkURL: nil,
            genre: "Test",
            bpm: 120,
            energy: 0.8,
            danceability: 0.7
        )
        
        // Utilise la méthode privée pour effectuer un test réel de connexion
        let _ = try await fetchPromptsFromAPI(track: track)
        return
    }
} 
