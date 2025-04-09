# Vibe ID

**Vibe ID** is an iOS application that identifies the music you're listening to and sends generated image prompts and identification data via OSC (Open Sound Control) to other software like TouchDesigner, MaxMSP, or Chataigne.

## Screenshots

### Idle Interface
![Vibe ID Idle Interface](https://raw.githubusercontent.com/Super-Carlos/VibeID/main/Vibe%20ID/screenshots/vibe-id-idle-v1.2.png)
*Ready to identify music with elegant neon-style UI*

### Results with Generated Prompts
![Vibe ID Results Interface](https://raw.githubusercontent.com/Super-Carlos/VibeID/main/Vibe%20ID/screenshots/vibe-id-results-v1.2.png)
*Displaying identified track with AI-generated image prompts*

### Settings Page
![Vibe ID Settings](https://raw.githubusercontent.com/Super-Carlos/VibeID/main/Vibe%20ID/screenshots/vibe-id-settings-v1.2.png)
*Configure API keys, OSC settings, and LLM parameters*

## What's New in Version 1.2

### AI-Powered Image Prompt Generation
- **LLM Integration**: Automatically generates creative visuals prompts for identified tracks using a LLM with AI websearch
- **Multi-LLM Support**: Architecture supports multiple LLM providers (Claude, OpenAI planned for future updates)
- **Web Search Enhanced**: Utilizes web search capabilities to gather information about tracks for better prompts
- **Customizable System Prompts**: Personalize the AI prompt generation system with your own instructions

### Enhanced OSC Communication
- **Extended OSC Messages**: Now sends AI-generated image prompts via `/vibeid/track/prompt1` through `/vibeid/track/prompt10`
- **Improved Testing**: Added simulation feature to test track identification without audio capture
- **Better Network Diagnostics**: Enhanced troubleshooting for OSC connections

### Improved User Interface
- **Prompt Display**: View generated prompts directly in the app interface
- **Smoother Animations**: Enhanced visual feedback during recognition and processing
- **Layout Optimizations**: Better space usage on all device sizes

## Features

- Audio identification every X minutes via the [AudD](https://audd.io/) API
- Automatic AI image prompt generation for identified music via LLM (DeepSeek)
- Sending musical identification data and AI prompts via OSC
- Simple and intuitive user interface with DJ/VJ-oriented design
- Customizable recognition interval configuration
- Real-time track information display (BPM, energy, danceability)
- Manual prompt functionality for free expression
- Network diagnostics for OSC connection
- Dark theme with glowing neon accents

## Requirements

- iOS 14.0+
- Xcode 13.0+
- An [AudD](https://dashboard.audd.io/) API key
- (Optional) A LLM API key for AI prompt generation
- A device or software that can receive OSC messages

## Installation

1. Clone this repository
2. Open `Vibe ID.xcodeproj` in Xcode
3. Compile and run on your iOS device

## Configuration

1. Open the application and go to Settings
2. Enter your AudD API key
3. Enter your DeepSeek API key for AI prompt generation
4. Configure the OSC host and destination port
5. Adjust the recognition frequency according to your needs
6. (Optional) Customize the LLM system prompt for personalized results

## OSC Message Format

The application sends the following information via OSC:

- `/vibeid/track/title` (string): Track title
- `/vibeid/track/artist` (string): Artist name
- `/vibeid/track/genre` (string): Musical genre
- `/vibeid/track/bpm` (float): BPM of the track (if available)
- `/vibeid/track/energy` (float): Energy of the track (if available)
- `/vibeid/track/danceability` (float): Danceability of the track (if available)
- `/vibeid/track/artwork` (string): Artwork URL
- `/vibeid/track/prompt1` through `/vibeid/track/prompt10` (string): AI-generated image prompts
- `/vibeid/status` (string): Application status ("listening", "recognizing", "identified", "no_match", "error", "stopped")
- `/vibeid/manual` (string): Manual prompts entered by the user
- `/vibeid/test` (string): Test messages ("ping")

## License

This project is licensed under the [GNU GPLv3](LICENSE).

## Credits

- Audio identification via [AudD](https://audd.io/)
- AI prompt generation via [DeepSeek](https://deepseek.com/)
- OSC implemented with [OSCKit](https://github.com/orchetect/OSCKit)
- Developed by [Studio Carlos](https://studiocarlos.fr)

---

# Vibe ID

**Vibe ID** est une application iOS qui identifie la musique que vous écoutez et envoie les données d'identification via OSC (Open Sound Control) à d'autres logiciels comme TouchDesigner, MaxMSP ou Chataigne.

## Nouveautés de la version 1.2

### Génération de prompts d'image par IA
- **Intégration de LLM** : Génère automatiquement des prompts créatifs pour les morceaux identifiés en utilisant DeepSeek AI
- **Support multi-LLM** : Architecture supportant plusieurs fournisseurs de LLM (Claude, OpenAI prévus pour les mises à jour futures)
- **Recherche web améliorée** : Utilise les capacités de recherche web pour rassembler des informations sur les morceaux et créer de meilleurs prompts
- **Prompts système personnalisables** : Personnalisez le système de génération de prompts avec vos propres instructions

### Communication OSC améliorée
- **Messages OSC étendus** : Envoie maintenant des prompts d'image générés par IA via `/vibeid/track/prompt1` à `/vibeid/track/prompt10`
- **Tests améliorés** : Ajout d'une fonction de simulation pour tester l'identification des morceaux sans capture audio
- **Meilleurs diagnostics réseau** : Dépannage amélioré pour les connexions OSC

### Interface utilisateur améliorée
- **Affichage des prompts** : Visualisez les prompts générés directement dans l'interface de l'application
- **Animations plus fluides** : Retour visuel amélioré pendant la reconnaissance et le traitement
- **Optimisations de mise en page** : Meilleure utilisation de l'espace sur tous les formats d'écran

## Fonctionnalités

- Identification audio toutes les X minutes via l'API [AudD](https://audd.io/)
- Génération automatique de prompts d'image par IA pour la musique identifiée via LLM (DeepSeek)
- Envoi des données d'identification musicales et des prompts IA via OSC
- Interface utilisateur simple et intuitive avec design orienté DJ/VJ
- Configuration d'intervalle de reconnaissance personnalisable
- Affichage en temps réel des informations de piste (BPM, énergie, dansabilité)
- Fonctionnalité de prompt manuel pour l'expression libre
- Diagnostic réseau pour la connexion OSC
- Thème sombre avec accents néon lumineux

## Prérequis

- iOS 14.0+
- Xcode 13.0+
- Une clé API [AudD](https://dashboard.audd.io/)
- (Optionnel) Une clé API DeepSeek pour la génération de prompts IA
- Un appareil ou logiciel qui peut recevoir des messages OSC

## Installation

1. Cloner ce repository
2. Ouvrir `Vibe ID.xcodeproj` dans Xcode
3. Compiler et exécuter sur votre appareil iOS

## Configuration

1. Ouvrez l'application et allez dans Réglages
2. Entrez votre clé API AudD
3. (Optionnel) Entrez votre clé API DeepSeek pour la génération de prompts IA
4. Configurez l'hôte OSC et le port de destination
5. Ajustez la fréquence de reconnaissance selon vos besoins
6. (Optionnel) Personnalisez le prompt système LLM pour des résultats personnalisés

## Format des messages OSC

L'application envoie les informations suivantes via OSC :

- `/vibeid/track/title` (string) : Titre du morceau
- `/vibeid/track/artist` (string) : Nom de l'artiste
- `/vibeid/track/genre` (string) : Genre musical
- `/vibeid/track/bpm` (float) : BPM du morceau (si disponible)
- `/vibeid/track/energy` (float) : Énergie du morceau (si disponible)
- `/vibeid/track/danceability` (float) : Dansabilité du morceau (si disponible)
- `/vibeid/track/artwork` (string) : URL de la pochette
- `/vibeid/track/prompt1` à `/vibeid/track/prompt10` (string) : Prompts d'image générés par IA
- `/vibeid/status` (string) : État de l'application ("listening", "recognizing", "identified", "no_match", "error", "stopped")
- `/vibeid/manual` (string) : Prompts manuels entrés par l'utilisateur
- `/vibeid/test` (string) : Messages de test ("ping")

## Licence

Ce projet est sous licence [GNU GPLv3](LICENSE).

## Credits

- Identification audio via [AudD](https://audd.io/)
- Génération de prompts IA via [DeepSeek](https://deepseek.com/)
- OSC implémenté avec [OSCKit](https://github.com/orchetect/OSCKit)
- Développé par [Studio Carlos](https://studiocarlos.fr)