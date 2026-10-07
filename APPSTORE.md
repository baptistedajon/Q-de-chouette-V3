# Préparation App Store

## Déjà en place

- [x] Nom affiché : « Cul de Chouette » (fr, en) ; identifiant `com.baptistedajon.Qdechouette`, version 1.0 (1).
- [x] Icône 1024 × 1024 (provisoire, voir ASSETS.md) et couleur d'accent.
- [x] iPhone en portrait (jeu autour d'un téléphone posé sur la table), iPad toutes orientations.
- [x] Description d'usage de l'appareil photo (fr, en). Les images sont analysées sur l'appareil, jamais enregistrées ni envoyées.
- [x] Manifeste de confidentialité `PrivacyInfo.xcprivacy` : aucun suivi, aucune donnée collectée ; API UserDefaults déclarée (raison CA92.1).
- [x] `ITSAppUsesNonExemptEncryption = NO` (aucun chiffrement propre) : pas de question d'export à chaque envoi.
- [x] Catégorie : jeux de société.
- [x] Aucune référence à une série télévisée, aucun asset ni son sous droits : tout est original (dessiné ou synthétisé en code).
- [x] Accessibilité : VoiceOver, Dynamic Type jusqu'aux tailles d'accessibilité, Réduire les animations, mode sombre, contrastes ≥ 4,5:1 sur les boutons principaux.

## À faire avant l'envoi

- [ ] Remplacer les assets provisoires prioritaires (icône, avatars) — voir ASSETS.md.
- [ ] Tester sur un vrai iPhone : réflexes à plusieurs doigts, secousse, caméra en conditions réelles (éclairage, dés de couleurs variées), sons et vibrations.
- [ ] Captures d'écran 6,9" et 13" (iPad), en français et en anglais.
- [ ] Texte de présentation, mots-clés, URL d'assistance et URL de politique de confidentialité (une page simple suffit : « aucune donnée collectée »).
- [ ] Questionnaire « Confidentialité de l'app » dans App Store Connect : « Aucune donnée collectée ».
- [ ] Classification par âge : 4+ (pas de jeu d'argent réel ; les paris portent sur des points fictifs). Répondre « Non » à « Jeux d'argent simulés » ou « Peu fréquent » selon la lecture d'Apple — les mises de points (civet, grelottine, paris du sirotage) peuvent être considérées comme du jeu simulé ; dans ce cas la classification devient 12+.
- [ ] Vérifier la disponibilité du nom « Cul de Chouette » sur l'App Store et l'absence de marque déposée sur ce nom.

## Proposition de texte

**Sous-titre (fr)** : Le jeu de dés de taverne
**Sous-titre (en)** : The tavern dice game

**Description (fr)** :
Chouettes, velutes, culs de chouette… Réunissez de 2 à 8 amis autour d'un seul téléphone et jouez au célèbre jeu de dés de taverne. Pas de dés ? L'app les lance pour vous, en 2D ou sur une table de taverne en 3D où les dés roulent vraiment. Vous avez les vôtres ? Saisissez les valeurs ou laissez l'appareil photo les lire.
Première partie ? La chouette vous explique chaque lancer en direct, et le livre de règles interactif vous apprend tout en quelques minutes.
Criez « Pas mou le caillou ! » plus vite que les autres, ne soyez pas le dernier à crier « Grelotte ça picote ! », et soyez le premier à 343 points.
