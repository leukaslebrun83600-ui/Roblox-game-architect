-- ChallengeModule — Utilitaires pour les défis quotidiens
-- Couvre E7-S1 (sélection), E7-S2 (reset)
--
-- Stateless : pas d'état interne, que des fonctions pures.

local ChallengeModule = {}

-- ============================================================
-- CLÉ JOURNALIÈRE
-- ============================================================

-- Retourne un entier représentant le jour UTC courant (jours depuis epoch).
-- Change à minuit UTC. Sert de clé pour détecter le reset.
function ChallengeModule.GetTodayKey()
    return math.floor(os.time() / 86400)
end

-- Retourne true si les défis doivent être réinitialisés
-- (nouveau jour ou jamais initialisés)
function ChallengeModule.NeedsReset(lastResetKey)
    return ChallengeModule.GetTodayKey() ~= (lastResetKey or -1)
end

-- ============================================================
-- SÉLECTION ALÉATOIRE
-- ============================================================

-- Mélange une table en place (Fisher-Yates)
local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

-- Sélectionne n défis aléatoires depuis le pool.
-- Retourne une table de copies indépendantes (avec progress=0, completed=false).
function ChallengeModule.SelectChallenges(pool, n)
    -- Copie le pool pour ne pas modifier l'original
    local shuffled = {}
    for _, def in ipairs(pool) do
        table.insert(shuffled, def)
    end
    shuffle(shuffled)

    local selected = {}
    for i = 1, math.min(n, #shuffled) do
        local def = shuffled[i]
        -- Crée une instance avec état initial
        table.insert(selected, {
            id          = def.id,
            type        = def.type,
            description = def.description,
            goal        = def.goal,
            reward      = def.reward,
            karmaType   = def.karmaType,
            singleRound = def.singleRound or false,
            progress    = 0,
            completed   = false,
        })
    end

    return selected
end

return ChallengeModule
