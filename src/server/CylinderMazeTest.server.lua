-- CylinderMazeTest.server.lua
-- Zone de test : Grand cylindre rotatif à 5 segments
-- Chaque segment adjacent tourne dans le sens opposé.
-- Trous pour tomber, murs-obstacles, punching balls qui repoussent.
--
-- Structure : le cylindre est horizontal, axe = Z.
-- Les joueurs courent sur le DESSUS du cylindre de gauche à droite (en Z).
-- Chaque segment est un polygone à N_FACES faces qui tourne autour de l'axe Z.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris     = game:GetService("Debris")

-- ────────────────────────────────────────────────────────────
-- CONFIG
-- ────────────────────────────────────────────────────────────
local ZONE_X  = -800    -- X de la zone (isolée du parcours)
local ZONE_Z  =    0    -- Z de départ
local AXIS_Y  =   35    -- hauteur de l'axe du cylindre

local CYL_R   =   30    -- rayon (studs)
local SEG_D   =   28    -- profondeur Z d'un segment
local N_SEG   =    5    -- nombre de segments
local N_FACES =   16    -- faces par segment (polygone) — 16 = trous ~11.7 studs (vs 15.5 avec 12)
local FACE_T  =    1.8  -- épaisseur d'une face
local OMEGA         =    0.75  -- vitesse angulaire max (rad/s)
local OMEGA_MIN     =    0.12  -- vitesse au démarrage (lente)
local OMEGA_ACCEL   =    0.009 -- accélération (rad/s²) → pleine vitesse en ~70s
local omegaCurrent  =    0     -- vitesse courante (0 = arrêté, contrôlé par RoundManager)

-- Faces retirées (trous) par segment — 0-indexed sur N_FACES=16 (22.5° par face)
-- Face 4 = sommet exact (90°) — on évite faces 3,4,5 au départ
-- Face 7 ≈ 157.5° (gauche-haut), face 15 ≈ 337.5° (droite-bas)
-- Face 1 ≈  22.5° (droite-haut), face  9 ≈ 202.5° (gauche-bas)
local HOLES = {
    {  7, 15 },  -- seg 1
    {  1,  9 },  -- seg 2
    {  7, 15 },  -- seg 3
    {  1,  9 },  -- seg 4
    {  7, 15 },  -- seg 5
}

-- Direction de rotation : sens opposés entre segments adjacents
-- +1 = antihoraire (vu de +Z), -1 = horaire
local DIRS = { 1, -1, 1, -1, 1 }

local SEG_COLORS = {
    Color3.fromRGB(220,  70,  70),  -- rouge
    Color3.fromRGB( 60, 140, 220),  -- bleu
    Color3.fromRGB(220, 180,  50),  -- or
    Color3.fromRGB( 60, 190, 110),  -- vert
    Color3.fromRGB(190,  70, 210),  -- violet
}
local COLOR_WALL = Color3.fromRGB( 50,  55,  75)
local COLOR_BALL = Color3.fromRGB(255, 200,  50)
local COLOR_PLAT = Color3.fromRGB(255, 213,  79)
local COLOR_HOLE = Color3.fromRGB( 15,  15,  15)

-- ────────────────────────────────────────────────────────────
-- UTILITAIRES
-- ────────────────────────────────────────────────────────────
local testFolder = Instance.new("Folder")
testFolder.Name   = "CylinderMazeTest"
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

-- Largeur d'une face (corde de l'arc + 0.3 studs overlap pour éviter les gaps)
local faceW = 2 * CYL_R * math.sin(math.pi / N_FACES) + 0.3

-- ────────────────────────────────────────────────────────────
-- CONSTRUCTION DES SEGMENTS
-- ────────────────────────────────────────────────────────────
local segments  = {}  -- { center, dir, parts = { {part, localCF} } }
local segAngles = {}

