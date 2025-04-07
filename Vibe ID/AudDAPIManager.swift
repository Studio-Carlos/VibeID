// AudDAPIManager.swift
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

// Custom error for AudD API issues
enum AudDAPIError: Error, LocalizedError {
    case networkError(Error)
    case invalidResponse(statusCode: Int?)
    case apiError(message: String, code: Int?) // Uses AudD's error status or message
    case fileEncodingError(Error)
    case dataConversionError
    case requestBodyCreationError(String)
    case jsonDecodingError(Error, data: Data? = nil) // Include data for debugging

    var errorDescription: String? {
        switch self {
        case .networkError(let underlyingError):
            // Hide cancellation network error which is normal
            if (underlyingError as NSError).code == NSURLErrorCancelled {
                return "API request cancelled."
            }
            return "Network error: \(underlyingError.localizedDescription)"
        case .invalidResponse(let statusCode):
            return "Invalid response from AudD server (Code: \(statusCode ?? 0))."
        case .apiError(let message, let code):
            let detailMessage = message.contains("status:") ? message : "API Message: \(message)"
            return "AudD API Error (\(code ?? 0)): \(detailMessage)"
        case .fileEncodingError(let underlyingError):
            return "Error reading audio file: \(underlyingError.localizedDescription)"
        case .dataConversionError:
             return "Data conversion error."
        case .requestBodyCreationError(let step):
            return "Error creating multipart request body (\(step))."
        case .jsonDecodingError(let underlyingError, _):
             return "JSON decoding error: \(underlyingError.localizedDescription)"
        }
    }
}

class AudDAPIManager {

    private let apiURL = URL(string: "https://api.audd.io/")!
    private let urlSession: URLSession
    // Store current task to be able to cancel it
    private var currentTask: URLSessionDataTask?

    init(session: URLSession = .shared) {
        self.urlSession = session
    }

