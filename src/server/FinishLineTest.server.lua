-- FinishLineTest.server.lua
-- Spawn → Sol plat → Pente 4 voies → Escaliers (entre canons) → Plateforme haute
-- Touche Y → TP spawn | Mort = respawn en bas de la pente

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ============================================================
-- CONFIG
-- ============================================================
local ZONE_X = 0
local ZONE_Z = 3000
local BASE_Y = 10

-- ── Rampe ─────────────────────────────────────────────────────
local RAMP_W     = 76
local RAMP_H_LEN = 90
local RAMP_RISE  = 18
local RAMP_THICK = 2
local RAMP_ANGLE = math.atan(RAMP_RISE / RAMP_H_LEN)
local RAMP_S_LEN = math.sqrt(RAMP_H_LEN^2 + RAMP_RISE^2)   -- ≈ 91.8

-- Sol plat avant la rampe (empêche les boules d'aller sur la spawn)
local FLAT_D       = 10
local RAMP_START_Z = ZONE_Z + 30 + FLAT_D   -- = 3040

local RAMP_END_Z   = RAMP_START_Z + RAMP_H_LEN  -- = 3130
local RAMP_TOP_Y   = BASE_Y + RAMP_RISE          -- = 28

local rampOriginCF = CFrame.new(ZONE_X, BASE_Y, RAMP_START_Z)
                   * CFrame.Angles(-RAMP_ANGLE, 0, 0)

local function onRamp(dx, dy, dz)
    return rampOriginCF * CFrame.new(dx, dy, dz)
end

-- ── Voies ──────────────────────────────────────────────────────
local LANE_W  = 13
local WALL_W  = 4
local WALL_H  = 7
local DIV_H   = 5
local BLOCK_D = 4
local BLOCK_G = 5
local BLOCK_STEP = BLOCK_D + BLOCK_G

local LANE_X  = {-25.5, -8.5, 8.5, 25.5}
local DIV_X   = {-17, 0, 17}
local OWALL_X = {-34, 34}

-- ── Blocs séparateurs : fin (retrait 2 derniers) ──────────────
local DIV_STOP = RAMP_S_LEN - BLOCK_D / 2 - 2 * BLOCK_STEP  -- ramp local ≈ 71.8

-- ── Escaliers (entre les canons → plateforme haute) ──────────────
local lastBlockEndDZ  = DIV_STOP + BLOCK_D / 2
local STAIR_START_Z_W = RAMP_START_Z + math.floor(lastBlockEndDZ * math.cos(RAMP_ANGLE)) + 3
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
local FIRE_INTERVAL = 2.8
local BALL_SPEED    = 38
local BALL_R        = 4
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
    Vector3.new(80, 1.2, SPAWN_D),
    CFrame.new(ZONE_X, BASE_Y, ZONE_Z),
    Color3.fromRGB(255, 213, 79))

for row = 0, 4 do
    for col = 0, 5 do
        mkPart(string.format("Marker_%d_%d", row, col),
            Vector3.new(3, 0.2, 3),
            CFrame.new(ZONE_X - 20 + col * 8, BASE_Y + 0.7, ZONE_Z - 16 + row * 8),
            Color3.fromRGB(255, 255, 255))
    end
end

-- ============================================================
-- SOL PLAT AVANT LA RAMPE (arrête les boules)
-- ============================================================
local FLAT_Z0 = ZONE_Z + SPAWN_D / 2   -- = 3030
mkPart("FlatFloor",
    Vector3.new(RAMP_W, 1.2, FLAT_D),
    CFrame.new(ZONE_X, BASE_Y - 0.6, FLAT_Z0 + FLAT_D / 2),
    Color3.fromRGB(180, 230, 255))

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
            Vector3.new(WALL_W, DIV_H, BLOCK_D),
            onRamp(dx, DIV_H / 2, dz),
            divColors[di])
        dz += BLOCK_STEP
        bi += 1
    end
end

-- ============================================================
-- CANONS (tambour cylindrique + tube)
-- ============================================================
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

print(string.format("[TestZone2] ✅ Rampe | %d canons | blocs | escaliers | plateforme Y=%d",
    #LANE_X, PLAT_Y_SURF))

-- ============================================================
-- RESPAWN : toujours en bas de la pente (pas vers spawn)
-- ============================================================
local function bindRespawn(player)
    player.CharacterAdded:Connect(function(char)
        local root = char:WaitForChild("HumanoidRootPart", 5)
        if root then
            task.wait(0.15)
            root.CFrame = RAMP_RESPAWN
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
    ball.Color    = Color3.fromRGB(255, 70, 70)
    ball.Material = Enum.Material.SmoothPlastic
    ball.Anchored = true
    ball.CastShadow = false
    ball.Parent   = zoneFolder

    table.insert(activeBalls, {
        ball  = ball,
        laneX = LANE_X[laneIndex],
        rampZ = CANNON_DZ - BALL_R - 3,
        hit   = false,
    })
end

for i = 1, #LANE_X do
    task.spawn(function()
        task.wait(CANNON_PHASE[i])
        while zoneFolder.Parent do
            spawnBall(math.random(1, #LANE_X))
            task.wait(FIRE_INTERVAL)
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
-- TP (touche Y → spawn platform)
-- ============================================================
local FINISH_SPAWN = CFrame.new(ZONE_X, BASE_Y + 4, ZONE_Z)

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
