-- CheckpointManager.server.lua — Sauvegarde position & respawn immédiat
-- Couvre E4-S1 (sauvegarde checkpoint) et E4-S2 (respawn)
--
-- API publique (_G.CheckpointManager) :
--   GetCheckpoint(player)   → CFrame du dernier checkpoint (ou nil)
--   ResetAll()              → efface tous les checkpoints (appelé au départ de manche)

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Events   = game.ReplicatedStorage:WaitForChild("Events")
local reRespawn = Events:WaitForChild("RespawnAt")

-- Respawn instantané : on désactive le timer Roblox par défaut
game.Players.RespawnTime = 0

-- ============================================================
-- ÉTAT INTERNE
-- ============================================================

local checkpoints = {}  -- [userId] = CFrame du dernier checkpoint atteint

-- ============================================================
-- API PUBLIQUE
-- ============================================================

local CheckpointManager = {}
_G.CheckpointManager = CheckpointManager

function CheckpointManager.GetCheckpoint(player)
    return checkpoints[player.UserId]
end

-- Appelé par RoundManager au départ de chaque manche
function CheckpointManager.ResetAll()
    checkpoints = {}
    print("[CheckpointManager] Checkpoints réinitialisés")
end

-- Permet à MarketplaceManager (Skip Checkpoint) de définir manuellement
-- le checkpoint d'un joueur après téléportation (E8-S4)
function CheckpointManager.SetCheckpoint(player, cframe)
    checkpoints[player.UserId] = cframe
end

-- ============================================================
-- DÉTECTION DES ZONES CHECKPOINT
-- ============================================================

local function setupCheckpoints()
    local function connectCheckpoint(zone)
        zone.Touched:Connect(function(hit)
            -- Uniquement pendant une manche active
            if not (_G.RoundManager and _G.RoundManager.GetState() == "ACTIVE") then return end

            local char   = hit.Parent
            local player = Players:GetPlayerFromCharacter(char)
            if not player then return end

            local sectionIdx = zone:GetAttribute("SectionIdx") or 0

            -- Ne recule jamais (on ne sauvegarde que si c'est plus loin)
            local current = checkpoints[player.UserId]
            if current then
                if zone.Position.Z <= current.Position.Z then return end
            end

            -- Spawn sur Plat_E (14 studs avant le centre de la zone), face au parcours (+Z)
            -- zone.Position.Y = platEY + 4  →  platEY + 3.6 = joueur 3 studs au-dessus de la surface
            local spawnPos = Vector3.new(
                zone.Position.X,
                zone.Position.Y - 0.4,   -- hauteur juste au-dessus de Plat_E
                zone.Position.Z - 14     -- recule sur Plat_E (dz 90→76)
            )
            checkpoints[player.UserId] = CFrame.new(spawnPos, spawnPos + Vector3.new(0, 0, 1))
            print(string.format("[CheckpointManager] ✅ %s sauvegardé Section %d (Z=%.0f)",
                player.Name, sectionIdx, zone.Position.Z))
        end)
    end

    local zones = CollectionService:GetTagged("Checkpoint")
    for _, zone in ipairs(zones) do
        connectCheckpoint(zone)
    end
    -- Connecte aussi les checkpoints ajoutés dynamiquement (re-run MapBuilder)
    CollectionService:GetInstanceAddedSignal("Checkpoint"):Connect(connectCheckpoint)

    print(string.format("[CheckpointManager] %d zone(s) Checkpoint connectée(s)", #zones))
end

-- ============================================================
-- RESPAWN AU CHECKPOINT (E4-S2)
-- ============================================================

local function setupRespawn(player)
    player.CharacterAdded:Connect(function(character)
        -- Attend que le personnage soit complètement chargé
        local root = character:WaitForChild("HumanoidRootPart", 5)
        if not root then return end

        -- Boost de saut pour les gaps du parcours
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.JumpPower = 62
        end

        task.wait(0.15)

        -- Téléporte au dernier checkpoint si manche active
        if _G.RoundManager and _G.RoundManager.GetState() == "ACTIVE" then
            local cp = checkpoints[player.UserId]
            if cp then
                root.CFrame = cp
                reRespawn:FireClient(player, { checkpointCFrame = cp })
                print(string.format("[CheckpointManager] Respawn : %s → checkpoint", player.Name))
            else
                -- Pas encore de checkpoint → première plateforme du parcours
                local spawned = false
                local course  = workspace:FindFirstChild("Course")
                if course then
                    local bestPlat, bestZ = nil, math.huge
                    for _, sec in ipairs(course:GetChildren()) do
                        local pf   = sec:FindFirstChild("Plateformes")
                        local platA = pf and pf:FindFirstChild("Plat_A")
                        if platA and platA.Position.Z < bestZ then
                            bestZ    = platA.Position.Z
                            bestPlat = platA
                        end
                    end
                    if bestPlat then
                        root.CFrame = bestPlat.CFrame + Vector3.new(0, bestPlat.Size.Y / 2 + 3, 0)
                        spawned = true
                    end
                end
                if not spawned then
                    -- Fallback absolu si Course introuvable (COURSE_START_Z=200, dz=8)
                    root.CFrame = CFrame.new(0, 13, 208)
                end
                reRespawn:FireClient(player, {})
                print(string.format("[CheckpointManager] Respawn : %s → départ parcours", player.Name))
            end
        end

        -- Connecte l'événement de mort pour ce personnage
        local humanoid = character:WaitForChild("Humanoid", 5)
        if not humanoid then return end

        humanoid.Died:Connect(function()
            -- Respawn immédiat si manche active
            if _G.RoundManager and _G.RoundManager.GetState() == "ACTIVE" then
                task.wait(0.1)
                player:LoadCharacter()
            end
        end)
    end)
end

-- ============================================================
-- KILL FLOOR (sol chocolat — tue et respawn au checkpoint)
-- ============================================================

local function setupKillFloor()
    local function connectZone(zone)
        zone.Touched:Connect(function(hit)
            if not (_G.RoundManager and _G.RoundManager.GetState() == "ACTIVE") then return end
            local char   = hit.Parent
            local player = Players:GetPlayerFromCharacter(char)
            if not player then return end
            -- Tue le joueur → respawn au dernier checkpoint (CheckpointManager gère le respawn)
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                humanoid.Health = 0
            end
        end)
    end

    for _, zone in ipairs(CollectionService:GetTagged("KillFloor")) do
        connectZone(zone)
    end
    CollectionService:GetInstanceAddedSignal("KillFloor"):Connect(connectZone)
    print("[CheckpointManager] KillFloor connecté")
end

-- ============================================================
-- INIT
-- ============================================================

setupCheckpoints()
setupKillFloor()

for _, player in ipairs(Players:GetPlayers()) do
    setupRespawn(player)
end
Players.PlayerAdded:Connect(setupRespawn)

Players.PlayerRemoving:Connect(function(player)
    checkpoints[player.UserId] = nil
end)

print("[CheckpointManager] ✅ Prêt")
