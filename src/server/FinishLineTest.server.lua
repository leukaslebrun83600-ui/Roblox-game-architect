-- FinishLineTest.server.lua
-- Spawn → Sol plat → Pente 4 voies → Escaliers (entre canons) → Plateforme haute
-- Touche Y → TP spawn | Mort = respawn en bas de la pente

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ============================================================
-- CONFIG
-- ============================================================
local ZONE_X = 0
local ZONE_Z = 2900
local BASE_Y = 10

-- ── Rampe ─────────────────────────────────────────────────────
local RAMP_W     = 84
local RAMP_H_LEN = 90
local RAMP_RISE  = 18
local RAMP_THICK = 2
local RAMP_ANGLE = math.atan(RAMP_RISE / RAMP_H_LEN)
local RAMP_S_LEN = math.sqrt(RAMP_H_LEN^2 + RAMP_RISE^2)   -- ≈ 91.8

-- Élévation de la plateforme de spawn + escaliers descente
local SPAWN_ELEV   = 8
local SPAWN_STEP_N = 4
local SPAWN_STEP_H = SPAWN_ELEV / SPAWN_STEP_N  -- = 2
local SPAWN_STEP_D = 3
local SPAWN_STAIR_W = 18
local SPAWN_STAIR_X = {-20, 20}

-- Sol plat avant la rampe (arrête les boules)
local FLAT_D       = 40
local RAMP_START_Z = ZONE_Z + 30 + FLAT_D

local RAMP_END_Z   = RAMP_START_Z + RAMP_H_LEN  -- = 3130
local RAMP_TOP_Y   = BASE_Y + RAMP_RISE          -- = 28

local rampOriginCF = CFrame.new(ZONE_X, BASE_Y, RAMP_START_Z)
                   * CFrame.Angles(-RAMP_ANGLE, 0, 0)

local function onRamp(dx, dy, dz)
    return rampOriginCF * CFrame.new(dx, dy, dz)
end

-- ── Voies ──────────────────────────────────────────────────────
local LANE_W  = 16
local WALL_W  = 4
local WALL_H  = 7
local DIV_H   = 6
local BLOCK_D = 7
local BLOCK_W = 6
local BLOCK_G = 7
local BLOCK_STEP = BLOCK_D + BLOCK_G

local LANE_X  = {-30, -10, 10, 30}
local DIV_X   = {-20, 0, 20}
local OWALL_X = {-40, 40}

-- ── Blocs séparateurs : fin (retrait 2 derniers) ──────────────
local DIV_STOP = RAMP_S_LEN - BLOCK_D / 2 - 3 * BLOCK_STEP  -- ramp local : retire 3 derniers blocs

-- ── Escaliers (entre les canons → plateforme haute) ──────────────
local lastBlockEndDZ  = DIV_STOP + BLOCK_D / 2
local STAIR_START_Z_W = RAMP_START_Z + math.floor(lastBlockEndDZ * math.cos(RAMP_ANGLE)) + 18
local STAIR_BASE_Y    = BASE_Y + RAMP_RISE * (STAIR_START_Z_W - RAMP_START_Z) / RAMP_H_LEN
local STAIR_H  = 3
local STAIR_D  = 4
local STAIR_N  = 5
local STAIR_W  = 8

-- ── Plateforme haute (accessible via escaliers) ───────────────────
local PLAT_Y_SURF  = math.floor(STAIR_BASE_Y + STAIR_H * STAIR_N + 0.5)  -- ≈ 40
local PLAT_START_Z = STAIR_START_Z_W + STAIR_N * STAIR_D
local PLAT_D       = 40
local PLAT_H       = 2

-- ── Canons ────────────────────────────────────────────────────
local FIRE_INTERVAL  = 2.0
local MIN_SPAWN_GAP  = 1.1   -- intervalle minimum entre deux spawns
local BALL_COLORS    = {
    Color3.fromRGB(255, 60, 60),    -- rouge
    Color3.fromRGB(255, 160, 20),   -- orange
    Color3.fromRGB(80, 180, 255),   -- bleu
    Color3.fromRGB(120, 220, 80),   -- vert
    Color3.fromRGB(200, 80, 255),   -- violet
    Color3.fromRGB(255, 220, 40),   -- jaune
}
local BALL_SPEED    = 25
local BALL_R        = 5.5
local CANNON_DZ     = RAMP_S_LEN - 3   -- ramp local ≈ 88.8
local CANNON_PHASE  = {0, 0.9, 1.8, 0.45}

-- ── Respawn (toujours en bas de la pente) ─────────────────────
local RAMP_RESPAWN = CFrame.new(ZONE_X, BASE_Y + 4, RAMP_START_Z - 3)

-- ============================================================
-- DOSSIER
-- ============================================================
local _old = workspace:FindFirstChild("TestZone2")
if _old then _old:Destroy() end

local zoneFolder = Instance.new("Folder")
zoneFolder.Name   = "TestZone2"
zoneFolder.Parent = workspace

-- ============================================================
-- UTILITAIRES
-- ============================================================
local function mkPart(name, size, cf, color, material)
    local p = Instance.new("Part")
    p.Name       = name
    p.Size       = size
    p.CFrame     = cf
    p.Color      = color or Color3.fromRGB(255, 213, 79)
    p.Material   = material or Enum.Material.SmoothPlastic
    p.Anchored   = true
    p.CastShadow = false
    p.Parent     = zoneFolder
    return p
