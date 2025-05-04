import Foundation

// Define the common track information structure expected by the app.
// Based on the existing TrackInfo struct, but simplified for the recognizer output.
struct RecognizedTrack: Identifiable, Equatable {
    let id = UUID()
    var title: String?
    var artist: String?
    var album: String?
    var releaseDate: String?
    var genre: String?
    var spotifyID: String?
    var appleID: String?
    var artworkURL: URL?
    var rawResponse: String? // Store the raw JSON response for potential debugging or future use

    // Initializer to map from AudDResult (assuming it exists based on AudDAPIManager)
    // We'll add an initializer for ACRCloud later.
    init(audDResult: AudDResult?) {
        guard let result = audDResult else { return }
        self.title = result.title
        self.artist = result.artist
        self.album = result.album
        self.releaseDate = result.release_date
        self.genre = result.estimatedGenre // Use the computed property for genre
        self.spotifyID = result.spotify?.id
        self.appleID = result.apple_music?.trackId // Use trackId instead of id
        if let artwork = result.apple_music?.artwork, let url = artwork.artworkURL() {
            // Use the helper method in AudDArtwork to get the URL
            self.artworkURL = url
        }
        // TODO: How to get raw JSON from AudDAPIManager? Add later if possible.
    }
    
    // Full initializer for direct creation
    init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        releaseDate: String? = nil,
        genre: String? = nil,
        spotifyID: String? = nil,
        appleID: String? = nil,
        artworkURL: URL? = nil,
        rawResponse: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.releaseDate = releaseDate
        self.genre = genre
        self.spotifyID = spotifyID
        self.appleID = appleID
        self.artworkURL = artworkURL
        self.rawResponse = rawResponse
    }

    // Placeholder initializer for ACRCloud - will be implemented in ACRCloudResponseModels.swift
    init(acrJSON: String?) {
        self.rawResponse = acrJSON
        // TODO: Implement JSON parsing logic here or in a dedicated model file.
    }

    // Empty initializer
    init() {}
}


// Protocol for any music recognition service
protocol MusicRecognizer {
    /// Identifies music from ambient sound.
    /// - Parameter seconds: The duration (in seconds) to record and analyze.
    /// - Returns: A `RecognizedTrack` object containing details of the identified song, or `nil` if no match.
    /// - Throws: An error if the recognition process fails (e.g., network issues, API errors).
    func identify(seconds: Int) async throws -> RecognizedTrack?

    /// Optional: Cancels any ongoing recognition task.
    func cancel()
}

// Add default implementation for cancel if not all recognizers need it.
extension MusicRecognizer {
    func cancel() {
        // Default implementation does nothing.
        print("Default cancel() called for \(type(of: self))")
    }
}

// Define a structure to hold ACRCloud credentials securely.
// Properties will be backed by Keychain.
struct ACRCreds {
    var host: String = ""
    var key: String = ""
    var secret: String = ""
    // TODO: Integrate KeychainAccess later in SettingsManager update.
}

// Enum for Music ID Providers - Moved here from SettingsManager for better domain organization
enum MusicIDProvider: String, Codable, CaseIterable, Identifiable {
    case audd = "AudD"
    case acrCloud = "ACRCloud"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .audd: return "AudD"
        case .acrCloud: return "ACRCloud"
        }
    }
} 