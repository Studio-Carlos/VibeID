// RecognitionViewModel.swift
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
import OSCKit // Ensure import is present

// --- TrackInfo Struct (in TrackInfo.swift) ---

@MainActor
class RecognitionViewModel: ObservableObject {

    @Published var isListening: Bool = false
    @Published var isPerformingIdentification: Bool = false
    @Published var statusMessage: String = "Prêt à identifier"
    @Published var latestTrack: TrackInfo? = nil
    @Published var timeUntilNextIdentification: Int? = nil
    @Published var llmState: LLMState = .idle

    enum LLMState: Equatable {
        case idle
        case generating
        case error(String)
        case success([LLMPrompt])
        
        static func == (lhs: LLMState, rhs: LLMState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.generating, .generating):
                return true
            case (.error(let lhsMsg), .error(let rhsMsg)):
                return lhsMsg == rhsMsg
            case (.success(let lhsPrompts), .success(let rhsPrompts)):
                // Maintenant que LLMPrompt est Equatable, on peut comparer les tableaux directement
                return lhsPrompts == rhsPrompts
            default:
                return false
            }
        }
    }

    private var identificationTimer: Timer? = nil
    private var countdownTimer: Timer? = nil
    private var displayTimer: Timer? = nil
    private var lastIdentificationTime: Date? = nil
    private let audioManager = AudioCaptureManager()
    private let apiManager = AudDAPIManager()
    private let settingsManager = SettingsManager.shared
    private let oscManager = OSCManager()
    // LLM Manager for prompt generation
    public let llmManager = LLMManager.shared

    init() {
        print("RecognitionViewModel Initialized")
    }

    deinit {
        // Standard cleanup
        print("RecognitionViewModel deinit")
    }

    // --- UI Actions ---

    func toggleListening() {
        print("--- toggleListening() called --- (isPerformingIdentification = \(isPerformingIdentification))")
        guard !isPerformingIdentification else {
            print("toggleListening: Ignored because isPerformingIdentification is true.")
            return
        }

        let shouldStartListening = !isListening

        if shouldStartListening { // === START ATTEMPT ===
            print("--- Beginning of START block ---")
            print("Settings Check: hasValidAPIKey = \(settingsManager.hasValidAPIKey) (Key: '\(settingsManager.apiKey ?? "nil")')") // Debug
            guard settingsManager.hasValidAPIKey else {
                statusMessage = "Error: AudD API key missing."
                print(">>> START FAILURE: API key missing or empty.")
                return
            }

            print("--- API Key OK ---")
            isListening = true // Activate state
            statusMessage = "Listening..."
            print("Toggle Listening: isListening set to \(isListening)")

            // Direct method calls instead of using Task { @MainActor }
            print(">>> Attempting direct call sendTestOSCMessage...")
            sendTestOSCMessage(message: "listening_started")

            print(">>> Attempting direct call startIdentificationTimers...")
            startIdentificationTimers()
            
            print("--- End of START block (direct calls) ---")

        } else { // === STOP ===
             print("--- Beginning of STOP block ---")
             isListening = false // Deactivate state
             print("Toggle Listening: isListening set to \(isListening)")

             statusMessage = "Stopping..."
             stopListening()
             print(">>> Attempting direct call sendTestOSCMessage (stop)...")
             // Direct call instead of using Task
             sendTestOSCMessage(message: "listening_stopped")
             statusMessage = "Ready"
        }
    } // End func toggleListening

     func sendManualPrompt(prompt: String) {
         guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
         print("Sending manual prompt: \(prompt)")
         
         guard settingsManager.hasValidOSCConfig else {
             statusMessage = "Error: OSC configuration missing."
             print("OSC not configured: Host='\(settingsManager.oscHost)', Port=\(settingsManager.oscPort)")
             DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                 if self.isListening { self.statusMessage = "Listening..." }
                 else { self.statusMessage = "Ready" }
             }
             return
         }
         
         let previousStatus = statusMessage
         statusMessage = "Sending OSC prompt..."
         
         print(">>> Calling oscManager.sendManualPrompt...")
         oscManager.sendManualPrompt(
             prompt: prompt,
             host: settingsManager.oscHost,
             port: settingsManager.oscPort
         )
         
         print(">>> OSC send completed for prompt: \(prompt)")
         
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
             if self.statusMessage == "Sending OSC prompt..." {
                 self.statusMessage = previousStatus
             }
         }
     }

     private func startIdentificationTimers() {
         print("--- startIdentificationTimers called --- (Frequency: \(settingsManager.recognitionFrequencyMinutes) min)")
         identificationTimer?.invalidate()
         stopDisplayTimer() // Stop previous display timer

         // Launch performIdentification immediately
    
         print("Immediate call to performIdentification from startIdentificationTimers")
         performIdentification()

         let interval = TimeInterval(settingsManager.recognitionFrequencyMinutes * 60)
         timeUntilNextIdentification = Int(interval)
         identificationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
             DispatchQueue.main.async {
                 print("Main Timer (ID) triggered.")
                 if self?.isListening == true {
                      self?.performIdentification()
                 } else {
                      self?.stopIdentificationTimer()
                 }
             }
         }

         displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
             DispatchQueue.main.async { // Ensure MainActor
                 guard let self = self, self.isListening else {
                     self?.stopDisplayTimer()
                     return
                 }
                 if let currentCountdown = self.timeUntilNextIdentification, currentCountdown > 0 {
                     self.timeUntilNextIdentification = currentCountdown - 1
                 } else {
                      self.timeUntilNextIdentification = 0
                 }
             }
         }
         print("--- New timers scheduled in startIdentificationTimers ---")
     }

     private func stopIdentificationTimer() {
         print("Stopping Main Timer (ID).")
         identificationTimer?.invalidate()
         identificationTimer = nil
     }

     private func stopDisplayTimer() {
         print("Stopping Display Timer (Countdown).")
         displayTimer?.invalidate()
         displayTimer = nil
         timeUntilNextIdentification = nil
     }

     func stopListening() {
         print("RecognitionViewModel: Stop operations requested...")
        // Cancel any running identifications
         print("RecognitionViewModel: Cancellation request to AudioCaptureManager...")
         audioManager.cancelRecording()
         print("RecognitionViewModel: Cancellation request to AudDAPIManager...")
        apiManager.cancelRequest()
        
        // Réinitialiser l'état lorsque nous arrêtons l'écoute
        isPerformingIdentification = false
        
        // Important: Quand nous arrêtons l'écoute, ne pas réinitialiser la liste des prompts
        // mais réinitialiser l'état du LLM pour que l'interface reflète le bon état
        llmState = .idle
        
        // Stop and invalidate timers
        print("Stopping Display Timer (Countdown).")
        identificationTimer?.invalidate()
        identificationTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

     private func performIdentification() {
         print("--- performIdentification called ---")
        // Initialiser OSCManager
        _ = OSCManager()
        
        guard !isPerformingIdentification else {
            print("performIdentification: Already performing identification, ignoring.")
              return
         }

        isPerformingIdentification = true
        latestTrack = nil
        // Réinitialiser l'état du LLM
        llmState = .idle
        
        // Reset countdown timer
         timeUntilNextIdentification = settingsManager.recognitionFrequencyMinutes * 60
        lastIdentificationTime = Date()

         print("RecognitionViewModel: Starting audio recording...")
        Task { @MainActor in
            do {
                // Capture audio
                let audioURL = try await audioManager.recordSnippet()
                   print("Audio recording successful: \(audioURL.lastPathComponent)")
                
                // Start identification against AudD
                print("AudDAPIManager: Starting recognition for \(audioURL.lastPathComponent)")
                let result = try await apiManager.recognizeAsync(audioFileURL: audioURL, apiKey: settingsManager.apiKey ?? "")
                
                // Process identification result
                if let audDResult = result {
                    print("Song identified: \(audDResult.title ?? "Unknown")")
                    
                    // Convertir AudDResult en TrackInfo
                    let track = TrackInfo(
                        title: audDResult.title,
                        artist: audDResult.artist,
                        artworkURL: audDResult.spotify?.album?.images?.first?.url != nil ?
                            URL(string: audDResult.spotify?.album?.images?.first?.url ?? "") :
                            audDResult.apple_music?.artwork?.artworkURL(width: 300, height: 300),
                        genre: audDResult.estimatedGenre,
                        bpm: audDResult.estimatedBpm,
                        energy: audDResult.estimatedEnergy,
                        danceability: audDResult.estimatedDanceability
                    )
                    
                    // Update the UI with the identified track
                    latestTrack = track
                    
                    // Send track info via OSC
                    print("Sending track info to OSC...")
                    await sendTrackInfo(track: track)
                    print("Track info sent to OSC")
                    
                    // Transition to LLM prompt generation if we have valid config
                    if SettingsManager.shared.hasValidLLMConfig {
                        print("OSCManager Initialized")
                        
                        // Définir l'état comme générant pour afficher l'animation
                        llmState = .generating
                        
                        // Générer les prompts en arrière-plan
                        Task {
                            // Attente pour montrer l'animation
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde pour voir l'animation
                            
                            do {
                                await llmManager.generatePrompts(for: track)
                                handleLLMState()
                            }
                        }
                    }
                        } else {
                    statusMessage = "No match found"
                    print("No song identified")
                        }
                
            } catch {
                print("Error during identification: \(error.localizedDescription)")
                statusMessage = "Error: \(error.localizedDescription)"
                   }
            
            isPerformingIdentification = false
         }
     }

     // --- OSC Functions ---
     private func sendTestOSCMessage(message: String) {
        print("--- sendTestOSCMessage called ---")
        print("OSC Test: Checking configuration...")
        guard settingsManager.hasValidOSCConfig else {
            print(">>> OSC Test: Not configured, skip. Host='\(settingsManager.oscHost)', Port=\(settingsManager.oscPort)")
            return
        }
        print(">>> OSC Test: Config OK. Calling oscManager.send (Test: \(message))...")

        // Only use standardized OSC address with the /vibeid/ prefix
        oscManager.sendStatusMessage(status: message, 
                                    host: settingsManager.oscHost, 
                                    port: settingsManager.oscPort)
    } // End func sendTestOSCMessage
    
   /// Sends track info via OSC if configured
   private func sendTrackInfo(track: TrackInfo) async {
       print("RecognitionViewModel: Envoi des informations de la piste")
       
       // Vérifier la configuration OSC
       guard SettingsManager.shared.hasValidOSCConfig else {
           print("RecognitionViewModel: Configuration OSC invalide")
           return
       }
       
       // Envoyer les informations de la piste
       oscManager.sendTrackInfo(track: track, host: SettingsManager.shared.oscHost, port: SettingsManager.shared.oscPort)
   }

   // Ajouter une méthode pour gérer les états LLM
   public func handleLLMState() {
       Task { @MainActor in
           // Check if LLM is generating
           if llmManager.isGenerating {
               print("RecognitionViewModel: Génération des prompts en cours...")
               llmState = .generating
               return
           }
           
           // Check if there's an error
           if let error = llmManager.errorMessage {
               print("RecognitionViewModel: Erreur lors de la génération des prompts: \(error)")
               llmState = .error(error)
               return
           }
           
           // Check if prompts are available
           let prompts = llmManager.currentPrompts
           if !prompts.isEmpty {
               print("RecognitionViewModel: \(prompts.count) prompts générés avec succès!")
               
               // Mettre à jour les prompts dans latestTrack
               if var track = latestTrack {
                   for (index, prompt) in prompts.enumerated() {
                       switch index {
                       case 0: track.prompt1 = prompt.prompt
                       case 1: track.prompt2 = prompt.prompt
                       case 2: track.prompt3 = prompt.prompt
                       case 3: track.prompt4 = prompt.prompt
                       case 4: track.prompt5 = prompt.prompt
                       case 5: track.prompt6 = prompt.prompt
                       case 6: track.prompt7 = prompt.prompt
                       case 7: track.prompt8 = prompt.prompt
                       case 8: track.prompt9 = prompt.prompt
                       case 9: track.prompt10 = prompt.prompt
                       default: break
                       }
                   }
                   latestTrack = track
                   
                   // Envoyer les informations mises à jour via OSC
                   await sendTrackInfo(track: track)
               }
               
               llmState = .success(prompts)
               return
           }
           
           // Default to idle
           print("RecognitionViewModel: État LLM: idle")
           llmState = .idle
       }
   }

   // Method to cancel ongoing identification
   func cancelIdentification() {
       print("RecognitionViewModel: Annulation de l'identification en cours")
       
       // Stop listening
       isListening = false
       
       // Stop recognition timer
       identificationTimer?.invalidate()
       identificationTimer = nil
       
       // Reset state
       isPerformingIdentification = false
       timeUntilNextIdentification = nil
       
       // Reset LLM
       llmState = .idle
       llmManager.isGenerating = false
       llmManager.errorMessage = nil
       llmManager.currentPrompts = []
   }
   
   // Method to reset state
   func resetState() {
       print("RecognitionViewModel: Réinitialisation de l'état")
       
       // Reset state variables
       isListening = false
       isPerformingIdentification = false
       timeUntilNextIdentification = nil
       latestTrack = nil
       
       // Stop recognition timer
       identificationTimer?.invalidate()
       identificationTimer = nil
       
       // Reset LLM
       llmState = .idle
       llmManager.isGenerating = false
       llmManager.errorMessage = nil
       llmManager.currentPrompts = []
   }
   
   // Method to simulate sending test track info
   func sendTestTrackInfo(track: TrackInfo) async {
       print("RecognitionViewModel: Envoi des informations de la piste de test")
       
       // Update current track
       latestTrack = track
       
       // Send track information
       await sendTrackInfo(track: track)
   }

   // Simulate prompt generation for testing
   func simulatePromptGeneration(for track: TrackInfo) async {
       // Create test prompts
       var testPrompts: [LLMPrompt] = []
       
       // Example prompts for "Pass This On" by The Knife
       let promptTexts = [
           "A surreal digital illustration of disembodied hands passing objects in a dark room, featuring stark contrasts and minimalist composition, inspired by Swedish electronic music, cyberpunk aesthetics with neon accents against black backgrounds, by Josan Gonzalez",
           "A mysterious figure in drag makeup performing in an empty room, cinematic photograph with harsh shadows and dramatic lighting, high contrast black and white, film noir style, inspired by early 2000s electronic music visuals",
           "Abstract visualization of knife-like shapes cutting through layers of electronic sound waves, digital art with geometric patterns, vibrant blues and purples against dark background, glitch art aesthetics",
           "Surreal photograph of identical twins wearing white masks in an abandoned building, symmetrical composition, desaturated colors with hints of cyan, inspired by Swedish electronic duo aesthetic"
       ]
       
       // Create prompts
       for (index, promptText) in promptTexts.enumerated() {
           let prompt = LLMPrompt(
               prompt: promptText,
               parameters: ["prompt_number": index + 1]
           )
           testPrompts.append(prompt)
       }
       
       // Update LLM manager
       llmManager.currentPrompts = testPrompts
       
       // Update state to display prompts
       llmState = .success(testPrompts)
    }

} // End of RecognitionViewModel class
