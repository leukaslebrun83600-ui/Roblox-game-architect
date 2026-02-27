-- TrapManager.server.lua — Validation et exécution des pièges
-- Couvre E4-S3 (validation), E4-S4/5/6 (via TrapModule), E4-S7 (bouton usagé), E4-S8 (Sacrifice)

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(game.ServerStorage.Config.GameConfig)
local TrapModule = require(game.ServerStorage.Modules.TrapModule)

local Events         = game.ReplicatedStorage:WaitForChild("Events")
local reTrapActivated    = Events:WaitForChild("TrapActivated")
local reSacrificeActivated = Events:WaitForChild("SacrificeActivated")
local reButtonUsed       = Events:WaitForChild("ButtonUsed")
local reqActivateTrap    = Events:WaitForChild("RequestActivateTrap")
local reqSacrifice       = Events:WaitForChild("RequestSacrifice")

-- ============================================================
-- RATE LIMITING (anti-exploit)
-- ============================================================

local requestTimestamps = {}  -- [userId] = { timestamps }

local function isRateLimited(player)
    local userId = player.UserId
    local now    = os.clock()
    local limit  = GameConfig.Security.RATE_LIMIT_PER_SECOND

    requestTimestamps[userId] = requestTimestamps[userId] or {}
    local timestamps = requestTimestamps[userId]

    -- Supprime les timestamps > 1 seconde
    for i = #timestamps, 1, -1 do
        if now - timestamps[i] > 1 then
            table.remove(timestamps, i)
        end
    end

    if #timestamps >= limit then
        warn(string.format("[TrapManager] Rate limit dépassé : %s", player.Name))
        return true
    end

    table.insert(timestamps, now)
    return false
end

-- ============================================================
-- VALIDATION COMMUNE
-- ============================================================

local function validateRequest(player, button)
    -- 1. Manche active
    if not (_G.RoundManager and _G.RoundManager.GetState() == "ACTIVE") then
        return false, "manche inactive"
    end

    -- 2. Bouton non usagé
    if button:GetAttribute("Used") then
        return false, "bouton déjà utilisé"
    end

    -- 3. Distance joueur → bouton
    local char = player.Character
    if not char then return false, "pas de personnage" end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false, "pas de HumanoidRootPart" end

    local dist = (root.Position - button.Position).Magnitude
    -- On tolère 2× le rayon pour absorber la latence réseau
    if dist > GameConfig.Traps.ACTIVATION_RADIUS * 2 then
        return false, string.format("trop loin (%.1f studs)", dist)
    end

    -- 4. Validation de la progression de section (E11-S3)
    -- Empêche d'activer un bouton dans une section très avancée que le joueur n'a pas atteinte
    local COURSE_START_Z   = 200  -- doit correspondre à MapBuilder
    local SECTION_LENGTH   = 120  -- longueur d'une section en studs (= MapBuilder.SECTION_LENGTH)
    local playerSection    = math.floor((root.Position.Z   - COURSE_START_Z) / SECTION_LENGTH)
    local buttonSection    = math.floor((button.Position.Z - COURSE_START_Z) / SECTION_LENGTH)
    if buttonSection > playerSection + 1 then
        return false, string.format("section invalide (joueur=%d, bouton=%d)",
            playerSection, buttonSection)
    end

    return true, nil
end

-- Marque un bouton comme usagé et prévient tous les clients
local function markButtonUsed(button)
    button:SetAttribute("Used", true)
    button.Color = Color3.fromRGB(120, 120, 120)  -- grisé visuellement (E4-S7)
    reButtonUsed:FireAllClients({ buttonId = button.Name })
end

-- Trouve un bouton par nom dans le dossier Course
local function findButton(name)
    local course = workspace:FindFirstChild("Course")
    if not course then return nil end
    for _, inst in ipairs(course:GetDescendants()) do
        if inst:IsA("BasePart") and inst.Name == name then
            return inst
        end
    end
    return nil
end

-- Trouve la TrapZone liée à un TrapButton
local function findLinkedZone(button)
    local zoneName = button:GetAttribute("LinkedZone")
    if not zoneName then return nil end
    -- La zone est dans le même dossier que le bouton
    return button.Parent and button.Parent:FindFirstChild(zoneName)
end

-- ============================================================
-- HANDLER : PIÈGE (E4-S3 à E4-S7)
-- ============================================================

