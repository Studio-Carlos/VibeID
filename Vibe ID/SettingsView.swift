// Fichier: SettingsView.swift
// (Version complète avec syntaxe onChange corrigée)

import SwiftUI

struct SettingsView: View {
    // Accéder à l'instance partagée de SettingsManager
    @StateObject private var settings = SettingsManager.shared

    // État local pour le champ SecureField de la clé API
    @State private var apiKeyInput: String = ""

    // Environnement pour pouvoir fermer la feuille modale
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Section pour la Clé API AudD
                Section("Clé API AudD") {
                    SecureField("Collez votre clé API AudD", text: $apiKeyInput)
                        // Utilisation de la nouvelle syntaxe onChange (iOS 14+ mais obligatoire en style pour iOS 17+)
                        .onChange(of: apiKeyInput) {
                            // Lire la valeur actuelle de l'état lié
                            let currentInputValue = apiKeyInput
                            // Mettre à jour le manager quand le champ change
                            if currentInputValue.isEmpty {
                                settings.apiKey = nil
                            } else {
                                settings.apiKey = currentInputValue
                            }
                        }
                }

                // Section pour la Configuration OSC
                Section("Configuration OSC") {
                    TextField("Adresse IP Cible (ex: 192.168.1.100)", text: $settings.oscHost)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled(true) // Désactiver la correction auto pour les IP
                        .textInputAutocapitalization(.never) // Pas de majuscule auto

                    TextField("Port Cible (ex: 9000)", value: $settings.oscPort, format: .number)
                        .keyboardType(.numberPad)
                }

                // Section pour la Fréquence d'Identification
                Section("Identification") {
                    Text("Fréquence : Toutes les \(settings.recognitionFrequencyMinutes) minutes")
                    Slider(value: Binding(
                        get: { Double(settings.recognitionFrequencyMinutes) },
                        set: { settings.recognitionFrequencyMinutes = Int($0) }
                       ),
                           in: 1...10, // Plage de 1 à 10
                           step: 1      // Pas de 1
                    )
                }

            } // Fin Form
            .navigationTitle("Réglages Vibe ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Bouton pour fermer la feuille modale
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") {
                        dismiss() // Ferme la vue modale
                    }
                    .fontWeight(.bold) // Mettre OK en gras
                }
            }
            // Charger la clé API initiale dans le champ texte quand la vue apparaît
            .onAppear {
                apiKeyInput = settings.apiKey ?? ""
            }
        } // Fin NavigationStack
    } // Fin body
} // Fin struct SettingsView

// --- Prévisualisation ---
#Preview {
    SettingsView()
}
