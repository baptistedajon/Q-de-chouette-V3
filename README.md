# Cul de Chouette

Application iOS pour jouer au Cul de Chouette, le jeu de dés de taverne, de 2 à 8 joueurs sur un seul appareil.
Pas besoin de connaître les règles ni d'avoir des dés : l'app explique tout et lance les dés pour vous.

## Fonctionnalités

- **Quatre façons de lancer** : dés virtuels 2D, table de taverne 3D avec physique réelle (secouer le téléphone ou lancer d'un geste ; la valeur est celle de la face réellement tournée vers le haut), vrais dés saisis à la main, ou vrais dés lus par l'appareil photo.
- **Mini-jeux de cri** (« Pas mou le caillou ! », « Grelotte ça picote ! ») : une zone de tap par joueur sur l'écran partagé, chronométrage au toucher près, faux départs.
- **Règles configurables** : règles traditionnelles par défaut, variantes allégées, règles avancées (sirotage, bévue, civet, grelottine), barème. Voir [RULES.md](RULES.md).
- **Apprentissage** : livre de règles interactif (exemples animés, testeur de lancer, entraînement au réflexe) et partie guidée qui explique chaque lancer.
- **Suivi** : sauvegarde automatique, annulation, tableau des scores, statistiques, historique, écran de victoire.
- **Finitions** : sons et musique synthétisés, vibrations, VoiceOver, Dynamic Type, Réduire les animations, mode sombre, français et anglais.

## Prérequis

- Xcode 26 ou plus récent, iOS 18 minimum (iPhone et iPad).
- Aucune dépendance externe.

## Architecture

```
Packages/ChouetteKit/          Logique pure, sans interface, testée (Swift Testing)
  Sources/ChouetteRules/
    Dice, Figures, RuleSet       dés, combinaisons, barème, règles configurables
    GameEngine, GameModel        machine à états de la partie (actions → événements)
    ReflexSession                logique des mini-jeux de cri
    GameStatistics, Teaching     statistiques, exemples et détail des calculs
    DiePhysics                   lecture de la face du dessus d'un dé 3D, détection d'arrêt
    DiceRecognizer               reconnaissance de dés sur une image
Q de Chouette/                 Application SwiftUI (MVVM, SwiftData)
  App/ Design/ Model/            navigation, thème, persistance, réglages, sons, textes
  Features/                      Home, Setup, Game, Reflex, Table3D, Camera, Rules,
                                 Scoreboard, History, Settings
Tools/                         Scripts : icône, photo de test pour la reconnaissance
```

Le moteur ne lance jamais les dés : il reçoit leurs valeurs, quelle que soit leur origine (2D, 3D, caméra, saisie).
Chaque action produit des événements, utilisés pour l'affichage, les sons, les vibrations et la partie guidée.

## Tests

```bash
cd Packages/ChouetteKit && swift test
```

Pour tester la reconnaissance caméra sur simulateur (pas d'appareil photo), générer une photo de dés et l'ajouter à la photothèque :

```bash
swift Tools/render-test-dice-photo.swift des.jpg && xcrun simctl addmedia booted des.jpg
```

## Documents

- [RULES.md](RULES.md) : règles exactes implémentées.
- [ASSETS.md](ASSETS.md) : éléments provisoires à remplacer par des créations professionnelles.
- [APPSTORE.md](APPSTORE.md) : préparation de la soumission.