reqActivateTrap.OnServerEvent:Connect(function(player, data)
    print(string.format("[TrapManager] Requête reçue de %s : %s", player.Name, tostring(data and data.buttonName)))
    if isRateLimited(player) then return end
    if type(data) ~= "table" or type(data.buttonName) ~= "string" then
        warn("[TrapManager] Données invalides")
        return
    end

    local button = findButton(data.buttonName)
    if not button then
        warn("[TrapManager] Bouton introuvable : " .. tostring(data.buttonName))
        return
    end

    local ok, reason = validateRequest(player, button)
    if not ok then
        print(string.format("[TrapManager] Refus (%s) : %s — %s", player.Name, data.buttonName, reason))
        return
    end

    local trapType = button:GetAttribute("TrapType") or "FloorCollapse"
    local zone     = findLinkedZone(button)
    print(string.format("[TrapManager] Zone liée : %s", tostring(zone and zone.Name or "INTROUVABLE")))

    print(string.format("[TrapManager] %s active %s (%s)", player.Name, data.buttonName, trapType))

    -- Marque le bouton usagé immédiatement (avant l'exécution async du piège)
    markButtonUsed(button)

    -- Informe tous les clients (animation côté client)
    reTrapActivated:FireAllClients({
        trapId      = data.buttonName,
        activatorId = player.UserId,
        trapType    = trapType,
    })

    -- Exécute le piège dans une tâche séparée (async — ne bloque pas les autres events)
    if zone then
        task.spawn(function()
            if trapType == "FloorCollapse" then
                TrapModule.FloorCollapse(zone, player)
            elseif trapType == "Projectile" then
                TrapModule.Projectile(zone, player)
            elseif trapType == "WallPusher" then
                TrapModule.WallPusher(zone, player)
            else
                warn("[TrapManager] Type de piège inconnu : " .. trapType)
            end
        end)
    else
        warn("[TrapManager] Aucune TrapZone liée pour " .. button.Name)
    end
end)

-- ============================================================
-- HANDLER : SACRIFICE (E4-S8)
-- ============================================================

reqSacrifice.OnServerEvent:Connect(function(player, data)
    if isRateLimited(player) then return end
    if type(data) ~= "table" or type(data.buttonName) ~= "string" then return end

    local button = findButton(data.buttonName)
    if not button then
        warn("[TrapManager] Bouton Sacrifice introuvable : " .. tostring(data.buttonName))
        return
    end

    local ok, reason = validateRequest(player, button)
    if not ok then
        print(string.format("[TrapManager] Sacrifice refusé (%s) : %s", player.Name, reason))
        return
    end

    print(string.format("[TrapManager] %s se sacrifie (%s)", player.Name, data.buttonName))

    markButtonUsed(button)

    -- Ouvre le passage (rend transparents/non-collidables les Parts "SacrificePassage" proches)
    -- Les passages doivent être nommés ou tagués "SacrificePassage" dans Studio
    local sectionFolder = button.Parent and button.Parent.Parent
    if sectionFolder then
        for _, obj in ipairs(sectionFolder:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == "SacrificePassage" then
                obj.CanCollide  = false
                obj.Transparency = 0.7
            end
        end
    end

    -- Téléporte l'activateur à son dernier checkpoint
    local cp = _G.CheckpointManager and _G.CheckpointManager.GetCheckpoint(player)
    local char = player.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            if cp then
                root.CFrame = cp
            else
                -- Pas de checkpoint → début de parcours
                local lobby = workspace:FindFirstChild("Lobby")
                local pad   = lobby and lobby:FindFirstChild("DebutManche")
                if pad then root.CFrame = pad.CFrame + Vector3.new(0, 3, 0) end
            end
        end
    end

    -- Karma +1 Martyr (E5)
    if _G.KarmaManager then
        _G.KarmaManager.AddKarma(player, "martyr", GameConfig.Karma.SACRIFICE, "sacrifice")
    end

    -- Informe tous les clients
    reSacrificeActivated:FireAllClients({
        playerId   = player.UserId,
        playerName = player.Name,
    })
end)

-- ============================================================
-- NETTOYAGE RATE LIMIT à la déconnexion
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
    requestTimestamps[player.UserId] = nil
end)

print("[TrapManager] ✅ Prêt")
