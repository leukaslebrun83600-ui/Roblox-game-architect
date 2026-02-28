-- BounceTest.server.lua
-- Zone de test : Soucoupes rebondissantes (style Fall Guys "Lily Leaper")
-- Disques plats style bonbon saucer → rebond à chaque atterrissage
-- Le joueur doit traverser le champ de soucoupes pour atteindre la sortie.
--
-- Layout (5 rangées zigzag) :
--   Approach (Z=-300) → [rangée 1 : 3 disques] → [rangée 2 : 2] → ... → Exit (Z=-176)
-- ============================================================

local Players  = game:GetService("Players")
local Workspace = game.Workspace

-- ────────────────────────────────────────────────────────────
-- CONFIG
-- ────────────────────────────────────────────────────────────
local BASE_X    = 800
local BASE_Y    = 10
local BASE_Z    = -300

-- Dimensions des soucoupes (style bonbon saucer deux couches)
local DISC_R    = 7     -- rayon couche externe
local DISC_H    = 1.5   -- épaisseur couche externe
local TOP_R     = 4.5   -- rayon couche interne (centre bombé)
local TOP_H     = 0.6   -- épaisseur couche interne

local BOUNCE_VY = 85    -- vitesse verticale appliquée au rebond (studs/s)

-- Couleurs pastel style bonbon saucer (externe, interne)
local DISC_COLORS = {
    { Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 182, 193) },  -- jaune / rose
    { Color3.fromRGB(200, 230, 255), Color3.fromRGB(255, 200, 240) },  -- bleu ciel / lilas
    { Color3.fromRGB(200, 255, 210), Color3.fromRGB(255, 240, 150) },  -- menthe / jaune
    { Color3.fromRGB(255, 200, 240), Color3.fromRGB(200, 230, 255) },  -- lilas / bleu ciel
}

-- ────────────────────────────────────────────────────────────
-- LAYOUT — 5 rangées en zigzag
-- Rangées impaires (1,3,5) : 3 disques à X={-16, 0, 16}
-- Rangées paires  (2,4)    : 2 disques à X={-8, 8}   (décalés entre les 3 du dessus)
-- ────────────────────────────────────────────────────────────
local rowDefs = {
    { dz = 22,  xs = {-16, 0, 16} },
    { dz = 42,  xs = {-8,  8}     },
    { dz = 62,  xs = {-16, 0, 16} },
    { dz = 82,  xs = {-8,  8}     },
    { dz = 102, xs = {-16, 0, 16} },
}

-- ────────────────────────────────────────────────────────────
-- HELPER
-- ────────────────────────────────────────────────────────────
local testFolder  = Instance.new("Folder")
testFolder.Name   = "BounceTest"
testFolder.Parent = Workspace

local function makePart(name, size, cf, color, canCollide)
    local p = Instance.new("Part")
    p.Name         = name
    p.Size         = size
    p.CFrame       = cf
    p.Color        = color
    p.Material     = Enum.Material.SmoothPlastic
    p.Anchored     = true
    p.CastShadow   = false
    p.CanCollide   = canCollide ~= false  -- true par défaut
    p.Parent       = testFolder
    return p
end

-- ────────────────────────────────────────────────────────────
-- CONSTRUCTION
-- ────────────────────────────────────────────────────────────
local platColor = Color3.fromRGB(255, 213, 79)  -- caramel (approche/sortie)

-- Plateforme d'approche
makePart("Approach",
    Vector3.new(20, 1.2, 14),
    CFrame.new(BASE_X, BASE_Y, BASE_Z),
    platColor)

-- Soucoupes rebondissantes
local bounceCooldown = {}
local discIdx = 0

for rowNum, row in ipairs(rowDefs) do
    local discZ = BASE_Z + row.dz
    for _, xOffset in ipairs(row.xs) do
        discIdx = discIdx + 1
        local palette   = DISC_COLORS[((discIdx - 1) % #DISC_COLORS) + 1]
        local outerCol  = palette[1]
        local innerCol  = palette[2]
        local discX     = BASE_X + xOffset
        local discCenY  = BASE_Y  -- surface haute = BASE_Y + DISC_H/2 ≈ niveau des plateformes

        -- Couche externe (grande, le sol rebondissant)
        -- Cylindre horizontal : Size=(DISC_H, DISC_R*2, DISC_R*2), axe local X → monde Y
        local outer = makePart(
            string.format("Disc_%d_%d_outer", rowNum, xOffset),
            Vector3.new(DISC_H, DISC_R * 2, DISC_R * 2),
            CFrame.new(discX, discCenY, discZ) * CFrame.Angles(0, 0, math.pi / 2),
            outerCol)
        outer.Shape = Enum.PartType.Cylinder

        -- Couche interne (bombée au centre, décorative)
        local topCenY = discCenY + DISC_H / 2 + TOP_H / 2  -- posée sur le dessus de la couche externe
        local inner = makePart(
            string.format("Disc_%d_%d_inner", rowNum, xOffset),
            Vector3.new(TOP_H, TOP_R * 2, TOP_R * 2),
            CFrame.new(discX, topCenY, discZ) * CFrame.Angles(0, 0, math.pi / 2),
            innerCol,
            false)  -- CanCollide=false : purement visuelle
        inner.Shape = Enum.PartType.Cylinder

        -- ── REBOND ──
        -- BodyVelocity : seule méthode fiable pour launcher un Humanoid vers le haut.
        -- AssemblyLinearVelocity est écrasé immédiatement par la physique du Humanoid.
        -- MaxForce Y=∞ → force uniquement verticale, vitesse X/Z conservée.
        outer.Touched:Connect(function(hit)
            local char = hit.Parent
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end

            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local uid = char.Name
            if bounceCooldown[uid] then return end
            bounceCooldown[uid] = true

            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(0, math.huge, 0)
            bv.Velocity  = Vector3.new(0, BOUNCE_VY, 0)
            bv.P         = math.huge
            bv.Parent    = hrp
            game:GetService("Debris"):AddItem(bv, 0.1)  -- supprime après 0.1 s

            task.delay(0.4, function() bounceCooldown[uid] = nil end)
        end)
    end
end

-- Plateforme de sortie
-- Dernière rangée dz=102, bord avant du disque à dz=109, sortie centrée à dz=124
makePart("Exit",
    Vector3.new(20, 1.2, 14),
    CFrame.new(BASE_X, BASE_Y, BASE_Z + 124),
    platColor)

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

for _, player in ipairs(Players:GetPlayers()) do
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(BASE_X, BASE_Y + 5, BASE_Z - 5)
        end
    end
end

print("[BounceTest] ✅ Zone prête — " .. discIdx .. " soucoupes sur " .. #rowDefs .. " rangées")
print(string.format("[BounceTest]   Rebond: %d studs/s | Disque R=%d | Décalage zigzag ✓", BOUNCE_VY, DISC_R))
