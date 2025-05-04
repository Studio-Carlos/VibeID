# Vibe ID v2.1

**Vibe ID** is an iOS application designed to assist AI-based automated VJing systems. It identifies ambient music (via **AudD**, **ACRCloud** (default), or incoming OSC) and leverages LLMs (Large Language Models) to generate creative prompts for image generation. Track information and generated prompts are sent via OSC (Open Sound Control) to other software (TouchDesigner, Chataigne, MaxMSP, etc.) for automated VJing or other creative interactions.

## Screenshots

### Main Interface (Idle / Listening)
![Vibe ID Interface Idle/Listening v2.0](Vibe%20ID/screenshots/vibe-id-idle-v2.0.png)
*Application ready for music.*

### Main Interface (Identified Track + Prompts)
![Vibe ID Results Interface v2.0](Vibe%20ID/screenshots/vibe-id-results-v2.0.png)
*Display of the identified track and carousel of generated AI prompts.*

### Settings Panel (Now with Provider Selection)
![Vibe ID Settings v2.1](Vibe%20ID/screenshots/vibe-id-settings-v2.1.png)
*Configuration includes Music ID Provider (AudD/ACRCloud), API keys, OSC parameters, LLM selection.*

## New in Version 2.1

- **ACRCloud Integration:** Added [ACRCloud](https://www.acrcloud.com/) as an alternative music identification provider.
    - Selectable in Settings ("Music Identification" section).
    - Requires ACRCloud Host, Access Key, and Secret Key (obtained from ACRCloud dashboard).
    - Credentials stored securely in Keychain.
- **Refactored Recognition Layer:** Introduced a protocol-based system (`MusicRecognizer`) to easily swap between providers (AudD, ACRCloud).

### AI Visual Prompt Generation with Multi-LLM
- **Advanced LLM Integration:** Automatically generates 10 creative image prompts for each identified track.
- **Multi-LLM Support:** Choose your preferred LLM in settings from **Deepseek, Groq (tested, works well), Gemini, and ChatGPT (via OpenAI API)**. *(Note: Groq and DeepSeek are tested; Gemini and ChatGPT are implemented but not tested in this version).*
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

## Key Features (v2.1)

- Periodic audio identification via **AudD or ACRCloud (default)** (configurable).
- **Title/Artist reception via OSC**.
- Generation of **10 AI prompts** via **LLM of choice (Groq and DeepSeek tested; Gemini, ChatGPT implemented but not tested)**.
- **Customizable LLM System Prompt**.
- Sending of music data AND 10 AI prompts via OSC.
- Track info display (Cover art, Title, Artist, Source, Genre?, BPM?).
- Carousel display of 10 AI prompts.
- **Data source indicator** (AudD/ACRCloud/OSC).
- Simple interface, optimized Dark Mode.
- Configuration: **Music ID Provider (AudD/ACRCloud)**, API Keys (AudD, ACRCloud, LLMs), OSC Send (IP/Port), OSC Receive (Port, Address), AudD ID Frequency, LLM Choice, LLM System Prompt.
- Manual prompt via OSC.

## Requirements

- **iOS 17.0+**
- Xcode 15.0+
- **Music ID Provider API Key(s):**
    - **AudD:** [AudD](https://dashboard.audd.io/) API key (if using AudD).
    - **ACRCloud:** Host, Access Key, Secret Key from [ACRCloud](https://console.acrcloud.com/) (if using ACRCloud).
- At least one LLM API key (DeepSeek recommended initially) for prompt generation.
- OSC receiver on local network.
- (Optional) OSC transmitter for track info.

## Installation

1. Clone the GitHub repository: https://github.com/Studio-Carlos/VibeID
2. **Integrate ACRCloud SDK:**
    - Download the `ACRCloudiOSSDK.xcframework` from the [ACRCloud SDK releases](https://github.com/acrcloud/acrcloud_sdk_ios/releases) or website.
    - Drag the `.xcframework` into your Xcode project (e.g., under a `Frameworks` group).
    - In Project Settings -> `Vibe ID` Target -> General -> Frameworks, Libraries, and Embedded Content:
        - Ensure `ACRCloudiOSSDK.xcframework` is listed.
        - Set **Embed** to **Embed & Sign**.
3. Open `Vibe ID.xcodeproj` in Xcode.
4. Resolve SPM dependencies if necessary (File > Packages > Resolve...).
5. Compile and launch on iOS device.
6. **Permissions:** Allow **Microphone** and **Local Network** access.

## Essential Configuration

1. Open Vibe ID > Settings (⚙️).
2. Go to the **Music Identification** section:
    - Select your desired **Provider** (AudD or ACRCloud).
    - **If AudD:** Enter the **AudD API key**.
    - **If ACRCloud:** Enter the **ACRCloud Host**, **Access Key**, and **Secret Key**.
3. Go to the **LLM Configuration** section:
    - Enter at least the **DeepSeek API key** (or other) and select the LLM.
    - (Recommended) Customize the **LLM System Prompt**.
4. Configure **OSC Output Configuration** (Target IP, Target Port).
5. Adjust **Identification Frequency**.
6. If using OSC reception: Enable **OSC Input Configuration**, configure **Listen Port**.

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
* `/vibeid/track/source` (string): "AudD" or "ACRCloud" or "OSC".
* `/vibeid/track/prompt1` ... `/vibeid/track/prompt10` (string): AI Prompts.
* `/vibeid/status` (string): Internal status (e.g., "identifying", "generating_prompts", "error"). *(To be refined)*
* `/vibeid/prompt/manual` (string): Manual prompt.

### Message Received by Vibe ID (Recommended Example):

* **Address:** (Configurable, e.g.: `/external/track`)
* **Arguments:** `s` (Artist), `s` (Title)

## License

This project is licensed under the **GNU GPL v3**. See the [LICENSE](LICENSE) file.

## Credits

* Audio identification: [AudD](https://audd.io/), [ACRCloud](https://www.acrcloud.com/)
* AI Prompt Generation: [DeepSeek](https://deepseek.com/) APIs (Tested), [Groq](https://groq.com/) (Tested, llama-3.1-8b-instant), [Google Gemini](https://ai.google.dev/), [OpenAI](https://openai.com/) (Implemented, Not tested).
* OSC: [OSCKit](https://github.com/orchetect/OSCKit).
* Keychain: [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess).
* Developed by **Studio Carlos (Copyright 2025)**

---
<br/>

---

# Vibe ID v2.1 (Français)

**Vibe ID** est une application iOS conçue pour assister les systèmes de VJing automatiques basés sur l'IA. Elle identifie la musique ambiante (via **AudD**, **ACRCloud** (par défaut), ou OSC entrant) et exploite des LLMs (Modèles de Langage Larges) pour générer des prompts créatifs destinés à la génération d'images. Les informations du morceau et les prompts générés sont envoyés via OSC (Open Sound Control) à d'autres logiciels (TouchDesigner, Chataigne, MaxMSP, etc.) pour le VJing automatique ou d'autres interactions créatives.

## Captures d'Écran

### Interface Principale (Repos / Écoute)
![Vibe ID Interface Repos/Écoute v2.0](Vibe%20ID/screenshots/vibe-id-idle-v2.0.png)
*Application prête ou en écoute active de la musique.*

### Interface Principale (Morceau Identifié + Prompts)
![Vibe ID Interface Résultats v2.0](Vibe%20ID/screenshots/vibe-id-results-v2.0.png)
*Affichage du morceau identifié et du carrousel de prompts IA générés.*

### Panneau des Réglages (Maintenant avec Choix du Fournisseur)
![Vibe ID Réglages v2.1](Vibe%20ID/screenshots/vibe-id-settings-v2.1.png)
*La configuration inclut le Fournisseur d'Identification Musicale (AudD/ACRCloud), clés API, paramètres OSC, choix LLM.*

## Nouveautés de la Version 2.1

- **Intégration ACRCloud :** Ajout de [ACRCloud](https://www.acrcloud.com/) comme fournisseur d'identification musicale alternatif.
    - Sélectionnable dans les Réglages (section "Identification Musicale").
    - Nécessite Hôte (Host), Clé d'Accès (Access Key), et Clé Secrète (Secret Key) ACRCloud (obtenus depuis le tableau de bord ACRCloud).
    - Identifiants stockés de manière sécurisée dans le Trousseau (Keychain).
- **Couche de Reconnaissance Refactorisée :** Introduction d'un système basé sur un protocole (`MusicRecognizer`) pour permuter facilement entre les fournisseurs (AudD, ACRCloud).

### Génération Visuelle IA Multi-LLM
- **Intégration avancée de LLM :** Génère automatiquement 10 prompts d'images créatifs pour chaque morceau identifié.
- **Support Multi-LLM :** Choisissez votre LLM préféré dans les réglages parmi **Deepseek, Groq (testé, fonctionne bien), Gemini, et ChatGPT (via OpenAI API)**. *(Note : Groq et DeepSeek testés ; Gemini et ChatGPT implémentés mais non testés dans cette version).*
- **Configuration dédiée :** Entrez vos clés API personnelles pour chaque service LLM dans les réglages (stockage sécurisé).
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
- **Stabilité :** Améliorations de la gestion d'état.
- **Compte à Rebours :** Indique le temps avant la prochaine ID AudD.

## Fonctionnalités Clés (v2.1)

- Identification audio périodique via **AudD ou ACRCloud (par défaut)** (configurable).
- **Réception Titre/Artiste via OSC**.
- Génération de **10 prompts IA** via **LLM au choix (Groq et DeepSeek testés ; Gemini, ChatGPT implémentés mais non testés)**.
- **Prompt Système LLM personnalisable**.
- Envoi des données musicales ET des 10 prompts IA via OSC.
- Affichage infos piste (Pochette, Titre, Artiste, Source, Genre?, BPM?).
- Affichage en carrousel des 10 prompts IA.
- **Indicateur de source de données** (AudD/ACRCloud/OSC).
- Interface simple, optimisée Dark Mode.
- Configuration : **Fournisseur ID Musique (AudD/ACRCloud)**, Clés API (AudD, ACRCloud, LLMs), Envoi OSC (IP/Port), Réception OSC (Port), Fréquence ID, Choix LLM, Prompt Système LLM.
- Prompt manuel via OSC.

## Prérequis

- **iOS 17.0+**
- Xcode 15.0+
- **Clé(s) API Fournisseur ID Musique :**
    - **AudD :** Clé API [AudD](https://dashboard.audd.io/) (si AudD est utilisé).
    - **ACRCloud :** Hôte, Clé d'Accès, Clé Secrète depuis [ACRCloud](https://console.acrcloud.com/) (si ACRCloud est utilisé).
- Au moins une clé API LLM (DeepSeek recommandé initialement) pour la génération de prompts.
- Récepteur OSC sur le réseau local.
- (Optionnel) Emetteur OSC pour info piste.

## Installation

1. Cloner le dépôt GitHub : https://github.com/Studio-Carlos/VibeID
2. **Intégrer le SDK ACRCloud :**
    - Télécharger `ACRCloudiOSSDK.xcframework` depuis les [releases du SDK ACRCloud](https://github.com/acrcloud/acrcloud_sdk_ios/releases) ou leur site.
    - Glisser le `.xcframework` dans votre projet Xcode (ex: sous un groupe `Frameworks`).
    - Dans Réglages Projet -> Cible `Vibe ID` -> General -> Frameworks, Libraries, and Embedded Content :
        - Assurez-vous que `ACRCloudiOSSDK.xcframework` est listé.
        - Réglez **Embed** sur **Embed & Sign**.
3. Ouvrir `Vibe ID.xcodeproj` dans Xcode.
4. Résoudre les dépendances SPM si nécessaire (File > Packages > Resolve...).
5. Compiler et lancer sur appareil iOS.
6. **Permissions :** Autoriser l'accès **Microphone** et **Réseau Local**.

## Configuration Essentielle

1. Ouvrir Vibe ID > Réglages (⚙️).
2. Aller à la section **Identification Musicale** :
    - Sélectionner le **Fournisseur** désiré (AudD ou ACRCloud).
    - **Si AudD :** Entrer la **clé API AudD**.
    - **Si ACRCloud :** Entrer l'**Hôte**, la **Clé d'Accès**, et la **Clé Secrète** ACRCloud.
3. Aller à la section **Configuration LLM** :
    - Entrer au moins la **clé API DeepSeek** (ou autre) et sélectionner le LLM.
    - (Recommandé) Personnaliser le **Prompt Système LLM**.
4. Configurer la **Configuration Sortie OSC** (IP Cible, Port Cible).
5. Ajuster la **Fréquence d'identification**.
6. Si réception OSC : Activer **Configuration Entrée OSC**, configurer **Port d'écoute**.

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
* `/vibeid/track/source` (string): "AudD" ou "ACRCloud" ou "OSC".
* `/vibeid/track/prompt1` ... `/vibeid/track/prompt10` (string): Prompts IA.
* `/vibeid/status` (string): Statut interne (ex: "identifying", "generating_prompts", "error"). *(À affiner)*
* `/vibeid/prompt/manual` (string): Prompt manuel.

### Message Reçu par Vibe ID (Exemple Recommandé) :

* **Adresse :** (Configurable, ex: `/external/track`)
* **Arguments :** `s` (Artiste), `s` (Titre)

## Licence

Ce projet est sous licence **GNU GPL v3**. Voir le fichier [LICENSE](LICENSE).

## Crédits

* Identification audio : [AudD](https://audd.io/), [ACRCloud](https://www.acrcloud.com/)
* Génération Prompts IA : APIs [DeepSeek](https://deepseek.com/) (Testé), [Groq](https://groq.com/) (Testé, llama-3.1-8b-instant), [Google Gemini](https://ai.google.dev/), [OpenAI](https://openai.com/) (Implémentés, Non testés).
* OSC : [OSCKit](https://github.com/orchetect/OSCKit).
* Keychain : [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess).
* Développé par **Studio Carlos (Copyright 2025)**
