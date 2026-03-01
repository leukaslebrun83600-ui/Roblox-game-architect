-- Course3.server.lua
-- Parcours 3 : FINALE — Pente géante + Étoile dorée
-- 10 joueurs spawnen sur la plateforme de départ.
-- Le premier à toucher l'étoile au sommet = Grand Vainqueur.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- ────────────────────────────────────────────────────────────
-- CONFIG
-- ────────────────────────────────────────────────────────────
local START_X    =     0    -- centre X
local START_Z    = 10000    -- Z de départ
local BASE_Y     =    12    -- Y de la plateforme de départ

local PLAT_W     =    50    -- largeur plateforme
local PLAT_D     =    40    -- profondeur plateforme

local SLOPE_L    =   380    -- longueur de la pente (studs, le long de la surface)
local SLOPE_W    =    90    -- largeur de la pente (X)
local SLOPE_T    =     3    -- épaisseur du plank
local SLOPE_ANG  =    15    -- angle de la pente (degrés)

local STAR_DIAM  =    10    -- diamètre de l'étoile

-- ────────────────────────────────────────────────────────────
-- NETTOYAGE SESSION PRÉCÉDENTE
-- ────────────────────────────────────────────────────────────
local _old = game.Workspace:FindFirstChild("Course3")
if _old then _old:Destroy() end

local courseFolder = Instance.new("Folder")
courseFolder.Name   = "Course3"
courseFolder.Parent = game.Workspace

local function mkPart(name, size, cf, color, material, transp, canCollide)
    local p = Instance.new("Part")
    p.Name         = name
    p.Size         = size
    p.CFrame       = cf
    p.Color        = color
    p.Material     = material or Enum.Material.SmoothPlastic
    p.Anchored     = true
    p.CastShadow   = false
    p.CanCollide   = (canCollide ~= false)
    p.Transparency = transp or 0
    p.Parent       = courseFolder
    return p
end

-- ────────────────────────────────────────────────────────────
-- GÉOMÉTRIE DE LA PENTE
-- ────────────────────────────────────────────────────────────
local ang    = math.rad(SLOPE_ANG)
local horizD = SLOPE_L * math.cos(ang)
local vertR  = SLOPE_L * math.sin(ang)

-- ────────────────────────────────────────────────────────────
-- PLATEFORME DE DÉPART
-- ────────────────────────────────────────────────────────────
mkPart("Plat_Depart",
    Vector3.new(PLAT_W, 1.2, PLAT_D),
    CFrame.new(START_X, BASE_Y, START_Z - PLAT_D / 2),
    Color3.fromRGB(120, 80, 200),
    Enum.Material.SmoothPlastic)

-- ────────────────────────────────────────────────────────────
-- PENTE GÉANTE
-- ────────────────────────────────────────────────────────────
mkPart("Pente",
    Vector3.new(SLOPE_W, SLOPE_T, SLOPE_L),
    CFrame.new(START_X, BASE_Y + vertR / 2, START_Z + horizD / 2)
        * CFrame.Angles(-ang, 0, 0),
    Color3.fromRGB(255, 220, 60),
    Enum.Material.SmoothPlastic)

-- Garde-corps gauche
mkPart("Rail_G",
    Vector3.new(1.2, 6, SLOPE_L),
    CFrame.new(START_X - SLOPE_W / 2, BASE_Y + vertR / 2 + 3, START_Z + horizD / 2)
        * CFrame.Angles(-ang, 0, 0),
    Color3.fromRGB(80, 60, 160), Enum.Material.SmoothPlastic)

-- Garde-corps droit
mkPart("Rail_D",
    Vector3.new(1.2, 6, SLOPE_L),
    CFrame.new(START_X + SLOPE_W / 2, BASE_Y + vertR / 2 + 3, START_Z + horizD / 2)
        * CFrame.Angles(-ang, 0, 0),
    Color3.fromRGB(80, 60, 160), Enum.Material.SmoothPlastic)

-- ────────────────────────────────────────────────────────────
-- ÉTOILE DORÉE
-- ────────────────────────────────────────────────────────────
local starZ = START_Z + horizD + 3
local starY = BASE_Y  + vertR  + 7

local star = Instance.new("Part")
star.Name         = "Star"
star.Shape        = Enum.PartType.Ball
star.Size         = Vector3.new(STAR_DIAM, STAR_DIAM, STAR_DIAM)
star.Color        = Color3.fromRGB(255, 215, 0)
star.Material     = Enum.Material.Neon
star.Anchored     = true
star.CastShadow   = false
star.CanCollide   = false
star.CFrame       = CFrame.new(START_X, starY, starZ)
star.Parent       = courseFolder

TweenService:Create(star,
    TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Size = Vector3.new(STAR_DIAM + 3, STAR_DIAM + 3, STAR_DIAM + 3) }
):Play()

local halo = Instance.new("Part")
halo.Name         = "StarHalo"
halo.Shape        = Enum.PartType.Ball
halo.Size         = Vector3.new(STAR_DIAM + 8, STAR_DIAM + 8, STAR_DIAM + 8)
halo.Color        = Color3.fromRGB(255, 245, 150)
halo.Material     = Enum.Material.Neon
halo.Anchored     = true
halo.CastShadow   = false
halo.CanCollide   = false
halo.Transparency = 0.78
halo.CFrame       = CFrame.new(START_X, starY, starZ)
halo.Parent       = courseFolder

TweenService:Create(halo,
    TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Transparency = 0.92 }
):Play()

-- ────────────────────────────────────────────────────────────
-- API PUBLIQUE (_G.Course3)
-- ────────────────────────────────────────────────────────────
local roundActive    = false
local winnerDeclared = false

local Course3 = {}
_G.Course3 = Course3

Course3.OnStarTouched = nil

Course3.StartRound = function()
    roundActive    = true
    winnerDeclared = false
    print("[Course3] ▶ Manche démarrée")
end

Course3.StopRound = function()
    roundActive = false
end

Course3.GetSpawnCFrames = function(n)
    local spawns = {}
    for i = 1, n do
        local col = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        local sx  = START_X + (col - 2) * 8
        local sz  = (START_Z - PLAT_D + 5) + row * 5
        table.insert(spawns, CFrame.new(sx, BASE_Y + 3, sz))
    end
    return spawns
end

-- ── Étoile ───────────────────────────────────────────────────
star.Touched:Connect(function(hit)
    if not roundActive or winnerDeclared then return end
    local char   = hit.Parent
    local player = Players:GetPlayerFromCharacter(char)
    if not player then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    winnerDeclared = true
    roundActive    = false

    print(string.format("[Course3] ⭐ %s a touché l'étoile !", player.Name))
    if Course3.OnStarTouched then Course3.OnStarTouched(player) end
end)

-- ────────────────────────────────────────────────────────────
print("[Course3] ✅ Finale prête")
print(string.format("  Pente : %d studs à %d° | Étoile : Y=%.0f Z=%.0f",
    SLOPE_L, SLOPE_ANG, starY, starZ))
