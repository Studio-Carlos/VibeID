# Changelog

## [2.1] - 2025-05-04

### Added
- **ACRCloud** is now the default music identification provider (can be changed in settings).
- **Groq LLM integration** (llama-3.1-8b-instant): tested and works well for prompt generation.
- **Gemini** and **ChatGPT** (OpenAI) integrations: implemented, but not yet tested.
- UI improvements for provider and LLM selection.
- Settings and credentials are stored securely in Keychain; **no API keys or secrets are hardcoded** in the codebase.

### Improved
- Refined settings and onboarding experience.
- Updated README and documentation.

### Fixed
- Various bug fixes and stability improvements.

---

## [2.1] - 2025-05-04 (Français)

### Ajouté
- **ACRCloud** est désormais le fournisseur d'identification musicale par défaut (modifiable dans les réglages).
- **Intégration Groq LLM** (llama-3.1-8b-instant) : testée et fonctionne très bien pour la génération de prompts.
- Intégrations **Gemini** et **ChatGPT** (OpenAI) : implémentées, mais pas encore testées.
- Améliorations de l'interface pour la sélection du fournisseur et du LLM.
- Les réglages et identifiants sont stockés de façon sécurisée dans le Trousseau ; **aucune clé API ou secret n'est codé en dur** dans le code source.

### Amélioré
- Expérience de configuration et d'accueil raffinée.
- Documentation et README mis à jour.

### Corrigé
- Divers correctifs de bugs et améliorations de stabilité. 

---

# Previous Versions

## [2.0] - 2025-04-10
- Major update with multi-LLM prompt generation (DeepSeek, Gemini, ChatGPT, Claude)
- OSC input support for track info
- UI improvements and bilingual documentation

## [1.2] - 2025-04-09
- Add LLM image prompt generation
- Improve OSC communication
- Enhance UI

## [1.1] - 2025-04-07
- Enhanced UI with DJ/VJ-oriented design improvements
- Nouvelle interface utilisateur plus élégante (Français)

## [1.0] - 2025-04-07
- First stable release with complete functionality
- Fully functional music identification via AudD API
- Complete OSC message sending implemented
- Clean SwiftUI interface with settings panel
- English localization throughout the application
- GNU GPL V3 License added
- Code documentation and structure improved for open source release

## [0.2] - 2025-04-06
- Resolve button action and enable identification flow

## [0.1] - 2025-04-05
- Initial functional version

---

*For full commit-level details, see the project git history.* 