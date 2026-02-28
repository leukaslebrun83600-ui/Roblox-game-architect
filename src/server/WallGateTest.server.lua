-- WallGateTest.server.lua
-- Zone de test : plateforme avec murs-portes oscillants
-- Les murs glissent latéralement. Passer dans la porte (verte) ou se faire
-- pousser dans le vide par le mur.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris     = game:GetService("Debris")

-- ────────────────────────────────────────────────────────────
-- CONFIG
-- ────────────────────────────────────────────────────────────
local ZONE_X   = -1150    -- X de la zone (isolée)
local ZONE_Z   =    0     -- Z de départ
local PLAT_Y   =   10     -- hauteur de la surface de la plateforme
local PLAT_HW  =   13     -- demi-largeur X (largeur totale = 26 studs)
local PLAT_L   =   90     -- longueur Z (joueur court dans +Z)
local WALL_H   =    7     -- hauteur des murs
local WALL_D   =    1.8   -- épaisseur des murs (Z)
local GAP_W    =    7     -- largeur de la porte
local N_WALLS  =    5     -- nombre de murs

-- Vitesse d'oscillation (rad/s) et phase initiale de chaque mur
local WALL_PARAMS = {
    { speed = 0.40, phase = 0               },
    { speed = 0.55, phase = math.pi * 0.50  },
    { speed = 0.45, phase = math.pi         },
    { speed = 0.60, phase = math.pi * 1.50  },
    { speed = 0.50, phase = math.pi * 0.25  },
}

local COLOR_PLAT = Color3.fromRGB(255, 213,  79)   -- or
local COLOR_WALL = Color3.fromRGB( 50,  55,  75)   -- sombre
local COLOR_GATE = Color3.fromRGB( 40, 200, 120)   -- vert = porte sûre

-- ────────────────────────────────────────────────────────────
-- UTILITAIRES
-- ────────────────────────────────────────────────────────────
local testFolder = Instance.new("Folder")
testFolder.Name   = "WallGateTest"
testFolder.Parent = game.Workspace

local function mkPart(name, size, cf, color, canCollide, transp)
    local p = Instance.new("Part")
    p.Name         = name
    p.Size         = size
    p.CFrame       = cf
    p.Color        = color
    p.Material     = Enum.Material.SmoothPlastic
    p.Anchored     = true
    p.CastShadow   = false
    p.CanCollide   = (canCollide ~= false)
    p.Transparency = transp or 0
    p.Parent       = testFolder
    return p
end

-- ────────────────────────────────────────────────────────────
-- CONSTRUCTION
-- ────────────────────────────────────────────────────────────
local wallY    = PLAT_Y + 0.6 + WALL_H / 2   -- centre Y des murs
local gapRange = PLAT_HW - GAP_W / 2 - 1     -- amplitude d'oscillation du centre de la porte
local leftEdge  = ZONE_X - PLAT_HW
local rightEdge = ZONE_X + PLAT_HW

-- Plateforme principale
mkPart("WG_Plat",
    Vector3.new(PLAT_HW * 2, 1.2, PLAT_L),
    CFrame.new(ZONE_X, PLAT_Y, ZONE_Z + PLAT_L / 2),
    COLOR_PLAT)

-- Plateformes d'entrée / sortie
mkPart("WG_PlatEntree",
    Vector3.new(PLAT_HW * 2, 1.2, 12),
    CFrame.new(ZONE_X, PLAT_Y, ZONE_Z - 7),
    COLOR_PLAT)

mkPart("WG_PlatSortie",
    Vector3.new(PLAT_HW * 2, 1.2, 12),
    CFrame.new(ZONE_X, PLAT_Y, ZONE_Z + PLAT_L + 7),
    COLOR_PLAT)

-- Murs dynamiques (taille/position mise à jour chaque Heartbeat)
local walls = {}

