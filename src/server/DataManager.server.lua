-- DataManager.server.lua — Sauvegarde et chargement des données joueur
-- Couvre E1-S4 (sauvegarde) et E1-S5 (chargement + migration)
--
-- API publique (accessible depuis les autres managers via _G) :
--   _G.DataManager.GetData(player)           → table des données du joueur
--   _G.DataManager.SetData(player, key, val) → modifie une clé dans les données
--   _G.DataManager.SaveData(player)          → sauvegarde immédiate
--
-- ⚠ Studio : activer "Enable Studio Access to API Services" dans
--   Game Settings → Security pour que le DataStore fonctionne en test local.

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local GameConfig = require(game.ServerStorage.Config.GameConfig)

-- ============================================================
-- ÉTAT INTERNE
-- ============================================================

local playerStore    = DataStoreService:GetDataStore("PlayerData")
local playerCache    = {}  -- [userId] = données en mémoire

-- ============================================================
-- DONNÉES PAR DÉFAUT
-- ============================================================

local function buildDefaultData()
    return {
        version   = GameConfig.DataStore.SCHEMA_VERSION,
        firstJoin = os.time(),
        lastJoin  = os.time(),

        karma = {
            traitor = 0,
            martyr  = 0,
        },

        stats = {
            trapsTriggered = 0,
            trapsKilled    = 0,
            sacrificesDone = 0,
            roundsPlayed   = 0,
            roundsWon      = 0,
        },

        -- Structure gérée par ChallengeManager (tableau de 3 défis du jour)
        challenges = {
            lastReset = -1,
            daily     = {},
        },

        badges = {},

        tooltipsShown = {
            goalTooltip      = false,
            trapTooltip      = false,
            karmaTooltip     = false,
            sacrificeTooltip = false,
            challengeTooltip = false,
        },

        purchases = {
            karmaPass    = false,
            deathEffects = false,
            radio        = false,
        },

        settings = {
            musicVolume     = 0.7,
            sfxVolume       = 1.0,
            tooltipsEnabled = true,
        },
    }
end

-- ============================================================
-- MIGRATION DE SCHÉMA
-- Appelée après chargement si la version des données est ancienne.
-- Ajouter ici les migrations au fil des updates du jeu.
-- ============================================================

local function migrateData(data)
    -- v1 → rien à migrer pour l'instant (c'est la version initiale)
    -- Exemple futur :
    --   if data.version < 2 then
    --       data.newField = valeurParDéfaut
    --       data.version = 2
    --   end
    data.version = GameConfig.DataStore.SCHEMA_VERSION
    return data
end

-- ============================================================
-- FUSION AVEC LES VALEURS PAR DÉFAUT
-- Garantit que tous les champs existent, même sur un profil ancien.
-- ============================================================

local function deepMergeDefaults(data, defaults)
    for key, defaultValue in pairs(defaults) do
        if data[key] == nil then
            -- champ absent → on prend la valeur par défaut
            data[key] = defaultValue
        elseif type(data[key]) == "table" and type(defaultValue) == "table" then
            -- champ table → on descend récursivement
            deepMergeDefaults(data[key], defaultValue)
        end
    end
end

-- ============================================================
-- RETRY AVEC BACKOFF EXPONENTIEL
-- ============================================================

local function withRetry(action, label)
    local waitTime = 1
    for attempt = 1, GameConfig.DataStore.RETRY_COUNT do
        local ok, result = pcall(action)
        if ok then
            return true, result
        end
        warn(string.format("[DataManager] %s — tentative %d/%d échouée : %s",
            label, attempt, GameConfig.DataStore.RETRY_COUNT, tostring(result)))
        if attempt < GameConfig.DataStore.RETRY_COUNT then
            task.wait(waitTime)
            waitTime = waitTime * 2  -- 1s → 2s → 4s
        end
    end
    warn("[DataManager] " .. label .. " — abandon après " .. GameConfig.DataStore.RETRY_COUNT .. " tentatives.")
    return false, nil
end

-- ============================================================
-- CHARGEMENT
-- ============================================================

