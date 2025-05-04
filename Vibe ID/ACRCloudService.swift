// ACRCloudService.swift
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

// Custom Error type for ACRCloudService
enum ACRCloudServiceError: Error, LocalizedError {
    case initializationFailed(String)
    case recognitionTimeout
    case apiError(message: String)
    case resultParsingError
    case recordingFailed(Error?)
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .initializationFailed(let reason):
            return "ACRCloud client initialization failed: \(reason)"
        case .recognitionTimeout:
            return "ACRCloud recognition timed out."
        case .apiError(let message):
            return "ACRCloud API Error: \(message)" // ACRCloud often puts errors in the result JSON
        case .resultParsingError:
            return "Failed to parse ACRCloud result JSON."
        case .recordingFailed(let underlyingError):
            return "Audio recording failed: \(underlyingError?.localizedDescription ?? "Unknown error")"
        case .missingCredentials:
             return "ACRCloud credentials (host, key, secret) are missing."
        }
    }
}

final class ACRCloudService: NSObject, MusicRecognizer {
    private var client: ACRCloudRecognition?
    private var config: ACRCloudConfig?
    private var recognitionContinuation: CheckedContinuation<RecognizedTrack?, Error>?
    private var stateLabel: String = "Idle" // For debugging

    init?(creds: ACRCreds) {
        super.init()
        
        // Validate credentials before initializing
        guard !creds.host.isEmpty, !creds.key.isEmpty, !creds.secret.isEmpty else {
             print("ACRCloudService ERROR: Credentials missing.")
             // We return nil to indicate initialization failure due to missing creds
             // The calling code (factory) should handle this.
             return nil
        }

        let cfg = ACRCloudConfig()
        cfg.accessKey = creds.key
        cfg.accessSecret = creds.secret
        cfg.host = creds.host
        cfg.protocol = "https" // Ensure HTTPS
        cfg.recMode = rec_mode_remote // Use remote recognition
        // Required even if empty:
        cfg.stateBlock = { [weak self] state in
            // This block is called with status updates from the SDK.
            // Useful for debugging or showing state changes in the UI.
            DispatchQueue.main.async {
                 self?.stateLabel = String(describing: state ?? "unknown")
                 print("ACRCloud State: \(self?.stateLabel ?? "unknown")")
                 // Check for specific error states if documented by ACRCloud
                 if let stateStr = self?.stateLabel, stateStr.contains("error") || stateStr.contains("failed") {
                     // Potentially handle specific SDK state errors here
                     // For example, if state indicates network issues, maybe fail the continuation?
                 }
            }
        }

        cfg.resultBlock = { [weak self] result, resType in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                print("ACRCloud Result Block: Received result.")
                // Ensure we have an active continuation
                guard let continuation = self.recognitionContinuation else {
                     print("ACRCloud Result Block: No active continuation. Ignoring result.")
                     return
                 }
                 
                 // Clear the continuation to prevent resuming multiple times
                 self.recognitionContinuation = nil
                 
                 // Check if the JSON result string is present
                 guard let jsonString = result else {
                     print("ACRCloud Result Block: Error - JSON result string is nil.")
                     continuation.resume(throwing: ACRCloudServiceError.resultParsingError)
                     return
                 }
                 
                 print("ACRCloud Result Block: Received JSON (length: \(jsonString.count))")
                 // For debugging: print first few characters
                 // print("ACRCloud JSON Preview: \(String(jsonString.prefix(300)))")
                 
                 // Parse the JSON and create RecognizedTrack
                 do {
                     let track = try self.parseACRCloudResponse(jsonString: jsonString)
                     if track.title != nil || track.artist != nil {
                        print("ACRCloud Result Block: Success - Parsed track: \(track.artist ?? "?") - \(track.title ?? "?")")
                     } else {
                         print("ACRCloud Result Block: Success - Parsed response, but no music match found.")
                     }
                     continuation.resume(returning: track)
                 } catch let parsingError {
                     print("ACRCloud Result Block: Error - Failed to parse JSON: \(parsingError.localizedDescription)")
                     continuation.resume(throwing: parsingError)
                 }
            }
        }
        
        // Keep config reference
        self.config = cfg
        