    /// Identifies a song from a local audio file.
    func recognize(audioFileURL: URL, apiKey: String, returnParams: String? = "apple_music,spotify", completion: @escaping (Result<AudDResult?, Error>) -> Void) {

        print("AudDAPIManager: Starting recognition for \(audioFileURL.lastPathComponent)")
        
        // Check that the file exists
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            print("AudDAPIManager: ERROR - Audio file not found: \(audioFileURL.path)")
            completion(.failure(AudDAPIError.fileEncodingError(NSError(domain: "AudDAPIManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Audio file not found"]))))
            return
        }

        // Cancel previous task if it exists (safety)
        cancelCurrentRequest()

        // 1. Create request and multipart body
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        print("AudDAPIManager: Preparing POST request with boundary: \(boundary)")

        do {
            print("AudDAPIManager: Creating multipart body...")
            let bodyData = try createMultipartBody(
                apiKey: apiKey,
                returnParams: returnParams,
                fileURL: audioFileURL,
                boundary: boundary
            )
            request.httpBody = bodyData
            print("AudDAPIManager: Multipart body created (\(bodyData.count) bytes)")
        } catch let error {
            print("AudDAPIManager: ERROR creating body: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        // 2. Create and launch network task
        print("AudDAPIManager: Starting network request to \(apiURL.absoluteString)")
        let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            // Make sure to clean up the task reference when it completes or is cancelled
             defer {
                 DispatchQueue.main.async { // Use main queue if currentTask is accessed/modified elsewhere
                      self?.currentTask = nil
                 }
             }

            // Check basic network error (includes cancellation NSURLErrorCancelled)
            if let networkError = error {
                // Don't log cancellation error as a real error
                if (networkError as NSError).code != NSURLErrorCancelled {
                    print("AudDAPIManager: NETWORK ERROR: \(networkError.localizedDescription)")
                } else {
                    print("AudDAPIManager: Network request cancelled.")
                }
                completion(.failure(AudDAPIError.networkError(networkError)))
                return
            }

            // Check HTTP response and status code
            guard let httpResponse = response as? HTTPURLResponse else {
                print("AudDAPIManager: ERROR - Non-HTTP response received.")
                completion(.failure(AudDAPIError.invalidResponse(statusCode: nil)))
                return
            }
            
            print("AudDAPIManager: HTTP response received with status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("AudDAPIManager: ERROR - Non-2xx HTTP status: \(httpResponse.statusCode)")
                 if let errorData = data, let errorString = String(data: errorData, encoding: .utf8) {
                      print("AudDAPIManager: Error response body: \(errorString)")
                 }
                completion(.failure(AudDAPIError.invalidResponse(statusCode: httpResponse.statusCode)))
                return
            }

            // Check received data
            guard let responseData = data else {
                print("AudDAPIManager: ERROR - No data received in response.")
                completion(.failure(AudDAPIError.invalidResponse(statusCode: httpResponse.statusCode)))
                return
            }
            
            print("AudDAPIManager: Data received (\(responseData.count) bytes), decoding JSON...")

            // Decode JSON response
            do {
                let decoder = JSONDecoder()
                let audDResponse = try decoder.decode(AudDResponse.self, from: responseData)

                if audDResponse.status == "success" {
                    if audDResponse.result != nil {
                        print("AudDAPIManager: API Success - Match found!")
                        if let artist = audDResponse.result?.artist, let title = audDResponse.result?.title {
                            print("AudDAPIManager: Song identified: \"\(title)\" by \(artist)")
                        }
                    } else {
                        print("AudDAPIManager: API Success - But no match found")
                    }
                    completion(.success(audDResponse.result))
                } else {
                    let errorMessage = audDResponse.status
                    print("AudDAPIManager: AudD API ERROR: \(errorMessage)")
                    completion(.failure(AudDAPIError.apiError(message: errorMessage, code: nil)))
                }

            } catch let decodingError {
                print("AudDAPIManager: JSON DECODING ERROR: \(decodingError.localizedDescription)")
                if let jsonString = String(data: responseData, encoding: .utf8) { 
                    print("AudDAPIManager: Received JSON (first 500 characters): \(String(jsonString.prefix(500)))...")
                }
                completion(.failure(AudDAPIError.jsonDecodingError(decodingError, data: responseData)))
            }
        } // End data task handler

        // Store reference and launch task
        self.currentTask = task
        print("AudDAPIManager: Launching request...")
        task.resume()

    } // End func recognize

    /// Cancels the current AudD network request, if it exists.
    func cancelCurrentRequest() {
        // Can be called from any thread, but currentTask is managed on main via defer
        print("AudDAPIManager: Request cancellation requested...")
        currentTask?.cancel()
        // No need to set to nil here, the defer in the handler takes care of it
    }


    // --- Helper to build multipart/form-data body ---
    private func createMultipartBody(apiKey: String, returnParams: String?, fileURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        let boundaryPrefix = "--\(boundary)\(lineBreak)"

        // api_token field
        body.append(Data(boundaryPrefix.utf8))
        body.append(Data("Content-Disposition: form-data; name=\"api_token\"\(lineBreak + lineBreak)".utf8))
        body.append(Data(apiKey.utf8))
        body.append(Data(lineBreak.utf8))

        // return field (optional)
        if let returnParams = returnParams, !returnParams.isEmpty {
            body.append(Data(boundaryPrefix.utf8))
            body.append(Data("Content-Disposition: form-data; name=\"return\"\(lineBreak + lineBreak)".utf8))
            body.append(Data(returnParams.utf8))
            body.append(Data(lineBreak.utf8))
        }

        // file field
        let filename = fileURL.lastPathComponent
        let mimeType = getMimeType(for: fileURL)
        do {
            let fileData = try Data(contentsOf: fileURL)
            body.append(Data(boundaryPrefix.utf8))
            body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(lineBreak)".utf8))
            body.append(Data("Content-Type: \(mimeType)\(lineBreak + lineBreak)".utf8))
            body.append(fileData)
            body.append(Data(lineBreak.utf8))
        } catch let error {
            print("Error reading audio file: \(error)")
            throw AudDAPIError.fileEncodingError(error)
        }

        // End boundary
        body.append(Data("--\(boundary)--\(lineBreak)".utf8))
        return body
    }

    // Helper function for MIME Type
    private func getMimeType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "wav": return "audio/wav"
        case "m4a": return "audio/mp4"
        case "mp3": return "audio/mpeg"
        default: return "application/octet-stream"
        }
    }

} // End of AudDAPIManager class