local function loadData(player)
    local key = GameConfig.DataStore.KEY_PREFIX .. player.UserId

    local ok, rawData = withRetry(function()
        return playerStore:GetAsync(key)
    end, "GetAsync(" .. player.Name .. ")")

    if ok and rawData then
        -- joueur connu : migration + fusion des nouveaux champs
        rawData = migrateData(rawData)
        deepMergeDefaults(rawData, buildDefaultData())
        print(string.format("[DataManager] %s chargé (v%d, %d pts Traître, %d pts Martyr)",
            player.Name, rawData.version, rawData.karma.traitor, rawData.karma.martyr))
        return rawData
    else
        -- nouveau joueur ou échec DataStore : données par défaut
        local defaultData = buildDefaultData()
        if ok and not rawData then
            print("[DataManager] Nouveau joueur : " .. player.Name)
        else
            warn("[DataManager] Échec chargement pour " .. player.Name .. " — données par défaut utilisées.")
        end
        return defaultData
    end
end

-- ============================================================
-- SAUVEGARDE
-- ============================================================

local function saveData(player)
    local data = playerCache[player.UserId]
    if not data then return false end

    data.lastJoin = os.time()
    local key = GameConfig.DataStore.KEY_PREFIX .. player.UserId

    local ok = withRetry(function()
        playerStore:SetAsync(key, data)
    end, "SetAsync(" .. player.Name .. ")")

    if ok then
        print("[DataManager] " .. player.Name .. " sauvegardé.")
    end
    return ok
end

-- ============================================================
-- API PUBLIQUE (_G.DataManager)
-- Les autres managers serveur accèdent aux données via cette table.
-- ============================================================

local DataManager = {}
_G.DataManager = DataManager

-- Retourne la table de données d'un joueur (référence directe — modifier in-place suffit)
function DataManager.GetData(player)
    return playerCache[player.UserId]
end

-- Modifie une clé de premier niveau dans les données d'un joueur
function DataManager.SetData(player, key, value)
    local data = playerCache[player.UserId]
    if not data then
        warn("[DataManager] SetData : pas de données pour " .. player.Name)
        return
    end
    data[key] = value
end

-- Force une sauvegarde immédiate (ex: après un achat Robux)
function DataManager.SaveData(player)
    return saveData(player)
end

-- ============================================================
-- GESTION DES JOUEURS
-- ============================================================

local function onPlayerAdded(player)
    local data = loadData(player)
    data.lastJoin = os.time()
    playerCache[player.UserId] = data
end

local function onPlayerRemoving(player)
    saveData(player)
    playerCache[player.UserId] = nil  -- libère la mémoire
end

-- ============================================================
-- AUTO-SAVE (toutes les AUTOSAVE_INTERVAL secondes)
-- ============================================================

task.spawn(function()
    while true do
        task.wait(GameConfig.DataStore.AUTOSAVE_INTERVAL)
        local playerList = Players:GetPlayers()
        for _, player in ipairs(playerList) do
            if playerCache[player.UserId] then
                saveData(player)
            end
        end
        if #playerList > 0 then
            print(string.format("[DataManager] Auto-save : %d joueur(s)", #playerList))
        end
    end
end)

-- ============================================================
-- BIND TO CLOSE — sauvegarde forcée à l'arrêt du serveur
-- ============================================================

game:BindToClose(function()
    print("[DataManager] Arrêt serveur — sauvegarde en cours...")
    local saves = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if playerCache[player.UserId] then
            table.insert(saves, task.spawn(saveData, player))
        end
    end
    -- attend que toutes les sauvegardes soient terminées
    for _, thread in ipairs(saves) do
        task.wait()
    end
    print("[DataManager] Sauvegarde finale terminée.")
end)

-- ============================================================
-- REMOTEFUNCTION : GetPlayerData (client demande ses données)
-- ============================================================

local Events = game.ReplicatedStorage:WaitForChild("Events")
local rfGetPlayerData = Events:WaitForChild("GetPlayerData")

rfGetPlayerData.OnServerInvoke = function(player)
    local data = playerCache[player.UserId]
    if not data then return nil end
    -- on ne renvoie que ce dont le client a besoin (pas les achats, pas les settings internes)
    return {
        karma  = data.karma,
        stats  = data.stats,
        badges = data.badges,
        tooltipsShown = data.tooltipsShown,
        settings      = data.settings,
    }
end

-- ============================================================
-- INIT
-- ============================================================

-- Connexion pour les joueurs déjà présents (si script rechargé à chaud)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

print("[DataManager] ✅ Prêt")
