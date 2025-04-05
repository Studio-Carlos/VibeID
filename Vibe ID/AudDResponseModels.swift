// Fichier: AudDResponseModels.swift

import Foundation

// Structure principale de la réponse AudD
struct AudDResponse: Codable {
    let status: String // "success" ou "error"
    let result: AudDResult? // Le résultat est optionnel (peut être null si pas de match)
    // Champs d'erreur potentiels (à vérifier dans les réponses d'erreur réelles)
    // let errorCode: Int?
    // let errorMessage: String?
}

// Structure pour le résultat en cas de succès
struct AudDResult: Codable {
    let artist: String? // Parfois manquant ? Rendre optionnel par sécurité
    let title: String?
    let album: String?
    let release_date: String? // Date sous forme de String YYYY-MM-DD
    let label: String?
    let timecode: String? // "00:12-00:24" par exemple
    let song_link: String? // Lien vers lis.tn

    // Champs additionnels si demandés dans le paramètre 'return'
    let apple_music: AudDAppleMusic?
    let spotify: AudDSpotify?
    // Ajouter Deezer, Napster, MusicBrainz si besoin
    // let deezer: AudDDeezer?
    // let napster: AudDNapster?
    // let musicbrainz: [AudDMusicBrainz]? // Semble être un tableau
    
    // Tenter de récupérer BPM et Genre depuis les métadonnées si AudD ne les fournit pas directement
    // Ces champs ne sont PAS listés dans la doc de base, on essaiera via Spotify/Apple Music si possible.
    var estimatedBpm: Double? {
        // Logique à ajouter si on trouve le BPM dans spotify.audio_features par exemple
        return spotify?.audio_features?.tempo
    }
    
    var estimatedGenre: String? {
        // Logique à ajouter si on trouve le genre dans apple_music.genreNames ou spotify.genres
        return apple_music?.genreNames?.first ?? spotify?.genres?.first
    }
}

// Sous-structures pour les données des plateformes

struct AudDAppleMusic: Codable {
    let previews: [AudDPreview]?
    let artwork: AudDArtwork?
    let artistName: String?
    let url: String?
    let discNumber: Int?
    let genreNames: [String]? // Potentiel pour le Genre
    let trackNumber: Int?
    let releaseDate: String? // Format YYYY-MM-DD
    let name: String? // = Titre
    let isrc: String?
    let albumName: String?
    let playParams: AudDPlayParams?
    let trackId: String? // Identifiant Apple Music
    let composerName: String?
}

struct AudDSpotify: Codable {
    let album: AudDSpotifyAlbum?
    let artist: String? // Nom d'artiste simplifié
    let title: String? // Titre simplifié
    let external_ids: [String: String]? // ex: {"isrc": "..."}
    let external_urls: [String: String]? // ex: {"spotify": "..."}
    let id: String? // Identifiant Spotify
    let uri: String?
    let popularity: Int?
    let preview_url: String?
    let track_number: Int?
    let disc_number: Int?
    let explicit: Bool?
    let duration_ms: Int?
    let album_details: AudDSpotifyAlbum? // Redondant ? À vérifier
    let artists: [AudDSpotifyArtist]? // Liste détaillée des artistes
    let available_markets: [String]?
    let audio_features: AudDSpotifyAudioFeatures? // Contient potentiellement le BPM (tempo)
    let genres: [String]? // Autre source potentielle pour le Genre
}

// Sous-structures pour Apple Music
struct AudDPreview: Codable {
    let url: String?
}

struct AudDArtwork: Codable {
    let width: Int?
    let height: Int?
    let url: String? // Format: "https://is1-ssl.mzstatic.com/.../{w}x{h}bb.jpg"
    let bgColor: String?
    let textColor1: String?
    let textColor2: String?
    let textColor3: String?
    let textColor4: String?

    // Fonction pour obtenir une URL d'artwork de taille spécifique
    func artworkURL(width desiredWidth: Int = 300, height desiredHeight: Int = 300) -> URL? {
        guard let urlString = url else { return nil }
        let sizedUrlString = urlString.replacingOccurrences(of: "{w}", with: "\(desiredWidth)")
                                      .replacingOccurrences(of: "{h}", with: "\(desiredHeight)")
        return URL(string: sizedUrlString)
    }
}

struct AudDPlayParams: Codable {
    let id: String?
    let kind: String?
}

// Sous-structures pour Spotify
struct AudDSpotifyAlbum: Codable {
    let name: String?
    let id: String?
    let uri: String?
    let album_type: String?
    let release_date: String?
    let release_date_precision: String?
    let external_urls: [String: String]?
    let images: [AudDSpotifyImage]?
    let artists: [AudDSpotifyArtist]? // Artistes de l'album
}

struct AudDSpotifyImage: Codable {
    let height: Int?
    let width: Int?
    let url: String?
}

struct AudDSpotifyArtist: Codable {
    let name: String?
    let id: String?
    let uri: String?
    let external_urls: [String: String]?
}

struct AudDSpotifyAudioFeatures: Codable {
    let acousticness: Double?
    let analysis_url: String?
    let danceability: Double?
    let duration_ms: Int?
    let energy: Double?
    let id: String?
    let instrumentalness: Double?
    let key: Int?
    let liveness: Double?
    let loudness: Double?
    let mode: Int?
    let speechiness: Double?
    let tempo: Double? // *** BPM potentiel ici ***
    let time_signature: Int?
    let track_href: String?
    let type: String?
    let uri: String?
    let valence: Double?
}

// Définir d'autres structures pour Deezer, Napster, MusicBrainz si nécessaire...
