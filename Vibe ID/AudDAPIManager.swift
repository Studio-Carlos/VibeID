// Fichier: AudDAPIManager.swift
// (Version avec gestion de l'annulation)

import Foundation

// Erreur personnalisée pour les problèmes API AudD
enum AudDAPIError: Error, LocalizedError {
    case networkError(Error)
    case invalidResponse(statusCode: Int?)
    case apiError(message: String, code: Int?) // Utilise le statut ou message d'erreur d'AudD
    case fileEncodingError(Error)
    case dataConversionError
    case requestBodyCreationError(String)
    case jsonDecodingError(Error, data: Data? = nil) // Inclure les données pour le debug

    var errorDescription: String? {
        switch self {
        case .networkError(let underlyingError):
            // Masquer l'erreur d'annulation réseau qui est normale
            if (underlyingError as NSError).code == NSURLErrorCancelled {
                return "Requête API annulée."
            }
            return "Erreur réseau: \(underlyingError.localizedDescription)"
        case .invalidResponse(let statusCode):
            return "Réponse invalide du serveur AudD (Code: \(statusCode ?? 0))."
        case .apiError(let message, let code):
            let detailMessage = message.contains("status:") ? message : "Message API: \(message)"
            return "Erreur API AudD (\(code ?? 0)): \(detailMessage)"
        case .fileEncodingError(let underlyingError):
            return "Erreur de lecture du fichier audio: \(underlyingError.localizedDescription)"
        case .dataConversionError:
             return "Erreur de conversion des données."
        case .requestBodyCreationError(let step):
            return "Erreur de création du corps de la requête multipart (\(step))."
        case .jsonDecodingError(let underlyingError, _):
             return "Erreur de décodage JSON: \(underlyingError.localizedDescription)"
        }
    }
}

class AudDAPIManager {

    private let apiURL = URL(string: "https://api.audd.io/")!
    private let urlSession: URLSession
    // Stocker la tâche en cours pour pouvoir l'annuler
    private var currentTask: URLSessionDataTask?

    init(session: URLSession = .shared) {
        self.urlSession = session
    }

