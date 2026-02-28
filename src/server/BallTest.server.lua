-- BallTest.server.lua
-- Zone de test : Boules en ligne (style Total Wipeout / Fall Guys)
-- 4 grandes sphères rose sur pieds bleus → le joueur saute de l'une à l'autre.
-- Pas d'animation : le défi vient de la surface courbe (glissant, imprecis).
--
-- Layout (BASE_Z = -300) :
--   Approach (Z=-300) →[8]→ Ball1 →[4]→ Ball2 →[4]→ Ball3 →[4]→ Ball4 →[8]→ Exit (Z=-210)
-- ============================================================

local Players  = game:GetService("Players")
local Workspace = game.Workspace

-- ────────────────────────────────────────────────────────────
-- CONFIG
-- ────────────────────────────────────────────────────────────
local BASE_X    = 800
local BASE_Y    = 10
local BASE_Z    = -300  -- centre de la plateforme d'approche

local BALL_R    = 5     -- rayon des boules (diamètre = 10 studs)
local BALL_GAP  = 4     -- gap entre surfaces de boules (studs)
local SPACING   = BALL_R * 2 + BALL_GAP  -- 14 studs centre-à-centre
local NUM_BALLS = 4

local PED_R     = 2.5   -- rayon du pied (cylindre)
local PED_H     = 8     -- hauteur du pied

-- Centre Y des boules = BASE_Y → sommet à BASE_Y + BALL_R = 15
-- Approche surface = BASE_Y + 0.6 = 10.6 → saut de 4.4 studs pour monter ✓
local ballCenterY = BASE_Y

-- ────────────────────────────────────────────────────────────
-- COULEURS
-- ────────────────────────────────────────────────────────────
local COLOR_PLAT = Color3.fromRGB(255, 213,  79)  -- caramel (approche / sortie)
local COLOR_BALL = Color3.fromRGB(255,  90, 180)  -- rose vif (boules)
local COLOR_PED  = Color3.fromRGB(100, 180, 255)  -- bleu bonbon (pieds)

-- ────────────────────────────────────────────────────────────
-- HELPER
-- ────────────────────────────────────────────────────────────
local testFolder  = Instance.new("Folder")
testFolder.Name   = "BallTest"
testFolder.Parent = Workspace

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

-- Plateforme d'approche
-- Bord avant (vers +Z) : BASE_Z + 7 = -293
makePart("Approach",
    Vector3.new(20, 1.2, 14),
    CFrame.new(BASE_X, BASE_Y, BASE_Z),
    COLOR_PLAT)

-- 4 boules en ligne
-- Ball 1 near edge = BASE_Z+7 + 8 = BASE_Z+15 → gap=8 studs depuis approche ✓
-- Boules espacées de SPACING=14 studs (gap surface=4 studs entre chaque) ✓
local ball1Z = BASE_Z + 7 + 8 + BALL_R   -- BASE_Z + 20

for i = 1, NUM_BALLS do
    local bz = ball1Z + (i - 1) * SPACING

    -- Pied (cylindre vertical sous la boule)
    -- Cylindre Roblox : axe = local X → on oriente avec CFrame.Angles(0,0,π/2)
    -- Size = (PED_H, PED_R*2, PED_R*2) : PED_H le long de l'axe (local X → world Y)
    local pedY = ballCenterY - BALL_R - PED_H / 2  -- centre du pied
    local ped = makePart("Pedestal_" .. i,
        Vector3.new(PED_H, PED_R * 2, PED_R * 2),
        CFrame.new(BASE_X, pedY, bz) * CFrame.Angles(0, 0, math.pi / 2),
        COLOR_PED)
    ped.Shape = Enum.PartType.Cylinder

    -- Boule (sphère)
    local ball = makePart("Ball_" .. i,
        Vector3.new(BALL_R * 2, BALL_R * 2, BALL_R * 2),
        CFrame.new(BASE_X, ballCenterY, bz),
        COLOR_BALL)
    ball.Shape = Enum.PartType.Ball
end

-- Plateforme de sortie
-- Bord gauche = Ball4 far edge + 8 = ball1Z + 3*SPACING + BALL_R + 8
local exitZ = ball1Z + (NUM_BALLS - 1) * SPACING + BALL_R + 8 + 7
makePart("Exit",
    Vector3.new(20, 1.2, 14),
    CFrame.new(BASE_X, BASE_Y, exitZ),
    COLOR_PLAT)

-- ────────────────────────────────────────────────────────────
-- TÉLÉPORTATION
-- ────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        task.wait(1)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(BASE_X, BASE_Y + 5, BASE_Z - 5)
        end
    end)
end)

-- Joueurs déjà présents (re-run en play mode)
for _, player in ipairs(Players:GetPlayers()) do
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(BASE_X, BASE_Y + 5, BASE_Z - 5)
        end
    end
end

print("[BallTest] ✅ Zone prête — " .. NUM_BALLS .. " boules (R=" .. BALL_R .. " studs, gap=" .. BALL_GAP .. " studs)")
print(string.format("[BallTest]   Approche Z=%d | Ball1 Z=%d | Ball4 Z=%d | Sortie Z=%d",
    BASE_Z, ball1Z, ball1Z + (NUM_BALLS-1)*SPACING, exitZ))
print(string.format("[BallTest]   Sommet des boules à Y=%d (%.1f studs au-dessus de l'approche)",
    ballCenterY + BALL_R, (ballCenterY + BALL_R) - (BASE_Y + 0.6)))
