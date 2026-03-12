-- FinishLineTest.server.lua
-- Parcours complet : Spawn → Rampe + Canons → Plateforme haute → Poutres → S3 Cylindres → Murs → Arrivée

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ============================================================
-- CONFIG
-- ============================================================
local ZONE_X = 0
local ZONE_Z = 200
local BASE_Y = 10

-- ── Rampe ─────────────────────────────────────────────────────
local RAMP_W     = 84
local RAMP_H_LEN = 90
local RAMP_RISE  = 18
local RAMP_THICK = 2
local RAMP_ANGLE = math.atan(RAMP_RISE / RAMP_H_LEN)
local RAMP_S_LEN = math.sqrt(RAMP_H_LEN^2 + RAMP_RISE^2)

-- Élévation spawn
local SPAWN_ELEV   = 8
local SPAWN_STEP_N = 4
local SPAWN_STEP_H = SPAWN_ELEV / SPAWN_STEP_N
local SPAWN_STEP_D = 3
local SPAWN_STAIR_W = 18
local SPAWN_STAIR_X = {-20, 20}

-- Sol plat avant la rampe
local FLAT_D       = 40
local RAMP_START_Z = ZONE_Z + 30 + FLAT_D

local RAMP_END_Z   = RAMP_START_Z + RAMP_H_LEN
local RAMP_TOP_Y   = BASE_Y + RAMP_RISE

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

local DIV_STOP = RAMP_S_LEN - BLOCK_D / 2 - 3 * BLOCK_STEP

-- ── Escaliers canons → plateforme haute ──────────────────────
local lastBlockEndDZ  = DIV_STOP + BLOCK_D / 2
local STAIR_START_Z_W = RAMP_START_Z + math.floor(lastBlockEndDZ * math.cos(RAMP_ANGLE)) + 18
local STAIR_BASE_Y    = BASE_Y + RAMP_RISE * (STAIR_START_Z_W - RAMP_START_Z) / RAMP_H_LEN
local STAIR_H  = 3
local STAIR_D  = 4
local STAIR_N  = 5
local STAIR_W  = 8

-- ── Plateforme haute ──────────────────────────────────────────
local PLAT_Y_SURF  = math.floor(STAIR_BASE_Y + STAIR_H * STAIR_N + 0.5)
local PLAT_START_Z = STAIR_START_Z_W + STAIR_N * STAIR_D
local PLAT_D       = 40
local PLAT_H       = 2

-- ── Canons ────────────────────────────────────────────────────
local FIRE_INTERVAL  = 2.0
local MIN_SPAWN_GAP  = 1.1
local BALL_COLORS = {
    Color3.fromRGB(255, 60, 60),
    Color3.fromRGB(255, 160, 20),
    Color3.fromRGB(80, 180, 255),
    Color3.fromRGB(120, 220, 80),
    Color3.fromRGB(200, 80, 255),
    Color3.fromRGB(255, 220, 40),
}
local BALL_SPEED   = 25
local BALL_R       = 5.5
local CANNON_DZ    = RAMP_S_LEN - 3
local CANNON_PHASE = {0, 0.9, 1.8, 0.45}

-- ── Respawn ───────────────────────────────────────────────────
local RAMP_RESPAWN = CFrame.new(ZONE_X, BASE_Y + 4, RAMP_START_Z - 3)

