-- KarmaModule — Calculs Karma (titres, seuils, multiplicateurs)
-- Couvre E5-S5 (calcul du titre selon score)
--
-- Utilisé par KarmaManager pour déterminer le titre affiché.

local GameConfig = require(game.ServerStorage.Config.GameConfig)

local KarmaModule = {}

-- ============================================================
-- TITRES
-- ============================================================

-- Retourne le titre correspondant à un score donné.
-- karmaType : "traitor" ou "martyr"
-- score     : nombre entier (total de points accumulés)
function KarmaModule.GetTitle(karmaType, score)
    local list = karmaType == "traitor"
        and GameConfig.Karma.TRAITOR_TITLES
        or  GameConfig.Karma.MARTYR_TITLES

    -- Les seuils sont triés du plus élevé au plus bas
    -- On cherche le premier seuil que le score dépasse
    for _, entry in ipairs(list) do
        if score >= entry.threshold then
            return entry.title
        end
    end

    -- Fallback (ne devrait jamais arriver car threshold=0 est en dernière position)
    return "Novice"
end

-- Retourne true si le nouveau score franchit un palier de titre
-- (pour déclencher une notification au joueur)
function KarmaModule.IsNewTitle(karmaType, oldScore, newScore)
    return KarmaModule.GetTitle(karmaType, oldScore)
        ~= KarmaModule.GetTitle(karmaType, newScore)
end

-- ============================================================
-- STYLE DOMINANT (pour le bonus victoire E5-S4)
-- ============================================================

-- Détermine le style dominant d'un joueur sur la manche en cours.
-- roundTraitor, roundMartyr : points gagnés DANS cette manche uniquement
-- Retourne "traitor", "martyr", ou "neutral" si égalité/zéro
function KarmaModule.GetDominantStyle(roundTraitor, roundMartyr)
    if roundTraitor > roundMartyr then
        return "traitor"
    elseif roundMartyr > roundTraitor then
        return "martyr"
    else
        return "neutral"
    end
end

return KarmaModule
