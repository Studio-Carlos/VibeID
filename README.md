# Vibe ID v2.0

**Vibe ID** is an iOS application designed to assist AI-based automated VJing systems. It identifies ambient music (via AudD API or incoming OSC) and leverages LLMs (Large Language Models) to generate creative prompts for image generation. Track information and generated prompts are sent via OSC (Open Sound Control) to other software (TouchDesigner, Chataigne, MaxMSP, etc.) for automated VJing or other creative interactions.

## Screenshots

### Main Interface (Idle / Listening)
![Vibe ID Interface Idle/Listening v2.0](Vibe%20ID/screenshots/vibe-id-idle-v2.0.png)
*Application ready for music.*

### Main Interface (Identified Track + Prompts)
![Vibe ID Results Interface v2.0](Vibe%20ID/screenshots/vibe-id-results-v2.0.png)
*Display of the identified track and carousel of generated AI prompts.*

### Settings Panel
![Vibe ID Settings v2.0](Vibe%20ID/screenshots/vibe-id-settings-v2.0.png)
*Configuration of API keys (AudD, LLMs), OSC parameters (Send/Receive), LLM selection and system prompt.*

## New in Version 2.0

This version introduces major features transforming Vibe ID into a true creative assistant for VJs.

### AI Visual Prompt Generation with Multi-LLM
- **Advanced LLM Integration:** Automatically generates 10 creative image prompts for each identified track.
- **Multi-LLM Support:** Choose your preferred LLM in settings from **Gemini, DeepSeek, ChatGPT (via OpenAI API), and Claude (via Anthropic API)**. *(Note: Only DeepSeek integration is actively tested in this version).*
- **Dedicated Configuration:** Enter your personal API keys for each LLM service in settings (secure storage).
- **Customizable System Prompt:** Guide the AI with your own "System Prompt" (modifiable in settings) to direct the style or content of generated prompts. The AI uses track information and potentially its own knowledge/web research to create prompts.
- **Integrated Display:** The 10 generated prompts are displayed at the bottom of the main screen in a navigable carousel.
- **OSC Prompt Transmission:** All 10 prompts are sent via OSC (`/vibeid/track/prompt1` to `/vibeid/track/prompt10`).

### Track Information Reception via OSC
- **Alternative to AudD:** Receive Title/Artist information directly from an external source (e.g., DJ software, Pro DJ Link to OSC adapter...).
- **Configurable Address:** Define in settings the exact OSC address that Vibe ID should listen to. *Recommended format: Unique address with Artist (string) and Title (string) as arguments.*
- **LLM Triggering:** Receiving information via OSC triggers prompt generation by the selected LLM.
- **AudD Timer Reset:** OSC reception resets the timer for the next automatic identification via AudD.
- **Visual Indicator:** The interface indicates when information comes from an OSC source.
- **Activation/Deactivation:** A button and a setting allow activating/deactivating OSC listening.

### User Interface and Improvements
- **Refined UI:** Improved general design, optimized Dark Mode.
- **Functional Prompt Carousel**.
- **Stability:** Improved state management.
- **Countdown:** Indicates time until next AudD ID.

## Key Features (v2.0)

