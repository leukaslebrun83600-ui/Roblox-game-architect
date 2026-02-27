-- GameConfig.lua — Constantes centralisées de Trust No One
-- Source : PRD 01, 02, 04, 12 + Architecture technique
--
-- RÈGLE : on ne met jamais de "magic numbers" ailleurs dans le code.
-- Si une valeur doit changer (équilibrage, patch), on la change ICI uniquement.

local GameConfig = {}

-- ============================================================
-- MANCHE (ROUND)
-- ============================================================
GameConfig.Round = {
    WAITING_COUNTDOWN  = 5,    -- (s) compte à rebours en salle d'attente avant le départ
    DURATION           = 300,  -- (s) durée max d'une manche (5 minutes)
    RESULTS_DURATION   = 10,   -- (s) écran de résultats avant retour au lobby
    MIN_PLAYERS        = 1,    -- 1 pour tester en solo (remettre 40 avant de publier)
    MAX_PLAYERS        = 60,   -- joueurs maximum par tournoi
    -- Qualification : arriver = qualifié, mourir = éliminé (pas de ratio)
}

-- ============================================================
-- PIÈGES
-- ============================================================
GameConfig.Traps = {
    ACTIVATION_RADIUS      = 5,   -- (studs) distance max joueur → bouton pour activer
    PLAYER_COOLDOWN        = 25,  -- (s) cooldown entre deux activations du même joueur (PRD 01 : "20-30s")
    COLLAPSED_FLOOR_DELAY  = 3,   -- (s) durée pendant laquelle les plateformes sont effondrées (PRD 02)
}

-- ============================================================
-- KARMA
-- ============================================================
GameConfig.Karma = {
    -- Points gagnés par action
    TRAP_KILL        = 1,  -- Traître : tuer un joueur via piège
    SACRIFICE        = 1,  -- Martyr  : activer un bouton Sacrifice
    VICTORY_BONUS    = 3,  -- bonus accordé au gagnant de manche (style dominant)
    PASS_MULTIPLIER  = 2,  -- multiplicateur si le joueur a le Karma Pass

    -- Titres Traître (seuils croissants, vérifiés de bas en haut)
    TRAITOR_TITLES = {
        { threshold = 150, title = "Traître Légendaire" },
        { threshold = 75,  title = "Grand Traître"      },
        { threshold = 30,  title = "Traître Confirmé"   },
        { threshold = 10,  title = "Faux Ami"           },
        { threshold = 0,   title = "Novice"             },
    },

    -- Titres Martyr (seuils croissants, vérifiés de bas en haut)
    MARTYR_TITLES = {
        { threshold = 150, title = "Martyr Légendaire" },
        { threshold = 75,  title = "Grand Martyr"      },
        { threshold = 30,  title = "Martyr Confirmé"   },
        { threshold = 10,  title = "Âme Pure"          },
        { threshold = 0,   title = "Novice"            },
    },
}

-- ============================================================
-- DATASTORE
-- ============================================================
GameConfig.DataStore = {
    KEY_PREFIX           = "PlayerData_",       -- clé = KEY_PREFIX .. player.UserId
    SCHEMA_VERSION       = 1,                   -- incrémenter si la structure des données change
    AUTOSAVE_INTERVAL    = 300,                 -- (s) sauvegarde automatique toutes les 5 min
    RETRY_COUNT          = 3,                   -- tentatives max en cas d'échec DataStore
    LEADERBOARD_TRAITOR  = "Leaderboard_Traitor",
    LEADERBOARD_MARTYR   = "Leaderboard_Martyr",
    LEADERBOARD_REFRESH  = 60,                  -- (s) intervalle de refresh des panneaux lobby
}

-- ============================================================
-- MONETISATION
-- ⚠ Mettre les vrais IDs Roblox avant de publier le jeu.
--   Les obtenir dans : Créer → Expérience → Monétisation
-- ============================================================
GameConfig.Monetisation = {
    -- Game Passes (achats uniques permanents)
    PASS_KARMA_ID          = 0,  -- Karma Pass        — 299 R$
    PASS_DEATH_EFFECTS_ID  = 0,  -- Effets de mort    — 149 R$
    PASS_RADIO_ID          = 0,  -- Radio / Boombox   — 249 R$

    -- Developer Products (achats répétables)
    PRODUCT_SKIP_ID   = 0,  -- Skip Checkpoint   — 50 R$
    PRODUCT_SHIELD_ID = 0,  -- Bouclier défensif — 25 R$

    SHIELD_DURATION = 10,  -- (s) durée d'invincibilité du bouclier défensif
}

-- ============================================================
-- SÉCURITÉ (anti-exploit)
-- ============================================================
GameConfig.Security = {
    RATE_LIMIT_PER_SECOND = 5,  -- requêtes RemoteEvent max par joueur/sec avant rejet
}

-- ============================================================
-- STRUCTURE DU TOURNOI (Fall Guys)
-- ============================================================
GameConfig.Tournament = {
    -- Chaque entrée = une manche du tournoi (dans l'ordre)
    -- qualify = nombre de joueurs qui passent à la manche suivante
    -- label   = affiché dans l'UI (type de manche)
    ROUNDS = {
        { qualify = 30, label = "Course Simple"         },  -- Manche 1 : 40 → 30
        { qualify = 18, label = "Course à Obstacles"    },  -- Manche 2 : 30 → 18
        { qualify = 10, label = "Survie"                },  -- Manche 3 : 18 → 10
        { qualify = 6,  label = "Demi-Finale"           },  -- Manche 4 : 10 → 6
        { qualify = 1,  label = "FINALE"                },  -- Manche 5 :  6 → 1 champion
    },
}

-- ============================================================
-- MAP
-- ============================================================
GameConfig.Map = {
    SECTION_COUNT = 8,  -- nombre de sections dans le parcours
}

return GameConfig
