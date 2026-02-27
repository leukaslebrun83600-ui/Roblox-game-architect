-- ChallengeConfig.lua — Pool de tous les défis quotidiens disponibles
--
-- Chaque défi :
--   id          : identifiant unique
--   type        : "kill" | "sacrifice" | "win"  (clé d'action pour UpdateProgress)
--   description : texte affiché au joueur
--   goal        : nombre d'actions à accomplir
--   reward      : Karma accordé à la complétion (+5 à +10)
--   karmaType   : "traitor" | "martyr"  (type du Karma récompense)
--   singleRound : true = progression remise à 0 à chaque nouvelle manche

local ChallengeConfig = {}

ChallengeConfig.DAILY_COUNT = 3   -- nombre de défis sélectionnés chaque jour

ChallengeConfig.POOL = {

    -- ── DÉFIS TRAÎTRE (pièges) ───────────────────────────
    {
        id          = "kill_easy",
        type        = "kill",
        description = "Élimine 2 joueurs avec des pièges",
        goal        = 2,
        reward      = 5,
        karmaType   = "traitor",
        singleRound = false,
    },
    {
        id          = "kill_medium",
        type        = "kill",
        description = "Élimine 4 joueurs avec des pièges",
        goal        = 4,
        reward      = 8,
        karmaType   = "traitor",
        singleRound = false,
    },
    {
        id          = "kill_hard",
        type        = "kill",
        description = "Élimine 7 joueurs avec des pièges",
        goal        = 7,
        reward      = 10,
        karmaType   = "traitor",
        singleRound = false,
    },
    {
        id          = "kill_round_easy",
        type        = "kill",
        description = "Élimine 2 joueurs en une seule manche",
        goal        = 2,
        reward      = 7,
        karmaType   = "traitor",
        singleRound = true,
    },
    {
        id          = "kill_round_hard",
        type        = "kill",
        description = "Élimine 3 joueurs en une seule manche",
        goal        = 3,
        reward      = 10,
        karmaType   = "traitor",
        singleRound = true,
    },

    -- ── DÉFIS MARTYR (sacrifices) ────────────────────────
    {
        id          = "sacrifice_easy",
        type        = "sacrifice",
        description = "Sacrifie-toi 2 fois pour tes alliés",
        goal        = 2,
        reward      = 5,
        karmaType   = "martyr",
        singleRound = false,
    },
    {
        id          = "sacrifice_medium",
        type        = "sacrifice",
        description = "Sacrifie-toi 4 fois pour tes alliés",
        goal        = 4,
        reward      = 8,
        karmaType   = "martyr",
        singleRound = false,
    },
    {
        id          = "sacrifice_hard",
        type        = "sacrifice",
        description = "Sacrifie-toi 6 fois pour tes alliés",
        goal        = 6,
        reward      = 10,
        karmaType   = "martyr",
        singleRound = false,
    },

    -- ── DÉFIS VICTOIRE ───────────────────────────────────
    {
        id          = "win_1",
        type        = "win",
        description = "Remporte 1 manche",
        goal        = 1,
        reward      = 7,
        karmaType   = "martyr",
        singleRound = false,
    },
    {
        id          = "win_3",
        type        = "win",
        description = "Remporte 3 manches",
        goal        = 3,
        reward      = 10,
        karmaType   = "traitor",
        singleRound = false,
    },
}

return ChallengeConfig
