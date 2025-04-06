// Fichier: RecognitionViewModel.swift
// (Basé sur la version #41 - Correction typo print - AVEC Task @MainActor dans toggleListening)

import Foundation
import Combine
import SwiftUI
import OSCKit // Assurer que l'import est là

// --- TrackInfo Struct (dans TrackInfo.swift) ---

@MainActor
class RecognitionViewModel: ObservableObject {

    @Published var isListening: Bool = false
    @Published var statusMessage: String = "Prêt"
    @Published var latestTrack: TrackInfo? = nil
    // Ajouter la propriété pour le compte à rebours qui manquait peut-être dans la version #41 ?
    // Assurons-nous qu'elle est bien là pour que ContentView compile.
    @Published var timeUntilNextIdentification: Int? = nil

    private let settingsManager = SettingsManager.shared
    private let audioManager = AudioCaptureManager()
    private let apiManager = AudDAPIManager()
    private let oscManager = OSCManager()

    private var identificationTimer: Timer?
    private var displayTimer: Timer? // Assurer que ce timer est aussi présent
    var isPerformingIdentification = false {
        didSet { print(">>> isPerformingIdentification changé à: \(isPerformingIdentification)") }
    }


    init() {
        print("RecognitionViewModel Initialisé")
    }

    // --- Actions UI ---

    func toggleListening() {
        print("--- toggleListening() appelée --- (isPerformingIdentification = \(isPerformingIdentification))")
        guard !isPerformingIdentification else {
            print("toggleListening: Ignoré car isPerformingIdentification est true.")
            return
        }

        let shouldStartListening = !isListening

        if shouldStartListening { // === TENTATIVE DE DÉMARRAGE ===
            print("--- Début du bloc de DÉMARRAGE ---")
            print("Settings Check: isApiKeySet = \(settingsManager.isApiKeySet) (Clé: '\(settingsManager.apiKey ?? "nil")')") // Debug
            guard settingsManager.isApiKeySet else {
                statusMessage = "Erreur: Clé API AudD manquante."
                print(">>> ÉCHEC DÉMARRAGE: Clé API manquante ou vide.")
                return
            }

            print("--- Clé API OK ---")
            isListening = true // Activation de l'état
            statusMessage = "Écoute en cours..."
            print("Toggle Listening: isListening mis à \(isListening)")

            // MODIFIÉ: Appel direct des méthodes au lieu d'utiliser Task { @MainActor }
            print(">>> Tentative d'appel direct sendTestOSCMessage...")
            sendTestOSCMessage(message: "listening_started")

            print(">>> Tentative d'appel direct startIdentificationTimers...")
            startIdentificationTimers()
            
            print("--- Fin du bloc de DÉMARRAGE (appels directs) ---")

        } else { // === ARRÊT ===
             print("--- Début du bloc d'ARRÊT ---")
             isListening = false // Désactivation de l'état
             print("Toggle Listening: isListening mis à \(isListening)")

             statusMessage = "Arrêt..."
             stopListening()
             print(">>> Tentative d'appel direct sendTestOSCMessage (stop)...")
             // MODIFIÉ: Appel direct au lieu d'utiliser Task
             sendTestOSCMessage(message: "listening_stopped")
             statusMessage = "Prêt"
        }
    } // Fin func toggleListening

    // ... (Le reste du fichier est identique à la version #41 que vous avez fournie,
    //      qui incluait sendManualPrompt, start/stop timers, stopListening, performIdentification, sendTestOSCMessage) ...

     func sendManualPrompt(prompt: String) {
         guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
         print("Envoi du prompt manuel demandé : \(prompt)")
         guard settingsManager.isOscConfigured else {
             statusMessage = "Erreur: Config OSC manquante."
             DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                 if self.isListening { self.statusMessage = "Écoute en cours..." }
                 else { self.statusMessage = "Prêt" }
             }
             return
         }
         let previousStatus = statusMessage
         statusMessage = "Envoi OSC prompt..."

