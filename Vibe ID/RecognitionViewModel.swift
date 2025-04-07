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
    @Published var statusMessage: String = "Ready"
    @Published var latestTrack: TrackInfo? = nil
    // Property to track the countdown until next identification
    @Published var timeUntilNextIdentification: Int? = nil

    private let settingsManager = SettingsManager.shared
    private let audioManager = AudioCaptureManager()
    private let apiManager = AudDAPIManager()
    private let oscManager = OSCManager()

    private var identificationTimer: Timer?
    private var displayTimer: Timer? // Timer for displaying countdown
    var isPerformingIdentification = false {
        didSet { print(">>> isPerformingIdentification changed to: \(isPerformingIdentification)") }
    }


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

     private func stopListening() {
         print("RecognitionViewModel: Stop operations requested...")
         stopIdentificationTimer()
         stopDisplayTimer()
         print("RecognitionViewModel: Cancellation request to AudioCaptureManager...")
         audioManager.cancelRecording()
         print("RecognitionViewModel: Cancellation request to AudDAPIManager...")
         apiManager.cancelCurrentRequest()
         isPerformingIdentification = false // Ensure flag reset
         // isListening is managed by toggleListening
     }


     private func performIdentification() {
         print("--- performIdentification called ---")
         guard !isPerformingIdentification else { print("Identification already in progress, skip."); return }
         guard isListening else { print("Not listening at the beginning of performIdentification, cancel."); return }
         guard let apiKey = settingsManager.apiKey, !apiKey.isEmpty else {
             statusMessage = "Error: AudD API key missing."; print("Failure: API key missing.");
              isListening = false
              stopListening()
              statusMessage = "Ready (API key missing)"
              return
         }

         // Reset timer for next identification
         timeUntilNextIdentification = settingsManager.recognitionFrequencyMinutes * 60

         // Update state and UI
         isPerformingIdentification = true
         statusMessage = "Recording audio..."
         print("RecognitionViewModel: Starting audio recording...")

         // Start audio recording
         audioManager.recordSnippet { [weak self] result in
              guard let self = self else { 
                   print("AudioManager callback: self is nil, abandon.")
                   return
              }

              switch result {
              case .success(let audioURL):
                   print("Audio recording successful: \(audioURL.lastPathComponent)")
                   self.statusMessage = "Identifying music..."
                   
                   // Launch API call with the audio file
                   self.apiManager.recognize(audioFileURL: audioURL, apiKey: apiKey) { [weak self] result in
                        guard let self = self else {
                             print("AudD API callback: self is nil, abandon.")
                             return
                        }
                   
                        switch result {
                        case .success(let audDResult):
                             if let resultData = audDResult {
                                  print("Song identified: \(resultData.title ?? "Unknown")")
                                  
                                  // Create TrackInfo from the result
                                  let identifiedTrack = TrackInfo(
                                       title: resultData.title ?? "Unknown Title",
                                       artist: resultData.artist ?? "Unknown Artist",
                                       artworkURL: (resultData.spotify?.album?.images?.first?.url != nil) ? 
                                           URL(string: resultData.spotify?.album?.images?.first?.url ?? "") : 
                                           resultData.apple_music?.artwork?.artworkURL(width: 300, height: 300),
                                       genre: resultData.estimatedGenre,
                                       bpm: resultData.estimatedBpm,
                                       energy: resultData.estimatedEnergy,
                                       danceability: resultData.estimatedDanceability
                                  )
                                  
                                  // Update UI with new track
                                  DispatchQueue.main.async {
                                       self.latestTrack = identifiedTrack
                                       if self.isListening {
                                            let titleDisplay = identifiedTrack.title ?? "Unknown Title"
                                            let artistDisplay = identifiedTrack.artist ?? "Unknown Artist"
                                            self.statusMessage = "Identified: \"\(titleDisplay)\" by \"\(artistDisplay)\""
                                            
                                            // Send track info to OSC if configured
                                            if self.settingsManager.hasValidOSCConfig {
                                                 self.sendTrackInfoToOSC(identifiedTrack)
                                            }
                                       } else {
                                            self.statusMessage = "Ready (Listening stopped)"
                                       }
                                       
                                       self.isPerformingIdentification = false
                                  }
                             } else {
                                  print("AudD found no match")
                                  DispatchQueue.main.async {
                                       if self.isListening {
                                            self.statusMessage = "No music detected"
                                       } else {
                                            self.statusMessage = "Ready"
                                       }
                                       self.isPerformingIdentification = false
                                  }
                             }
                             
                        case .failure(let error):
                             print("AudD API error: \(error.localizedDescription)")
                             DispatchQueue.main.async {
                                  if self.isListening {
                                       self.statusMessage = "Error: \(error.localizedDescription)"
                                  } else {
                                       self.statusMessage = "Ready (Error)"
                                  }
                                  self.isPerformingIdentification = false
                             }
                        }
                   }
                   
              case .failure(let error):
                   print("Audio recording error: \(error.localizedDescription)")
                   DispatchQueue.main.async {
                        if self.isListening {
                             self.statusMessage = "Error: Recording failed"
                        } else {
                             self.statusMessage = "Ready (Recording failed)"
                        }
                        self.isPerformingIdentification = false
                   }
              }
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
    
    private func sendTrackInfoToOSC(_ track: TrackInfo) {
        print("Sending track info to OSC...")
        oscManager.sendTrackInfo(
            track: track,
            host: settingsManager.oscHost,
            port: settingsManager.oscPort
        )
        print("Track info sent to OSC")
    }

} // End of RecognitionViewModel class
