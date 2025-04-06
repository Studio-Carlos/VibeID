// Fichier: OSCManager.swift
// (Version Corrigée : send n'est plus private)

import Foundation
import OSCKit

@MainActor
class OSCManager {

    private let oscClient = OSCClient()

    // Définition complète de l'enum OSCError
    enum OSCError: Error, LocalizedError {
        case invalidHost
        case invalidPort
        case sendError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidHost: return "Hôte OSC invalide"
            case .invalidPort: return "Port OSC invalide"
            case .sendError(let error): return "Erreur d'envoi OSC: \(error.localizedDescription)"
            }
        }
    }

    init() {
        print("OSCManager Initialisé")
    }

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

    /// Envoie les informations d'un morceau identifié via OSC.
    func sendTrackInfo(track: TrackInfo, host: String, port: Int) {
        print("OSCManager: Envoi des infos du morceau via OSC")
        
        // Vérifier validité
        guard !host.isEmpty, port > 0, port <= 65535 else {
            print("OSCManager: Configuration OSC invalide pour sendTrackInfo")
            return
        }
        
        // Créer les messages pour chaque attribut
        if let title = track.title {
            let titleMsg = OSCMessage(OSCAddressPattern("/vibeid/track/title"), values: [title])
            send(titleMsg, to: host, port: port)
        }
        
        if let artist = track.artist {
            let artistMsg = OSCMessage(OSCAddressPattern("/vibeid/track/artist"), values: [artist])
            send(artistMsg, to: host, port: port)
        }
        
        if let genre = track.genre {
            let genreMsg = OSCMessage(OSCAddressPattern("/vibeid/track/genre"), values: [genre])
            send(genreMsg, to: host, port: port)
        }
        
        if let bpm = track.bpm {
            let bpmMsg = OSCMessage(OSCAddressPattern("/vibeid/track/bpm"), values: [Float(bpm)])
            send(bpmMsg, to: host, port: port)
        }
        
        // Envoyer une notification de "nouveau morceau" à la fin
        let newTrackMsg = OSCMessage(OSCAddressPattern("/vibeid/track/new"), values: [1])
        send(newTrackMsg, to: host, port: port)
    }
    
    /// Envoie un prompt manuel saisi par l'utilisateur via OSC.
    func sendManualPrompt(prompt: String, host: String, port: Int) {
        print("OSCManager: Envoi du prompt manuel via OSC: \"\(prompt)\"")
        
        // Vérifier validité
        guard !host.isEmpty, port > 0, port <= 65535 else {
            print("OSCManager: Configuration OSC invalide pour sendManualPrompt")
            return
        }
        
        // Créer le message pour le prompt
        let promptMsg = OSCMessage(OSCAddressPattern("/vibeid/prompt"), values: [prompt])
        send(promptMsg, to: host, port: port)
    }

} // Fin classe OSCManager
