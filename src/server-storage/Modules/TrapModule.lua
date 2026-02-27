-- TrapModule — Logique d'exécution des 3 types de pièges
-- Couvre E4-S4 (FloorCollapse), E4-S5 (Projectile), E4-S6 (WallPusher)
--
-- Chaque fonction reçoit :
--   zone      : Part taggée "TrapZone" (définit la zone d'effet)
--   activator : Player qui a déclenché le piège (pour le Karma)

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local Players      = game:GetService("Players")

local GameConfig = require(game.ServerStorage.Config.GameConfig)

local TrapModule = {}

-- ============================================================
-- UTILITAIRES
-- ============================================================

-- Trouve toutes les plateformes dans une zone (pour FloorCollapse)
local function getPlatformsInZone(zone)
    local overlapParams = OverlapParams.new()
    local parts = workspace:GetPartBoundsInBox(zone.CFrame, zone.Size, overlapParams)
    local platforms = {}
    for _, part in ipairs(parts) do
        -- On ne cible que les Parts dans un dossier "Plateformes"
        if part ~= zone
            and part:IsA("BasePart")
            and part.Parent
            and part.Parent.Name == "Plateformes"
        then
            table.insert(platforms, part)
        end
    end
    return platforms
end

-- Vérifie si un BasePart contient des personnages joueurs et les tue
local function killPlayersInBox(cframe, size, activator, killed)
    local overlapParams = OverlapParams.new()
    local parts = workspace:GetPartBoundsInBox(cframe, size, overlapParams)
    for _, part in ipairs(parts) do
        local char     = part.Parent
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 and not killed[char] then
            local victim = Players:GetPlayerFromCharacter(char)
            -- Ne tue pas l'activateur du piège
            if victim == activator then continue end
            -- Bouclier défensif : joueur protégé (E8-S5)
            if victim and _G.MarketplaceManager and _G.MarketplaceManager.IsShielded(victim) then
                continue
            end
            killed[char] = true
            humanoid.Health = 0
            -- Karma attribué si KarmaManager disponible (E5)
            if _G.KarmaManager then
                _G.KarmaManager.AddKarma(activator, "traitor", GameConfig.Karma.TRAP_KILL, "kill")
            end
        end
    end
end

-- ============================================================
-- TYPE 1 — SOL EFFONDRANT (FloorCollapse)
-- Les plateformes dans la zone disparaissent 3s puis reviennent
-- ============================================================

function TrapModule.FloorCollapse(zone, activator)
    local platforms = getPlatformsInZone(zone)

    if #platforms == 0 then
        warn("[TrapModule] FloorCollapse : aucune plateforme dans " .. zone.Name)
        return
    end

    -- Zone de mort invisible sous le vide créé (récupère les chutes)
    local killZone = Instance.new("Part")
    killZone.Size        = Vector3.new(zone.Size.X + 4, 1, zone.Size.Z + 4)
    killZone.CFrame      = zone.CFrame - Vector3.new(0, zone.Size.Y / 2 + 6, 0)
    killZone.Transparency = 1
    killZone.CanCollide  = false
    killZone.Anchored    = true
    killZone.Parent      = workspace

    local killed = {}
    killZone.Touched:Connect(function(hit)
        local char     = hit.Parent
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 and not killed[char] then
            local victim = Players:GetPlayerFromCharacter(char)
            if victim == activator then return end  -- ne tue pas l'activateur
            if victim and _G.MarketplaceManager and _G.MarketplaceManager.IsShielded(victim) then
                return
            end
            killed[char] = true
            humanoid.Health = 0
            if _G.KarmaManager then
                _G.KarmaManager.AddKarma(activator, "traitor", GameConfig.Karma.TRAP_KILL, "kill")
            end
        end
    end)

    -- Effondrement
    for _, p in ipairs(platforms) do
        p.CanCollide  = false
        p.Transparency = 0.85
    end

    task.wait(GameConfig.Traps.COLLAPSED_FLOOR_DELAY)

    -- Restauration
    for _, p in ipairs(platforms) do
        if p and p.Parent then
            p.CanCollide  = true
            p.Transparency = 0
        end
    end

    task.delay(1, function() killZone:Destroy() end)
end

-- ============================================================
-- TYPE 2 — JET DE PROJECTILE (Projectile)
-- Une sphère traverse la zone latéralement et élimine les joueurs
-- ============================================================

function TrapModule.Projectile(zone, activator)
    -- Direction de traversée : axe X local de la zone
    local halfX    = zone.Size.X / 2
    local startCF  = zone.CFrame * CFrame.new(-halfX - 3, 0, 0)
    local endCF    = zone.CFrame * CFrame.new( halfX + 3, 0, 0)
    local duration = 1.8  -- secondes pour traverser

    local ball = Instance.new("Part")
    ball.Name        = "Projectile"
    ball.Shape       = Enum.PartType.Ball
    ball.Size        = Vector3.new(5, 5, 5)
    ball.Color       = Color3.fromRGB(255, 80, 50)
    ball.Material    = Enum.Material.Neon
    ball.Anchored    = true
    ball.CanCollide  = false  -- ne bloque pas le parcours
    ball.CastShadow  = false
    ball.CFrame      = startCF
    ball.Parent      = workspace

    local killed    = {}
    local startTime = os.clock()

    -- Déplacement + détection via Heartbeat (plus fiable que Touched sur anchored)
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local t = (os.clock() - startTime) / duration

        if t >= 1 then
            conn:Disconnect()
            ball:Destroy()
            return
        end

        ball.CFrame = startCF:Lerp(endCF, t)
        killPlayersInBox(ball.CFrame, ball.Size + Vector3.new(1, 1, 1), activator, killed)
    end)
end

-- ============================================================
-- TYPE 3 — MUR POUSSEUR (WallPusher)
-- Un mur surgit depuis le côté et pousse les joueurs hors de la plateforme
-- ============================================================

function TrapModule.WallPusher(zone, activator)
    local halfX   = zone.Size.X / 2
    local startCF = zone.CFrame * CFrame.new(-halfX - 1, 0, 0)
    local endCF   = zone.CFrame * CFrame.new( halfX + 1, 0, 0)
    local duration = 1.2

    local wall = Instance.new("Part")
    wall.Name       = "WallPusher"
    wall.Size       = Vector3.new(2, zone.Size.Y - 1, zone.Size.Z + 2)
    wall.Color      = Color3.fromRGB(200, 100, 50)
    wall.Material   = Enum.Material.SmoothPlastic
    wall.Anchored   = true
    wall.CanCollide = false
    wall.CastShadow = false
    wall.CFrame     = startCF
    wall.Parent     = workspace

    local killed    = {}
    local startTime = os.clock()

    -- Avance + détecte les joueurs
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local t = (os.clock() - startTime) / duration

        if t >= 1 then
            conn:Disconnect()
            -- Rétraction (disparaît côté opposé)
            TweenService:Create(wall,
                TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { CFrame = endCF + Vector3.new(3, 0, 0) }
            ):Play()
            task.delay(0.5, function() wall:Destroy() end)
            return
        end

        wall.CFrame = startCF:Lerp(endCF, t)
        killPlayersInBox(wall.CFrame, wall.Size, activator, killed)
    end)
end

return TrapModule