end

local function mkCylinder(name, size, cf, color)
    local p = Instance.new("Part")
    p.Name       = name
    p.Shape      = Enum.PartType.Cylinder
    p.Size       = size
    p.CFrame     = cf
    p.Color      = color or Color3.fromRGB(40, 40, 70)
    p.Material   = Enum.Material.SmoothPlastic
    p.Anchored   = true
    p.CastShadow = false
    p.Parent     = zoneFolder
    return p
end

-- ============================================================
-- PLATEFORME DE SPAWN (80×60)
-- ============================================================
local SPAWN_D = 60
mkPart("Spawn_Platform",
    Vector3.new(90, 1.2, SPAWN_D),
    CFrame.new(ZONE_X, BASE_Y + SPAWN_ELEV, ZONE_Z),
    Color3.fromRGB(255, 213, 79))

for row = 0, 4 do
    for col = 0, 5 do
        mkPart(string.format("Marker_%d_%d", row, col),
            Vector3.new(3, 0.2, 3),
            CFrame.new(ZONE_X - 20 + col * 8, BASE_Y + SPAWN_ELEV + 0.7, ZONE_Z - 16 + row * 8),
            Color3.fromRGB(255, 255, 255))
    end
end

-- ============================================================
-- SOL PLAT AVANT LA RAMPE (arrête les boules)
-- ============================================================
local FLAT_Z0 = ZONE_Z + SPAWN_D / 2
mkPart("FlatFloor",
    Vector3.new(RAMP_W, 1.2, FLAT_D),
    CFrame.new(ZONE_X, BASE_Y - 0.6, FLAT_Z0 + FLAT_D / 2),
    Color3.fromRGB(180, 230, 255))

-- ============================================================
-- ESCALIERS SPAWN → FLATFLOOR (2 voies)
-- ============================================================
for si, sx in ipairs(SPAWN_STAIR_X) do
    for s = 0, SPAWN_STEP_N - 1 do
        local stepH  = (SPAWN_ELEV + 0.6) - s * SPAWN_STEP_H
        local stepCY = BASE_Y + stepH / 2
        local stepCZ = FLAT_Z0 + s * SPAWN_STEP_D + SPAWN_STEP_D / 2
        mkPart(string.format("SpawnStair_%d_S%d", si, s),
            Vector3.new(SPAWN_STAIR_W, stepH, SPAWN_STEP_D),
            CFrame.new(sx, stepCY, stepCZ),
            Color3.fromRGB(180, 230, 255))
    end
end

-- Barrière entre les deux voies d'escalier
local barrierW = 2 * (math.abs(SPAWN_STAIR_X[1]) - SPAWN_STAIR_W / 2) + 2
mkPart("SpawnBarrier",
    Vector3.new(barrierW, SPAWN_ELEV + 4, 1.5),
    CFrame.new(ZONE_X, BASE_Y + (SPAWN_ELEV + 4) / 2, FLAT_Z0),
    Color3.fromRGB(255, 190, 80))

-- ============================================================
-- RAMPE
-- ============================================================
mkPart("Ramp_Surface",
    Vector3.new(RAMP_W, RAMP_THICK, RAMP_S_LEN),
    onRamp(0, -RAMP_THICK / 2, RAMP_S_LEN / 2),
    Color3.fromRGB(180, 230, 255))

for _, ox in ipairs(OWALL_X) do
    local side = (ox < 0) and "Left" or "Right"
    mkPart("OuterWall_" .. side,
        Vector3.new(WALL_W, WALL_H, RAMP_S_LEN),
        onRamp(ox, WALL_H / 2, RAMP_S_LEN / 2),
        Color3.fromRGB(255, 190, 80))

    local cap = mkPart("OuterWallCap_" .. side,
        Vector3.new(WALL_W, 12, RAMP_S_LEN),
        onRamp(ox, WALL_H + 6, RAMP_S_LEN / 2),
        Color3.fromRGB(255, 255, 255))
    cap.Transparency = 1
end

-- ── Blocs séparateurs ──────────────────────────────────────────────
local divColors = {
    Color3.fromRGB(255, 160, 80),
    Color3.fromRGB(110, 230, 160),
    Color3.fromRGB(190, 130, 255),
}
for di, dx in ipairs(DIV_X) do
    local bi = 0
    local dz = BLOCK_D / 2
    while dz <= DIV_STOP do
        mkPart(string.format("Div%d_B%d", di, bi),
            Vector3.new(BLOCK_W, DIV_H, BLOCK_D),
            onRamp(dx, DIV_H / 2, dz),
            divColors[di])

        -- Cap invisible : bloque l'atterrissage sur le dessus du bloc
        local cap = mkPart(string.format("DivCap%d_B%d", di, bi),
            Vector3.new(BLOCK_W, 10, BLOCK_D),
            onRamp(dx, DIV_H + 5, dz),
            Color3.fromRGB(255, 255, 255))
        cap.Transparency = 1

        dz += BLOCK_STEP
        bi += 1
    end
end

-- ============================================================
-- CANONS (tambour cylindrique + tube)
-- ============================================================