    /// Identifie un morceau à partir d'un fichier audio local.
    func recognize(audioFileURL: URL, apiKey: String, returnParams: String? = "apple_music,spotify", completion: @escaping (Result<AudDResult?, Error>) -> Void) {

        print("AudDAPIManager: Démarrage reconnaissance pour \(audioFileURL.lastPathComponent)")
        
        // Vérifier que le fichier existe
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            print("AudDAPIManager: ERREUR - Fichier audio introuvable: \(audioFileURL.path)")
            completion(.failure(AudDAPIError.fileEncodingError(NSError(domain: "AudDAPIManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Fichier audio introuvable"]))))
            return
        }

        // Annuler la tâche précédente si elle existe (sécurité)
        cancelCurrentRequest()

        // 1. Créer la requête et le corps multipart
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        print("AudDAPIManager: Préparation requête POST avec boundary: \(boundary)")

        do {
            print("AudDAPIManager: Création du corps multipart...")
            let bodyData = try createMultipartBody(
                apiKey: apiKey,
                returnParams: returnParams,
                fileURL: audioFileURL,
                boundary: boundary
            )
            request.httpBody = bodyData
            print("AudDAPIManager: Corps multipart créé (\(bodyData.count) octets)")
        } catch let error {
            print("AudDAPIManager: ERREUR création body: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        // 2. Créer et lancer la tâche réseau
        print("AudDAPIManager: Début requête réseau à \(apiURL.absoluteString)")
        let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            // Assurer de nettoyer la référence à la tâche quand elle se termine ou est annulée
             defer {
                 DispatchQueue.main.async { // Utiliser main queue si currentTask est accédé/modifié ailleurs
                      self?.currentTask = nil
                 }
             }

            // Vérifier erreur réseau basique (inclut l'annulation NSURLErrorCancelled)
            if let networkError = error {
                // Ne pas logguer l'erreur d'annulation comme une vraie erreur
                if (networkError as NSError).code != NSURLErrorCancelled {
                    print("AudDAPIManager: ERREUR réseau: \(networkError.localizedDescription)")
                } else {
                    print("AudDAPIManager: Requête réseau annulée.")
                }
                completion(.failure(AudDAPIError.networkError(networkError)))
                return
            }

            // Vérifier la réponse HTTP et le statut code
            guard let httpResponse = response as? HTTPURLResponse else {
                print("AudDAPIManager: ERREUR - Réponse non-HTTP reçue.")
                completion(.failure(AudDAPIError.invalidResponse(statusCode: nil)))
                return
            }
            
            print("AudDAPIManager: Réponse HTTP reçue avec statut: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("AudDAPIManager: ERREUR - Statut HTTP non-2xx: \(httpResponse.statusCode)")
                 if let errorData = data, let errorString = String(data: errorData, encoding: .utf8) {
                      print("AudDAPIManager: Corps de la réponse d'erreur: \(errorString)")
                 }
                completion(.failure(AudDAPIError.invalidResponse(statusCode: httpResponse.statusCode)))
                return
            }

            // Vérifier les données reçues
            guard let responseData = data else {
                print("AudDAPIManager: ERREUR - Aucune donnée reçue dans la réponse.")
                completion(.failure(AudDAPIError.invalidResponse(statusCode: httpResponse.statusCode)))
                return
            }
            
            print("AudDAPIManager: Données reçues (\(responseData.count) octets), décodage JSON...")

            // Décoder la réponse JSON
            do {
                let decoder = JSONDecoder()
                let audDResponse = try decoder.decode(AudDResponse.self, from: responseData)

                if audDResponse.status == "success" {
                    if audDResponse.result != nil {
                        print("AudDAPIManager: Succès API - Match trouvé!")
                        if let artist = audDResponse.result?.artist, let title = audDResponse.result?.title {
                            print("AudDAPIManager: Morceau identifié: \"\(title)\" par \(artist)")
                        }
                    } else {
                        print("AudDAPIManager: Succès API - Mais aucun match trouvé")
                    }
                    completion(.success(audDResponse.result))
                } else {
                    let errorMessage = audDResponse.status
                    print("AudDAPIManager: ERREUR API AudD: \(errorMessage)")
                    completion(.failure(AudDAPIError.apiError(message: errorMessage, code: nil)))
                }

            } catch let decodingError {
                print("AudDAPIManager: ERREUR décodage JSON: \(decodingError.localizedDescription)")
                if let jsonString = String(data: responseData, encoding: .utf8) { 
                    print("AudDAPIManager: JSON reçu (premier 500 caractères): \(String(jsonString.prefix(500)))...")
                }
                completion(.failure(AudDAPIError.jsonDecodingError(decodingError, data: responseData)))
            }
        } // Fin data task handler

        // Stocker la référence et lancer la tâche
        self.currentTask = task
        print("AudDAPIManager: Lancement de la requête...")
        task.resume()

    } // Fin func recognize

    /// Annule la requête réseau AudD en cours, si elle existe.
    func cancelCurrentRequest() {
        // Peut être appelé depuis n'importe quel thread, mais currentTask est géré sur main via defer
        print("AudDAPIManager: Demande d'annulation de la requête...")
        currentTask?.cancel()
        // Inutile de mettre à nil ici, le defer dans le handler s'en occupe
    }


    // --- Helper pour construire le corps multipart/form-data ---
    private func createMultipartBody(apiKey: String, returnParams: String?, fileURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        let boundaryPrefix = "--\(boundary)\(lineBreak)"

        // Champ api_token
        body.append(Data(boundaryPrefix.utf8))
        body.append(Data("Content-Disposition: form-data; name=\"api_token\"\(lineBreak + lineBreak)".utf8))
        body.append(Data(apiKey.utf8))
        body.append(Data(lineBreak.utf8))

        // Champ return (optionnel)
        if let returnParams = returnParams, !returnParams.isEmpty {
            body.append(Data(boundaryPrefix.utf8))
            body.append(Data("Content-Disposition: form-data; name=\"return\"\(lineBreak + lineBreak)".utf8))
            body.append(Data(returnParams.utf8))
            body.append(Data(lineBreak.utf8))
        }

        // Champ file
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
            print("Erreur lecture fichier audio: \(error)")
            throw AudDAPIError.fileEncodingError(error)
        }

        // Boundary de fin
        body.append(Data("--\(boundary)--\(lineBreak)".utf8))
        return body
    }

    // Fonction Helper pour MIME Type
    private func getMimeType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "wav": return "audio/wav"
        case "m4a": return "audio/mp4"
        case "mp3": return "audio/mpeg"
        default: return "application/octet-stream"
        }
    }

} // Fin classe AudDAPIManager
