// TrackInfo.swift
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

import Foundation // Import Foundation for URL

// Model for track information
struct TrackInfo: Identifiable, Equatable {
    let id = UUID()
    var title: String?
    var artist: String?
    var artworkURL: URL? // Keep URL here
    var genre: String?
    var bpm: Double?
    var energy: Double? // Energy (0.0 to 1.0)
    var danceability: Double? // Danceability (0.0 to 1.0)

    // Comparison based on title and artist
    static func == (lhs: TrackInfo, rhs: TrackInfo) -> Bool {
        // Compare nil and empty as identical to avoid unnecessary OSC sends if only case changes, for example
        let lhsTitle = lhs.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rhsTitle = rhs.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lhsArtist = lhs.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rhsArtist = rhs.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Optional: Make case-insensitive if needed?
        // return lhsTitle.lowercased() == rhsTitle.lowercased() && lhsArtist.lowercased() == rhsArtist.lowercased()

        return lhsTitle == rhsTitle && lhsArtist == rhsArtist
    }
}
