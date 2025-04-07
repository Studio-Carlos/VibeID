// AudDResponseModels.swift
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

// Main structure of the AudD response
struct AudDResponse: Codable {
    let status: String // "success" or "error"
    let result: AudDResult? // Result is optional (can be null if no match)
    // Potential error fields (to be verified in actual error responses)
    // let errorCode: Int?
    // let errorMessage: String?
}

// Structure for the result in case of success
struct AudDResult: Codable {
    let artist: String? // Sometimes missing? Made optional for safety
    let title: String?
    let album: String?
    let release_date: String? // Date as String YYYY-MM-DD
    let label: String?
    let timecode: String? // "00:12-00:24" for example
    let song_link: String? // Link to lis.tn

    // Additional fields if requested in the 'return' parameter
    let apple_music: AudDAppleMusic?
    let spotify: AudDSpotify?
    // Add Deezer, Napster, MusicBrainz if needed
    // let deezer: AudDDeezer?
    // let napster: AudDNapster?
    // let musicbrainz: [AudDMusicBrainz]? // Appears to be an array
    
    // Try to retrieve BPM and Genre from metadata if AudD doesn't provide them directly
    // These fields are NOT listed in the basic docs, we'll try via Spotify/Apple Music if possible.
    var estimatedBpm: Double? {
        // Logic to add if we find BPM in spotify.audio_features for example
        return spotify?.audio_features?.tempo
    }
    
    var estimatedGenre: String? {
        // Logic to add if we find genre in apple_music.genreNames or spotify.genres
        return apple_music?.genreNames?.first ?? spotify?.genres?.first
    }
    
    var estimatedEnergy: Double? {
        // Energy from Spotify audio features
        return spotify?.audio_features?.energy
    }
    
    var estimatedDanceability: Double? {
        // Danceability from Spotify audio features
        return spotify?.audio_features?.danceability
    }
}

// Sub-structures for platform data

struct AudDAppleMusic: Codable {
    let previews: [AudDPreview]?
    let artwork: AudDArtwork?
    let artistName: String?
    let url: String?
    let discNumber: Int?
    let genreNames: [String]? // Potential for Genre
    let trackNumber: Int?
    let releaseDate: String? // Format YYYY-MM-DD
    let name: String? // = Title
    let isrc: String?
    let albumName: String?
    let playParams: AudDPlayParams?
    let trackId: String? // Apple Music identifier
    let composerName: String?
}

struct AudDSpotify: Codable {
    let album: AudDSpotifyAlbum?
    let artist: String? // Simplified artist name
    let title: String? // Simplified title
    let external_ids: [String: String]? // e.g.: {"isrc": "..."}
    let external_urls: [String: String]? // e.g.: {"spotify": "..."}
    let id: String? // Spotify identifier
    let uri: String?
    let popularity: Int?
    let preview_url: String?
    let track_number: Int?
    let disc_number: Int?
    let explicit: Bool?
    let duration_ms: Int?
    let album_details: AudDSpotifyAlbum? // Redundant? To verify
    let artists: [AudDSpotifyArtist]? // Detailed list of artists
    let available_markets: [String]?
    let audio_features: AudDSpotifyAudioFeatures? // Potentially contains BPM (tempo)
    let genres: [String]? // Another potential source for Genre
}

// Sub-structures for Apple Music
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

    // Function to get an artwork URL of specific size
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

// Sub-structures for Spotify
struct AudDSpotifyAlbum: Codable {
    let name: String?
    let id: String?
    let uri: String?
    let album_type: String?
    let release_date: String?
    let release_date_precision: String?
    let external_urls: [String: String]?
    let images: [AudDSpotifyImage]?
    let artists: [AudDSpotifyArtist]? // Album artists
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
    let tempo: Double? // *** Potential BPM here ***
    let time_signature: Int?
    let track_href: String?
    let type: String?
    let uri: String?
    let valence: Double?
}

// Define other structures for Deezer, Napster, MusicBrainz if necessary...
