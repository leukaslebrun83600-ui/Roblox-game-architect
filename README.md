# Roblox Game Architect

> Framework pour architecturer un jeu Roblox de A à Z avant d'écrire une seule ligne de code.

**Règle absolue : on ne code RIEN tant que TOUT n'est pas documenté.**

## Pourquoi ?

Un jeu Roblox, c'est un vrai projet logiciel : systèmes interconnectés, économie à équilibrer, UX à penser, architecture client/serveur à sécuriser. Les créateurs qui foncent dans le code sans plan finissent par tout refaire 5 fois.

Ce framework force une approche méthodique en **5 phases** :

| Phase | Nom | Ce qu'on fait |
|-------|-----|---------------|
| 0 | **Oracle** | Valider que l'idée de jeu vaut le coup |
| 1 | **Vision** | Définir le concept global (pitch, core loop, public) |
| 2 | **Game Design** | Détailler chaque aspect du jeu (13 documents) |
| 3 | **Architecture** | Planifier le code technique (Roblox Studio) |
| 4 | **Production** | Découper en tâches de dev ordonnées |

Ensuite seulement : on ouvre Roblox Studio et on code, story par story.

## Comment l'utiliser

### Prérequis

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installé (CLI)
- Un terminal (Mac/Linux/Windows WSL)

### Installation

```bash
# Cloner le repo
git clone https://github.com/yanmusic/roblox-game-architect.git mon-jeu

# Aller dans le dossier
cd mon-jeu

# Lancer Claude Code
claude
```

Claude détecte automatiquement le `CLAUDE.md` et se met en mode Architecte de Jeu.

### Première interaction

Dis simplement :
- **"J'ai une idée de jeu"** → Claude évalue ton idée (scoring /100)
- **"Aide-moi à trouver une idée"** → Claude te guide par genre (simulateur, RPG, tycoon...)

Claude te pose des questions, remplit les documents, et te guide phase par phase.

## Structure

```
├── CLAUDE.md                    ← Instructions pour Claude (le cerveau)
├── _output/                     ← Documents générés (ton game design)
├── 0-oracle/                    ← Scoring d'idée (4 axes, /100)
├── 1-vision/                    ← Concept global du jeu
├── 2-game-design/               ← 13 PRD couvrant TOUT le jeu
│   ├── 01-core-loop             ← Boucle de gameplay
│   ├── 02-mecaniques            ← Chaque mécanique détaillée
│   ├── 03-monde                 ← Zones, map, navigation
│   ├── 04-progression           ← Niveaux, XP, déverrouillages
│   ├── 05-economie              ← Monnaies, prix, équilibre
│   ├── 06-ui-hud                ← Écrans, menus, boutons
│   ├── 07-social                ← Multijoueur, équipes, chat
│   ├── 08-items-inventaire      ← Objets, raretés, crafting
│   ├── 09-pnj-ennemis           ← IA, boss, comportements
│   ├── 10-audio-visuel          ← Style graphique, sons, musique
│   ├── 11-onboarding            ← Tutoriel, première expérience
│   ├── 12-monetisation          ← Game Passes, éthique, revenus
│   └── 13-evenements            ← Events, updates, roadmap
├── 3-architecture/              ← Plan technique Roblox Studio
├── 4-production/                ← Epics & Stories de dev
└── 5-implementation/            ← Conventions de code Luau
```

## Les 13 PRD de Game Design

Chaque aspect du jeu a son propre document de design. Impossible de passer au code sans les avoir complétés :

| # | Document | Question clé |
|---|----------|-------------|
| 01 | Core Loop | Qu'est-ce que le joueur fait encore et encore ? |
| 02 | Mécaniques | Comment chaque action fonctionne exactement ? |
| 03 | Monde & Map | Où se passe le jeu ? Quelles zones ? |
| 04 | Progression | Comment le joueur évolue et monte en puissance ? |
| 05 | Économie | D'où vient l'argent in-game, où va-t-il ? |
| 06 | UI & HUD | Que voit le joueur à l'écran ? |
| 07 | Social | Comment les joueurs interagissent entre eux ? |
| 08 | Items | Quels objets, quelles raretés, quel loot ? |
| 09 | PNJ & Ennemis | Quels ennemis, quelle IA, quels boss ? |
| 10 | Audio & Visuel | Quel style, quels sons, quelle ambiance ? |
| 11 | Onboarding | Le joueur comprend-il le jeu en 2 minutes ? |
| 12 | Monétisation | Comment le jeu gagne de l'argent (sans pay-to-win) ? |
| 13 | Événements | Comment le jeu reste vivant après le lancement ? |

## Scoring Oracle (Phase 0)

Chaque idée est évaluée sur 4 axes :

| Axe | /25 | Ce qu'on évalue |
|-----|-----|-----------------|
| **FUN** | /25 | Core loop addictif, rejouabilité, originalité |
| **MARCHÉ** | /25 | Demande, concurrence, timing |
| **FAISABILITÉ** | /25 | Complexité technique, assets, temps au MVP |
| **MONÉTISATION** | /25 | Game Passes naturels, éthique, potentiel |

- **75+ : GO** — on passe au design
- **50-74 : À retravailler** — itérer sur les points faibles
- **< 50 : KILL** — changer d'idée

## Conçu pour

- Des créateurs Roblox qui veulent structurer leur projet
- Des équipes (même petites) qui veulent éviter de refaire le même système 5 fois
- Des débutants qui découvrent Claude Code et veulent un guide pas à pas

## Licence

MIT — Faites-en ce que vous voulez.