- Periodic audio identification via [AudD](https://audd.io/).
- **Title/Artist reception via OSC**.
- Generation of **10 AI prompts** via **LLM of choice (DeepSeek tested**; Gemini, ChatGPT, Claude implemented but not tested).
- **Customizable LLM System Prompt**.
- Sending of music data AND 10 AI prompts via OSC.
- Track info display (Cover art, Title, Artist, Source, Genre?, BPM?).
- Carousel display of 10 AI prompts.
- **Data source indicator** (AudD/OSC).
- Simple interface, optimized Dark Mode.
- Configuration: API Keys (AudD, LLMs), OSC Send (IP/Port), OSC Receive (Port, Address), AudD ID Frequency, LLM Choice, LLM System Prompt.
- Manual prompt via OSC.

## Requirements

- **iOS 17.0+**
- Xcode 15.0+
- [AudD](https://dashboard.audd.io/) API key.
- At least one LLM API key (DeepSeek recommended initially) for prompt generation.
- OSC receiver on local network.
- (Optional) OSC transmitter for track info.

## Installation

1. Clone the GitHub repository.
2. Open `Vibe ID.xcodeproj` in Xcode.
3. Resolve SPM dependencies if necessary (File > Packages > Resolve...).
4. Compile and launch on iOS device.
5. **Permissions:** Allow **Microphone** and **Local Network** access.

## Essential Configuration

1. Open Vibe ID > Settings (⚙️).
2. Enter the **AudD API key**.
3. Enter at least the **DeepSeek API key** (or other, knowing that others are untested) and select the LLM.
4. (Recommended) Customize the **LLM System Prompt**.
5. Configure **OSC Target IP** and **OSC Target Port**.
6. Adjust **Identification Frequency**.
7. If OSC reception: Enable, configure **Listening Port** and **Incoming OSC Address**.

## OSC Message Format

### Messages Sent by Vibe ID:

* `/vibeid/app/status` (string): "listening_started", "listening_stopped".
* `/vibeid/track/new` (bang/trigger): New track signal.
* `/vibeid/track/title` (string): Title.
* `/vibeid/track/artist` (string): Artist.
* `/vibeid/track/album` (string): Album (if available).
* `/vibeid/track/genre` (string): Genre(s) (if available).
* `/vibeid/track/bpm` (float): BPM (if available).
* `/vibeid/track/artworkURL` (string): Cover art URL (if available).
* `/vibeid/track/source` (string): "AudD" or "OSC".
* `/vibeid/track/prompt1` ... `/vibeid/track/prompt10` (string): AI Prompts.
* `/vibeid/status` (string): Internal status (e.g., "identifying", "generating_prompts", "error"). *(To be refined)*
* `/vibeid/prompt/manual` (string): Manual prompt.

### Message Received by Vibe ID (Recommended Example):

* **Address:** (Configurable, e.g.: `/external/track`)
* **Arguments:** `s` (Artist), `s` (Title)

## License

This project is licensed under the **GNU GPL v3**. See the [LICENSE](LICENSE) file.

## Credits

* Audio identification: [AudD](https://audd.io/)
* AI Prompt Generation: [DeepSeek](https://deepseek.com/) APIs (Tested), [Google Gemini](https://ai.google.dev/), [OpenAI](https://openai.com/), [Anthropic Claude](https://www.anthropic.com/) (Implemented, Not tested).
* OSC: [OSCKit](https://github.com/orchetect/OSCKit).
* Keychain: [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess).
* Developed by **Studio Carlos (Copyright 2025)**

---
<br/>

---

# Vibe ID v2.0 (Français)

**Vibe ID** est une application iOS conçue pour assister les systèmes de VJing automatiques basés sur l'IA. Elle identifie la musique ambiante (via l'API AudD ou OSC entrant) et exploite des LLMs (Modèles de Langage Larges) pour générer des prompts créatifs destinés à la génération d'images. Les informations du morceau et les prompts générés sont envoyés via OSC (Open Sound Control) à d'autres logiciels (TouchDesigner, Chataigne, MaxMSP, etc.) pour le VJing automatique ou d'autres interactions créatives.

## Captures d'Écran

### Interface Principale (Repos / Écoute)
![Vibe ID Interface Repos/Écoute v2.0](Vibe%20ID/screenshots/vibe-id-idle-v2.0.png)
*Application prête ou en écoute active de la musique.*

### Interface Principale (Morceau Identifié + Prompts)
![Vibe ID Interface Résultats v2.0](Vibe%20ID/screenshots/vibe-id-results-v2.0.png)
*Affichage du morceau identifié et du carrousel de prompts IA générés.*

### Panneau des Réglages
![Vibe ID Réglages v2.0](Vibe%20ID/screenshots/vibe-id-settings-v2.0.png)
*Configuration des clés API (AudD, LLMs), des paramètres OSC (Envoi/Réception), du choix du LLM et du prompt système.*

## Nouveautés de la Version 2.0

Cette version introduit des fonctionnalités majeures transformant Vibe ID en un véritable assistant créatif pour VJ.

### Génération de Prompts Visuels par IA Multi-LLM
- **Intégration Avancée de LLM :** Génère automatiquement 10 prompts d'images créatifs pour chaque morceau identifié.
- **Support Multi-LLM :** Choisissez votre LLM préféré dans les réglages parmi **Gemini, DeepSeek, ChatGPT (via API OpenAI), et Claude (via API Anthropic)**. *(Note : Seule l'intégration de DeepSeek est activement testée dans cette version).*
- **Configuration Dédiée :** Entrez vos clés API personnelles pour chaque service LLM dans les réglages (stockage sécurisé).
- **Prompt Système Personnalisable :** Guidez l'IA avec votre propre "System Prompt" (modifiable dans les réglages) pour orienter le style ou le contenu des prompts générés. L'IA utilise les informations du morceau et potentiellement ses propres connaissances/recherche web pour créer les prompts.
- **Affichage Intégré :** Les 10 prompts générés s'affichent en bas de l'écran principal dans un carrousel navigable.
- **Envoi OSC des Prompts :** Les 10 prompts sont envoyés via OSC (`/vibeid/track/prompt1` à `/vibeid/track/prompt10`).

### Réception d'Informations de Piste via OSC
- **Alternative à AudD :** Recevez directement les informations Titre/Artiste depuis une source externe (ex: logiciel DJ, adaptateur Pro DJ Link vers OSC...).
- **Adresse Configurable :** Définissez dans les réglages l'adresse OSC exacte que Vibe ID doit écouter. *Format recommandé : Adresse unique avec Artiste (string) et Titre (string) comme arguments.*
- **Déclenchement LLM :** La réception d'informations via OSC déclenche la génération de prompts par le LLM sélectionné.
- **Réinitialisation Timer AudD :** La réception OSC réinitialise le compteur pour la prochaine identification automatique via AudD.
- **Indicateur Visuel :** L'interface indique quand les informations proviennent d'une source OSC.
- **Activation/Désactivation :** Un bouton et un réglage permettent d'activer/désactiver l'écoute OSC.

### Interface Utilisateur et Améliorations
- **UI Raffinée :** Design général amélioré, optimisé Dark Mode.
- **Carrousel de Prompts Fonctionnel**.
- **Stabilité :** Améliorations de la gestion d'état.
- **Compte à Rebours :** Indique le temps avant la prochaine ID AudD.

## Fonctionnalités Clés (v2.0)

- Identification audio périodique via [AudD](https://audd.io/).
- **Réception Titre/Artiste via OSC**.
- Génération de **10 prompts IA** via **LLM au choix (DeepSeek testé**; Gemini, ChatGPT, Claude implémentés mais non testés).
- **Prompt Système LLM personnalisable**.
- Envoi des données musicales ET des 10 prompts IA via OSC.
- Affichage infos piste (Pochette, Titre, Artiste, Source, Genre?, BPM?).
- Affichage en carrousel des 10 prompts IA.
- **Indicateur de source de données** (AudD/OSC).
- Interface simple, optimisée Dark Mode.
- Configuration : Clés API (AudD, LLMs), Envoi OSC (IP/Port), Réception OSC (Port, Adresse), Fréquence ID AudD, Choix LLM, Prompt Système LLM.
- Prompt manuel via OSC.

## Prérequis

- **iOS 17.0+**
- Xcode 15.0+
- Clé API [AudD](https://dashboard.audd.io/).
- Au moins une clé API LLM (DeepSeek recommandé initialement) pour la génération de prompts.
- Récepteur OSC sur le réseau local.
- (Optionnel) Emetteur OSC pour info piste.

## Installation

1.  Cloner le dépôt GitHub.
2.  Ouvrir `Vibe ID.xcodeproj` dans Xcode.
3.  Résoudre les dépendances SPM si nécessaire (File > Packages > Resolve...).
4.  Compiler et lancer sur appareil iOS.
5.  **Permissions :** Autoriser l'accès **Microphone** et **Réseau Local**.

## Configuration Essentielle

1.  Ouvrir Vibe ID > Réglages (⚙️).
2.  Entrer la **clé API AudD**.
3.  Entrer au moins la **clé API DeepSeek** (ou autre, en sachant que les autres sont non testés) et sélectionner le LLM.
4.  (Recommandé) Personnaliser le **Prompt Système LLM**.
5.  Configurer **IP Cible OSC** et **Port Cible OSC**.
6.  Ajuster **Fréquence d'identification**.
7.  Si réception OSC : Activer, configurer **Port d'écoute** et **Adresse OSC entrante**.

## Format des Messages OSC

### Messages Envoyés par Vibe ID :

* `/vibeid/app/status` (string): "listening_started", "listening_stopped".
* `/vibeid/track/new` (bang/trigger): Signal nouveau morceau.
* `/vibeid/track/title` (string): Titre.
* `/vibeid/track/artist` (string): Artiste.
* `/vibeid/track/album` (string): Album (si dispo).
* `/vibeid/track/genre` (string): Genre(s) (si dispo).
* `/vibeid/track/bpm` (float): BPM (si dispo).
* `/vibeid/track/artworkURL` (string): URL Pochette (si dispo).
* `/vibeid/track/source` (string): "AudD" ou "OSC".
* `/vibeid/track/prompt1` ... `/vibeid/track/prompt10` (string): Prompts IA.
* `/vibeid/status` (string): Statut interne (ex: "identifying", "generating_prompts", "error"). *(À affiner)*
* `/vibeid/prompt/manual` (string): Prompt manuel.

### Message Reçu par Vibe ID (Exemple Recommandé) :

* **Adresse :** (Configurable, ex: `/external/track`)
* **Arguments :** `s` (Artiste), `s` (Titre)

## Licence

Ce projet est sous licence **GNU GPL v3**. Voir le fichier [LICENSE](LICENSE).

## Crédits

* Identification audio : [AudD](https://audd.io/)
* Génération Prompts IA : APIs [DeepSeek](https://deepseek.com/) (Testé), [Google Gemini](https://ai.google.dev/), [OpenAI](https://openai.com/), [Anthropic Claude](https://www.anthropic.com/) (Implémentés, Non testés).
* OSC : [OSCKit](https://github.com/orchetect/OSCKit).
* Keychain : [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess).
* Développé par **Studio Carlos (Copyright 2025)**
