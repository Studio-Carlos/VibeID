// Fichier: SettingsManager.swift
// (Version Corrigée : Guillemet manquant dans print)

import Foundation
import KeychainAccess
import Combine

@MainActor
class SettingsManager: ObservableObject {

    static let shared = SettingsManager()

    private enum Keys {
        static let oscHost = "oscHost"
        static let oscPort = "oscPort"
        static let frequency = "recognitionFrequency"
        static let keychainService = "fr.studiocarlos.VibeID"
        static let apiKey = "audD_api_key"
    }

    private let keychain = Keychain(service: Keys.keychainService)

    @Published var oscHost: String = "192.168.1.100" {
        didSet { UserDefaults.standard.set(oscHost, forKey: Keys.oscHost) }
    }
    @Published var oscPort: Int = 12000 {
        didSet { UserDefaults.standard.set(max(1, min(65535, oscPort)), forKey: Keys.oscPort) }
    }
    @Published var recognitionFrequencyMinutes: Int = 5 {
        didSet { UserDefaults.standard.set(max(1, min(10, recognitionFrequencyMinutes)), forKey: Keys.frequency) }
    }
    @Published var apiKey: String? {
        didSet { saveApiKey() }
    }

    private init() {
        self.oscHost = UserDefaults.standard.string(forKey: Keys.oscHost) ?? self.oscHost
        let loadedPort = UserDefaults.standard.integer(forKey: Keys.oscPort)
        self.oscPort = loadedPort == 0 ? self.oscPort : loadedPort
        let loadedFreq = UserDefaults.standard.integer(forKey: Keys.frequency)
        self.recognitionFrequencyMinutes = loadedFreq == 0 ? self.recognitionFrequencyMinutes : loadedFreq
        self.apiKey = loadApiKey()
        print("SettingsManager Initialisé: Host=\(oscHost), Port=\(oscPort), Freq=\(recognitionFrequencyMinutes)min, APIKey Loaded=\(apiKey != nil)")
    }

    // Méthodes de Sauvegarde/Chargement
    private func saveApiKey() {
        if let key = self.apiKey, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                try keychain.set(key, key: Keys.apiKey)
                print("Clé API sauvegardée dans le Keychain.")
            } catch { print("Erreur sauvegarde Keychain: \(error)") }
        } else {
            do {
                try keychain.remove(Keys.apiKey)
                // <<< CORRECTION ICI : Ajout du guillemet fermant >>>
                print("Clé API supprimée du Keychain.")
            } catch { print("Erreur suppression Keychain: \(error)") }
        }
    }

    private func loadApiKey() -> String? {
        do {
            return try keychain.getString(Keys.apiKey)
        } catch let error {
            print("Erreur lecture Keychain (ou clé absente): \(error.localizedDescription)")
            return nil
        }
    }

    // Propriétés Calculées
    var isOscConfigured: Bool {
        print("--- Checking isOscConfigured: Host='\(self.oscHost)', Port=\(self.oscPort)")
        let hostIsValid = !self.oscHost.trimmingCharacters(in: .whitespaces).isEmpty
        let portIsValid = self.oscPort > 0 && self.oscPort <= 65535
        let configured = hostIsValid && portIsValid
        print("--- isOscConfigured Result: \(configured) (Host valid: \(hostIsValid), Port valid: \(portIsValid))")
        return configured
    }

    var isApiKeySet: Bool {
        let keyIsPresentAndValid = self.apiKey != nil && !(self.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        // print("--- Checking isApiKeySet: Result = \(keyIsPresentAndValid)") // Optionnel debug
        return keyIsPresentAndValid
    }

} // Fin classe SettingsManager
