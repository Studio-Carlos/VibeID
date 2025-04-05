// Fichier: TrackInfo.swift

import Foundation // Importer Foundation pour URL

// Modèle pour les infos de piste
struct TrackInfo: Identifiable, Equatable {
    let id = UUID()
    var title: String?
    var artist: String?
    var artworkURL: URL? // Garder URL ici
    var genre: String?
    var bpm: Double?

    // Comparaison basée sur titre et artiste
    static func == (lhs: TrackInfo, rhs: TrackInfo) -> Bool {
        // Comparer nil et vide comme identiques pour éviter envois OSC inutiles si seule la casse change par ex.
        let lhsTitle = lhs.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rhsTitle = rhs.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lhsArtist = lhs.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rhsArtist = rhs.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Optionnel: Rendre insensible à la casse si besoin ?
        // return lhsTitle.lowercased() == rhsTitle.lowercased() && lhsArtist.lowercased() == rhsArtist.lowercased()

        return lhsTitle == rhsTitle && lhsArtist == rhsArtist
    }
}
