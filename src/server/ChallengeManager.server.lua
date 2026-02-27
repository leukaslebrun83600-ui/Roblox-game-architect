-- ChallengeManager.server.lua — Défis Quotidiens
-- Couvre E7-S1 (sélection), E7-S2 (reset UTC), E7-S3 (progression), E7-S4 (récompense)
--
-- API publique (_G.ChallengeManager) :
--   UpdateProgress(player, actionType, amount)  → met à jour les défis concernés
--   ResetRoundProgress(player)                  → réinitialise les défis singleRound
--   GetChallenges(player)                       → retourne les 3 défis courants

local Players = game:GetService("Players")

local ChallengeConfig = require(game.ServerStorage.Config.ChallengeConfig)
local ChallengeModule = require(game.ServerStorage.Modules.ChallengeModule)

local Events            = game.ReplicatedStorage:WaitForChild("Events")
local reUpdateChallenges = Events:WaitForChild("UpdateChallenges")
local fnGetChallenges    = Events:WaitForChild("GetChallenges")

-- ============================================================
-- UTILITAIRES INTERNES
-- ============================================================

-- S'assure que le joueur a des défis valides pour aujourd'hui.
-- Sélectionne de nouveaux défis si besoin (premier login ou nouveau jour).
local function ensureChallenges(player)
    local data = _G.DataManager and _G.DataManager.GetData(player)
    if not data then return end

    -- Initialise la structure si absente (migration E1)
    if type(data.challenges) ~= "table" then
        data.challenges = { daily = {}, lastReset = -1 }
    end
    if type(data.challenges.daily) ~= "table" then
        data.challenges.daily = {}
    end

    -- Reset quotidien (E7-S2)
    if ChallengeModule.NeedsReset(data.challenges.lastReset) then
        data.challenges.daily    = ChallengeModule.SelectChallenges(
            ChallengeConfig.POOL,
            ChallengeConfig.DAILY_COUNT
        )
        data.challenges.lastReset = ChallengeModule.GetTodayKey()
        print(string.format("[ChallengeManager] Nouveaux défis pour %s (jour %d)",
            player.Name, data.challenges.lastReset))

        -- Notifie le client immédiatement
        reUpdateChallenges:FireClient(player, data.challenges.daily)
    end
end

-- Envoie la liste des défis au client
local function notifyClient(player)
    local data = _G.DataManager and _G.DataManager.GetData(player)
    if not data or not data.challenges then return end
    reUpdateChallenges:FireClient(player, data.challenges.daily)
end

-- ============================================================
-- API PUBLIQUE
-- ============================================================

local ChallengeManager = {}
_G.ChallengeManager = ChallengeManager

-- Met à jour la progression des défis correspondant à une action.
-- actionType : "kill" | "sacrifice" | "win"
-- amount     : entier (généralement 1)
function ChallengeManager.UpdateProgress(player, actionType, amount)
    if not player or not player.Parent then return end
    amount = amount or 1

    ensureChallenges(player)

    local data = _G.DataManager and _G.DataManager.GetData(player)
    if not data or not data.challenges or not data.challenges.daily then return end

    local changed = false

    for _, challenge in ipairs(data.challenges.daily) do
        -- Ignore les défis déjà complétés ou de type différent
        if not challenge.completed and challenge.type == actionType then
            challenge.progress = math.min(challenge.progress + amount, challenge.goal)
            changed = true

            -- Complétion (E7-S4)
            if challenge.progress >= challenge.goal then
                challenge.completed = true

                print(string.format("[ChallengeManager] %s complète '%s' → +%d %s",
                    player.Name, challenge.id, challenge.reward, challenge.karmaType))

                -- Attribution Karma de récompense
                if _G.KarmaManager then
                    _G.KarmaManager.AddKarma(player, challenge.karmaType, challenge.reward)
                end
            end
        end
    end

    if changed then
        notifyClient(player)
    end
end

-- Réinitialise la progression des défis singleRound au départ de chaque manche.
-- Appelé par RoundManager avant chaque ACTIVE.
function ChallengeManager.ResetRoundProgress(player)
    local data = _G.DataManager and _G.DataManager.GetData(player)
    if not data or not data.challenges or not data.challenges.daily then return end

    local changed = false
    for _, challenge in ipairs(data.challenges.daily) do
        if challenge.singleRound and not challenge.completed then
            challenge.progress = 0
            changed = true
        end
    end

    if changed then
        notifyClient(player)
    end
end

-- Retourne les défis courants (utilisé par GetChallenges RemoteFunction)
function ChallengeManager.GetChallenges(player)
    ensureChallenges(player)
    local data = _G.DataManager and _G.DataManager.GetData(player)
    if not data or not data.challenges then return {} end
    return data.challenges.daily
end

-- ============================================================
-- REMOTE FUNCTION : GetChallenges (E6-S9)
-- ============================================================

fnGetChallenges.OnServerInvoke = function(player)
    return ChallengeManager.GetChallenges(player)
end

-- ============================================================
-- CONNEXION JOUEURS
-- ============================================================

Players.PlayerAdded:Connect(function(player)
    -- Attend que DataManager ait chargé les données du joueur
    task.delay(2, function()
        ensureChallenges(player)
        notifyClient(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    -- Les données sont sauvegardées par DataManager — rien de spécial ici
end)

-- Initialise les défis pour les joueurs déjà connectés
for _, player in ipairs(Players:GetPlayers()) do
    task.delay(2, function()
        ensureChallenges(player)
    end)
end

print("[ChallengeManager] ✅ Prêt")