         print(">>> Appel oscManager.sendManualPrompt...")
         oscManager.sendManualPrompt(
            prompt: prompt,
            host: settingsManager.oscHost,
            port: settingsManager.oscPort
         )

         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              if self.statusMessage == "Envoi OSC prompt..." {
                   self.statusMessage = previousStatus
              }
         }
     }

     private func startIdentificationTimers() {
         // Correction typo du print
         print("--- startIdentificationTimers appelée --- (Fréq: \(settingsManager.recognitionFrequencyMinutes) min)")
         identificationTimer?.invalidate()
         stopDisplayTimer() // Arrêter ancien timer affichage

         // Lancer performIdentification immédiatement (comme dans la version #41)
         // Si cela cause des problèmes, on remettra l'appel asynchrone ici.
         print("Appel immédiat de performIdentification depuis startIdentificationTimers")
         performIdentification()

         let interval = TimeInterval(settingsManager.recognitionFrequencyMinutes * 60)
         timeUntilNextIdentification = Int(interval)
         identificationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
             DispatchQueue.main.async {
                 print("Timer Principal (ID) déclenché.")
                 if self?.isListening == true {
                      self?.performIdentification()
                 } else {
                      self?.stopIdentificationTimer()
                 }
             }
         }

         displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
             DispatchQueue.main.async { // Assurer MainActor
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
         print("--- Nouveaux timers planifiés dans startIdentificationTimers ---")
     }

     private func stopIdentificationTimer() {
         print("Arrêt du Timer Principal (ID).")
         identificationTimer?.invalidate()
         identificationTimer = nil
     }

     private func stopDisplayTimer() {
         print("Arrêt du Timer d'Affichage (Compte à rebours).")
         displayTimer?.invalidate()
         displayTimer = nil
         timeUntilNextIdentification = nil
     }

     private func stopListening() {
         print("RecognitionViewModel: Arrêt des opérations demandé...")
         stopIdentificationTimer()
         stopDisplayTimer()
         print("RecognitionViewModel: Demande d'annulation à AudioCaptureManager...")
         audioManager.cancelRecording()
         print("RecognitionViewModel: Demande d'annulation à AudDAPIManager...")
         apiManager.cancelCurrentRequest()
         isPerformingIdentification = false // Assurer le reset du flag
         // isListening est géré par toggleListening
     }


     private func performIdentification() {
         print("--- performIdentification appelée ---")
         guard !isPerformingIdentification else { print("Identification déjà en cours, skip."); return }
         guard isListening else { print("Plus en écoute au début de performIdentification, annulation."); return }
         guard let apiKey = settingsManager.apiKey, !apiKey.isEmpty else {
             statusMessage = "Erreur: Clé API AudD manquante."; print("Échec: Clé API manquante.");
              isListening = false
              stopListening()
              statusMessage = "Prêt (Clé API manquante)"
             return
         }

         isPerformingIdentification = true
         statusMessage = "Enregistrement audio..."
         timeUntilNextIdentification = nil // Masquer pendant ID
         print("performIdentification: Appel recordSnippet...")

         audioManager.recordSnippet { [weak self] result in
              guard let self = self else { 
                  print("AudioManager callback: self est nil, abandon.")
                  return
              }
              // NE PAS vérifier isListening ici pour pouvoir traiter même si arrêté PENDANT record

             switch result {
             case .success(let fileURL):
                  print("Audio enregistré: \(fileURL.lastPathComponent)")
                  // Vérifier isListening AVANT appel API
                  guard self.isListening else {
                       print("Callback recordSnippet: Non en écoute avant appel API, abandon.")
                       try? FileManager.default.removeItem(at: fileURL)
                       self.isPerformingIdentification = false
                       return
                  }
                  self.statusMessage = "Envoi API AudD..."

                  self.apiManager.recognize(audioFileURL: fileURL, apiKey: apiKey) { [weak self] apiResult in
                       // Traiter le résultat sur MainActor
                       Task { @MainActor [weak self] in
                            guard let strongSelf = self else { return }
                            // NE PAS vérifier isListening ici pour pouvoir traiter même si arrêté PENDANT API call

                            var currentCycleStatusMessage: String? = nil
                            var apiCallWasCancelled = false

                            switch apiResult {
                             case .success(let audDResult):
                                  if let resultData = audDResult {
                                       print("AudD API: Morceau trouvé: \(resultData.title ?? "Sans titre") - \(resultData.artist ?? "Artiste inconnu")")
                                       
                                       // Créer TrackInfo à partir des données AudD
                                       let newTrack = TrackInfo(
                                           title: resultData.title,
                                           artist: resultData.artist,
                                           artworkURL: resultData.apple_music?.artwork?.artworkURL(width: 300, height: 300) ?? 
                                                      resultData.spotify?.album?.images?.first?.url.flatMap { URL(string: $0) },
                                           genre: resultData.estimatedGenre,
                                           bpm: resultData.estimatedBpm
                                       )
                                       
                                       // Ne mettre à jour que si le morceau a changé
                                       let trackChanged = strongSelf.latestTrack != newTrack && newTrack.title != nil
                                       if trackChanged {
                                           strongSelf.latestTrack = newTrack
                                           
                                           // Envoyer les infos par OSC si OSC configuré
                                           if strongSelf.settingsManager.isOscConfigured {
                                               strongSelf.oscManager.sendTrackInfo(
                                                   track: newTrack,
                                                   host: strongSelf.settingsManager.oscHost,
                                                   port: strongSelf.settingsManager.oscPort
                                               )
                                           }
                                       }
                                       
                                       currentCycleStatusMessage = "Morceau trouvé!"
                                  } else {
                                       print("AudD API: Aucune correspondance trouvée.")
                                       currentCycleStatusMessage = "Aucune correspondance."
                                  }
                             case .failure(let error):
                                  if (error as NSError).code == NSURLErrorCancelled {
                                       apiCallWasCancelled = true
                                       print("AudD API: Appel annulé.")
                                       currentCycleStatusMessage = "Identification annulée."
                                  } else {
                                       print("AudD API: Erreur: \(error.localizedDescription)")
                                       currentCycleStatusMessage = "Erreur: \(error.localizedDescription)"
                                  }
                            }

                            try? FileManager.default.removeItem(at: fileURL)
                            strongSelf.isPerformingIdentification = false // Fin cycle
                            print("Fin cycle identification (callback API).")

                            // Mise à jour statut et compte à rebours (logique identique à version précédente)
                            if strongSelf.isListening {
                                 // Si toujours en écoute et pas annulé, préparer prochain cycle
                                 if !apiCallWasCancelled {
                                      // Mettre à jour le statut temporairement
                                      if let message = currentCycleStatusMessage {
                                           strongSelf.statusMessage = message
                                      }
                                      
                                      // Rétablir "Écoute en cours..." après 2s
                                      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                           if strongSelf.isListening {
                                                strongSelf.statusMessage = "Écoute en cours..."
                                           }
                                      }
                                      
                                      // Réinitialiser le compteur pour le prochain cycle
                                      let interval = TimeInterval(strongSelf.settingsManager.recognitionFrequencyMinutes * 60)
                                      strongSelf.timeUntilNextIdentification = Int(interval)
                                 }
                            } else {
                                 // Si plus en écoute, reset le statut
                                 strongSelf.statusMessage = "Prêt"
                            }
                       } // Fin Task @MainActor
                  } // Fin closure recognize

             case .failure(let error):
                  var wasAudioCancelled = false
                  if case .recordingCancelled = (error as? AudioCaptureError) {
                       print("AudioManager: Enregistrement annulé.")
                       wasAudioCancelled = true
                  } else {
                       print("AudioManager: Erreur: \(error.localizedDescription)")
                       self.statusMessage = "Erreur audio: \(error.localizedDescription)"
                  }
                  self.isPerformingIdentification = false
                  print("Fin cycle identification (erreur audio).")
                  
                  // Mise à jour statut et compte à rebours
                  if self.isListening && !wasAudioCancelled {
                       // Si erreur mais toujours en écoute, restaurer après délai
                       DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if self.isListening {
                                 self.statusMessage = "Écoute en cours..."
                                 // Réinitialiser le compteur pour prochain cycle
                                 let interval = TimeInterval(self.settingsManager.recognitionFrequencyMinutes * 60)
                                 self.timeUntilNextIdentification = Int(interval)
                            }
                       }
                  } else if !self.isListening {
                       // Si plus en écoute, reset statut
                       self.statusMessage = "Prêt"
                  }
             } // Fin switch result
         } // Fin closure recordSnippet
     } // Fin func performIdentification


     // --- Fonctions OSC ---
     private func sendTestOSCMessage(message: String) {
          print("--- sendTestOSCMessage appelée ---")
          print("OSC Test: Vérification configuration...")
          guard settingsManager.isOscConfigured else {
               print(">>> OSC Test: Non configuré, skip. Host='\(settingsManager.oscHost)', Port=\(settingsManager.oscPort)")
               return
          }
          print(">>> OSC Test: Config OK. Appel oscManager.send (Test: \(message))...")

          let addr = OSCAddressPattern("/vibeid/app/status")
          let values: [any OSCValue] = [message]
          oscManager.send(OSCMessage(addr, values: values),
                          to: settingsManager.oscHost,
                          port: settingsManager.oscPort)
     } // Fin func sendTestOSCMessage

} // Fin classe RecognitionViewModel