-- Mur jaune continu sous tous les canons (même couleur que les murs latéraux)
mkPart("CannonWall",
    Vector3.new(RAMP_W, WALL_H, 10),
    onRamp(0, WALL_H / 2, CANNON_DZ),
    Color3.fromRGB(255, 190, 80))

for li, lx in ipairs(LANE_X) do
    -- Tambour : cylindre vertical (axe X → rotate Z 90° pour axe Y)
    mkCylinder("CannonDrum_" .. li,
        Vector3.new(7, 9, 9),
        onRamp(lx, WALL_H + 3.5, CANNON_DZ) * CFrame.Angles(0, 0, math.pi / 2),
        Color3.fromRGB(45, 45, 80))

    -- Tube : cylindre horizontal pointant vers les joueurs (axe Z ramp)
    mkCylinder("CannonBarrel_" .. li,
        Vector3.new(11, 3, 3),
        onRamp(lx, WALL_H + 4, CANNON_DZ - 4) * CFrame.Angles(0, math.pi / 2, 0),
        Color3.fromRGB(20, 20, 50))

    -- Bague d'embout (bouche du canon)
    mkCylinder("CannonMuzzle_" .. li,
        Vector3.new(2, 4.5, 4.5),
        onRamp(lx, WALL_H + 4, CANNON_DZ - 9.5) * CFrame.Angles(0, math.pi / 2, 0),
        Color3.fromRGB(65, 65, 110))
end

-- ============================================================
-- ESCALIERS (3 voies entre les canons → plateforme haute)
-- ============================================================
local STAIR_COLOR = Color3.fromRGB(160, 220, 255)
for si, sx in ipairs(DIV_X) do
    for s = 0, STAIR_N - 1 do
        local stepH  = STAIR_H * (s + 1)
        local stepCY = STAIR_BASE_Y + stepH / 2
        local stepCZ = STAIR_START_Z_W + s * STAIR_D + STAIR_D / 2
        mkPart(string.format("Stair_%d_S%d", si, s),
            Vector3.new(STAIR_W, stepH, STAIR_D),
            CFrame.new(sx, stepCY, stepCZ),
            STAIR_COLOR)
    end
end

-- ============================================================
-- PLATEFORME HAUTE (accessible via escaliers)
-- ============================================================
mkPart("HighPlatform",
    Vector3.new(RAMP_W, PLAT_H, PLAT_D),
    CFrame.new(ZONE_X, PLAT_Y_SURF - PLAT_H / 2, PLAT_START_Z + PLAT_D / 2),
    Color3.fromRGB(200, 240, 255))

local PLAT_WALL_H = 6
for _, ox in ipairs(OWALL_X) do
    local side = (ox < 0) and "L" or "R"
    mkPart("PlatWall_" .. side,
        Vector3.new(WALL_W, PLAT_WALL_H, PLAT_D),
        CFrame.new(ox, PLAT_Y_SURF + PLAT_WALL_H / 2, PLAT_START_Z + PLAT_D / 2),
        Color3.fromRGB(255, 190, 80))
end

-- ============================================================
-- SECTION 2 : POUTRES CYLINDRIQUES + FOSSE
-- ============================================================
local CYL_SEC_Z      = PLAT_START_Z + PLAT_D + 2
local CYL_LENGTH     = 60           -- longueur totale (2 × demi-poutres)
local CYL_D          = 5            -- diamètre (poutres fines)
local halfL          = CYL_LENGTH / 2  -- = 30, longueur de chaque demi-poutre
local CYL_GAP        = 8            -- espace (Z) entre les 2 paires
local TOTAL_CYL_SPAN = CYL_LENGTH + CYL_GAP  -- = 68, portée Z totale
local PIT_Y_SURF     = PLAT_Y_SURF - 28  -- sol de la fosse (plus bas)
local PIT_W          = RAMP_W
local PIT_LENGTH     = TOTAL_CYL_SPAN   -- fosse couvre exactement les cylindres

-- Groupe 1 (Z_near) : 6 poutres parallèles — saut latéral, 7 studs de gap libre
-- Groupe 2 (Z_far)  : 4 poutres espacées  — plus dur, saut pour atteindre
local cylDefs = {
    -- Groupe 1 : 6 poutres à même plage Z, X = {-30,-18,-6,+6,+18,+30}
    {x = -30, zOff = 0},
    {x = -18, zOff = 0},
    {x =  -6, zOff = 0},
    {x =   6, zOff = 0},
    {x =  18, zOff = 0},
    {x =  30, zOff = 0},
    -- Groupe 2 : 4 poutres décalées en Z, X = {-22,-8,+8,+22}
    {x = -22, zOff = halfL + CYL_GAP},
    {x =  -8, zOff = halfL + CYL_GAP},
    {x =   8, zOff = halfL + CYL_GAP},
    {x =  22, zOff = halfL + CYL_GAP},
}
for ci, def in ipairs(cylDefs) do
    mkCylinder(string.format("CylBeam_%d", ci),
        Vector3.new(halfL, CYL_D, CYL_D),
        CFrame.new(def.x, PLAT_Y_SURF - CYL_D/2,
                   CYL_SEC_Z + def.zOff + halfL/2)
            * CFrame.Angles(0, math.pi/2, 0),
        Color3.fromRGB(100, 200, 255))
end

