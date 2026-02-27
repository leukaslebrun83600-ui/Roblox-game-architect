-- MarketplaceManager.server.lua — Monétisation (Game Passes + Dev Products)
-- E8-S1 (vérif passes connexion), E8-S2 (Karma Pass x2, déjà géré par KarmaManager),
-- E8-S3 (flag deathEffects pour E9), E8-S4 (Skip Checkpoint), E8-S5 (Bouclier)
--
-- API publique (_G.MarketplaceManager) :
--   IsShielded(player)    → bool
--   GetPurchases(player)  → table { karmaPass, deathEffects, radio }

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService  = game:GetService("CollectionService")

local GameConfig = require(game.ServerStorage.Config.GameConfig)

local Events       = game.ReplicatedStorage:WaitForChild("Events")
local rePlayEffect = Events:WaitForChild("PlayEffect")

-- IDs de monétisation (0 = placeholder — remplacer avant publication via GameConfig)
local PASS_KARMA_ID         = GameConfig.Monetisation.PASS_KARMA_ID
local PASS_DEATH_EFFECTS_ID = GameConfig.Monetisation.PASS_DEATH_EFFECTS_ID
local PASS_RADIO_ID         = GameConfig.Monetisation.PASS_RADIO_ID
local PRODUCT_SKIP_ID       = GameConfig.Monetisation.PRODUCT_SKIP_ID
local PRODUCT_SHIELD_ID     = GameConfig.Monetisation.PRODUCT_SHIELD_ID
local SHIELD_DURATION       = GameConfig.Monetisation.SHIELD_DURATION

-- ============================================================
-- ÉTAT INTERNE
-- ============================================================

local shieldedUntil = {}   -- [userId] = os.clock() heure d'expiration

-- ============================================================
-- API PUBLIQUE
-- ============================================================

local MarketplaceManager = {}
_G.MarketplaceManager = MarketplaceManager

-- Retourne true si le bouclier du joueur est encore actif (E8-S5)
function MarketplaceManager.IsShielded(player)
    local t = shieldedUntil[player.UserId]
    return t ~= nil and os.clock() < t
end

-- Retourne la table des achats du joueur (pour le client via GetPlayerData)
function MarketplaceManager.GetPurchases(player)
    local data = _G.DataManager and _G.DataManager.GetData(player)
    return data and data.purchases or {}
end

-- ============================================================
-- VÉRIFICATION GAME PASSES À LA CONNEXION (E8-S1)
-- ============================================================

local function checkGamePasses(player)
    local data = _G.DataManager and _G.DataManager.GetData(player)
    if not data then return end

    local checks = {
        { id = PASS_KARMA_ID,         key = "karmaPass"    },
        { id = PASS_DEATH_EFFECTS_ID, key = "deathEffects" },
        { id = PASS_RADIO_ID,         key = "radio"        },
    }

    for _, check in ipairs(checks) do
        if check.id ~= 0 then
            local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync,
                MarketplaceService, player.UserId, check.id)
            if ok and owned and not data.purchases[check.key] then
                data.purchases[check.key] = true
                print(string.format("[MarketplaceManager] %s possède %s", player.Name, check.key))
            end
        end
    end
end

-- ============================================================
-- PRODUIT : SKIP CHECKPOINT (E8-S4)
-- Téléporte le joueur au prochain checkpoint devant lui sur l'axe Z
-- ============================================================

local function skipToNextCheckpoint(player)
    if not (_G.RoundManager and _G.RoundManager.GetState() == "ACTIVE") then
        return false   -- pas pendant le lobby ou les résultats
    end

    local char = player.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local playerZ = root.Position.Z
    local zones   = CollectionService:GetTagged("Checkpoint")

    -- Checkpoint immédiatement devant le joueur (Z strictement supérieur, le plus proche)
    local best, bestZ = nil, math.huge
    for _, zone in ipairs(zones) do
        local z = zone.Position.Z
        if z > playerZ and z < bestZ then
            best, bestZ = zone, z
        end
    end

    if not best then
        print(string.format("[MarketplaceManager] Skip : %s déjà à la fin", player.Name))
        return false
    end

    local targetCF = best.CFrame + Vector3.new(0, 4, -3)
    root.CFrame = targetCF

    -- Met à jour le checkpoint enregistré dans CheckpointManager
    if _G.CheckpointManager then
        _G.CheckpointManager.SetCheckpoint(player, targetCF)
    end

    print(string.format("[MarketplaceManager] Skip : %s → Z %.1f", player.Name, bestZ))
    return true
end

-- ============================================================
-- PRODUIT : BOUCLIER DÉFENSIF (E8-S5)
-- Joueur invincible SHIELD_DURATION secondes
-- ============================================================

local function applyShield(player)
    shieldedUntil[player.UserId] = os.clock() + SHIELD_DURATION

    -- Informe le client (EffectsController affiche le VFX en E9)
    rePlayEffect:FireClient(player, { type = "shield", duration = SHIELD_DURATION })

    -- Expiration automatique
    task.delay(SHIELD_DURATION, function()
        if shieldedUntil[player.UserId] and os.clock() >= shieldedUntil[player.UserId] then
            shieldedUntil[player.UserId] = nil
            -- Signal fin du bouclier au client
            rePlayEffect:FireClient(player, { type = "shieldEnd" })
        end
    end)

    print(string.format("[MarketplaceManager] Bouclier : %s (%ds)", player.Name, SHIELD_DURATION))
end

-- ============================================================
-- PROCESS RECEIPT — Developer Products (E8-S4, E8-S5)
-- ============================================================

-- ⚠ Ne doit être assigné qu'une seule fois dans tout le jeu.
MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)

    -- Joueur hors-ligne → on retraitera plus tard
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local productId = receiptInfo.ProductId

    if productId == PRODUCT_SKIP_ID and PRODUCT_SKIP_ID ~= 0 then
        skipToNextCheckpoint(player)
        return Enum.ProductPurchaseDecision.PurchaseGranted

    elseif productId == PRODUCT_SHIELD_ID and PRODUCT_SHIELD_ID ~= 0 then
        applyShield(player)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    warn("[MarketplaceManager] ProductId non géré : " .. tostring(productId))
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ============================================================
-- ACHAT GAME PASS EN DIRECT (mise à jour sans reconnexion)
-- ============================================================

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
    if not wasPurchased then return end
    local data = _G.DataManager and _G.DataManager.GetData(player)
    if not data then return end

    if passId == PASS_KARMA_ID then
        data.purchases.karmaPass    = true
        print(string.format("[MarketplaceManager] %s — Karma Pass activé (×2 Karma)", player.Name))
    elseif passId == PASS_DEATH_EFFECTS_ID then
        data.purchases.deathEffects = true
        print(string.format("[MarketplaceManager] %s — Effets de Mort activés", player.Name))
    elseif passId == PASS_RADIO_ID then
        data.purchases.radio        = true
        print(string.format("[MarketplaceManager] %s — Radio activée", player.Name))
    end
end)

-- ============================================================
-- CONNEXION JOUEURS
-- ============================================================

Players.PlayerAdded:Connect(function(player)
    -- Attends que DataManager ait chargé les données (délai de sécurité)
    task.delay(2, function()
        if player.Parent then  -- vérifie que le joueur est toujours là
            checkGamePasses(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    shieldedUntil[player.UserId] = nil
end)

-- Pour les joueurs déjà présents au démarrage du script
for _, player in ipairs(Players:GetPlayers()) do
    task.delay(2, function()
        if player.Parent then checkGamePasses(player) end
    end)
end

print("[MarketplaceManager] ✅ Prêt")
