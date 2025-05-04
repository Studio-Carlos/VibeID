// ACRCloudResponseModels.swift
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

// Root response structure from ACRCloud
struct ACRCloudResponse: Codable {
    let status: ACRCloudStatus
    let metadata: ACRCloudMetadata?
    let result_type: Int?
}

// Status object within the response
struct ACRCloudStatus: Codable {
    let msg: String
    let version: String?
    let code: Int
}

// Metadata object containing recognition results
struct ACRCloudMetadata: Codable {
    let timestamp_utc: String?
    let music: [ACRCloudMusic]?
    // Potentially add other metadata types if needed (e.g., streams, custom_files)
}

// Detailed music information
struct ACRCloudMusic: Codable {
    let acrid: String?
    let title: String?
    let artists: [ACRCloudArtist]?
    let album: ACRCloudAlbum?
    let releaseDate: String?
    let genres: [ACRCloudGenre]?
    let externalMetadata: ACRCloudExternalMetadata? // Changed name to avoid conflict
    let score: Int?
    let playOffsetMs: Int?

    enum CodingKeys: String, CodingKey {
        case acrid, title, artists, album, genres, score
        case releaseDate = "release_date"
        case externalMetadata = "external_metadata" // Map JSON key
        case playOffsetMs = "play_offset_ms"
    }
}

// Artist information
struct ACRCloudArtist: Codable {
    let name: String?
    // Add other potential artist fields if needed
}

// Album information
struct ACRCloudAlbum: Codable {
    let name: String?
    let id: String? // Sometimes ID is provided
}

// Genre information
struct ACRCloudGenre: Codable {
    let name: String?
}

// External metadata (Spotify, Apple Music, etc.)
struct ACRCloudExternalMetadata: Codable {
    let spotify: ACRCloudSpotify? // Changed to optional
    let appleMusic: ACRCloudAppleMusic? // Changed to optional & renamed
    // Add other providers like deezer, youtube if necessary

    enum CodingKeys: String, CodingKey {
        case spotify
        case appleMusic = "applemusic" // Map JSON key (assuming it's lowercase)
    }
}

// Spotify specific metadata
struct ACRCloudSpotify: Codable {
    let track: ACRCloudSpotifyTrack?
    let artists: [ACRCloudSpotifyArtist]?
    let album: ACRCloudSpotifyAlbum?
}

struct ACRCloudSpotifyTrack: Codable {
    let id: String?
}

struct ACRCloudSpotifyArtist: Codable {
    let id: String?
}

struct ACRCloudSpotifyAlbum: Codable {
    let id: String?
    let images: [ACRCloudImage]? // Add images for artwork
}

// Apple Music specific metadata
struct ACRCloudAppleMusic: Codable {
    let track: ACRCloudAppleMusicTrack?
    let artists: [ACRCloudAppleMusicArtist]?
    let album: ACRCloudAppleMusicAlbum?
    let artwork: ACRCloudAppleMusicArtwork? // Add artwork info
}

struct ACRCloudAppleMusicTrack: Codable {
    let id: String?
}

struct ACRCloudAppleMusicArtist: Codable {
    let id: String?
}

struct ACRCloudAppleMusicAlbum: Codable {
    let id: String?
}

// Artwork information (specifically for Apple Music as seen in sample parsing)
struct ACRCloudAppleMusicArtwork: Codable {
    let url: String? // URL template like ".../{w}x{h}bb.jpg"
}

// Image information (for Spotify artwork)
struct ACRCloudImage: Codable {
    let url: String?
    let height: Int?
    let width: Int?
}

// ---- Extension to map ACRCloudMusic to RecognizedTrack ----
// Moved parsing logic here from ACRCloudService for better separation.

extension RecognizedTrack {
    init(acrResponse: ACRCloudResponse, rawJson: String?) throws {
        // Check status code first
        guard acrResponse.status.code == 0 else {
            if acrResponse.status.code == 1001 { // No Result
                self.init()
                self.rawResponse = rawJson
                return
            } else {
                throw ACRCloudServiceError.apiError(message: "\(acrResponse.status.msg) (Code: \(acrResponse.status.code))")
            }
        }
        
        guard let musicInfo = acrResponse.metadata?.music?.first else {
            // Success status, but no music array or it's empty
            self.init()
            self.rawResponse = rawJson
            return
        }
        
        self.init(
            title: musicInfo.title,
            artist: musicInfo.artists?.first?.name,
            album: musicInfo.album?.name,
            releaseDate: musicInfo.releaseDate,
            genre: musicInfo.genres?.first?.name,
            spotifyID: musicInfo.externalMetadata?.spotify?.track?.id,
            appleID: musicInfo.externalMetadata?.appleMusic?.track?.id,
            artworkURL: nil, // Populate below
            rawResponse: rawJson
        )
        
        // Populate artworkURL
        if let spotifyArtworkUrlStr = musicInfo.externalMetadata?.spotify?.album?.images?.first?.url, let url = URL(string: spotifyArtworkUrlStr) {
            self.artworkURL = url
        } else if let appleArtworkUrlStr = musicInfo.externalMetadata?.appleMusic?.artwork?.url, let url = URL(string: appleArtworkUrlStr.replacingOccurrences(of: "{w}x{h}", with: "300x300")) { // Example size
            self.artworkURL = url
        }
    }
} 