-- Sol de la fosse (ralentit les joueurs)
local pitFloor = mkPart("PitFloor",
    Vector3.new(PIT_W, 2, PIT_LENGTH),
    CFrame.new(ZONE_X, PIT_Y_SURF - 1, CYL_SEC_Z + PIT_LENGTH / 2),
    Color3.fromRGB(80, 190, 255))

-- Murs latéraux de la fosse
local pitWallH = PLAT_Y_SURF - PIT_Y_SURF + 4
for _, sx in ipairs({-(PIT_W/2 + 1), PIT_W/2 + 1}) do
    mkPart("PitWall_" .. (sx < 0 and "L" or "R"),
        Vector3.new(2, pitWallH, PIT_LENGTH),
        CFrame.new(sx, PIT_Y_SURF + pitWallH / 2 - 1, CYL_SEC_Z + PIT_LENGTH / 2),
        Color3.fromRGB(255, 190, 80))
end

-- Mur avant de la fosse (côté plateforme — flush avec PLAT_Y_SURF, ne dépasse pas)
local frontWallH = PLAT_Y_SURF - PIT_Y_SURF   -- exactement de PIT_Y_SURF à PLAT_Y_SURF
mkPart("PitWall_Front",
    Vector3.new(PIT_W + 4, frontWallH, 2),
    CFrame.new(ZONE_X, PIT_Y_SURF + frontWallH / 2, CYL_SEC_Z - 1),
    Color3.fromRGB(255, 190, 80))

-- Rampe de remontée : part exactement au bout des cylindres
local REC_RISE  = PLAT_Y_SURF - PIT_Y_SURF
local REC_H_LEN = 34
local REC_ANGLE = math.atan(REC_RISE / REC_H_LEN)
local REC_S_LEN = math.sqrt(REC_H_LEN^2 + REC_RISE^2)
local REC_Z     = CYL_SEC_Z + PIT_LENGTH   -- aligne avec la fin des cylindres
local recCF     = CFrame.new(ZONE_X, PIT_Y_SURF, REC_Z) * CFrame.Angles(-REC_ANGLE, 0, 0)

mkPart("RecoveryRamp",
    Vector3.new(PIT_W, 2, REC_S_LEN),
    recCF * CFrame.new(0, -1, REC_S_LEN / 2),
    Color3.fromRGB(180, 230, 255))

for _, ox in ipairs({-(PIT_W/2 + 1), PIT_W/2 + 1}) do
    mkPart("RecWall_" .. (ox < 0 and "L" or "R"),
        Vector3.new(2, pitWallH, REC_S_LEN),
        recCF * CFrame.new(ox, pitWallH / 2, REC_S_LEN / 2),
        Color3.fromRGB(255, 190, 80))
end

-- Blocs triangulaires sur la pente (gênent le joueur, slalom gauche/droite)
local WEDGE_H = 3
local WEDGE_D = 4
local WEDGE_W = 18
local wedgeDefs = {
    {dx = -16, dz = REC_S_LEN * 0.28},
    {dx =  16, dz = REC_S_LEN * 0.55},
    {dx = -16, dz = REC_S_LEN * 0.78},
}
for wi, wd in ipairs(wedgeDefs) do
    local w = Instance.new("WedgePart")
    w.Name       = "RampWedge_" .. wi
    w.Size       = Vector3.new(WEDGE_W, WEDGE_H, WEDGE_D)
    w.Color      = Color3.fromRGB(255, 160, 60)
    w.Material   = Enum.Material.SmoothPlastic
    w.Anchored   = true
    w.CastShadow = false
    w.Parent     = zoneFolder
    w.CFrame     = recCF * CFrame.new(wd.dx, WEDGE_H / 2, wd.dz)
                 * CFrame.Angles(0, math.pi, 0)
end

-- Plateforme après la pente (même longueur que la pente en horizontal)
local PLAT2_D     = REC_H_LEN   -- = 34 studs, même footprint que la pente
local PLAT2_H     = 2
local PLAT2_START = REC_Z + REC_H_LEN
mkPart("Platform2",
    Vector3.new(RAMP_W, PLAT2_H, PLAT2_D),
    CFrame.new(ZONE_X, PLAT_Y_SURF - PLAT2_H / 2, PLAT2_START + PLAT2_D / 2),
    Color3.fromRGB(200, 240, 255))

-- Même X que les murs de la pente (±43), même hauteur projetée
-- Extension arrière pour combler le triangle entre le mur de pente et celui de plateforme
local PLAT2_WALL_H = PLAT_WALL_H   -- = 6, comme les autres murs de plateforme
local WALL_EXT     = math.ceil(PLAT2_WALL_H * math.sin(REC_ANGLE))  -- recouvre le gap
for _, ox in ipairs({-(PIT_W/2 + 1), PIT_W/2 + 1}) do
    mkPart("Plat2Wall_" .. (ox < 0 and "L" or "R"),
        Vector3.new(2, PLAT2_WALL_H, PLAT2_D + WALL_EXT),
        CFrame.new(ox, PLAT_Y_SURF + PLAT2_WALL_H / 2,
                   PLAT2_START + PLAT2_D / 2 - WALL_EXT / 2),
        Color3.fromRGB(255, 190, 80))
end

