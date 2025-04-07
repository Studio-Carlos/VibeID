// AudioCaptureManager.swift
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
import AVFoundation
import AVFAudio
import Accelerate

// Possible errors during audio capture
enum AudioCaptureError: Error, LocalizedError {
    case audioEngineError(String)
    case audioSessionConfigError(Error)
    case fileCreationError(Error?)
    case recordingFailed(String)
    case alreadyRecording
    case measurementModeUnsupported
    case tapInstallationFailed
    case fileWriteError(Error)
    case outputURLMissing
    case recordingCancelled

    var errorDescription: String? {
        switch self {
        case .audioEngineError(let reason): return "AVAudioEngine error: \(reason)"
        case .audioSessionConfigError(let err): return "AVAudioSession config error: \(err.localizedDescription)"
        case .fileCreationError(let err): return "Audio file creation error: \(err?.localizedDescription ?? "Unknown")"
        case .recordingFailed(let reason): return "Error during recording: \(reason)"
        case .alreadyRecording: return "Recording already in progress."
        case .measurementModeUnsupported: return "Measurement mode not supported."
        case .tapInstallationFailed: return "Failed to install audio tap."
        case .fileWriteError(let err): return "Audio file write error: \(err.localizedDescription)"
        case .outputURLMissing: return "Output file URL missing."
        case .recordingCancelled: return "Recording cancelled."
        }
    }
}

@MainActor
class AudioCaptureManager: ObservableObject {

    private let audioEngine = AVAudioEngine()
    private var outputFileURL: URL?
    private var audioFile: AVAudioFile?
    private let snippetDuration: TimeInterval = 7.0
    @Published private(set) var isRecording = false
    private var tapFormat: AVAudioFormat?
    private var recordingCompletionHandler: ((Result<URL, Error>) -> Void)?
    private var stopWorkItem: DispatchWorkItem?

    init() {
        setupAudioSession()
        configureTapFormat()
    }

