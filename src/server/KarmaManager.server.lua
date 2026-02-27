-- KarmaManager.server.lua — Points Karma Traître / Martyr
-- Couvre E5-S1 à E5-S5
--
-- API publique (_G.KarmaManager) :
--   AddKarma(player, karmaType, amount)   → ajoute des points, notifie le client
--   AwardVictoryBonus(player)             → +3 Karma selon style dominant de la manche
--   ResetRoundTracking()                  → réinitialise les compteurs par manche

local Players    = game:GetService("Players")

local GameConfig = require(game.ServerStorage.Config.GameConfig)
local KarmaModule = require(game.ServerStorage.Modules.KarmaModule)

local Events              = game.ReplicatedStorage:WaitForChild("Events")
local reUpdateKarma       = Events:WaitForChild("UpdateKarma")
local reShowNotif         = Events:WaitForChild("ShowKarmaNotification")

-- ============================================================
-- ÉTAT INTERNE
-- ============================================================

-- Suivi des points gagnés PAR manche (pour le bonus victoire E5-S4)
-- [userId] = { traitor = N, martyr = N }
local roundKarma = {}

-- ============================================================
-- API PUBLIQUE
-- ============================================================

local KarmaManager = {}
_G.KarmaManager = KarmaManager

-- Ajoute des points Karma à un joueur.
-- karmaType  : "traitor" | "martyr"
-- amount     : entier positif (avant multiplicateur)
-- actionType : (optionnel) "kill" | "sacrifice" | "win" — déclenche la progression des défis
function KarmaManager.AddKarma(player, karmaType, amount, actionType)
    if not player or not player.Parent then return end
    if amount <= 0 then return end

    local data = _G.DataManager and _G.DataManager.GetData(player)
    if not data then return end

    -- Applique le multiplicateur Karma Pass (E8)
    local multiplier = 1
    if data.purchases and data.purchases.karmaPass then
        multiplier = GameConfig.Karma.PASS_MULTIPLIER
    end

    local finalAmount = amount * multiplier

    -- Mise à jour du total (persistant)
    if karmaType == "traitor" then
        local oldScore = data.karma.traitor
        data.karma.traitor += finalAmount

        -- Détection de nouveau titre (E5-S5)
        if KarmaModule.IsNewTitle("traitor", oldScore, data.karma.traitor) then
            local newTitle = KarmaModule.GetTitle("traitor", data.karma.traitor)
            reShowNotif:FireClient(player, {
                karmaType = "traitor",
                title     = newTitle,
                points    = finalAmount,
            })
        else
            -- Notification simple sans changement de titre
            reShowNotif:FireClient(player, {
                karmaType = "traitor",
                title     = nil,
                points    = finalAmount,
            })
        end

    elseif karmaType == "martyr" then
        local oldScore = data.karma.martyr
        data.karma.martyr += finalAmount

        if KarmaModule.IsNewTitle("martyr", oldScore, data.karma.martyr) then
            local newTitle = KarmaModule.GetTitle("martyr", data.karma.martyr)
            reShowNotif:FireClient(player, {
                karmaType = "martyr",
                title     = newTitle,
                points    = finalAmount,
            })
        else
            reShowNotif:FireClient(player, {
                karmaType = "martyr",
                title     = nil,
                points    = finalAmount,
            })
        end
    else
        warn("[KarmaManager] Type inconnu : " .. tostring(karmaType))
        return
    end

    -- Suivi par manche
    local userId = player.UserId
    roundKarma[userId] = roundKarma[userId] or { traitor = 0, martyr = 0 }
    roundKarma[userId][karmaType] += finalAmount

    -- Suivi des stats cumulées (pour les badges E11-S6)
    if actionType == "kill" then
        data.stats.trapsKilled += 1
    elseif actionType == "sacrifice" then
        data.stats.sacrificesDone += 1
    end

    -- Badges (E11-S6) — vérifie après chaque action significative
    if actionType and _G.BadgeManager then
        task.spawn(function()
            _G.BadgeManager.CheckBadges(player)
        end)
    end

    -- Informe le client de ses totaux mis à jour
    reUpdateKarma:FireClient(player, {
        traitor       = data.karma.traitor,
        martyr        = data.karma.martyr,
        traitorTitle  = KarmaModule.GetTitle("traitor", data.karma.traitor),
        martyrTitle   = KarmaModule.GetTitle("martyr",  data.karma.martyr),
    })

    -- Mise à jour des classements OrderedDataStore (asynchrone)
    if _G.LeaderboardManager then
        task.spawn(function()
            _G.LeaderboardManager.UpdateScore(player, karmaType, data.karma[karmaType])
        end)
    end

    -- Progression des défis quotidiens (E7-S3) — seulement si action réelle (pas récompense défi)
    if actionType and _G.ChallengeManager then
        task.spawn(function()
            _G.ChallengeManager.UpdateProgress(player, actionType, 1)
        end)
    end

    print(string.format("[KarmaManager] %s +%d %s (total : %d)",
        player.Name, finalAmount, karmaType, data.karma[karmaType]))
end

-- Accorde le bonus victoire au gagnant de la manche (E5-S4)
-- Appelé par RoundManager.endRound(winner)
function KarmaManager.AwardVictoryBonus(player)
    if not player or not player.Parent then return end

    local userId = player.UserId
    local rk = roundKarma[userId] or { traitor = 0, martyr = 0 }
    local style = KarmaModule.GetDominantStyle(rk.traitor, rk.martyr)

    local karmaType
    if style == "traitor" then
        karmaType = "traitor"
    elseif style == "martyr" then
        karmaType = "martyr"
    else
        -- Égalité → on booste les deux de moitié (arrondi supérieur)
        KarmaManager.AddKarma(player, "traitor", math.ceil(GameConfig.Karma.VICTORY_BONUS / 2))
        KarmaManager.AddKarma(player, "martyr",  math.ceil(GameConfig.Karma.VICTORY_BONUS / 2))
        return
    end

    KarmaManager.AddKarma(player, karmaType, GameConfig.Karma.VICTORY_BONUS)
end

-- Réinitialise les compteurs par manche (appelé par RoundManager au départ)
function KarmaManager.ResetRoundTracking()
    roundKarma = {}
end

-- ============================================================
-- NETTOYAGE À LA DÉCONNEXION
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
    roundKarma[player.UserId] = nil
end)

print("[KarmaManager] ✅ Prêt")
