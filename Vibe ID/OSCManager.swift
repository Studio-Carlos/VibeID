// Fichier: OSCManager.swift
// (Version Corrigée : send n'est plus private)

import Foundation
import OSCKit

@MainActor
class OSCManager {

    private let oscClient = OSCClient()

    // ... (Enum OSCError identique) ...
    enum OSCError: Error, LocalizedError { /* ... */ }

    init() {
        print("OSCManager Initialisé")
    }

    // <<< SUPPRESSION de 'private' ici >>>
    /// Envoie un message OSC unique.
    func send(_ message: OSCMessage, to host: String, port: Int) {
        guard !host.isEmpty, port > 0, port <= 65535 else {
            print("OSCManager Erreur: Hôte (\(host)) ou Port (\(port)) invalide.")
            return
        }
        print("OSCManager: Tentative d'envoi message \(message.addressPattern) à \(host):\(port)")

        Task(priority: .utility) {
             try? oscClient.send(message, to: host, port: UInt16(port))
             // Les erreurs UDP ne sont pas vraiment récupérables ici.
        }
    } // Fin func send

    // ... (sendTrackInfo et sendManualPrompt restent identiques) ...
     func sendTrackInfo(track: TrackInfo, host: String, port: Int) { /* ... */ }
     func sendManualPrompt(prompt: String, host: String, port: Int) { /* ... */ }


} // Fin classe OSCManager