-- ============================================================
-- SECTION 3 : PENTE CENTRALE + PLATEFORME + FOSSES LATÉRALES
-- ============================================================
local S3_START_Z    = PLAT2_START + PLAT2_D
local S3_RAMP_W     = 36                              -- largeur de la pente centrale
local S3_RAMP_H_LEN = 45                              -- projection horizontale
local S3_RAMP_RISE  = 10                              -- descente
local S3_RAMP_ANGLE = math.atan(S3_RAMP_RISE / S3_RAMP_H_LEN)
local S3_RAMP_S_LEN = math.sqrt(S3_RAMP_H_LEN^2 + S3_RAMP_RISE^2)
local PLAT3_Y       = PLAT_Y_SURF - S3_RAMP_RISE     -- surface de la plateforme basse

local S3_PLAT_D     = 80
local S3_PLAT_H     = 2
local S3_PLAT_START = S3_START_Z + S3_RAMP_H_LEN

-- Fosses latérales
local PIT3_DEPTH   = 12
local PIT3_Y       = PLAT3_Y - PIT3_DEPTH             -- sol des fosses
local PIT3_W       = RAMP_W / 2 - S3_RAMP_W / 2      -- = 24 studs de large par fosse
local PIT3_Z_END   = S3_PLAT_START + S3_PLAT_D
local PIT3_Z_LEN   = PIT3_Z_END - S3_START_Z
local PIT3_WALL_H  = PLAT_Y_SURF - PIT3_Y + 4
local pit3WallCY   = PIT3_Y + PIT3_WALL_H / 2

-- ── Pente centrale descendante ─────────────────────────────
local s3rampCF = CFrame.new(ZONE_X, PLAT_Y_SURF, S3_START_Z)
               * CFrame.Angles(S3_RAMP_ANGLE, 0, 0)
mkPart("S3_Ramp",
    Vector3.new(S3_RAMP_W, 2, S3_RAMP_S_LEN),
    s3rampCF * CFrame.new(0, -1, S3_RAMP_S_LEN / 2),
    Color3.fromRGB(180, 230, 255))

-- ── Plateforme centrale basse ───────────────────────────────
mkPart("S3_Platform",
    Vector3.new(S3_RAMP_W, S3_PLAT_H, S3_PLAT_D),
    CFrame.new(ZONE_X, PLAT3_Y - S3_PLAT_H / 2, S3_PLAT_START + S3_PLAT_D / 2),
    Color3.fromRGB(200, 240, 255))

-- ── Fosses latérales (gauche et droite) ─────────────────────
for _, side in ipairs({"L", "R"}) do
    local sign   = (side == "L") and -1 or 1
    local pitCX  = sign * (S3_RAMP_W / 2 + PIT3_W / 2)  -- centre X de la fosse = ±30
    local outerX = sign * (RAMP_W / 2 + 1)               -- mur extérieur = ±43

    -- Sol de la fosse
    mkPart("S3_PitFloor_" .. side,
        Vector3.new(PIT3_W, 2, PIT3_Z_LEN),
        CFrame.new(pitCX, PIT3_Y - 1, S3_START_Z + PIT3_Z_LEN / 2),
        Color3.fromRGB(80, 190, 255))

    -- Mur extérieur (X = ±43, du sol de la fosse au-dessus de PLAT_Y_SURF)
    mkPart("S3_PitOuter_" .. side,
        Vector3.new(2, PIT3_WALL_H, PIT3_Z_LEN),
        CFrame.new(outerX, pit3WallCY, S3_START_Z + PIT3_Z_LEN / 2),
        Color3.fromRGB(255, 190, 80))

    -- Mur arrière (ferme le fond de la fosse)
    mkPart("S3_PitBack_" .. side,
        Vector3.new(PIT3_W + 4, PIT3_WALL_H, 2),
        CFrame.new(pitCX, pit3WallCY, PIT3_Z_END + 1),
        Color3.fromRGB(255, 190, 80))
end

-- ── Escaliers dans les fosses latérales (descente en Z, depuis PLAT_Y_SURF → PIT3_Y) ──
-- L'ensemble des marches couvre exactement la longueur de S3_Platform (S3_PLAT_D)
local S3_STAIR_H  = 2                                        -- hauteur par marche
local S3_STAIR_N  = (PLAT_Y_SURF - PIT3_Y) / S3_STAIR_H     -- = 11 marches
local S3_STAIR_D  = S3_PLAT_D / S3_STAIR_N                  -- profondeur auto ≈ 7.3 studs
local S3_STAIR_W  = 10                                       -- largeur (en X, dans la fosse)
local S3_STAIR_Z0 = S3_PLAT_START                            -- démarre avec la plateforme centrale

for _, side in ipairs({"L", "R"}) do
    local sign  = (side == "L") and -1 or 1
    local stepX = sign * (S3_RAMP_W / 2 + PIT3_W / 2)  -- centre X de la fosse = ±30
    for si = 0, S3_STAIR_N - 1 do
        local topY    = PLAT_Y_SURF - si * S3_STAIR_H
        local blockH  = topY - PIT3_Y
        local blockCY = PIT3_Y + blockH / 2
        local blockCZ = S3_STAIR_Z0 + si * S3_STAIR_D + S3_STAIR_D / 2
        mkPart(string.format("S3_Stair_%s_%d", side, si),
            Vector3.new(S3_STAIR_W, blockH, S3_STAIR_D),
            CFrame.new(stepX, blockCY, blockCZ),
            Color3.fromRGB(160, 220, 255))
    end
