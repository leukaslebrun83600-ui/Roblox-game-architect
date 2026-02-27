-- DiscTest.server.lua
-- Zone de test : Plateforme Tournante (style Fall Guys "Dizzy Heights")
--
-- Mécanique :
--   1. Le joueur saute de l'approche sur le bout du bras tournant (gap ≈ 8 studs)
--   2. Il ride le bras 180° (≈ 5 s) jusqu'à ce qu'il soit côté sortie
--   3. Il saute sur la plateforme de sortie (gap ≈ 5 studs)
--
-- Layout (BASE_Z = -300) :
--   Approach  (Z=-300) →[8]→ ArmTip_A (Z=-285) ←bras→ ArmTip_B (Z=-245) →[5]→ Exit (Z=-233)
--   Bras centre : Z=-265, tourne autour de Y
-- ============================================================

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

-- ────────────────────────────────────────────────────────────
-- CONFIG
-- ────────────────────────────────────────────────────────────
local BASE_X  = 800
local BASE_Y  = 10
local BASE_Z  = -300   -- centre de la zone de test (plateforme d'approche)

local ARM_LEN = 20     -- demi-longueur du bras (studs depuis le centre)
local ARM_W   = 8      -- largeur du bras (X), assez large pour marcher dessus
local ARM_H   = 1.2    -- épaisseur = même que les plateformes normales

-- ~35°/s → demi-tour en ≈ 5 secondes (dosé pour être jouable)
local SPEED   = math.rad(35)

-- Couleurs
local COLOR_PLAT = Color3.fromRGB(197, 193, 227)  -- lavande (même que Section 7)
local COLOR_ARM  = Color3.fromRGB(255, 90, 180)   -- rose vif
local COLOR_HUB  = Color3.fromRGB(80,  80, 80)    -- gris foncé

-- ────────────────────────────────────────────────────────────
-- HELPERS
-- ────────────────────────────────────────────────────────────
local testFolder  = Instance.new("Folder")
testFolder.Name   = "DiscTest"
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

-- Plateforme d'approche
-- Bord avant (vers +Z) : BASE_Z + 7 = -293
makePart("Approach",
    Vector3.new(20, 1.2, 14),
    CFrame.new(BASE_X, BASE_Y, BASE_Z),
    COLOR_PLAT)

-- Centre du bras : BASE_Z + 35 = -265
-- Tip approche : -265 - 20 = -285  → gap 8 studs depuis bord approche (-293) ✓
-- Tip sortie   : -265 + 20 = -245  → gap 5 studs jusqu'à bord gauche sortie (-240) ✓
local armCenterZ = BASE_Z + 35
local armPosV    = Vector3.new(BASE_X, BASE_Y, armCenterZ)

-- Moyeu central (pilier visuel)
makePart("Hub",
    Vector3.new(4, 6, 4),
    CFrame.new(BASE_X, BASE_Y + 3, armCenterZ),
    COLOR_HUB)

-- Bras tournant
-- Size = (ARM_W, ARM_H, ARM_LEN*2) → s'étend en ±Z quand angle=0
-- Surface haute = BASE_Y + ARM_H/2 = BASE_Y + 0.6 → alignée avec les plateformes ✓
local arm = makePart("Arm",
    Vector3.new(ARM_W, ARM_H, ARM_LEN * 2),
    CFrame.new(armPosV),
    COLOR_ARM)

-- Plateforme de sortie
-- Bord gauche (vers -Z) : -240  → gap 5 studs depuis tip sortie (-245) ✓
-- Centre : -240 + 7 = -233 → BASE_Z + 67
makePart("Exit",
    Vector3.new(20, 1.2, 14),
    CFrame.new(BASE_X, BASE_Y, BASE_Z + 67),
    COLOR_PLAT)

-- ────────────────────────────────────────────────────────────
-- ANIMATION (Heartbeat — frame-rate indépendant)
-- Le bras tourne autour de l'axe Y mondial.
-- Les joueurs posés dessus sont entraînés automatiquement par la physique Roblox.
-- ────────────────────────────────────────────────────────────
local t = 0
RunService.Heartbeat:Connect(function(dt)
    t = t + dt
    arm.CFrame = CFrame.new(armPosV) * CFrame.Angles(0, t * SPEED, 0)
end)

-- ────────────────────────────────────────────────────────────
-- TÉLÉPORTATION — TP automatique à l'apparition du personnage
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

-- Gère les joueurs déjà connectés (cas du re-run en play mode)
for _, player in ipairs(Players:GetPlayers()) do
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(BASE_X, BASE_Y + 5, BASE_Z - 5)
        end
    end
end

print("[DiscTest] ✅ Zone prête")
print(string.format("[DiscTest]   Approche Z=%.0f  |  Bras centre Z=%.0f  |  Sortie Z=%.0f",
    BASE_Z, armCenterZ, BASE_Z + 67))
print(string.format("[DiscTest]   Gap approche→bras : 8 studs  |  Gap bras→sortie : 5 studs"))
print(string.format("[DiscTest]   Vitesse : %.0f°/s → demi-tour en %.1f s", math.deg(SPEED), math.pi / SPEED))
