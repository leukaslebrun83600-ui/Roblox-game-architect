-- PunchTest.server.lua
-- Zone de test : Plateforme inclinée (13°, légèrement glissante)
-- + 7 cylindres oscillants style Fall Guys
--
-- Layout :
--   Approach (Z=-300) →[8]→ Slope (115 studs, +13°, 7 cylindres) →[5]→ Exit
-- ============================================================

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local Debris     = game:GetService("Debris")

-- ────────────────────────────────────────────────────────────
-- CONFIG
-- ────────────────────────────────────────────────────────────
local BASE_X = 800
local BASE_Y = 10
local BASE_Z = -300

-- Plateforme inclinée
local PLAT_W = 22
local PLAT_D = 115   -- étendue pour 7 cylindres
local PLAT_H = 1.2
local TILT   = math.rad(13)

-- Cylindres
local CYL_R  = 2.8
local CYL_H  = 9
local SWING  = 8

-- Poussée
local PUSH_F = 55
local PUSH_Y = 18

-- ────────────────────────────────────────────────────────────
-- COULEURS
-- ────────────────────────────────────────────────────────────
local COLOR_CYL  = Color3.fromRGB(255, 198,  41)
local COLOR_PLAT = Color3.fromRGB(255, 213,  79)

-- ────────────────────────────────────────────────────────────
-- GÉOMÉTRIE DE LA PENTE
-- ────────────────────────────────────────────────────────────
local PLAT_START_Z = BASE_Z + 15
local platCenZ     = PLAT_START_Z + PLAT_D / 2
local platCenY     = BASE_Y + (PLAT_D / 2) * math.sin(TILT)

local function surfaceY(dz)
    return BASE_Y + dz * math.sin(TILT)
end

-- ────────────────────────────────────────────────────────────
-- HELPER
-- ────────────────────────────────────────────────────────────
local testFolder  = Instance.new("Folder")
testFolder.Name   = "PunchTest"
testFolder.Parent = game.Workspace

local function makePart(name, size, cf, color)
    local p = Instance.new("Part")
    p.Name         = name
    p.Size         = size
    p.CFrame       = cf
    p.Color        = color
    p.Material     = Enum.Material.SmoothPlastic
    p.Anchored     = true
    p.CastShadow   = false
    p.Parent       = testFolder
    return p
end

-- ────────────────────────────────────────────────────────────
-- CONSTRUCTION
-- ────────────────────────────────────────────────────────────

makePart("Approach",
    Vector3.new(20, PLAT_H, 14),
    CFrame.new(BASE_X, BASE_Y, BASE_Z),
    COLOR_PLAT)

local slope = makePart("Slope",
    Vector3.new(PLAT_W, PLAT_H, PLAT_D),
    CFrame.new(BASE_X, platCenY, platCenZ) * CFrame.Angles(-TILT, 0, 0),
    COLOR_PLAT)
slope.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.15, 0, 0, 0)

local exitSurfY = surfaceY(PLAT_D)
local exitZ     = PLAT_START_Z + PLAT_D + 12
makePart("Exit",
    Vector3.new(20, PLAT_H, 14),
    CFrame.new(BASE_X, exitSurfY, exitZ),
    COLOR_PLAT)

-- ────────────────────────────────────────────────────────────
-- 7 CYLINDRES OSCILLANTS — espacés de ~14 studs
-- ────────────────────────────────────────────────────────────
local CYL_DEFS = {
    { dz =  10, speed = 0.45, phase = 0                },
    { dz =  24, speed = 0.40, phase = math.pi          },
    { dz =  38, speed = 0.50, phase = math.pi / 2      },
    { dz =  52, speed = 0.42, phase = 0                },
    { dz =  66, speed = 0.48, phase = math.pi * 3 / 4  },
    { dz =  80, speed = 0.38, phase = math.pi          },
    { dz =  94, speed = 0.46, phase = math.pi / 4      },
}

local cylData      = {}
local pushCooldown = {}

for i, cd in ipairs(CYL_DEFS) do
    local bz      = PLAT_START_Z + cd.dz
    local surfY   = surfaceY(cd.dz)
    local cylCenY = surfY + CYL_H / 2

    local cyl = makePart("Cyl_" .. i,
        Vector3.new(CYL_H, CYL_R * 2, CYL_R * 2),
        CFrame.new(BASE_X, cylCenY, bz) * CFrame.Angles(0, 0, math.pi / 2),
        COLOR_CYL)
    cyl.Shape = Enum.PartType.Cylinder

    cyl.Touched:Connect(function(hit)
        local char = hit.Parent
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local uid = char.Name
        if pushCooldown[uid] then return end
        pushCooldown[uid] = true

        local pushDir = math.sign(hrp.Position.X - cyl.Position.X)
        if pushDir == 0 then pushDir = 1 end

        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, 0)
        bv.Velocity  = Vector3.new(pushDir * PUSH_F, PUSH_Y, 0)
        bv.P         = math.huge
        bv.Parent    = hrp
        Debris:AddItem(bv, 0.15)

        task.delay(0.6, function() pushCooldown[uid] = nil end)
    end)

    table.insert(cylData, {
        cyl     = cyl,
        cylCenY = cylCenY,
        bz      = bz,
        speed   = cd.speed,
        phase   = cd.phase,
    })
end

-- ────────────────────────────────────────────────────────────
-- ANIMATION (Heartbeat)
-- ────────────────────────────────────────────────────────────
local t = 0
RunService.Heartbeat:Connect(function(dt)
    t = t + dt
    for _, c in ipairs(cylData) do
        local bx = BASE_X + SWING * math.sin(t * c.speed * math.pi * 2 + c.phase)
        if c.cyl and c.cyl.Parent then
            c.cyl.CFrame = CFrame.new(bx, c.cylCenY, c.bz)
                * CFrame.Angles(0, 0, math.pi / 2)
        end
    end
end)

print(string.format(
    "[PunchTest] ✅ Pente %.0f° | %d cylindres | Oscillation ±%d studs",
    math.deg(TILT), #CYL_DEFS, SWING))