for i = 1, N_WALLS do
    local wz = ZONE_Z + PLAT_L * (i / (N_WALLS + 1))
    local p  = WALL_PARAMS[i]

    -- Partie gauche du mur
    local lp = mkPart(string.format("WG_Mur%d_L", i),
        Vector3.new(1, WALL_H, WALL_D),
        CFrame.new(ZONE_X - PLAT_HW / 2, wallY, wz),
        COLOR_WALL)

    -- Partie droite du mur
    local rp = mkPart(string.format("WG_Mur%d_R", i),
        Vector3.new(1, WALL_H, WALL_D),
        CFrame.new(ZONE_X + PLAT_HW / 2, wallY, wz),
        COLOR_WALL)

    -- Indicateur de porte (vert, non-solide)
    local gi = mkPart(string.format("WG_Mur%d_Porte", i),
        Vector3.new(GAP_W, WALL_H, WALL_D * 0.25),
        CFrame.new(ZONE_X, wallY, wz),
        COLOR_GATE, false, 0.3)

    walls[i] = {
        z          = wz,
        speed      = p.speed,
        phase      = p.phase,
        leftPart   = lp,
        rightPart  = rp,
        gateMarker = gi,
        gapCenterX = ZONE_X,
    }
end

-- ────────────────────────────────────────────────────────────
-- ANIMATION — Heartbeat
-- ────────────────────────────────────────────────────────────
local elapsed      = 0
local pushCooldown = {}  -- [userId] = timestamp dernière poussée

RunService.Heartbeat:Connect(function(dt)
    elapsed += dt

    -- ── Mise à jour des murs ─────────────────────────────────
    for _, wall in ipairs(walls) do
        local gapCX  = ZONE_X + gapRange * math.sin(wall.speed * elapsed + wall.phase)
        wall.gapCenterX = gapCX

        local gapLeft  = gapCX - GAP_W / 2
        local gapRight = gapCX + GAP_W / 2

        local leftW  = math.max(0.05, gapLeft  - leftEdge)
        local rightW = math.max(0.05, rightEdge - gapRight)

        wall.leftPart.Size   = Vector3.new(leftW,  WALL_H, WALL_D)
        wall.leftPart.CFrame = CFrame.new(leftEdge + leftW / 2, wallY, wall.z)

        wall.rightPart.Size   = Vector3.new(rightW, WALL_H, WALL_D)
        wall.rightPart.CFrame = CFrame.new(rightEdge - rightW / 2, wallY, wall.z)

        wall.gateMarker.CFrame = CFrame.new(gapCX, wallY, wall.z)
    end

    -- ── Poussée des joueurs touchant un mur ──────────────────
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then continue end
        local pos = root.Position

        -- Filtre zone rapide
        if math.abs(pos.X - ZONE_X) > PLAT_HW + 3    then continue end
        if pos.Y < PLAT_Y - 1 or pos.Y > wallY + WALL_H then continue end
        if pos.Z < ZONE_Z - 5  or pos.Z > ZONE_Z + PLAT_L + 5 then continue end

        local uid = player.UserId
        if pushCooldown[uid] and (elapsed - pushCooldown[uid]) < 0.3 then continue end

        for _, wall in ipairs(walls) do
            -- Hors de la zone Z du mur → pas de poussée
            if math.abs(pos.Z - wall.z) > WALL_D / 2 + 1.8 then continue end

            -- Dans la porte → pas de poussée
            local inGap = pos.X > wall.gapCenterX - GAP_W / 2 - 1.5
                       and pos.X < wall.gapCenterX + GAP_W / 2 + 1.5
            if inGap then continue end

            -- Poussée latérale vers le bord le plus proche → vide
            local pushX = (pos.X >= ZONE_X) and 1 or -1
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = Vector3.new(pushX * 58, 14, 0)
            bv.MaxForce = Vector3.new(1e5, 1e5, 0)
            bv.Parent   = root
            Debris:AddItem(bv, 0.18)
            pushCooldown[uid] = elapsed
            break
        end
    end
end)

-- ────────────────────────────────────────────────────────────
-- TP (touche Y depuis le client)
-- ────────────────────────────────────────────────────────────
local spawnCF    = CFrame.new(ZONE_X, PLAT_Y + 4, ZONE_Z - 7)
local reTeleport = game.ReplicatedStorage:WaitForChild("Events")
                     :WaitForChild("TeleportToWallGate")

reTeleport.OnServerEvent:Connect(function(player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = spawnCF end
end)

-- ────────────────────────────────────────────────────────────
print("[WallGateTest] ✅ Murs-portes prêts")
print(string.format("  Zone X=%d | Plat %dx%d studs | %d murs", ZONE_X, PLAT_HW*2, PLAT_L, N_WALLS))
print("  [Y] = TP vers cette zone")
