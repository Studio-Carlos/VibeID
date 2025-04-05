# Vibe ID (iOS App)

Une application iOS expérimentale pour identifier la musique ambiante via l'API AudD et envoyer des informations via OSC pour des systèmes de VJing automatiques ou d'autres interactions créatives.

## État Actuel (v0.1)

* Interface utilisateur basique (SwiftUI) avec bouton Start/Stop et affichage des infos.
* Panneau de réglages fonctionnel (Clé API, OSC Target, Fréquence).
* Capture audio via micro (AVAudioEngine).
* Appel à l'API AudD `recognize` fonctionnel.
* Structure pour envoi OSC (OSCKit) en place.
* **Problèmes connus :** Bouton Start/Stop parfois instable visuellement, envoi OSC des données de piste non encore fonctionnel/vérifié.

## Comment Utiliser (Pour l'instant)

1.  Cloner le dépôt.
2.  Ouvrir avec Xcode (version compatible avec iOS 17+).
3.  Ajouter les dépendances Swift Package Manager (`KeychainAccess`, `OSCKit`).
4.  Lancer l'app sur un iPhone.
5.  Aller dans les Réglages (⚙️) et entrer votre propre clé API AudD (obtenue sur audd.io).
6.  Configurer l'IP et le Port de votre récepteur OSC.
7.  Lancer l'écoute.

## TODO / Prochaines Étapes

* Stabiliser l'interface utilisateur (bouton Start/Stop).
* Implémenter et tester l'envoi OSC des informations de piste.
* Améliorer la gestion des erreurs et des états.
* Explorer l'API streaming d'AudD.
* Connecter à un LLM pour générer des prompts VJ.

## Licence

MIT License (Voir fichier LICENSE)