        // Initialize the recognition client
        self.client = ACRCloudRecognition(config: cfg)
        print("ACRCloudService: Initialized successfully.")
    }

    // MARK: - MusicRecognizer Protocol Implementation

    func identify(seconds: Int = 12) async throws -> RecognizedTrack? {
         guard let client = self.client else {
             print("ACRCloudService: ERROR - Client not initialized.")
             throw ACRCloudServiceError.initializationFailed("Client is nil")
         }
         
         // Ensure no other recognition is in progress
         guard recognitionContinuation == nil else {
             print("ACRCloudService: Recognition already in progress. Ignoring new request.")
             // Or throw an error? Depending on desired behavior.
             throw ACRCloudServiceError.apiError(message: "Recognition already in progress")
         }

         print("ACRCloudService: Starting recognition for \(seconds) seconds...")
         
         return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RecognizedTrack?, Error>) in
             // Store the continuation
             self.recognitionContinuation = continuation

             // Start recording & recognition process
             // startPreRecord: millseconds for pre-recording buffer.
             // startRecordRec: Starts the main recording and recognition cycle.
             DispatchQueue.main.async { // Ensure SDK calls happen on main thread if required
                 client.startPreRecord(3000) // 3 seconds pre-record buffer
                 // startRecordRec() is expected to run until stopRecordRec() is called
                 // The result will arrive asynchronously via the resultBlock
                 client.startRecordRec() // We don't check the return value as it appears to be Void
                 print("ACRCloudService: Recording started...")
             }

             // Schedule stop after the requested duration
             // Use a Task to schedule the stop, allowing cancellation if needed.
             _ = Task { 
                 try await Task.sleep(for: .seconds(seconds))
                 // Check if the continuation is still valid (i.e., hasn't been resumed by result/error)
                 if self.recognitionContinuation != nil {
                     print("ACRCloudService: \(seconds)s elapsed. Stopping recording...")
                     DispatchQueue.main.async { // Ensure SDK calls happen on main thread if required
                         client.stopRecordRec()
                         print("ACRCloudService: stopRecordRec() called.")
                         // Note: The result might still arrive shortly after stopRecordRec via the resultBlock.
                         // We don't immediately throw a timeout here, we let the resultBlock handle it
                         // or potentially add another failsafe timer if the resultBlock never fires.
                     }
                 }
             }

             // Optional: Add a safety timeout slightly longer than the recording duration
             // This handles cases where the resultBlock *never* gets called after stopping.
             _ = Task { 
                try await Task.sleep(for: .seconds(seconds + 5)) // e.g., 5s grace period
                // Check if the continuation is *still* valid (resultBlock didn't fire)
                if let timeoutContinuation = self.recognitionContinuation {
                    print("ACRCloudService: ERROR - Safety timeout reached. No result received.")
                    self.recognitionContinuation = nil // Clean up
                    timeoutContinuation.resume(throwing: ACRCloudServiceError.recognitionTimeout)
                    DispatchQueue.main.async { client.stopRecordRec() } // Ensure stop is called
                }
             }
         }
     }

    func cancel() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("ACRCloudService: cancel() called.")
            self.client?.stopRecordRec() // Stop any ongoing recording
            
            // If there's a pending continuation, resume it with a cancellation error
            if let continuation = self.recognitionContinuation {
                 print("ACRCloudService: Resuming continuation with cancellation error.")
                 self.recognitionContinuation = nil
                 continuation.resume(throwing: CancellationError())
             }
            // TODO: Cancel any associated Tasks (stopTask, safetyTimeoutTask) explicitly if needed.
        }
    }

    deinit {
        print("ACRCloudService: Deinitializing.")
        // Ensure client resources are released if necessary
        // The SDK documentation should specify if explicit cleanup is needed.
        client?.stopRecordRec() // Good practice to stop recording on deinit
    }
    
    // MARK: - Response Parsing
    
    private func parseACRCloudResponse(jsonString: String) throws -> RecognizedTrack {
        guard let data = jsonString.data(using: .utf8) else {
            print("ACRCloudService: Failed to convert JSON string to Data.")
            throw ACRCloudServiceError.resultParsingError
        }
        
        do {
            // Decode the main response structure
            let decoder = JSONDecoder()
            let response = try decoder.decode(ACRCloudResponse.self, from: data)
            
            // Use the new initializer in RecognizedTrack extension to map the data
            let track = try RecognizedTrack(acrResponse: response, rawJson: jsonString)
            return track
            
        } catch let error {
            print("ACRCloudService: JSON Decoding/Parsing Error: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                 print("ACRCloudService: Decoding Error Details: \(decodingError)")
            }
            // If it's already an ACRCloudServiceError from the initializer, rethrow it
            if let acrError = error as? ACRCloudServiceError {
                throw acrError
            } else {
                // Otherwise, wrap it as a parsing error
                throw ACRCloudServiceError.resultParsingError
            }
        }
    }
    
} // End of ACRCloudService class 
