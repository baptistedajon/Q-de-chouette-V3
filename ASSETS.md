# Assets provisoires à remplacer

Tous les éléments ci-dessous sont **originaux** (générés par le code ou issus des polices
et emojis du système) et peuvent être livrés tels quels, mais gagneraient à être remplacés
par des créations professionnelles avant la sortie.

| Élément | Où | Actuellement | À remplacer par |
|---|---|---|---|
| Avatars des joueurs | `Model/Avatar.swift` | Emoji système sur un écu dessiné en code | 12 illustrations médiévales originales (PDF vectoriel ou PNG @2x/@3x), même cadrage en écu |
| Logo / illustration d'accueil | `Features/Home/HomeView.swift` | Emoji 🦉 | Illustration originale de chouette |
| Dés 2D | `Design/DieView.swift` | Dessinés en code (ivoire, points d'encre) | Peut rester ; éventuellement texture os/bois |
| Tapis de jeu 2D | `Features/Game/GameView.swift` (`DiceTray`) | Dégradé vert + bordure bois | Texture feutre / bois |
| Typographie des titres | `Design/Theme.swift` (`title`, `heading`) | Serif du système (New York), Dynamic Type complet | Police médiévale lisible sous licence OFL (ex. IM Fell English) : ajouter le fichier `.ttf`, `UIAppFonts`, et `Font.custom(…, relativeTo:)` dans ces deux fonctions |
| Icône de l'app | `Assets.xcassets/AppIcon.appiconset` (générée par `Tools/render-app-icon.swift`) | Chouette géométrique sur fond vin | Icône dessinée par un illustrateur, 1024×1024, variantes sombre et teintée |
| Bruitages (dés, gobelet, cloche, fanfare) | `Model/SoundEngine.swift` (`Synth`) | Synthétisés en code ; aperçus WAV dans `Docs/Sons (aperçu)/` | Enregistrements de dés en os sur bois, gobelet en cuir ; garder des sons courts (< 1 s) |
| Musique et ambiance | `SoundEngine.swift` (`luteTune`, `tavernAmbience`) | Air de luth (Karplus-Strong) + feu de cheminée synthétiques | Musique médiévale originale (luth, flûte) et ambiance de taverne enregistrée, en boucle |
| Table de taverne 3D | `Features/Table3D/DiceTable3D.swift` (`makeTable`) | Boîte en code + texture de veines générée | Modèle USDZ de table en chêne avec textures PBR (couleur, normale, rugosité) |
| Dés 3D | `DiceTable3D.makeDie` | Cube arrondi + points en sphères | Modèle USDZ de dé en os/ivoire gravé. **Garder l'orientation des faces** de `DieOrientation` (1 en +Y, 2 en +X, 3 en +Z) |
| Bougies, parchemin, gobelet | `DiceTable3D.makeDecor` | Cylindres et boîtes en code | Modèles USDZ ; garder les `PointLight` des flammes |
| Environnement (murs, sol) | `DiceTable3D.makeTable` | Sol uni sombre | Décor de taverne ou image d'environnement (IBL) |
