# Règles implémentées — variante de référence

Ce document décrit exactement ce que fait le moteur (`Packages/ChouetteKit`).
Chaque valeur marquée ⚙︎ est réglable dans `RuleSet`. Les tests vérifient chaque règle.

**Par défaut, la règle traditionnelle s'applique.** Trois points peuvent être adoucis
dans les réglages (marqués 🪶 ci-dessous), un par un ou tous ensemble avec le
préréglage « Règles allégées » (`RuleSet.light` / `applyLightVariants()`).

## Déroulement

- 2 à 8 joueurs jouent chacun leur tour et lancent 3 dés.
- La partie se termine dès qu'un joueur atteint **343 points ⚙︎**. On vérifie à la fin de chaque tour, et aussitôt après une grelottine.
- Si plusieurs joueurs dépassent la cible en même temps (par exemple grâce à un réflexe), le meilleur score gagne. En cas d'égalité, la victoire revient au joueur courant, puis aux suivants dans l'ordre du tour.
- **Mode exact ⚙︎** (désactivé par défaut) : il faut atteindre 343 pile, et l'excédent est retranché (350 → 336).
- **Les scores négatifs sont autorisés ⚙︎.** Si on les interdit, un score ne descend jamais sous 0.

## Figures de base

| Figure | Exemple | Effet |
|---|---|---|
| **Cul de chouette** : trois dés identiques | 5-5-5 | Le lanceur marque **40 + 10 × valeur ⚙︎** (50 à 100) |
| **Chouette** : deux dés identiques | 4-4-1 | Le lanceur marque **valeur² ⚙︎** (1 à 36) |
| **Velute** : deux dés dont la somme égale le troisième | 1-4-5 | Le lanceur marque **2 × (grand dé)² ⚙︎** (18 à 72) |
| **Chouette-velute** | 1-1-2, 2-2-4, 3-3-6 uniquement | Mini-jeu « Pas mou le caillou ! » : le **premier** à crier marque la velute. Le lanceur ne marque rien, sauf s'il crie le premier ⚙︎ |
| **Suite** : trois valeurs consécutives | 3-4-5 | Mini-jeu « Grelotte ça picote ! » : le **dernier** à crier perd **10 points ⚙︎** |
| **Néant** | 1-3-6 | 0 point |

- **1-2-3** est à la fois une velute et une suite. Par défaut ⚙︎, le lanceur marque la velute (18), puis on joue la suite.
- **Mini-jeux de réflexe** : tous les joueurs y participent, lanceur compris.
  - « Grelotte ça picote ! » : le dernier à crier perd. Si certains n'ont pas tapé avant la fin du temps imparti, ils sont tous à égalité au dernier rang et **perdent tous**. Si tout le monde a tapé, seul le dernier perd.
    - 🪶 Allégée (`suiteLosers = .lastTapperOnly`) : seuls ceux qui ont tapé comptent, et le plus lent d'entre eux perd. Si personne n'a tapé, personne ne perd.
  - « Pas mou le caillou ! » : si personne ne tape, personne ne marque.
- Sur 216 lancers possibles : 6 culs de chouette, 81 chouettes, 9 chouettes-velutes, 36 velutes, 24 suites (dont les 6 « 1-2-3 ») et 66 néants.

## Règles avancées (chacune activable séparément)

### Sirotage
- Après une **chouette simple**, le lanceur peut siroter : il annonce le nom de sa chouette (1 Linotte, 2 Alouette, 3 Fauvette, 4 Mouette, 5 Bergeronnette, 6 Chouette) et relance le dé restant.
- Il n'y a pas de sirotage sur une chouette-velute ni sur un cul de chouette.
- **S'il réussit** (le dé donne la valeur de la paire), il marque les points du **cul de chouette**.
- **S'il échoue**, il **perd** les points de sa chouette. On ne regarde pas les autres figures que pourrait former le dé relancé.
  - 🪶 Allégée (`sirotage.failure = .scoreNothing`) : il ne marque rien, sans perte.
- **Paris ⚙︎** : avant la relance, chaque autre joueur peut parier sur une valeur de 1 à 6. Un pari juste rapporte **25 points ⚙︎**, que le sirotage réussisse ou non.

### Bévue
- Pendant un mini-jeu de réflexe, taper **avant le signal** est un faux départ, qui coûte **10 points ⚙︎**.
- Ce tap ne compte pas dans l'ordre de passage.

### Civet
- Avant son lancer, un joueur peut parier de **1 à 102 points ⚙︎** sur la figure qu'il va obtenir.
- Il a droit à **1 civet par partie ⚙︎**.
- S'il obtient la figure, il gagne la mise. Sinon, il la perd. Les points de la figure s'ajoutent normalement.
- Le civet se décide sur le lancer principal, avant un éventuel sirotage.

### Grelottine
- Un **néant** donne une grelottine au lanceur. On ne peut en détenir qu'une à la fois.
- Au début de son tour, avant de lancer, le détenteur peut défier un autre joueur : il choisit une figure et une mise.
- La mise va de 1 à **50 ⚙︎**, quels que soient les scores : on peut défier un joueur à 0 point, et les scores peuvent devenir négatifs.
  - 🪶 Allégée (`grelottine.stakeLimitedByScores = true`) : la mise ne dépasse ni le score du défieur ni celui de l'adversaire, donc un joueur à 0 point ne peut pas être défié.
- Le joueur défié lance les dés :
  - s'il obtient la figure, il prend la mise au défieur ;
  - sinon, c'est le défieur qui prend la mise.
- Le défieur joue ensuite son tour normalement.

## Réglages

Les règles avancées n'ont pas de texte officiel unique. Les versions par défaut sont les plus strictes, celles que la communauté pratique le plus. Toutes les valeurs ⚙︎ et les variantes 🪶 seront exposées dans l'écran des réglages en phase 2.
