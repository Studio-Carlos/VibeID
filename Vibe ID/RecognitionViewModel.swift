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
    @Published var statusMessage: String = "Ready to identify"
    @Published var latestTrack: TrackInfo? = nil
    @Published var timeUntilNextIdentification: Int? = nil
    @Published var llmState: LLMState = .idle
    
    // Property to easily access the current TrackInfo
    var currentTrackInfo: TrackInfo? {
        return latestTrack
    }
    
    // Check if the current source is OSC
    var isOSCSourceActive: Bool {
        return latestTrack?.source == .osc
    }

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
                // Now that LLMPrompt is Equatable, we can compare arrays directly
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
    private let oscManager = OSCService.shared.getOSCManager()
    // LLM Manager for prompt generation
    public let llmManager = LLMManager.shared
    
    // Use the protocol type for the recognizer
    private var musicRecognizer: MusicRecognizer? 
    
    // For storing cancellations
    private var cancellables = Set<AnyCancellable>()

    init() {
        print("RecognitionViewModel Initialized")
        
        // Subscribe to track notifications received via OSC
        oscManager.trackReceivedPublisher
            .sink { [weak self] trackInfo in
                self?.handleExternalTrackInfo(trackInfo)
            }
            .store(in: &cancellables)
        
        // Subscribe to settings changes to update the recognizer
        settingsManager.$musicIDProvider
            .combineLatest(settingsManager.$auddAPIKey)
            .receive(on: DispatchQueue.main) // Ensure updates on main thread
            .sink { [weak self] _, _ in
                print("RecognitionViewModel: Settings changed, updating music recognizer...")
                self?.updateMusicRecognizer()
            }
            .store(in: &cancellables)
            
        // Also subscribe to ACR credentials changes separately
        settingsManager.$acrHost
            .combineLatest(settingsManager.$acrAccessKey, settingsManager.$acrSecretKey)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                print("RecognitionViewModel: ACR credentials changed, updating music recognizer...")
                self?.updateMusicRecognizer()
            }
            .store(in: &cancellables)
            
        // Initial setup of the recognizer
        updateMusicRecognizer()
    }

    deinit {
        // Standard cleanup
        print("RecognitionViewModel deinit")
        cancellables.removeAll()
    }
    
    // Method to process track information received by OSC
    private func handleExternalTrackInfo(_ trackInfo: TrackInfo) {
        print("RecognitionViewModel: Received external track info via OSC - Title: \(trackInfo.title ?? "Unknown"), Artist: \(trackInfo.artist ?? "Unknown")")
        
        // Update the UI with the new information
        latestTrack = trackInfo
        
        // Update status
        statusMessage = "Track received via OSC"
        
        // Reset AudD identification timers if in listening mode
        if isListening {
            resetIdentificationTimers()
        }
        
        // Generate LLM prompts for the track if the configuration is valid
        if settingsManager.hasValidLLMConfig {
            print("RecognitionViewModel: Generating LLM prompts for OSC-received track")
            Task {
                // Set state as generating to display animation
                llmState = .generating
                
                // Generate prompts in the background
                await llmManager.generatePrompts(for: trackInfo)
                handleLLMState()
                
                // Send updated information via OSC
                if let updatedTrack = latestTrack {
                    await sendTrackInfo(track: updatedTrack)
                }
            }
        }
    }
    
    // Reset identification timers
    private func resetIdentificationTimers() {
        print("RecognitionViewModel: Resetting identification timers after OSC track reception")
        
        // Stop existing timers
        stopIdentificationTimer()
        stopDisplayTimer()
        
        // Reset countdown
        timeUntilNextIdentification = settingsManager.recognitionFrequencyMinutes * 60
        
        // Restart timers for the next AudD identification cycle
        startDisplayTimer()
    }
    
    // Start only the display timer without immediately starting an identification
    private func startDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, self.isListening else {
                    self?.stopDisplayTimer()
                    return
                }
                
                if let currentCountdown = self.timeUntilNextIdentification {
                    if currentCountdown > 0 {
                        self.timeUntilNextIdentification = currentCountdown - 1
                    } else {
                        // Once the countdown is finished, start an identification
                        self.performIdentification()
                        self.timeUntilNextIdentification = self.settingsManager.recognitionFrequencyMinutes * 60
                    }
                }
            }
        }
        print("RecognitionViewModel: Display timer started for next AudD identification")
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
            // Check if a recognizer is available and configured
            guard let currentRecognizer = musicRecognizer else {
                 statusMessage = "Error: Music Recognizer not available or configured."
                 print(">>> START FAILURE: Music Recognizer is nil (Check provider & credentials).")
                 return
            }
            print("--- Recognizer Available: \(type(of: currentRecognizer)) ---")
            
            // Check if *selected* provider keys are valid
            guard settingsManager.hasValidMusicIDKeys else {
                statusMessage = "Error: API keys missing for \(settingsManager.musicIDProvider.displayName)."
                print(">>> START FAILURE: API keys missing for selected provider.")
                return
            }
            print("--- API Keys OK for \(settingsManager.musicIDProvider.displayName) ---")

            isListening = true
            statusMessage = "Listening..."
            print("Toggle Listening: isListening set to \(isListening)")

            sendTestOSCMessage(message: "listening_started")
            startIdentificationTimers()
            
            print("--- End of START block ---")

        } else { // === STOP ===
             print("--- Beginning of STOP block ---")
             isListening = false
             print("Toggle Listening: isListening set to \(isListening)")

             statusMessage = "Stopping..."
             stopListening()
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
         // Cancel any running identifications via the protocol
         print("RecognitionViewModel: Cancellation request via MusicRecognizer protocol...")
         musicRecognizer?.cancel()
        
         // Cancel audio recording separately if needed (depends on implementation)
         audioManager.cancelRecording() 
        
        isPerformingIdentification = false
        llmState = .idle
        
        stopIdentificationTimer()
        stopDisplayTimer() // Call the correct stop function
        timeUntilNextIdentification = nil // Ensure countdown is cleared
        print("RecognitionViewModel: Listening stopped, timers invalidated.")
    }

     private func performIdentification() {
         print("--- performIdentification called --- Provider: \(settingsManager.musicIDProvider.displayName)")
         _ = OSCManager() // Ensure initialized
        
         guard !isPerformingIdentification else {
             print("performIdentification: Already performing identification, ignoring.")
             return
         }
         
         // Ensure we have a valid recognizer instance
         guard let recognizer = musicRecognizer else {
             print("performIdentification: ERROR - No music recognizer available.")
             statusMessage = "Error: Music Recognizer not configured."
             // Potentially stop listening or prevent retries?
             isListening = false // Stop listening if recognizer is gone
             stopIdentificationTimer()
             stopDisplayTimer()
             return
         }

         isPerformingIdentification = true
         latestTrack = nil // Clear previous track info
         llmState = .idle
         statusMessage = "Identifying... (using \(settingsManager.musicIDProvider.displayName))"
        
         timeUntilNextIdentification = settingsManager.recognitionFrequencyMinutes * 60
         lastIdentificationTime = Date()

         print("RecognitionViewModel: Starting identification via \(type(of: recognizer))...")
         Task { @MainActor in
             var identifiedTrack: RecognizedTrack? = nil // Use the protocol's track type
             var identificationError: Error? = nil
             
             do {
                 // Use the MusicRecognizer protocol method
                 // Note: AudD implementation currently throws an error here.
                 identifiedTrack = try await recognizer.identify(seconds: 12) // Use a default duration
                 
                 if let track = identifiedTrack, (track.title != nil || track.artist != nil) {
                      print("RecognitionViewModel: Match found by \(settingsManager.musicIDProvider.displayName) - \(track.artist ?? "?") - \(track.title ?? "?")")
                      statusMessage = "Match: \(track.title ?? "Unknown")" 
                 } else {
                      print("RecognitionViewModel: No match found by \(settingsManager.musicIDProvider.displayName)." )
                      statusMessage = "No match found"
                 }
                 
             } catch let error {
                 print("RecognitionViewModel: Error during identification: \(error.localizedDescription)")
                 identificationError = error
                 // Use specific error messages
                 if let acrError = error as? ACRCloudServiceError {
                     statusMessage = "ACR Error: \(acrError.localizedDescription)"
                 } else if let auddError = error as? AudDAPIError {
                      statusMessage = "AudD Error: \(auddError.localizedDescription)"
                 } else if error is CancellationError {
                     statusMessage = "Identification cancelled."
                 } else {
                      statusMessage = "Error: \(error.localizedDescription)"
                 }
             }
             
             // --- Post-identification processing --- 
             isPerformingIdentification = false
             
             // If a track was successfully identified, process it
             if let recognizedTrack = identifiedTrack, identificationError == nil {
                 // Convert RecognizedTrack to TrackInfo for the rest of the app
                 let trackInfo = mapRecognizedTrackToTrackInfo(recognizedTrack)
                 
                 // Update UI
                 self.latestTrack = trackInfo
                 
                 // Send via OSC
                 print("Sending track info to OSC...")
                 await sendTrackInfo(track: trackInfo)
                 print("Track info sent to OSC")
                 
                 // Generate LLM prompts if configured
                 if SettingsManager.shared.hasValidLLMConfig {
                     print("Triggering LLM prompt generation...")
                     llmState = .generating
                     Task {
                         await llmManager.generatePrompts(for: trackInfo) // Use TrackInfo
                         handleLLMState()
                         // Resend track info *after* prompts are added
                         if let updatedTrack = self.latestTrack { 
                              print("Resending track info with prompts...")
                              await self.sendTrackInfo(track: updatedTrack)
                         }
                     }
                 }
             }
             // If no track was identified (but no error occurred), status is already "No match found"
             // If an error occurred, status message is already set
             
             // Reset countdown display timer *after* identification attempt completes
             // This ensures the countdown reflects the *next* identification cycle
             timeUntilNextIdentification = settingsManager.recognitionFrequencyMinutes * 60 
         }
     }
     
    // Updates the music recognizer based on the current settings
    private func updateMusicRecognizer() {
        print("RecognitionViewModel: Updating music recognizer based on settings...")
        
        // Clear previous recognizer
        musicRecognizer = nil
        
        // Create the appropriate recognizer based on selected provider
        switch settingsManager.musicIDProvider {
        case .audd:
            if !settingsManager.auddAPIKey.isEmpty {
                print("RecognitionViewModel: Creating AudD recognizer instance")
                musicRecognizer = AudDAPIManager() // Initialize without parameters
            } else {
                print("RecognitionViewModel: Cannot create AudD recognizer - missing API key")
            }
            
        case .acrCloud:
            if !settingsManager.acrCreds.host.isEmpty && 
               !settingsManager.acrCreds.key.isEmpty && 
               !settingsManager.acrCreds.secret.isEmpty {
                print("RecognitionViewModel: Creating ACRCloud recognizer instance")
                musicRecognizer = ACRCloudService(creds: settingsManager.acrCreds)
            } else {
                print("RecognitionViewModel: Cannot create ACRCloud recognizer - missing credentials")
            }
        }
        
        // Update status if no recognizer could be created
        if musicRecognizer == nil {
            print("RecognitionViewModel: Warning - No music recognizer available")
            // Don't set statusMessage here to avoid overriding current UI state
        }
    }

    // Helper to map RecognizedTrack to the app's main TrackInfo model
    private func mapRecognizedTrackToTrackInfo(_ recognizedTrack: RecognizedTrack) -> TrackInfo {
        // Create TrackInfo instance, mapping relevant fields
        let trackInfo = TrackInfo(
            title: recognizedTrack.title,
            artist: recognizedTrack.artist,
            album: recognizedTrack.album,
            releaseDate: recognizedTrack.releaseDate,
            genre: recognizedTrack.genre,
            spotifyID: recognizedTrack.spotifyID,
            appleID: recognizedTrack.appleID,
            artworkURL: recognizedTrack.artworkURL,
            // TODO: Map BPM, energy, danceability if ACRCloud provides them
            bpm: nil, 
            energy: nil,
            danceability: nil,
            // Determine source based on the actual recognizer type (could be stored/checked)
            source: settingsManager.musicIDProvider == .acrCloud ? .acrCloud : .audD 
             // Note: Temporarily mapping source like this. A better way might be needed.
        )
        // We don't map prompts here; LLMManager handles that.
        return trackInfo
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
   
   /// Send a generic OSC message with the specified address and values
   func sendOscMessage(address: String, values: [Any]) {
       guard settingsManager.hasValidOSCConfig else {
           print("RecognitionViewModel: Invalid OSC configuration, message not sent")
           return
       }
       
       // Use existing OSCManager methods directly
       if address == "/vibeid/status" && values.count == 1, let status = values[0] as? String {
           // For status messages, use sendStatusMessage
           oscManager.sendStatusMessage(status: status, 
                                       host: settingsManager.oscHost, 
                                       port: settingsManager.oscPort)
       } else if address == "/vibeid/test" {
           // For test/ping messages
           oscManager.sendPing(to: settingsManager.oscHost, port: settingsManager.oscPort)
       } else {
           // For other unhandled messages, simply log them
           print("RecognitionViewModel: Unhandled OSC message - Address: \(address), Values: \(values)")
       }
   }
   
  /// Sends track info via OSC if configured
  private func sendTrackInfo(track: TrackInfo) async {
      print("RecognitionViewModel: Sending track information")
      
      // Check OSC configuration
      guard SettingsManager.shared.hasValidOSCConfig else {
          print("RecognitionViewModel: Invalid OSC configuration")
          return
      }
      
      // Send track information
      oscManager.sendTrackInfo(track: track, host: SettingsManager.shared.oscHost, port: SettingsManager.shared.oscPort)
  }

  // Add a method to handle LLM states
  public func handleLLMState() {
      Task { @MainActor in
          // Check if LLM is generating
          if llmManager.isGenerating {
              print("RecognitionViewModel: Generating prompts in progress...")
              llmState = .generating
              return
          }
          
          // Check if there's an error
          if let error = llmManager.errorMessage {
              print("RecognitionViewModel: Error during prompts generation: \(error)")
              llmState = .error(error)
              return
          }
          
          // Check if prompts are available
          let prompts = llmManager.currentPrompts
          if !prompts.isEmpty {
              print("RecognitionViewModel: \(prompts.count) prompts generated successfully!")
              
              // Update prompts in latestTrack
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
                  
                  // Send updated information via OSC
                  await sendTrackInfo(track: track)
              }
              
              llmState = .success(prompts)
              return
          }
          
          // Default to idle
          print("RecognitionViewModel: LLM state: idle")
          llmState = .idle
      }
  }

  // Method to cancel ongoing identification
  func cancelIdentification() {
      print("RecognitionViewModel: Cancelling ongoing identification")
      isListening = false // Ensure listening stops
      musicRecognizer?.cancel() // Cancel via protocol
      audioManager.cancelRecording() // Explicitly cancel recording too
      stopIdentificationTimer()
      stopDisplayTimer()
      isPerformingIdentification = false
      timeUntilNextIdentification = nil
      llmState = .idle
      // Reset LLM Manager state if needed
      // llmManager.reset()
      statusMessage = "Identification cancelled."
  }
  
  // Method to reset state
  func resetState() {
      print("RecognitionViewModel: Resetting state")
      
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
  
  // Method to send test track info
  func sendTestTrackInfo(track: TrackInfo) async {
      print("RecognitionViewModel: Sending test track information")
      
      // Update current track
      latestTrack = track
      
      // Send track information
      await sendTrackInfo(track: track)
  }

} // End of RecognitionViewModel class

// Make TrackInfo's source Codable if needed (check if TrackInfo is actually saved)
// Add CodingKeys if necessary
