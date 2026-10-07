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
| Typographie des titres | `Design/Theme.swift` | Serif du système (New York) | Police médiévale lisible sous licence OFL (prévue : IM Fell English) — phase 6 |
| Icône de l'app | `Assets.xcassets` | Aucune | Icône originale 1024×1024 — phase 6 |
| Sons | — | Aucun | Phase 6 |
| Table de taverne 3D | `Features/Table3D/DiceTable3D.swift` (`makeTable`) | Boîte en code + texture de veines générée | Modèle USDZ de table en chêne avec textures PBR (couleur, normale, rugosité) |
| Dés 3D | `DiceTable3D.makeDie` | Cube arrondi + points en sphères | Modèle USDZ de dé en os/ivoire gravé. **Garder l'orientation des faces** de `DieOrientation` (1 en +Y, 2 en +X, 3 en +Z) |
| Bougies, parchemin, gobelet | `DiceTable3D.makeDecor` | Cylindres et boîtes en code | Modèles USDZ ; garder les `PointLight` des flammes |
| Environnement (murs, sol) | `DiceTable3D.makeTable` | Sol uni sombre | Décor de taverne ou image d'environnement (IBL) |
