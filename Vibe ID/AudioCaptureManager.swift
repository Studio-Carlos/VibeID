// Fichier: AudioCaptureManager.swift
// (Version Corrigée : Erreurs init / recordTimer / deinit)

import Foundation
import AVFoundation

// ... (Enum AudioCaptureError reste identique) ...
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
        case .audioEngineError(let reason): return "Erreur AVAudioEngine: \(reason)"
        case .audioSessionConfigError(let err): return "Erreur config AVAudioSession: \(err.localizedDescription)"
        case .fileCreationError(let err): return "Erreur création fichier audio: \(err?.localizedDescription ?? "Inconnue")"
        case .recordingFailed(let reason): return "Erreur pendant l'enregistrement: \(reason)"
        case .alreadyRecording: return "Enregistrement déjà en cours."
        case .measurementModeUnsupported: return "Mode Measurement non supporté."
        case .tapInstallationFailed: return "Échec installation tap audio."
        case .fileWriteError(let err): return "Erreur écriture fichier audio: \(err.localizedDescription)"
        case .outputURLMissing: return "URL fichier sortie manquante."
        case .recordingCancelled: return "Enregistrement annulé."
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
        print("AudioCaptureManager: Configuration AVAudioSession...")
        let session = AVAudioSession.sharedInstance()
        do {
            // Demander les permissions d'enregistrement (important pour iOS)
            try session.setCategory(.record, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Vérifier que l'app a la permission d'enregistrer
            switch session.recordPermission {
            case .granted:
                print("AudioCaptureManager: Permission d'enregistrement accordée")
            case .denied:
                print("AudioCaptureManager: ERREUR - Permission d'enregistrement refusée par l'utilisateur")
            case .undetermined:
                print("AudioCaptureManager: Permission d'enregistrement non déterminée, demande en cours...")
                // Demander la permission (sera affichée à l'utilisateur)
                session.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted {
                            print("AudioCaptureManager: Permission d'enregistrement accordée par l'utilisateur")
                        } else {
                            print("AudioCaptureManager: ERREUR - Permission d'enregistrement refusée par l'utilisateur")
                        }
                    }
                }
            @unknown default:
                print("AudioCaptureManager: ERREUR - État de permission d'enregistrement inconnu")
            }
            
            print("AudioCaptureManager: AVAudioSession configurée avec succès. Format d'entrée: \(session.inputDataSource?.description ?? "Inconnu")")
        } catch let error {
            print("AudioCaptureManager: ERREUR configuration AVAudioSession: \(error.localizedDescription)")
        }
    }

    private func configureTapFormat() {
         let inputNode = audioEngine.inputNode
         let hardwareFormat = inputNode.outputFormat(forBus: 0)
         guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
             print("AudioCaptureManager: ERREUR: Format hardware invalide détecté: \(hardwareFormat)")
             tapFormat = nil
             return
         }
         print("AudioCaptureManager: Format Hardware/Tap détecté = \(hardwareFormat)")
         tapFormat = hardwareFormat
    }

    /// Enregistre un court extrait audio dans un fichier temporaire.
    func recordSnippet(completion: @escaping (Result<URL, Error>) -> Void) {
        print("AudioCaptureManager: Démarrage recordSnippet...")
        
        guard !isRecording else {
            print("AudioCaptureManager: ERREUR - Déjà en enregistrement")
            completion(.failure(AudioCaptureError.alreadyRecording))
            return
        }
        guard let tapFormat = self.tapFormat else {
             print("AudioCaptureManager: ERREUR - Format de tap invalide ou nil")
             completion(.failure(AudioCaptureError.audioEngineError("Format de tap invalide")))
             return
        }

        recordingCompletionHandler = completion // Stocker le nouveau handler
        outputFileURL = nil // S'assurer que l'URL est nulle au début
        isRecording = true
        print("AudioCaptureManager: Début enregistrement snippet (\(snippetDuration)s)...")

        // Activer session audio
        do { 
            try AVAudioSession.sharedInstance().setActive(true)
            print("AudioCaptureManager: Session audio activée") 
        } catch {
            print("AudioCaptureManager: ERREUR activation session audio: \(error.localizedDescription)")
            cleanupRecording(error: AudioCaptureError.audioSessionConfigError(error))
            return
        }

        // Définir URL et format sortie
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording-\(UUID().uuidString).m4a"
        let currentOutputURL = tempDir.appendingPathComponent(fileName)
        self.outputFileURL = currentOutputURL // Stocker

        print("AudioCaptureManager: Fichier de sortie: \(currentOutputURL.path)")
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: tapFormat.sampleRate,
            AVNumberOfChannelsKey: tapFormat.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        print("AudioCaptureManager: Format d'enregistrement - Fréquence: \(tapFormat.sampleRate)Hz, Canaux: \(tapFormat.channelCount)")

        // Créer AVAudioFile
        do {
            audioFile = try AVAudioFile(forWriting: currentOutputURL, settings: outputSettings, commonFormat: tapFormat.commonFormat, interleaved: tapFormat.isInterleaved)
            print("AudioCaptureManager: Fichier audio créé")
        } catch let error {
            print("AudioCaptureManager: ERREUR création fichier audio: \(error.localizedDescription)")
            cleanupRecording(error: AudioCaptureError.fileCreationError(error))
            return
        }

        // Installer Tap
        print("AudioCaptureManager: Installation du tap sur inputNode...")
        let inputNode = audioEngine.inputNode
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, time in
            guard let self = self, let audioFile = self.audioFile, self.isRecording else { return }
            do { 
                try audioFile.write(from: buffer)
            } catch let error {
                 DispatchQueue.main.async {
                     print("AudioCaptureManager: ERREUR ÉCRITURE AUDIO FILE: \(error.localizedDescription)")
                     self.cleanupRecording(error: AudioCaptureError.fileWriteError(error))
                 }
            }
        }
        print("AudioCaptureManager: Tap installé avec succès")

        // Préparer et démarrer moteur
        do {
            if audioEngine.isRunning { 
                print("AudioCaptureManager: Arrêt du moteur audio précédent")
                audioEngine.stop() 
            }
            
            print("AudioCaptureManager: Préparation du moteur audio...")
            audioEngine.prepare()
            
            print("AudioCaptureManager: Démarrage du moteur audio...")
            try audioEngine.start()
            print("AudioCaptureManager: Audio Engine démarré avec succès.")

            // Planifier l'arrêt
            let workItem = DispatchWorkItem { [weak self] in
                 if self?.isRecording == true {
                      print("AudioCaptureManager: Durée d'enregistrement atteinte.")
                      self?.stopRecordingAndComplete()
                 } else {
                      print("AudioCaptureManager: WorkItem exécuté mais enregistrement déjà arrêté/annulé.")
                 }
            }
            stopWorkItem = workItem
            print("AudioCaptureManager: Planification de l'arrêt dans \(snippetDuration) secondes")
            DispatchQueue.main.asyncAfter(deadline: .now() + snippetDuration, execute: workItem)

        } catch let error {
            print("AudioCaptureManager: ERREUR démarrage moteur audio: \(error.localizedDescription)")
            cleanupRecording(error: AudioCaptureError.audioEngineError(error.localizedDescription))
            return
        }
    } // Fin func recordSnippet

    /// Arrête l'enregistrement normalement (appelé par le DispatchWorkItem)
    private func stopRecordingAndComplete() {
        guard isRecording else { return }
        print("AudioCaptureManager: Arrêt normal de l'enregistrement...")

        let completion = recordingCompletionHandler
        recordingCompletionHandler = nil
        stopWorkItem = nil

        cleanupInternalState() // Nettoyer moteur/tap/fichier/état

        if let url = self.outputFileURL {
             print("AudioCaptureManager: Enregistrement terminé succès: \(url.lastPathComponent)")
             completion?(.success(url))
        } else {
             print("AudioCaptureManager: Enregistrement terminé mais URL sortie manquante?")
             completion?(.failure(AudioCaptureError.outputURLMissing))
        }
        self.outputFileURL = nil
         try? AVAudioSession.sharedInstance().setActive(false)
    }

    /// Annule l'enregistrement en cours (appelé par le ViewModel)
    func cancelRecording() {
        guard isRecording else { return }
        print("AudioCaptureManager: Demande d'annulation de l'enregistrement...")

        stopWorkItem?.cancel()
        stopWorkItem = nil

        let completion = recordingCompletionHandler
        recordingCompletionHandler = nil

        cleanupInternalState() // Nettoyer moteur/tap/fichier/état

        completion?(.failure(AudioCaptureError.recordingCancelled))

        if let url = self.outputFileURL {
            print("AudioCaptureManager: Nettoyage fichier annulé: \(url.lastPathComponent)")
            try? FileManager.default.removeItem(at: url)
            self.outputFileURL = nil
        }
         try? AVAudioSession.sharedInstance().setActive(false)
    }


    /// Arrête moteur, enlève tap, ferme fichier, remet isRecording à false.
    private func cleanupInternalState() {
        print("AudioCaptureManager: Nettoyage état interne (moteur/tap/fichier)...")
        // --- SUPPRESSION des lignes recordTimer ---
        // recordTimer?.invalidate()
        // recordTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioFile = nil
        print("AudioCaptureManager: Fichier audio nil (fermé).")

        if isRecording {
            isRecording = false
        }
    } // Fin func cleanupInternalState

    /// Fonction de nettoyage appelée suite à une ERREUR pendant l'enregistrement.
    private func cleanupRecording(error: Error?) {
        print("AudioCaptureManager: Nettoyage suite à une erreur...")

        stopWorkItem?.cancel()
        stopWorkItem = nil

        let completion = recordingCompletionHandler
        recordingCompletionHandler = nil

        cleanupInternalState() // Nettoyer moteur/tap/fichier/état

        if let error = error {
            print("AudioCaptureManager: Nettoyage dû à l'erreur: \(error.localizedDescription)")
            completion?(.failure(error))
        }

        if let url = self.outputFileURL {
             print("AudioCaptureManager: Nettoyage fichier suite à erreur: \(url.lastPathComponent)")
             try? FileManager.default.removeItem(at: url)
             self.outputFileURL = nil
        }
         try? AVAudioSession.sharedInstance().setActive(false)
    } // Fin func cleanupRecording


    deinit {
        print("AudioCaptureManager deinit (ne fait plus cleanup automatiquement)")
        // --- SUPPRESSION de l'appel cleanupInternalState() ici ---
        // cleanupInternalState()
    }

} // Fin classe AudioCaptureManager