for s = 1, N_SEG do
    local cx = ZONE_X
    local cy = AXIS_Y
    local cz = ZONE_Z + (s - 1) * SEG_D + SEG_D / 2

    local center   = Vector3.new(cx, cy, cz)
    local centerCF = CFrame.new(center)  -- CFrame de référence du segment (pas de rotation)

    -- Ensemble des indices de trous pour ce segment
    local holeSet = {}
    for _, h in ipairs(HOLES[s]) do holeSet[h] = true end

    local parts = {}  -- liste de { part, localCF }

    -- ── Faces du cylindre ────────────────────────────────────
    for f = 0, N_FACES - 1 do
        local baseAngle = (f / N_FACES) * math.pi * 2
        local px = cx + CYL_R * math.cos(baseAngle)
        local py = cy + CYL_R * math.sin(baseAngle)

        -- CFrame de la face : position sur le cylindre, orientée tangentiellement
        -- CFrame.Angles(0,0, baseAngle + π/2) tourne la face pour qu'elle soit tangente
        local faceCF = CFrame.new(px, py, cz) * CFrame.Angles(0, 0, baseAngle + math.pi / 2)

        if not holeSet[f] then
            -- Face pleine (solide)
            local p = mkPart(
                string.format("S%d_F%d", s, f),
                Vector3.new(faceW, FACE_T, SEG_D - 0.15),
                faceCF, SEG_COLORS[s])
            table.insert(parts, { part = p, localCF = centerCF:Inverse() * faceCF })
        else
            -- Trou : indicateur sombre non-solide
            local h = mkPart(
                string.format("S%d_Trou%d", s, f),
                Vector3.new(faceW, FACE_T * 0.35, SEG_D - 0.15),
                faceCF, COLOR_HOLE, false, 0.55)
            table.insert(parts, { part = h, localCF = centerCF:Inverse() * faceCF })
        end
    end

    -- ── Murs (fins radiales) — 2 par segment ─────────────────
    -- Placés sur des faces non-trouées, positions alternées entre segments
    local wallFaceList = (s % 2 == 1) and { 0, 8 } or { 5, 13 }
    local WALL_H = 13  -- hauteur du mur (studs, radiale)

    for _, wf in ipairs(wallFaceList) do
        if not holeSet[wf] then
            local wa = (wf / N_FACES) * math.pi * 2
            -- Centre du mur : à CYL_R + WALL_H/2 du centre (au-dessus de la face)
            local wallR = CYL_R + WALL_H / 2
            local wallX = cx + wallR * math.cos(wa)
            local wallY = cy + wallR * math.sin(wa)
            local wallCF = CFrame.new(wallX, wallY, cz) * CFrame.Angles(0, 0, wa + math.pi / 2)
            local wall = mkPart(
                string.format("S%d_Mur%d", s, wf),
                Vector3.new(1.2, WALL_H, SEG_D - 0.15),
                wallCF, COLOR_WALL)
            table.insert(parts, { part = wall, localCF = centerCF:Inverse() * wallCF })
        end
    end

    -- ── PunchCylinder (segments 2 et 4) ──────────────────────
    -- Cylindre jaune pointant radialement vers l'extérieur (même modèle que le dernier piège)
    if s == 2 or s == 4 then
        local CYL_H   = 12   -- longueur du cylindre
        local CYL_R_P = 2.0  -- rayon du cylindre (soit diamètre 4)
        local ballFace = 2   -- face 2 = ~72° (proche du sommet côté droit)
        local ba = (ballFace / N_FACES) * math.pi * 2
        -- Centre du cylindre : à CYL_R + CYL_H/2 de l'axe (pointe vers l'extérieur)
        local punchR = CYL_R + CYL_H / 2
        local px2 = cx + punchR * math.cos(ba)
        local py2 = cy + punchR * math.sin(ba)
        -- CFrame.Angles(0,0,ba) oriente l'axe X du cylindre dans la direction radiale
        local punchCF = CFrame.new(px2, py2, cz) * CFrame.Angles(0, 0, ba)

        local punch = mkPart(
            string.format("S%d_Punch", s),
            Vector3.new(CYL_H, CYL_R_P * 2, CYL_R_P * 2),
            punchCF, COLOR_BALL)
        punch.Shape = Enum.PartType.Cylinder

        -- Poussée au contact
        punch.Touched:Connect(function(hit)
            local char = hit.Parent
            local hum  = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if not hum or hum.Health <= 0 or not root then return end
            local pushDir = (root.Position - punch.Position).Unit
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = (pushDir + Vector3.new(0, 0.5, 0)).Unit * 60
            bv.MaxForce = Vector3.new(1e5, 1e5, 0)
            bv.Parent   = root
            Debris:AddItem(bv, 0.15)
        end)

        table.insert(parts, { part = punch, localCF = centerCF:Inverse() * punchCF })
    end

    segments[s]  = { center = center, dir = DIRS[s], parts = parts }
    segAngles[s] = 0
