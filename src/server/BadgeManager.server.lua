-- BadgeManager.server.lua — Attribution des badges Roblox (E11-S6)
--
-- API publique (_G.BadgeManager) :
--   CheckBadges(player) → vérifie et attribue tous les badges mérités
--
-- ⚠ Remplace les 0 par les vrais Badge IDs depuis :
--   Creator Hub → ton jeu → Engagement → Badges → (créer puis copier l'ID)

local BadgeService = game:GetService("BadgeService")
local Players      = game:GetService("Players")

-- ============================================================
-- IDS DES BADGES
-- ============================================================

local BADGE_IDS = {
    firstRound     = 0,   -- "Première manche"   : jouer 1 manche complète
    firstKill      = 0,   -- "Premier sang"       : éliminer un joueur
    firstSacrifice = 0,   -- "Premier sacrifice"  : se sacrifier
    firstWin       = 0,   -- "Première victoire"  : terminer 1er
    killer10       = 0,   -- "Sans pitié"         : 10 kills cumulés
    sacrifice5     = 0,   -- "Esprit noble"       : 5 sacrifices cumulés
    win5           = 0,   -- "Champion"           : 5 victoires cumulées
    traitorLegend  = 0,   -- "Traître Légendaire" : 150 Karma Traître
    martyrLegend   = 0,   -- "Martyr Légendaire"  : 150 Karma Martyr
}

-- ============================================================
-- UTILITAIRE : ATTRIBUER UN BADGE (async, silencieux si déjà obtenu)
-- ============================================================

local function award(player, badgeId)
    if badgeId == 0 then return end  -- ID non configuré → on saute

    task.spawn(function()
        -- Vérifie si le joueur l'a déjà (évite les appels inutiles à l'API)
        local okHas, hasIt = pcall(function()
            return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
        end)
        if not okHas then return end  -- erreur réseau → on abandonne silencieusement
        if hasIt then return end

        local okAward = pcall(function()
            BadgeService:AwardBadge(player.UserId, badgeId)
        end)
        if okAward then
            print(string.format("[BadgeManager] Badge %d → %s", badgeId, player.Name))
        end
    end)
end

-- ============================================================
-- API PUBLIQUE
-- ============================================================

local BadgeManager = {}
_G.BadgeManager = BadgeManager

-- Vérifie l'ensemble des seuils et attribue les badges mérités.
-- Appelé après chaque action significative (fin de manche, kill, sacrifice).
function BadgeManager.CheckBadges(player)
    if not player or not player.Parent then return end

    local data = _G.DataManager and _G.DataManager.GetData(player)
    if not data then return end

    local stats = data.stats
    local karma = data.karma

    -- ── Stats ─────────────────────────────────────────────────
    if stats.roundsPlayed >= 1 then
        award(player, BADGE_IDS.firstRound)
    end
    if stats.roundsWon >= 1 then
        award(player, BADGE_IDS.firstWin)
    end
    if stats.roundsWon >= 5 then
        award(player, BADGE_IDS.win5)
    end
    if stats.trapsKilled >= 1 then
        award(player, BADGE_IDS.firstKill)
    end
    if stats.trapsKilled >= 10 then
        award(player, BADGE_IDS.killer10)
    end
    if stats.sacrificesDone >= 1 then
        award(player, BADGE_IDS.firstSacrifice)
    end
    if stats.sacrificesDone >= 5 then
        award(player, BADGE_IDS.sacrifice5)
    end

    -- ── Karma ──────────────────────────────────────────────────
    if karma.traitor >= 150 then
        award(player, BADGE_IDS.traitorLegend)
    end
    if karma.martyr >= 150 then
        award(player, BADGE_IDS.martyrLegend)
    end
end

-- ============================================================
-- NETTOYAGE (pas d'état interne à libérer pour ce manager)
-- ============================================================

print("[BadgeManager] ✅ Prêt")
