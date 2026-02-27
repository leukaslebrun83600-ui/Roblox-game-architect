-- Init.server.lua — Point d'entrée serveur & handlers utilitaires légers

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Events        = game.ReplicatedStorage:WaitForChild("Events")
local reShowTooltip = Events:WaitForChild("ShowTooltip")

-- ============================================================
-- RE-TAGGING MAP (fix copy-paste Studio)
-- Les tags CollectionService ne survivent pas toujours au copy-paste
-- depuis Play mode. On les ré-applique au démarrage selon les noms.
-- ============================================================

local TAG_PREFIXES = {
    { prefix = "TrapButton_",      tag = "TrapButton"      },
    { prefix = "SacrificeButton_", tag = "SacrificeButton" },
    { prefix = "Checkpoint_",      tag = "Checkpoint"      },
    { prefix = "TrapZone_",        tag = "TrapZone"        },
    { name   = "ArrivalZone",      tag = "ArrivalZone"     },
}

local function retagMap()
    local course = workspace:FindFirstChild("Course")
    if not course then
        warn("[Init] Dossier 'Course' introuvable dans Workspace — tags non appliqués")
        return
    end

    local count = 0
    for _, inst in ipairs(course:GetDescendants()) do
        if inst:IsA("BasePart") then
            for _, rule in ipairs(TAG_PREFIXES) do
                local match = rule.prefix and inst.Name:sub(1, #rule.prefix) == rule.prefix
                           or rule.name   and inst.Name == rule.name
                if match and not CollectionService:HasTag(inst, rule.tag) then
                    CollectionService:AddTag(inst, rule.tag)
                    count += 1
                end
            end
        end
    end

    print(string.format("[Init] Re-tagging map : %d instance(s) taguée(s)", count))
end

-- Légère pause pour laisser le Workspace se charger
task.delay(0.5, retagMap)

-- ============================================================
-- SPAWN LOBBY AU PREMIER JOIN
-- Roblox n'utilise pas automatiquement les SpawnLocations
-- imbriquées dans des dossiers → téléportation explicite.
-- ============================================================

local function teleportToLobby(character)
    task.wait(0.4)
    -- Uniquement si pas en manche active
    if _G.RoundManager and _G.RoundManager.GetState() == "ACTIVE" then return end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Cherche un SpawnLocation dans le lobby
    local lobby  = workspace:FindFirstChild("Lobby")
    local folder = lobby and lobby:FindFirstChild("SpawnLocations")
    local spawns = folder and folder:GetChildren() or {}

    if #spawns > 0 then
        local sp = spawns[math.random(1, #spawns)]
        root.CFrame = sp.CFrame + Vector3.new(0, 3, 0)
    else
        -- Fallback : centre du lobby
        root.CFrame = CFrame.new(0, 14, 0)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(teleportToLobby)
end)

-- ============================================================
-- MARQUER UN TOOLTIP COMME VU (E10-S1)
-- TooltipController.client fire ShowTooltip:FireServer(key)
-- après avoir affiché un tooltip → persiste via DataManager
-- ============================================================

reShowTooltip.OnServerEvent:Connect(function(player, key)
    if type(key) ~= "string" then return end

    local data = _G.DataManager and _G.DataManager.GetData(player)
    if not data or type(data.tooltipsShown) ~= "table" then return end

    -- Sécurité : on ne marque que les clés prévues dans le schéma
    if data.tooltipsShown[key] ~= nil then
        data.tooltipsShown[key] = true
    end
end)

print("[TrustNoOne] Serveur démarré ✅")
