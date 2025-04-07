# Vibe ID

**Vibe ID** is an iOS application that identifies the music you're listening to and sends identification data via OSC (Open Sound Control) to other software like TouchDesigner, MaxMSP, or Chataigne.

## Features

- Audio identification every X minutes via the [AudD](https://audd.io/) API
- Sending musical identification data via OSC
- Simple and intuitive user interface
- Customizable recognition interval configuration
- History of identified tracks
- Manual prompt functionality for free expression
- Network diagnostics for OSC connection

## Requirements

- iOS 14.0+
- Xcode 13.0+
- An [AudD](https://dashboard.audd.io/) API key
- A device or software that can receive OSC messages

## Installation

1. Clone this repository
2. Open `Vibe ID.xcodeproj` in Xcode
3. Compile and run on your iOS device

## Configuration

1. Open the application and go to Settings
2. Enter your AudD API key
3. Configure the OSC host and destination port
4. Adjust the recognition frequency according to your needs

## OSC Message Format

The application sends the following information via OSC:

- `/vibeid/track/title` (string): Track title
- `/vibeid/track/artist` (string): Artist name
- `/vibeid/track/genre` (string): Musical genre
- `/vibeid/track/bpm` (float): BPM of the track (if available)
- `/vibeid/track/energy` (float): Energy of the track (if available)
- `/vibeid/track/danceability` (float): Danceability of the track (if available)
- `/vibeid/track/artwork` (string): Artwork URL
- `/vibeid/status` (string): Application status ("listening", "recognizing", "identified", "no_match", "error", "stopped")
- `/vibeid/prompt` (string): Manual prompts entered by the user
- `/vibeid/test` (string): Test messages ("ping")

## License

This project is licensed under the [GNU GPLv3](LICENSE).

## Credits

- Audio identification via [AudD](https://audd.io/)
- OSC implemented with [OSCKit](https://github.com/orchetect/OSCKit)
- Developed by [Studio Carlos](https://studiocarlos.fr)

---

# Vibe ID

**Vibe ID** est une application iOS qui identifie la musique que vous écoutez et envoie les données d'identification via OSC (Open Sound Control) à d'autres logiciels comme TouchDesigner, MaxMSP ou Chataigne.

## Fonctionnalités

- Identification audio toute les X minutes via l'API [AudD](https://audd.io/)
- Envoi des données d'identification musicales via OSC
- Interface utilisateur simple et intuitive
- Configuration d'intervalle de reconnaissance personnalisable
- Historique des morceaux identifiés
- Fonctionnalité de prompt manuel pour l'expression libre
- Diagnostic réseau pour la connexion OSC

## Prérequis

- iOS 14.0+
- Xcode 13.0+
- Une clé API [AudD](https://dashboard.audd.io/)
- Un appareil ou logiciel qui peut recevoir des messages OSC

## Installation

1. Cloner ce repository
2. Ouvrir `Vibe ID.xcodeproj` dans Xcode
3. Compiler et exécuter sur votre appareil iOS

## Configuration

1. Ouvrez l'application et allez dans Réglages
2. Entrez votre clé API AudD
3. Configurez l'hôte OSC et le port de destination
4. Ajustez la fréquence de reconnaissance selon vos besoins

## Format des messages OSC

L'application envoie les informations suivantes via OSC :

- `/vibeid/track/title` (string) : Titre du morceau
- `/vibeid/track/artist` (string) : Nom de l'artiste
- `/vibeid/track/genre` (string) : Genre musical
- `/vibeid/track/bpm` (float) : BPM du morceau (si disponible)
- `/vibeid/track/energy` (float) : Énergie du morceau (si disponible)
- `/vibeid/track/danceability` (float) : Dansabilité du morceau (si disponible)
- `/vibeid/track/artwork` (string) : URL de la pochette
- `/vibeid/status` (string) : État de l'application ("listening", "recognizing", "identified", "no_match", "error", "stopped")
- `/vibeid/prompt` (string) : Prompts manuels entrés par l'utilisateur
- `/vibeid/test` (string) : Messages de test ("ping")

## Licence

Ce projet est sous licence [GNU GPLv3](LICENSE).

## Credits

- Identification audio via [AudD](https://audd.io/)
- OSC implémenté avec [OSCKit](https://github.com/orchetect/OSCKit)
- Développé par [Studio Carlos](https://studiocarlos.fr)