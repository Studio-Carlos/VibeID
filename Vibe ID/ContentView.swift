// Fichier: ContentView.swift
// (Version complète et vérifiée - Espérons la bonne !)

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RecognitionViewModel()
    @State private var manualPromptText: String = ""
    @State private var showingSettings: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                // VStack principal qui contient TOUT ce qui scrolle
                VStack(spacing: 20) {

                    // --- Bouton Start/Stop & Statut ---
                    VStack(spacing: 5) {
                        Button {
                            // ---> AJOUT : Log pour confirmer l'entrée dans l'action
                            print("[ContentView] Bouton principal touché !")
                            // Action correcte
                            viewModel.toggleListening()
                        } label: {
                            Text(viewModel.isListening ? "Stop ID" : "Lancer Vibe ID")
                                .fontWeight(.bold)
                                .padding(.vertical, 22)
                                .frame(maxWidth: .infinity)
                                .background(viewModel.isListening ? Color.red : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                        }
                        .padding(.horizontal)
                        // Animation toujours supprimée
                        .disabled(viewModel.isPerformingIdentification) // Modificateur Disabled est bien là

                        // Statut Principal
                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 5)

                        // Compte à Rebours
                        if viewModel.isListening && !viewModel.isPerformingIdentification && viewModel.timeUntilNextIdentification != nil {
                            Text("Prochain essai dans : \(viewModel.timeUntilNextIdentification ?? 0)s")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.top, 30) // Espace après barre de navigation

                    // --- VSTACK POUR INFOS MORCEAU - VÉRIFIÉ PRÉSENT ---
                    VStack(spacing: 15) {
                        // Pochette
                        AsyncImage(url: viewModel.latestTrack?.artworkURL) { phase in
                             if let image = phase.image { image.resizable().aspectRatio(contentMode: .fit) }
                             else if phase.error != nil { Image(systemName: "photo").resizable().aspectRatio(contentMode: .fit).padding(40).foregroundColor(.gray.opacity(0.5)) }
                             else { Image(systemName: "music.note").resizable().aspectRatio(contentMode: .fit).padding(50).foregroundColor(.gray.opacity(0.5)) }
                         }
                         .frame(width: 200, height: 200)
                         .background(Color.gray.opacity(0.1))
                         .cornerRadius(12)
                         .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                         // Textes
                         Text(viewModel.latestTrack?.title ?? "En attente...")
                             .font(.title2).fontWeight(.bold).multilineTextAlignment(.center)
                         Text(viewModel.latestTrack?.artist ?? "-")
                             .font(.title3).foregroundColor(.gray).multilineTextAlignment(.center)

                         // Genre & BPM
                         HStack(spacing: 15) {
                             if let genre = viewModel.latestTrack?.genre, !genre.isEmpty {
                                 Text("Genre: \(genre)").font(.caption).foregroundColor(.secondary)
                             }
                             if let bpm = viewModel.latestTrack?.bpm {
                                 Text("BPM: \(String(format: "%.0f", bpm))").font(.caption).foregroundColor(.secondary)
                             }
                         }
                         .padding(.top, 5)
                    } // --- FIN VSTACK INFOS MORCEAU ---
                    .padding(.horizontal, 30)
                    .padding(.top, 30)

                } // Fin VStack principal
                .padding(.bottom, 20) // Espace en bas du contenu scrollable

            } // Fin ScrollView
            // Barre d'outils (Toolbar)
            .toolbar {
                ToolbarItem(placement: .principal) { // Titre centré stylisé
                    Text("Vibe ID")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(
                            LinearGradient( colors: [.blue, .purple.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                         )
                }
                ToolbarItem(placement: .navigationBarTrailing) { // Bouton Réglages
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape.fill").foregroundColor(.gray)
                    }
                }
            }
            // Barre de Prompt en bas (hors ScrollView, DANS safeAreaInset)
            .safeAreaInset(edge: .bottom) {
                 HStack {
                      TextField("Envoyer un prompt manuel...", text: $manualPromptText, axis: .vertical)
                          .lineLimit(1...3).textFieldStyle(.plain).padding(12)
                          .background(Color(uiColor: .systemGray5)).cornerRadius(10)
                      Button {
                           viewModel.sendManualPrompt(prompt: manualPromptText)
                           manualPromptText = ""
                           UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                      } label: {
                           Image(systemName: "paperplane.fill")
                                .resizable().scaledToFit().frame(width: 22, height: 22)
                                .foregroundColor(manualPromptText.isEmpty ? .gray : .blue)
                                .padding(.horizontal, 10)
                      }
                      .disabled(manualPromptText.isEmpty)
                 }
                 .padding(.horizontal).padding(.vertical, 8).background(.thinMaterial)
            }
            // Feuille Modale pour les Réglages
            .sheet(isPresented: $showingSettings) { SettingsView() }

        } // Fin NavigationStack
        .preferredColorScheme(.dark)
    } // Fin body
} // Fin struct ContentView

#Preview { ContentView() }