-- ============================================================
-- DOSSIER
-- ============================================================
-- ============================================================
-- DÉPLACER L'ANCIEN "Course" à Z ≈ 2900 (échange de place)
-- ============================================================
local _courseFolder = workspace:FindFirstChild("Course")
if _courseFolder then
    local Z_OFFSET = Vector3.new(0, 0, 2700)
    for _, part in ipairs(_courseFolder:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Position = part.Position + Z_OFFSET
        end
    end
    print("[Manche 1] Ancien 'Course' déplacé à Z+2700")
end

local _old = workspace:FindFirstChild("Manche 1")
if _old then _old:Destroy() end

local zoneFolder = Instance.new("Folder")
zoneFolder.Name   = "Manche 1"
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
-- PLATEFORME DE SPAWN
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

-- SpawnLocation fiable
local spawnLoc = Instance.new("SpawnLocation")
spawnLoc.Name         = "CourseSpawn"
spawnLoc.Size         = Vector3.new(80, 1, 50)
spawnLoc.CFrame       = CFrame.new(ZONE_X, BASE_Y + SPAWN_ELEV + 0.5, ZONE_Z)
spawnLoc.Anchored     = true
spawnLoc.Neutral      = true
spawnLoc.Duration     = 0
spawnLoc.Transparency = 1
spawnLoc.Parent       = zoneFolder

-- ============================================================
-- SOL PLAT AVANT LA RAMPE
-- ============================================================
local FLAT_Z0 = ZONE_Z + SPAWN_D / 2
mkPart("FlatFloor",
    Vector3.new(RAMP_W, 1.2, FLAT_D),
    CFrame.new(ZONE_X, BASE_Y - 0.6, FLAT_Z0 + FLAT_D / 2),
    Color3.fromRGB(180, 230, 255))

-- ============================================================
-- ESCALIERS SPAWN → FLATFLOOR
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

-- Blocs séparateurs
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
-- CANONS
-- ============================================================
mkPart("CannonWall",
    Vector3.new(RAMP_W, WALL_H, 10),
    onRamp(0, WALL_H / 2, CANNON_DZ),
    Color3.fromRGB(255, 190, 80))

for li, lx in ipairs(LANE_X) do
    mkCylinder("CannonDrum_" .. li,
        Vector3.new(7, 9, 9),
        onRamp(lx, WALL_H + 3.5, CANNON_DZ) * CFrame.Angles(0, 0, math.pi / 2),
        Color3.fromRGB(45, 45, 80))

    mkCylinder("CannonBarrel_" .. li,
        Vector3.new(11, 3, 3),
        onRamp(lx, WALL_H + 4, CANNON_DZ - 4) * CFrame.Angles(0, math.pi / 2, 0),
        Color3.fromRGB(20, 20, 50))

    mkCylinder("CannonMuzzle_" .. li,
        Vector3.new(2, 4.5, 4.5),
        onRamp(lx, WALL_H + 4, CANNON_DZ - 9.5) * CFrame.Angles(0, math.pi / 2, 0),
        Color3.fromRGB(65, 65, 110))
end

-- ============================================================
-- ESCALIERS (entre canons → plateforme haute)
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
-- PLATEFORME HAUTE
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
local CYL_LENGTH     = 60
local CYL_D          = 5
local halfL          = CYL_LENGTH / 2
local CYL_GAP        = 8
local TOTAL_CYL_SPAN = CYL_LENGTH + CYL_GAP
local PIT_Y_SURF     = PLAT_Y_SURF - 28
local PIT_W          = RAMP_W
local PIT_LENGTH     = TOTAL_CYL_SPAN

local cylDefs = {
    {x = -30, zOff = 0},
    {x = -18, zOff = 0},
    {x =  -6, zOff = 0},
    {x =   6, zOff = 0},
    {x =  18, zOff = 0},
    {x =  30, zOff = 0},
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

-- Sol de la fosse
local pitFloor = mkPart("PitFloor",
    Vector3.new(PIT_W, 2, PIT_LENGTH),
    CFrame.new(ZONE_X, PIT_Y_SURF - 1, CYL_SEC_Z + PIT_LENGTH / 2),
    Color3.fromRGB(80, 190, 255))

local pitWallH = PLAT_Y_SURF - PIT_Y_SURF + 4

mkPart("PitWall_Front",
    Vector3.new(PIT_W + 4, PLAT_Y_SURF - PIT_Y_SURF, 2),
    CFrame.new(ZONE_X, PIT_Y_SURF + (PLAT_Y_SURF - PIT_Y_SURF) / 2, CYL_SEC_Z - 1),
    Color3.fromRGB(255, 190, 80))

-- Rampe de remontée
local REC_RISE  = PLAT_Y_SURF - PIT_Y_SURF
local REC_H_LEN = 34
local REC_ANGLE = math.atan(REC_RISE / REC_H_LEN)
local REC_S_LEN = math.sqrt(REC_H_LEN^2 + REC_RISE^2)
local REC_Z     = CYL_SEC_Z + PIT_LENGTH
local recCF     = CFrame.new(ZONE_X, PIT_Y_SURF, REC_Z) * CFrame.Angles(-REC_ANGLE, 0, 0)

mkPart("RecoveryRamp",
    Vector3.new(PIT_W, 2, REC_S_LEN),
    recCF * CFrame.new(0, -1, REC_S_LEN / 2),
    Color3.fromRGB(180, 230, 255))

-- Murs latéraux fosse + rampe (un seul bloc droit)
local pitWallTotalLen = PIT_LENGTH + REC_H_LEN
for _, sx in ipairs({-(PIT_W/2 + 1), PIT_W/2 + 1}) do
    mkPart("PitWall_" .. (sx < 0 and "L" or "R"),
        Vector3.new(2, pitWallH, pitWallTotalLen),
        CFrame.new(sx, PIT_Y_SURF + pitWallH / 2 - 1, CYL_SEC_Z + pitWallTotalLen / 2),
        Color3.fromRGB(255, 190, 80))
end

-- Blocs triangulaires sur la pente
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

-- Plateforme 2
local PLAT2_D     = REC_H_LEN
local PLAT2_H     = 2
local PLAT2_START = REC_Z + REC_H_LEN
mkPart("Platform2",
    Vector3.new(RAMP_W, PLAT2_H, PLAT2_D),
    CFrame.new(ZONE_X, PLAT_Y_SURF - PLAT2_H / 2, PLAT2_START + PLAT2_D / 2),
    Color3.fromRGB(200, 240, 255))

local PLAT2_WALL_H = PLAT_WALL_H
local WALL_EXT     = math.ceil(PLAT2_WALL_H * math.sin(REC_ANGLE))
for _, ox in ipairs({-(PIT_W/2 + 1), PIT_W/2 + 1}) do
    mkPart("Plat2Wall_" .. (ox < 0 and "L" or "R"),
        Vector3.new(2, PLAT2_WALL_H, PLAT2_D + WALL_EXT),
        CFrame.new(ox, PLAT_Y_SURF + PLAT2_WALL_H / 2,
                   PLAT2_START + PLAT2_D / 2 - WALL_EXT / 2),
        Color3.fromRGB(255, 190, 80))
end

-- ============================================================
-- SECTION 3 : PENTE CENTRALE + CYLINDRES + FOSSES LATÉRALES
-- ============================================================
local S3_START_Z    = PLAT2_START + PLAT2_D
local S3_RAMP_W     = 36
local S3_RAMP_H_LEN = 45
local S3_RAMP_RISE  = 10
local S3_RAMP_ANGLE = math.atan(S3_RAMP_RISE / S3_RAMP_H_LEN)
local S3_RAMP_S_LEN = math.sqrt(S3_RAMP_H_LEN^2 + S3_RAMP_RISE^2)
local PLAT3_Y       = PLAT_Y_SURF - S3_RAMP_RISE

local S3_PLAT_D     = 80
local S3_PLAT_H     = 2
local S3_PLAT_START = S3_START_Z + S3_RAMP_H_LEN

local PIT3_DEPTH  = 12
local PIT3_Y      = PLAT3_Y - PIT3_DEPTH
local PIT3_W      = RAMP_W / 2 - S3_RAMP_W / 2
local PIT3_Z_END  = S3_PLAT_START + S3_PLAT_D
local PIT3_Z_LEN  = PIT3_Z_END - S3_START_Z
local PIT3_WALL_H = PLAT_Y_SURF - PIT3_Y + 4
local pit3WallCY  = PIT3_Y + PIT3_WALL_H / 2

-- Pente centrale
local s3rampCF = CFrame.new(ZONE_X, PLAT_Y_SURF, S3_START_Z)
               * CFrame.Angles(S3_RAMP_ANGLE, 0, 0)
mkPart("S3_Ramp",
    Vector3.new(S3_RAMP_W, 2, S3_RAMP_S_LEN),
    s3rampCF * CFrame.new(0, -1, S3_RAMP_S_LEN / 2),
    Color3.fromRGB(180, 230, 255))

local S3_RAMP_SIDE_H = PLAT_Y_SURF - PIT3_Y
for _, sx in ipairs({-(S3_RAMP_W/2 + 1), S3_RAMP_W/2 + 1}) do
    mkPart("S3_RampSide_" .. (sx < 0 and "L" or "R"),
        Vector3.new(2, S3_RAMP_SIDE_H, S3_RAMP_S_LEN),
        s3rampCF * CFrame.new(sx, -S3_RAMP_SIDE_H / 2, S3_RAMP_S_LEN / 2),
        Color3.fromRGB(255, 190, 80))
end

mkPart("S3_Platform",
    Vector3.new(S3_RAMP_W, S3_PLAT_H, S3_PLAT_D),
    CFrame.new(ZONE_X, PLAT3_Y - S3_PLAT_H / 2, S3_PLAT_START + S3_PLAT_D / 2),
    Color3.fromRGB(200, 240, 255))

for _, side in ipairs({"L", "R"}) do
    local sign   = (side == "L") and -1 or 1
    local pitCX  = sign * (S3_RAMP_W / 2 + PIT3_W / 2)
    local outerX = sign * (RAMP_W / 2 + 1)

    mkPart("S3_PitFloor_" .. side,
        Vector3.new(PIT3_W, 2, PIT3_Z_LEN),
        CFrame.new(pitCX, PIT3_Y - 1, S3_START_Z + PIT3_Z_LEN / 2),
        Color3.fromRGB(80, 190, 255))

    mkPart("S3_PitOuter_" .. side,
        Vector3.new(2, PIT3_WALL_H, PIT3_Z_LEN),
        CFrame.new(outerX, pit3WallCY, S3_START_Z + PIT3_Z_LEN / 2),
        Color3.fromRGB(255, 190, 80))

    mkPart("S3_PitBack_" .. side,
        Vector3.new(PIT3_W + 4, PIT3_WALL_H, 2),
        CFrame.new(pitCX, pit3WallCY, PIT3_Z_END + 1),
        Color3.fromRGB(255, 190, 80))

    local innerX = sign * (S3_RAMP_W / 2 + 1)
    mkPart("S3_PitInner_" .. side,
        Vector3.new(2, PIT3_DEPTH, PIT3_Z_LEN),
        CFrame.new(innerX, PIT3_Y + PIT3_DEPTH / 2, S3_START_Z + PIT3_Z_LEN / 2),
        Color3.fromRGB(255, 190, 80))
end

local S3_STAIR_H = 2
local S3_STAIR_N = (PLAT_Y_SURF - PIT3_Y) / S3_STAIR_H
local S3_STAIR_D = S3_RAMP_H_LEN / S3_STAIR_N
local S3_STAIR_W = RAMP_W / 2 - (S3_RAMP_W / 2 + 2)

for _, side in ipairs({"L", "R"}) do
    local sign  = (side == "L") and -1 or 1
    local stepX = sign * (S3_RAMP_W / 2 + 2 + S3_STAIR_W / 2)
    for si = 0, S3_STAIR_N - 1 do
        local topY    = PLAT_Y_SURF - si * S3_STAIR_H
        local blockH  = topY - PIT3_Y
        local blockCY = PIT3_Y + blockH / 2
        local blockCZ = S3_START_Z + si * S3_STAIR_D + S3_STAIR_D / 2
        mkPart(string.format("S3_Stair_%s_%d", side, si),
            Vector3.new(S3_STAIR_W, blockH, S3_STAIR_D),
            CFrame.new(stepX, blockCY, blockCZ),
            Color3.fromRGB(160, 220, 255))
    end
end

-- Cylindres oscillants
local S3CYL_PIVOT_H = 24
local S3CYL_PIVOT_Y = PLAT3_Y + S3CYL_PIVOT_H
local S3CYL_HANG_Y  = PLAT3_Y + 7
local S3CYL_LEN     = 22
local S3CYL_D       = 7
local S3CYL_FREQ    = 1.3
local S3CYL_AMP     = 16
local S3CYL_COLOR   = Color3.fromRGB(255, 100, 175)

local s3CylDefs = {
    {pz = S3_PLAT_START + 20, phase = 0},
    {pz = S3_PLAT_START + 58, phase = math.pi},
}
local s3cylData  = {}
local s3cylHitCD = {}

for i, def in ipairs(s3CylDefs) do
    local postH = S3CYL_PIVOT_Y - PLAT3_Y
    for _, zEnd in ipairs({def.pz - S3CYL_LEN/2, def.pz + S3CYL_LEN/2}) do
        mkPart(string.format("S3CylPost_%d_%s", i, zEnd > def.pz and "F" or "B"),
            Vector3.new(1.5, postH, 1.5),
            CFrame.new(ZONE_X, PLAT3_Y + postH / 2, zEnd),
            Color3.fromRGB(55, 55, 65), Enum.Material.Metal)
    end

    local cyl = Instance.new("Part")
    cyl.Name       = "S3Cyl_" .. i
    cyl.Shape      = Enum.PartType.Cylinder
    cyl.Size       = Vector3.new(S3CYL_LEN, S3CYL_D, S3CYL_D)
    cyl.Color      = S3CYL_COLOR
    cyl.Material   = Enum.Material.SmoothPlastic
    cyl.Anchored   = true
    cyl.CanCollide = false
    cyl.CastShadow = false
    cyl.Parent     = zoneFolder

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

-- ============================================================
-- CONSTANTES SECTION 4 (définies tôt car utilisées par WaitPlatform)
-- ============================================================
local S4_PANEL_W  = 18
local S4_DIV_W    = 2
local S4_WALL_H   = 12
local S4_WALL_D   = 3
local S4_RISE_SPD = 14
local S4_FALL_SPD = 18
local S4_PANEL_XS = {-30, -10, 10, 30}
local S4_DIV_XS   = {-20, 0, 20}
local S4_TOTAL_W  = 4 * S4_PANEL_W + 3 * S4_DIV_W  -- 78

-- ============================================================
-- PLATEFORME D'ATTENTE (contient les murs coulissants)
-- ============================================================
local WAIT_Z      = PIT3_Z_END
local WAIT_PLAT_D = 130   -- assez long pour 4 rangées espacées + zones libres
local WAIT_PLAT_H = 2

mkPart("WaitPlatform",
    Vector3.new(S4_TOTAL_W, WAIT_PLAT_H, WAIT_PLAT_D),
    CFrame.new(ZONE_X, PLAT3_Y - WAIT_PLAT_H / 2, WAIT_Z + WAIT_PLAT_D / 2),
    Color3.fromRGB(200, 240, 255))

-- ============================================================
-- SECTION 4 : MURS COULISSANTS (sur la WaitPlatform)
-- ============================================================
local S4_Z = WAIT_Z   -- murs démarrent au début de la WaitPlatform

-- Espacement généreux entre les rangées : 30 studs d'écart
local s4WallZOffsets = {15, 45, 75, 105}
local s4WallData = {}

for ri, dz in ipairs(s4WallZOffsets) do
    local wallZ = S4_Z + dz

    for di, dx in ipairs(S4_DIV_XS) do
        mkPart(string.format("S4_Div_%d_%d", ri, di),
            Vector3.new(S4_DIV_W, S4_WALL_H, S4_WALL_D),
            CFrame.new(dx, PLAT3_Y + S4_WALL_H / 2, wallZ),
            Color3.fromRGB(255, 190, 80))
    end

    for pi, px in ipairs(S4_PANEL_XS) do
        local wall = Instance.new("Part")
        wall.Name       = string.format("S4_Panel_%d_%d", ri, pi)
        wall.Size       = Vector3.new(S4_PANEL_W, S4_WALL_H, S4_WALL_D)
        wall.Color      = Color3.fromRGB(210, 230, 140)
        wall.Material   = Enum.Material.SmoothPlastic
        wall.Anchored   = true
        wall.CanCollide = false
        wall.CastShadow = false
        wall.Parent     = zoneFolder
        wall.CFrame     = CFrame.new(px, PLAT3_Y - S4_WALL_H / 2, wallZ)

        table.insert(s4WallData, {
            wall     = wall,
            panelX   = px,
            wallZ    = wallZ,
            state    = "DOWN",
            timer    = math.random() * 4,
            currentY = PLAT3_Y - S4_WALL_H / 2,
        })
    end
end

-- ============================================================
-- LIGNE D'ARRIVÉE
-- ============================================================
local FIN_Z      = WAIT_Z + WAIT_PLAT_D  -- juste après la WaitPlatform
local FIN_PLAT_D = 24
local FIN_ARCH_H = 20
local FIN_RED    = Color3.fromRGB(255, 50, 80)
local FIN_YEL    = Color3.fromRGB(255, 220, 40)

local CHECK_W = 6
local nCX = math.floor(S4_TOTAL_W / CHECK_W)
local nCZ = math.floor(FIN_PLAT_D  / CHECK_W)
for col = 0, nCX - 1 do
    for row = 0, nCZ - 1 do
        mkPart(string.format("FinCheck_%d_%d", col, row),
            Vector3.new(CHECK_W, WAIT_PLAT_H, CHECK_W),
            CFrame.new(
                -S4_TOTAL_W/2 + col * CHECK_W + CHECK_W/2,
                PLAT3_Y - WAIT_PLAT_H / 2,
                FIN_Z + row * CHECK_W + CHECK_W/2),
            ((col + row) % 2 == 0)
                and Color3.fromRGB(20, 20, 20)
                or  Color3.fromRGB(240, 240, 240))
    end
end

local pillarX = S4_TOTAL_W / 2 + 2
for _, sx in ipairs({-pillarX, pillarX}) do
    mkPart("FinPillar_" .. (sx < 0 and "L" or "R"),
        Vector3.new(4, FIN_ARCH_H, 4),
        CFrame.new(sx, PLAT3_Y + FIN_ARCH_H / 2, FIN_Z),
        FIN_RED)
end

local BAR_W    = S4_TOTAL_W + 8
local STRIPE_W = 6
local nStripes = math.floor(BAR_W / STRIPE_W)
for si = 0, nStripes - 1 do
    mkPart("FinStripe_" .. si,
        Vector3.new(STRIPE_W, 4, 4),
        CFrame.new(-BAR_W/2 + si * STRIPE_W + STRIPE_W/2, PLAT3_Y + FIN_ARCH_H + 2, FIN_Z),
        (si % 2 == 0) and FIN_RED or FIN_YEL)
end

for _, sx in ipairs({-pillarX, pillarX}) do
    local ball = Instance.new("Part")
    ball.Name       = "FinBall_" .. (sx < 0 and "L" or "R")
    ball.Shape      = Enum.PartType.Ball
    ball.Size       = Vector3.new(6, 6, 6)
    ball.Color      = FIN_YEL
    ball.Material   = Enum.Material.SmoothPlastic
    ball.Anchored   = true
    ball.CastShadow = false
    ball.Parent     = zoneFolder
    ball.CFrame     = CFrame.new(sx, PLAT3_Y + FIN_ARCH_H + 5, FIN_Z)
end

local FIN_WALL_H = 8
mkPart("FinWall_L",
    Vector3.new(2, FIN_WALL_H, FIN_PLAT_D),
    CFrame.new(-S4_TOTAL_W/2 - 1, PLAT3_Y + FIN_WALL_H/2, FIN_Z + FIN_PLAT_D/2),
    FIN_RED)
mkPart("FinWall_R",
    Vector3.new(2, FIN_WALL_H, FIN_PLAT_D),
    CFrame.new( S4_TOTAL_W/2 + 1, PLAT3_Y + FIN_WALL_H/2, FIN_Z + FIN_PLAT_D/2),
    FIN_RED)
mkPart("FinWall_Back",
    Vector3.new(S4_TOTAL_W + 4, FIN_WALL_H, 2),
    CFrame.new(ZONE_X, PLAT3_Y + FIN_WALL_H/2, FIN_Z + FIN_PLAT_D + 1),
    FIN_RED)

local LOBBY_SPAWN = CFrame.new(ZONE_X, BASE_Y + SPAWN_ELEV + 4, ZONE_Z)

local finDetector = Instance.new("Part")
finDetector.Name         = "FinishDetector"
finDetector.Size         = Vector3.new(S4_TOTAL_W, 10, 2)
finDetector.CFrame       = CFrame.new(ZONE_X, PLAT3_Y + 5, FIN_Z + FIN_PLAT_D - 1)
finDetector.Anchored     = true
finDetector.CanCollide   = false
finDetector.Transparency = 1
finDetector.Parent       = zoneFolder

local finishedPlayers = {}
finDetector.Touched:Connect(function(hit)
    local char   = hit.Parent
    local player = Players:GetPlayerFromCharacter(char)
    if not player or finishedPlayers[player] then return end
    finishedPlayers[player] = true
    print(string.format("[Finish] ✅ %s est qualifié !", player.Name))
    task.delay(0.6, function()
        local c = player.Character
        if not c then return end
        local root = c:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = LOBBY_SPAWN end
    end)
end)

print(string.format("[Manche 1] ✅ Rampe | %d canons | S3 | S4 | Finish — PLAT_Y=%d",
    #LANE_X, PLAT_Y_SURF))

-- ============================================================
-- CHECKPOINT (plateforme haute)
-- ============================================================
local checkpointRespawn = {}

local CP_CF  = CFrame.new(ZONE_X, PLAT_Y_SURF + 4, PLAT_START_Z + 5)
local cpPart = Instance.new("Part")
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
    finishedPlayers[player]   = nil
end)

-- ============================================================
-- RESPAWN
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

task.spawn(function()
    task.wait(0.8)
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = checkpointRespawn[player] or RAMP_RESPAWN
        end
    end
end)

-- ============================================================
-- BOULES DE CANON
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
            while tick() - lastSpawnTime < MIN_SPAWN_GAP do
                task.wait(0.05)
            end
            lastSpawnTime = tick()
            local data = spawnBall(math.random(1, #LANE_X))
            repeat task.wait(0.05) until data.hit or not data.ball.Parent
            task.wait(0.3)
        end
    end)
end

-- ============================================================
-- BOULES DE DÉMOLITION (section 2)
-- ============================================================
local WB_PIVOT_Y = PLAT_Y_SURF + 20
local WB_BALL_Y  = PLAT_Y_SURF + 3
local WB_BALL_R  = 3.5
local WB_FREQ    = 2.2
local wbHitCD    = {}

local WB_COLORS = {
    Color3.fromRGB(220, 50,  50),
    Color3.fromRGB(50,  180, 255),
    Color3.fromRGB(80,  220, 80),
    Color3.fromRGB(255, 160, 20),
    Color3.fromRGB(200, 80,  255),
}

local wbDefs = {
    {px = -24, pz = CYL_SEC_Z + 10, phase = 0,             amp = 8},
    {px =   0, pz = CYL_SEC_Z + 19, phase = math.pi,       amp = 8},
    {px =  24, pz = CYL_SEC_Z + 13, phase = 0,             amp = 8},
    {px = -15, pz = CYL_SEC_Z + 48, phase = math.pi * 0.5, amp = 9},
    {px =  15, pz = CYL_SEC_Z + 58, phase = math.pi * 1.5, amp = 9},
}

local wbData = {}
local postH  = WB_PIVOT_Y - PIT_Y_SURF
local postCY = PIT_Y_SURF + postH / 2

for i, def in ipairs(wbDefs) do
    mkPart(string.format("WBPost_%d", i),
        Vector3.new(1.5, postH, 1.5),
        CFrame.new(def.px, postCY, def.pz),
        Color3.fromRGB(55, 55, 65), Enum.Material.Metal)

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

-- Sol ralentissant (fosse section 2)
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
-- HEARTBEAT : BOULES DE CANON
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
    for idx = #activeBalls, 1, -1 do
        local b = activeBalls[idx]
        if b.hit or not b.ball.Parent then
            table.remove(activeBalls, idx)
            continue
        end

        b.rampZ -= BALL_SPEED * dt
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
                if hum and hum.Health > 0 then hum.Health = 0 end
                b.hit = true
                b.ball:Destroy()
                break
            end
        end
    end
end)

-- ============================================================
-- HEARTBEAT : BOULES DE DÉMOLITION
-- ============================================================
local wbT = 0
RunService.Heartbeat:Connect(function(dt)
    wbT += dt
    for i, wb in ipairs(wbData) do
        local bx      = wb.px + wb.amp * math.sin(wbT * WB_FREQ + wb.phase)
        local ballPos = Vector3.new(bx, WB_BALL_Y, wb.pz)
        wb.ball.CFrame = CFrame.new(ballPos)

        local pivotPos = Vector3.new(wb.px, WB_PIVOT_Y, wb.pz)
        local ropeLen  = (ballPos - pivotPos).Magnitude
        local ropeMid  = (ballPos + pivotPos) / 2
        wb.rope.Size   = Vector3.new(0.35, 0.35, ropeLen)
        wb.rope.CFrame = CFrame.new(ropeMid, ballPos)

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
-- HEARTBEAT : CYLINDRES S3
-- ============================================================
local s3CylT = 0
RunService.Heartbeat:Connect(function(dt)
    s3CylT += dt
    for i, sc in ipairs(s3cylData) do
        local bx     = S3CYL_AMP * math.sin(s3CylT * S3CYL_FREQ + sc.phase)
        local cylPos = Vector3.new(bx, S3CYL_HANG_Y, sc.pz)
        sc.cyl.CFrame = CFrame.new(cylPos) * CFrame.Angles(0, math.pi / 2, 0)

        for _, rope in ipairs(sc.ropes) do
            local pivotPos = Vector3.new(ZONE_X, S3CYL_PIVOT_Y, rope.zEnd)
            local endPos   = Vector3.new(bx, S3CYL_HANG_Y, rope.zEnd)
            local ropeLen  = (endPos - pivotPos).Magnitude
            local ropeMid  = (endPos + pivotPos) / 2
            rope.part.Size   = Vector3.new(0.35, 0.35, ropeLen)
            rope.part.CFrame = CFrame.new(ropeMid, endPos)
        end

        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            if not char then continue end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then continue end
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local relZ   = math.clamp(root.Position.Z - sc.pz, -S3CYL_LEN/2, S3CYL_LEN/2)
            local nearPt = Vector3.new(bx, S3CYL_HANG_Y, sc.pz + relZ)
            if (root.Position - nearPt).Magnitude < S3CYL_D/2 + 2.5 then
                local key = i .. "_" .. player.Name
                if not s3cylHitCD[key] or tick() - s3cylHitCD[key] > 1.2 then
                    s3cylHitCD[key] = tick()
                    local pushX = root.Position.X - bx
                    local push  = Vector3.new(pushX, 0.6, 0).Unit
                    root.AssemblyLinearVelocity = push * 90
                end
            end
        end
    end
end)

-- ============================================================
-- HEARTBEAT : MURS COULISSANTS S4
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
    for _, sw in ipairs(s4WallData) do
        if sw.state == "DOWN" then
            sw.timer -= dt
            if sw.timer <= 0 then
                sw.state = "RISING"
                sw.wall.CanCollide = true
            end
        elseif sw.state == "RISING" then
            sw.currentY += S4_RISE_SPD * dt
            if sw.currentY >= PLAT3_Y + S4_WALL_H / 2 then
                sw.currentY = PLAT3_Y + S4_WALL_H / 2
                sw.state    = "UP"
                sw.timer    = 1.5 + math.random() * 2
            end
        elseif sw.state == "UP" then
            sw.timer -= dt
            if sw.timer <= 0 then sw.state = "FALLING" end
        elseif sw.state == "FALLING" then
            sw.currentY -= S4_FALL_SPD * dt
            if sw.currentY <= PLAT3_Y - S4_WALL_H / 2 then
                sw.currentY = PLAT3_Y - S4_WALL_H / 2
                sw.state    = "DOWN"
                sw.wall.CanCollide = false
                sw.timer    = 1 + math.random() * 2
            end
        end
        sw.wall.CFrame = CFrame.new(sw.panelX, sw.currentY, sw.wallZ)
    end
end)

-- ============================================================
-- TP (touche Y → avant les murs S4)
-- ============================================================
local FINISH_SPAWN = CFrame.new(ZONE_X, PLAT3_Y + 4, S4_Z + 5)

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
    print("[Manche 1] ✅ Prêt | [Y] = TP murs S4 | mort = respawn bas de rampe")
end