end

-- ── Cylindres oscillants (suspendus par 2 cordes, bougent gauche-droite) ──
local S3CYL_PIVOT_H = 24              -- hauteur pivot au-dessus de PLAT3_Y
local S3CYL_PIVOT_Y = PLAT3_Y + S3CYL_PIVOT_H
local S3CYL_HANG_Y  = PLAT3_Y + 7    -- centre du cylindre (plus haut, torse/épaules)
local S3CYL_LEN     = 32             -- longueur du cylindre (axe Z)
local S3CYL_D       = 7              -- diamètre (bien visible)
local S3CYL_FREQ    = 1.3            -- vitesse (rad/s)
local S3CYL_AMP     = 12            -- amplitude X (±12 → balaye presque tout le plateau)

-- 2 cylindres espacés le long de la plateforme, en opposition de phase
local s3CylDefs = {
    {pz = S3_PLAT_START + 20, phase = 0         },
    {pz = S3_PLAT_START + 58, phase = math.pi   },
}
local s3cylData  = {}
local s3cylHitCD = {}

for i, def in ipairs(s3CylDefs) do
    -- Poteaux de support (un à chaque extrémité Z du cylindre)
    local postH = S3CYL_PIVOT_Y - PLAT3_Y
    for _, zEnd in ipairs({def.pz - S3CYL_LEN/2, def.pz + S3CYL_LEN/2}) do
        mkPart(string.format("S3CylPost_%d_%s", i, zEnd > def.pz and "F" or "B"),
            Vector3.new(1.5, postH, 1.5),
            CFrame.new(ZONE_X, PLAT3_Y + postH / 2, zEnd),
            Color3.fromRGB(55, 55, 65), Enum.Material.Metal)
    end

    -- Cylindre (long axe = Z via Angles(0, π/2, 0))
    local cyl = Instance.new("Part")
    cyl.Name       = "S3Cyl_" .. i
    cyl.Shape      = Enum.PartType.Cylinder
    cyl.Size       = Vector3.new(S3CYL_LEN, S3CYL_D, S3CYL_D)
    cyl.Color      = Color3.fromRGB(220, 80, 60)
    cyl.Material   = Enum.Material.SmoothPlastic
    cyl.Anchored   = true
    cyl.CanCollide = false   -- collision gérée manuellement (push custom)
    cyl.CastShadow = false
    cyl.Parent     = zoneFolder

    -- 2 cordes : du pivot au-dessus jusqu'à chaque extrémité Z du cylindre
    local ropes = {}
    for _, zSign in ipairs({-1, 1}) do
        local r = Instance.new("Part")
        r.Name       = string.format("S3CylRope_%d_%d", i, zSign)
        r.Size       = Vector3.new(0.35, 0.35, 1)
        r.Color      = Color3.fromRGB(65, 50, 30)
        r.Material   = Enum.Material.Metal
        r.Anchored   = true
        r.CanCollide = false
        r.CastShadow = false
        r.Parent     = zoneFolder
        table.insert(ropes, {part = r, zEnd = def.pz + zSign * S3CYL_LEN / 2})
    end

    table.insert(s3cylData, {cyl = cyl, ropes = ropes, pz = def.pz, phase = def.phase})
end

-- Sol ralentissant via Touched (zone correcte uniquement)
local slowedPlayers = {}
pitFloor.Touched:Connect(function(hit)
    local char = hit.Parent
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 and not slowedPlayers[char] then
        slowedPlayers[char] = hum.WalkSpeed
        hum.WalkSpeed = 7
    end
end)
pitFloor.TouchEnded:Connect(function(hit)
    local char = hit.Parent
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum and slowedPlayers[char] then
        hum.WalkSpeed = slowedPlayers[char]
        slowedPlayers[char] = nil
    end
end)

-- ============================================================
-- BOULES DE DÉMOLITION (pendules sur les cylindres)
-- ============================================================
local WB_PIVOT_Y = PLAT_Y_SURF + 20  -- point d'attache en hauteur
local WB_BALL_Y  = PLAT_Y_SURF + 3   -- hauteur de la boule (torse du joueur)
local WB_BALL_R  = 3.5               -- rayon de la boule
local WB_FREQ    = 2.2               -- vitesse angulaire (rad/s)
local wbHitCD    = {}                -- debounce collision par joueur

local WB_COLORS = {
    Color3.fromRGB(220, 50,  50),   -- rouge
    Color3.fromRGB(50,  180, 255),  -- bleu
    Color3.fromRGB(80,  220, 80),   -- vert
    Color3.fromRGB(255, 160, 20),   -- orange
    Color3.fromRGB(200, 80,  255),  -- violet
}

-- 5 boules : 3 sur groupe 1 (couvrent paires de cylindres), 2 sur groupe 2
-- amp individuel par boule pour couvrir exactement ses 2 cylindres
local wbDefs = {
    {px = -24, pz = CYL_SEC_Z + 10, phase = 0,             amp = 8},
    {px =   0, pz = CYL_SEC_Z + 19, phase = math.pi,       amp = 8},
    {px =  24, pz = CYL_SEC_Z + 13, phase = 0,             amp = 8},
    {px = -15, pz = CYL_SEC_Z + 48, phase = math.pi * 0.5, amp = 9},
    {px =  15, pz = CYL_SEC_Z + 58, phase = math.pi * 1.5, amp = 9},
}