end

-- ────────────────────────────────────────────────────────────
-- DIMENSIONS (utilisées pour le spawn et la kill zone)
-- ────────────────────────────────────────────────────────────
local topY  = AXIS_Y + CYL_R           -- hauteur du sommet du cylindre
local endZ  = ZONE_Z + N_SEG * SEG_D   -- fin de la zone
-- Plateformes entrée/sortie supprimées — les joueurs arrivent via RoundManager

-- ────────────────────────────────────────────────────────────
-- ANIMATION — Heartbeat
-- ────────────────────────────────────────────────────────────
-- Chaque frame : incrémenter l'angle du segment → mettre à jour le CFrame de chaque part.
-- La formule : part.CFrame = CFrame(center) * RotZ(angle) * localCF
-- où localCF = position/orientation de la part relative au centre du segment à angle=0.

RunService.Heartbeat:Connect(function(dt)
    -- ── Accélération progressive ──────────────────────────────
    if omegaCurrent > 0 and omegaCurrent < OMEGA then
        omegaCurrent = math.min(OMEGA, omegaCurrent + OMEGA_ACCEL * dt)
    end

    -- ── Rotation des segments ─────────────────────────────────
    for s, seg in ipairs(segments) do
        local dAngle = seg.dir * omegaCurrent * dt
        segAngles[s] += dAngle
        local rotCF = CFrame.new(seg.center) * CFrame.Angles(0, 0, segAngles[s])
        for _, entry in ipairs(seg.parts) do
            if entry.part and entry.part.Parent then
                entry.part.CFrame = rotCF * entry.localCF
            end
        end
    end

    -- ── Kill zone : intérieur du cylindre ────────────────────
    -- Un joueur qui tombe dans un trou se retrouve à l'intérieur.
    -- Si distance à l'axe < CYL_R - 3, il est clairement dedans → mort.
    local killR2 = (CYL_R - 10) ^ 2
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then continue end
        local pos = root.Position
        if pos.Z < ZONE_Z - 2 or pos.Z > endZ + 2 then continue end
        local dx = pos.X - ZONE_X
        local dy = pos.Y - AXIS_Y
        if dx * dx + dy * dy < killR2 then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                hum.Health = 0
            end
        end
    end
end)

-- ────────────────────────────────────────────────────────────
-- API PUBLIQUE (_G.CylinderMaze) — utilisée par RoundManager
-- ────────────────────────────────────────────────────────────

local function getCylinderSpawnCFrames(n)
    -- Répartit n joueurs sur le dessus du cylindre, étalement Z sur tous les segments
    local spawns = {}
    local totalZ = N_SEG * SEG_D
    for i = 1, n do
        local t  = (i - 0.5) / n
        local sz = ZONE_Z + t * totalZ
        -- X légèrement décalé en alternance pour éviter la superposition
        local sx = ZONE_X + (((i - 1) % 3) - 1) * 4
        local sy = AXIS_Y + CYL_R + 4  -- 4 studs au-dessus du sommet
        table.insert(spawns, CFrame.new(sx, sy, sz))
    end
    return spawns
end

_G.CylinderMaze = {
    Start = function()
        omegaCurrent = OMEGA_MIN   -- démarre lentement, accélère via Heartbeat
        print("[CylinderMaze] ▶ Rotation démarrée (accélération progressive)")
    end,
    Stop = function()
        omegaCurrent = 0
        print("[CylinderMaze] ⏹ Rotation arrêtée")
    end,
    GetSpawnCFrames = function(n)
        return getCylinderSpawnCFrames(n)
    end,
    IsRunning = function()
        return omegaCurrent ~= 0
    end,
    TopY  = AXIS_Y + CYL_R,
    ZoneX = ZONE_X,
    ZoneZ = ZONE_Z,
    EndZ  = ZONE_Z + N_SEG * SEG_D,
}

-- ────────────────────────────────────────────────────────────
print("[CylinderMazeTest] ✅ Cylindre 5 segments prêt")
print(string.format("  Rayon: %d studs | %d segments | %.2f rad/s", CYL_R, N_SEG, OMEGA))
print(string.format("  Sommet Y=%.0f | Z=%d → %d", topY, ZONE_Z, endZ))
print("  Segments : rouge→bleu→or→vert→violet")
print("  Sens : +1 -1 +1 -1 +1 (adjacents toujours opposés)")