    private func setupAudioSession() {
        print("AudioCaptureManager: Configuring AVAudioSession...")
        let session = AVAudioSession.sharedInstance()
        do {
            // Request recording permissions (important for iOS)
            try session.setCategory(.record, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Check if the app has permission to record
            // Use AVAudioApplication for iOS 17+ and AVAudioSession for earlier versions
            if #available(iOS 17.0, *) {
                switch AVAudioApplication.shared.recordPermission {
                case .granted:
                    print("AudioCaptureManager: Recording permission granted")
                case .denied:
                    print("AudioCaptureManager: ERROR - Recording permission denied by user")
                case .undetermined:
                    print("AudioCaptureManager: Recording permission not determined, requesting...")
                    // Request permission (will be displayed to user)
                    AVAudioApplication.requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            if granted {
                                print("AudioCaptureManager: Recording permission granted by user")
                            } else {
                                print("AudioCaptureManager: ERROR - Recording permission denied by user")
                            }
                        }
                    }
                @unknown default:
                    print("AudioCaptureManager: ERROR - Unknown recording permission state")
                }
            } else {
                // For iOS versions prior to 17.0
                switch session.recordPermission {
                case .granted:
                    print("AudioCaptureManager: Recording permission granted")
                case .denied:
                    print("AudioCaptureManager: ERROR - Recording permission denied by user")
                case .undetermined:
                    print("AudioCaptureManager: Recording permission not determined, requesting...")
                    // Request permission (will be displayed to user)
                    session.requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            if granted {
                                print("AudioCaptureManager: Recording permission granted by user")
                            } else {
                                print("AudioCaptureManager: ERROR - Recording permission denied by user")
                            }
                        }
                    }
                @unknown default:
                    print("AudioCaptureManager: ERROR - Unknown recording permission state")
                }
            }
            
            print("AudioCaptureManager: AVAudioSession configured successfully. Input format: \(session.inputDataSource?.description ?? "Unknown")")
        } catch let error {
            print("AudioCaptureManager: ERROR configuring AVAudioSession: \(error.localizedDescription)")
        }
    }

    private func configureTapFormat() {
         let inputNode = audioEngine.inputNode
         let hardwareFormat = inputNode.outputFormat(forBus: 0)
         guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
             print("AudioCaptureManager: ERROR: Invalid hardware format detected: \(hardwareFormat)")
             tapFormat = nil
             return
         }
         print("AudioCaptureManager: Hardware/Tap Format detected = \(hardwareFormat)")
         tapFormat = hardwareFormat
    }

    /// Records a short audio snippet to a temporary file.
    func recordSnippet(completion: @escaping (Result<URL, Error>) -> Void) {
        print("AudioCaptureManager: Starting recordSnippet...")
        
        guard !isRecording else {
            print("AudioCaptureManager: ERROR - Already recording")
            completion(.failure(AudioCaptureError.alreadyRecording))
            return
        }
        guard let tapFormat = self.tapFormat else {
             print("AudioCaptureManager: ERROR - Invalid or nil tap format")
             completion(.failure(AudioCaptureError.audioEngineError("Invalid tap format")))
             return
        }

        recordingCompletionHandler = completion // Store the new handler
        outputFileURL = nil // Ensure URL is nil at the start
        isRecording = true
        print("AudioCaptureManager: Beginning snippet recording (\(snippetDuration)s)...")

        // Activate audio session
        do { 
            try AVAudioSession.sharedInstance().setActive(true)
            print("AudioCaptureManager: Audio session activated") 
        } catch {
            print("AudioCaptureManager: ERROR activating audio session: \(error.localizedDescription)")
            cleanupRecording(error: AudioCaptureError.audioSessionConfigError(error))
            return
        }

        // Set output URL and format
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording-\(UUID().uuidString).m4a"
        let currentOutputURL = tempDir.appendingPathComponent(fileName)
        self.outputFileURL = currentOutputURL // Store

        print("AudioCaptureManager: Output file: \(currentOutputURL.path)")
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: tapFormat.sampleRate,
            AVNumberOfChannelsKey: tapFormat.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        print("AudioCaptureManager: Recording format - Sample Rate: \(tapFormat.sampleRate)Hz, Channels: \(tapFormat.channelCount)")

        // Create AVAudioFile
        do {
            audioFile = try AVAudioFile(forWriting: currentOutputURL, settings: outputSettings, commonFormat: tapFormat.commonFormat, interleaved: tapFormat.isInterleaved)
            print("AudioCaptureManager: Audio file created")
        } catch let error {
            print("AudioCaptureManager: ERROR creating audio file: \(error.localizedDescription)")
            cleanupRecording(error: AudioCaptureError.fileCreationError(error))
            return
        }

        // Install Tap
        print("AudioCaptureManager: Installing tap on inputNode...")
        let inputNode = audioEngine.inputNode
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, time in
            guard let self = self, let audioFile = self.audioFile, self.isRecording else { return }
            do { 
                try audioFile.write(from: buffer)
            } catch let error {
                 DispatchQueue.main.async {
                     print("AudioCaptureManager: AUDIO FILE WRITE ERROR: \(error.localizedDescription)")
                     self.cleanupRecording(error: AudioCaptureError.fileWriteError(error))
                 }
            }
        }
        print("AudioCaptureManager: Tap installed successfully")

        // Prepare and start engine
        do {
            if audioEngine.isRunning { 
                print("AudioCaptureManager: Stopping previous audio engine")
                audioEngine.stop() 
            }
            
            print("AudioCaptureManager: Preparing audio engine...")
            audioEngine.prepare()
            
            print("AudioCaptureManager: Starting audio engine...")
            try audioEngine.start()
            print("AudioCaptureManager: Audio Engine started successfully.")

            // Schedule stop
            let workItem = DispatchWorkItem { [weak self] in
                 if self?.isRecording == true {
                      print("AudioCaptureManager: Recording duration reached.")
                      self?.stopRecordingAndComplete()
                 } else {
                      print("AudioCaptureManager: WorkItem executed but recording already stopped/cancelled.")
                 }
            }
            stopWorkItem = workItem
            print("AudioCaptureManager: Scheduling stop in \(snippetDuration) seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + snippetDuration, execute: workItem)

        } catch let error {
            print("AudioCaptureManager: ERROR starting audio engine: \(error.localizedDescription)")
            cleanupRecording(error: AudioCaptureError.audioEngineError(error.localizedDescription))
            return
        }
    } // End func recordSnippet

    /// Stops recording normally (called by DispatchWorkItem)
    private func stopRecordingAndComplete() {
        guard isRecording else { return }
        print("AudioCaptureManager: Normal recording stop...")

        let completion = recordingCompletionHandler
        recordingCompletionHandler = nil
        stopWorkItem = nil

        cleanupInternalState() // Clean engine/tap/file/state

        if let url = self.outputFileURL {
             print("AudioCaptureManager: Recording successfully completed: \(url.lastPathComponent)")
             completion?(.success(url))
        } else {
             print("AudioCaptureManager: Recording completed but output URL missing?")
             completion?(.failure(AudioCaptureError.outputURLMissing))
        }
        self.outputFileURL = nil
         try? AVAudioSession.sharedInstance().setActive(false)
    }

    /// Cancels the ongoing recording (called by the ViewModel)
    func cancelRecording() {
        guard isRecording else { return }
        print("AudioCaptureManager: Recording cancellation requested...")

        stopWorkItem?.cancel()
        stopWorkItem = nil

        let completion = recordingCompletionHandler
        recordingCompletionHandler = nil

        cleanupInternalState() // Clean engine/tap/file/state

        completion?(.failure(AudioCaptureError.recordingCancelled))

        if let url = self.outputFileURL {
            print("AudioCaptureManager: Cleaning up cancelled file: \(url.lastPathComponent)")
            try? FileManager.default.removeItem(at: url)
            self.outputFileURL = nil
        }
         try? AVAudioSession.sharedInstance().setActive(false)
    }


    /// Stops engine, removes tap, closes file, resets isRecording to false.
    private func cleanupInternalState() {
        print("AudioCaptureManager: Cleaning up internal state (engine/tap/file)...")
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioFile = nil
        print("AudioCaptureManager: Audio file nil (closed).")

        if isRecording {
            isRecording = false
        }
    } // End func cleanupInternalState

    /// Cleanup function called after an ERROR during recording.
    private func cleanupRecording(error: Error?) {
        print("AudioCaptureManager: Cleanup after an error...")

        stopWorkItem?.cancel()
        stopWorkItem = nil

        let completion = recordingCompletionHandler
        recordingCompletionHandler = nil

        cleanupInternalState() // Clean engine/tap/file/state

        if let error = error {
            print("AudioCaptureManager: Cleanup due to error: \(error.localizedDescription)")
            completion?(.failure(error))
        }

        if let url = self.outputFileURL {
             print("AudioCaptureManager: Cleaning up file after error: \(url.lastPathComponent)")
             try? FileManager.default.removeItem(at: url)
             self.outputFileURL = nil
        }
         try? AVAudioSession.sharedInstance().setActive(false)
    } // End func cleanupRecording


    deinit {
        print("AudioCaptureManager deinit (no longer performs automatic cleanup)")
    }

} // End of AudioCaptureManager class