local wbData = {}
local postH  = WB_PIVOT_Y - PIT_Y_SURF   -- poteau du sol de la fosse au pivot
local postCY = PIT_Y_SURF + postH / 2
for i, def in ipairs(wbDefs) do
    -- Poteau du sol de la fosse jusqu'au pivot (traverse le plancher des cylindres)
    mkPart(string.format("WBPost_%d", i),
        Vector3.new(1.5, postH, 1.5),
        CFrame.new(def.px, postCY, def.pz),
        Color3.fromRGB(55, 55, 65), Enum.Material.Metal)

    -- Boule colorée
    local ball = Instance.new("Part")
    ball.Name       = "WreckBall_" .. i
    ball.Shape      = Enum.PartType.Ball
    ball.Size       = Vector3.new(WB_BALL_R*2, WB_BALL_R*2, WB_BALL_R*2)
    ball.Color      = WB_COLORS[((i - 1) % #WB_COLORS) + 1]
    ball.Material   = Enum.Material.SmoothPlastic
    ball.Anchored   = true
    ball.CanCollide = false
    ball.CastShadow = false
    ball.Parent     = zoneFolder

    -- Corde (Part mis à jour chaque frame)
    local rope = Instance.new("Part")
    rope.Name       = "WBRope_" .. i
    rope.Size       = Vector3.new(0.35, 0.35, WB_PIVOT_Y - WB_BALL_Y)
    rope.Color      = Color3.fromRGB(65, 50, 30)
    rope.Material   = Enum.Material.Metal
    rope.Anchored   = true
    rope.CanCollide = false
    rope.CastShadow = false
    rope.Parent     = zoneFolder

    table.insert(wbData, {
        ball  = ball, rope = rope,
        px    = def.px, pz = def.pz,
        phase = def.phase, amp = def.amp,
    })
end

print(string.format("[TestZone2] ✅ Rampe | %d canons | blocs | escaliers | plateforme Y=%d | cylindres | %d boules",
    #LANE_X, PLAT_Y_SURF, #wbDefs))

-- ============================================================
-- CHECKPOINT (invisible, au début de la plateforme haute)
-- ============================================================
local checkpointRespawn = {}  -- [player] = CFrame

local CP_CF   = CFrame.new(ZONE_X, PLAT_Y_SURF + 4, PLAT_START_Z + 5)
local cpPart  = Instance.new("Part")
cpPart.Name         = "Checkpoint_1"
cpPart.Size         = Vector3.new(RAMP_W, 12, 4)
cpPart.CFrame       = CP_CF
cpPart.Anchored     = true
cpPart.CanCollide   = false
cpPart.Transparency = 1
cpPart.Parent       = zoneFolder

cpPart.Touched:Connect(function(hit)
    local char   = hit.Parent
    local player = Players:GetPlayerFromCharacter(char)
    if player and not checkpointRespawn[player] then
        checkpointRespawn[player] = CP_CF
    end
end)

Players.PlayerRemoving:Connect(function(player)
    checkpointRespawn[player] = nil
end)

-- ============================================================
-- RESPAWN : checkpoint si atteint, sinon bas de la pente
-- ============================================================
local function bindRespawn(player)
    player.CharacterAdded:Connect(function(char)
        local root = char:WaitForChild("HumanoidRootPart", 5)
        if root then
            task.wait(0.15)
            root.CFrame = checkpointRespawn[player] or RAMP_RESPAWN
        end
    end)
end

Players.PlayerAdded:Connect(function(player) bindRespawn(player) end)
for _, player in ipairs(Players:GetPlayers()) do bindRespawn(player) end

-- ============================================================
-- LOGIQUE BOULETS
-- ============================================================
local activeBalls = {}

local function spawnBall(laneIndex)
    local ball = Instance.new("Part")
    ball.Name     = "Ball_L" .. laneIndex
    ball.Shape    = Enum.PartType.Ball
    ball.Size     = Vector3.new(BALL_R * 2, BALL_R * 2, BALL_R * 2)
    ball.Color    = BALL_COLORS[math.random(1, #BALL_COLORS)]
    ball.Material = Enum.Material.SmoothPlastic
    ball.Anchored = true
    ball.CastShadow = false
    ball.Parent   = zoneFolder

    local data = {
        ball  = ball,
        laneX = LANE_X[laneIndex],
        rampZ = CANNON_DZ - BALL_R - 3,
        hit   = false,
    }
    table.insert(activeBalls, data)
    return data
end

local lastSpawnTime = 0

for i = 1, #LANE_X do
    task.spawn(function()
        task.wait(CANNON_PHASE[i])
        while zoneFolder.Parent do
            -- Respect du gap minimum entre spawns
            while tick() - lastSpawnTime < MIN_SPAWN_GAP do
                task.wait(0.05)
            end
            lastSpawnTime = tick()
            local data = spawnBall(math.random(1, #LANE_X))
            -- Attendre que CETTE boule disparaisse avant d'en tirer une autre
            repeat task.wait(0.05) until data.hit or not data.ball.Parent
            task.wait(0.3)  -- petit délai entre deux tirs
        end
    end)
end

RunService.Heartbeat:Connect(function(dt)
    for idx = #activeBalls, 1, -1 do
        local b = activeBalls[idx]

        if b.hit or not b.ball.Parent then
            table.remove(activeBalls, idx)
            continue
        end

        b.rampZ -= BALL_SPEED * dt

        -- Détruire la boule en bas de la rampe (avant d'atteindre la zone plate)
        if b.rampZ < 3 then
            b.ball:Destroy()
            table.remove(activeBalls, idx)
            continue
        end

        b.ball.CFrame = onRamp(b.laneX, BALL_R, b.rampZ)

        local ballPos = b.ball.Position
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            if not char then continue end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then continue end

            if (root.Position - ballPos).Magnitude < BALL_R + 2 then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    hum.Health = 0    -- mort → respawn en bas de la pente
                end
                b.hit = true
                b.ball:Destroy()
                break
            end
        end
    end
end)

-- ============================================================
-- BOULES DE DÉMOLITION : Heartbeat balancement + collision
-- ============================================================
local wbT = 0
RunService.Heartbeat:Connect(function(dt)
    wbT += dt
    for i, wb in ipairs(wbData) do
        -- Position oscillante en X (sinusoïde)
        local bx      = wb.px + wb.amp * math.sin(wbT * WB_FREQ + wb.phase)
        local ballPos = Vector3.new(bx, WB_BALL_Y, wb.pz)
        wb.ball.CFrame = CFrame.new(ballPos)

        -- Mise à jour de la corde (Part orienté du pivot vers la boule)
        local pivotPos = Vector3.new(wb.px, WB_PIVOT_Y, wb.pz)
        local ropeLen  = (ballPos - pivotPos).Magnitude
        local ropeMid  = (ballPos + pivotPos) / 2
        wb.rope.Size   = Vector3.new(0.35, 0.35, ropeLen)
        wb.rope.CFrame = CFrame.new(ropeMid, ballPos)

        -- Collision : pousse les joueurs proches latéralement
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            if not char then continue end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then continue end
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end

            if (root.Position - ballPos).Magnitude < WB_BALL_R + 2.5 then
                local key = i .. "_" .. player.Name
                if not wbHitCD[key] or tick() - wbHitCD[key] > 1.2 then
                    wbHitCD[key] = tick()
                    local push = (root.Position - ballPos)
                    push = Vector3.new(push.X, 0.4, push.Z).Unit
                    root.AssemblyLinearVelocity = push * 65
                end
            end
        end
    end
end)

-- ============================================================
-- CYLINDRES S3 : Heartbeat balancement + collision
-- ============================================================
local s3CylT = 0
RunService.Heartbeat:Connect(function(dt)
    s3CylT += dt
    for i, sc in ipairs(s3cylData) do
        local bx     = S3CYL_AMP * math.sin(s3CylT * S3CYL_FREQ + sc.phase)
        local cylPos = Vector3.new(bx, S3CYL_HANG_Y, sc.pz)
        sc.cyl.CFrame = CFrame.new(cylPos) * CFrame.Angles(0, math.pi / 2, 0)

        -- Mise à jour des 2 cordes (pivot fixe → extrémité du cylindre)
        for _, rope in ipairs(sc.ropes) do
            local pivotPos = Vector3.new(ZONE_X, S3CYL_PIVOT_Y, rope.zEnd)
            local endPos   = Vector3.new(bx,    S3CYL_HANG_Y,   rope.zEnd)
            local ropeLen  = (endPos - pivotPos).Magnitude
            local ropeMid  = (endPos + pivotPos) / 2
            rope.part.Size   = Vector3.new(0.35, 0.35, ropeLen)
            rope.part.CFrame = CFrame.new(ropeMid, endPos)
        end

        -- Collision : pousse les joueurs hors de la plateforme (dans les fosses)
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            if not char then continue end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then continue end
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end

            -- Distance joueur → segment cylindre (approximation capsule)
            local relZ   = math.clamp(root.Position.Z - sc.pz, -S3CYL_LEN/2, S3CYL_LEN/2)
            local nearPt = Vector3.new(bx, S3CYL_HANG_Y, sc.pz + relZ)
            if (root.Position - nearPt).Magnitude < S3CYL_D/2 + 2.5 then
                local key = i .. "_" .. player.Name
                if not s3cylHitCD[key] or tick() - s3cylHitCD[key] > 1.2 then
                    s3cylHitCD[key] = tick()
                    -- Pousse latéralement (en X) vers la fosse la plus proche
                    local pushX = root.Position.X - bx
                    local push  = Vector3.new(pushX, 0.6, 0).Unit
                    root.AssemblyLinearVelocity = push * 90
                end
            end
        end
    end
end)

-- ============================================================
-- TP (touche Y → spawn platform)
-- ============================================================
local FINISH_SPAWN = CFrame.new(ZONE_X, BASE_Y + SPAWN_ELEV + 4, ZONE_Z)

local ok, reTeleport = pcall(function()
    return game.ReplicatedStorage:WaitForChild("Events", 10)
               :WaitForChild("TeleportToFinish", 10)
end)

if not ok or not reTeleport then
    warn("[FinishLineTest] RemoteEvent TeleportToFinish introuvable !")
else
    reTeleport.OnServerEvent:Connect(function(player)
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = FINISH_SPAWN end
    end)
    print("[FinishLineTest] ✅ Prêt | [Y] = TP Spawn | mort = respawn bas de pente")
end
