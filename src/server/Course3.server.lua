-- Course3.server.lua
-- Manche 3 : HEX-A-GONE — Plateformes disparaissantes
--
-- 4 niveaux de tuiles carrées empilés verticalement.
-- Quand un joueur touche une tuile → elle devient rouge → disparaît.
-- Au départ : chaque joueur est sur une plateforme individuelle (Y=90).
-- Au lancement (10s countdown) : les plateformes tombent.
-- Dernier survivant = Grand Vainqueur.

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")

-- ────────────────────────────────────────────────────────────
-- CONFIG
-- ────────────────────────────────────────────────────────────
local ARENA_X  =     0
local ARENA_Z  = 10000   -- centre de la zone

local TILE_W   =   6.0   -- largeur/longueur d'une tuile (studs)
local TILE_H   =   1.5   -- hauteur d'une tuile
local TILE_N   =    10   -- tuiles par côté (10×10 = 100 tuiles/niveau)
local TILE_GAP =  0.15   -- petit écart visuel entre les tuiles

-- 4 niveaux, de haut en bas — chaque niveau a 2 couleurs en damier
local LEVELS = {
    { y = 68, c1 = Color3.fromRGB(100, 160, 255), c2 = Color3.fromRGB( 60, 120, 220) },  -- bleu
    { y = 50, c1 = Color3.fromRGB( 80, 210, 190), c2 = Color3.fromRGB( 50, 175, 155) },  -- teal
    { y = 32, c1 = Color3.fromRGB(190, 100, 255), c2 = Color3.fromRGB(155,  65, 220) },  -- violet
    { y = 14, c1 = Color3.fromRGB(255, 165,  50), c2 = Color3.fromRGB(225, 130,  25) },  -- orange
}

local SPAWN_Y = 90    -- Y des plateformes individuelles de départ
local KILL_Y  = -25   -- joueur éliminé si Y descend sous ce seuil

-- ────────────────────────────────────────────────────────────
-- NETTOYAGE SESSION PRÉCÉDENTE
-- ────────────────────────────────────────────────────────────
local _old = workspace:FindFirstChild("Course3")
if _old then _old:Destroy() end

local courseFolder = Instance.new("Folder")
courseFolder.Name   = "Course3"
courseFolder.Parent = workspace

-- ────────────────────────────────────────────────────────────
-- CONSTRUCTION DES 4 NIVEAUX DE TUILES
-- ────────────────────────────────────────────────────────────
-- totalW = 10×6 + 9×0.15 = 61.35 studs par côté
local step       = TILE_W + TILE_GAP                    -- 6.15 studs entre deux centres
local totalW     = TILE_N * TILE_W + (TILE_N - 1) * TILE_GAP  -- ≈ 61.35 studs
local origin     = -totalW / 2 + TILE_W / 2             -- offset du 1er centre

for levelIdx, lv in ipairs(LEVELS) do
    local lvFolder = Instance.new("Folder")
    lvFolder.Name   = "Level" .. levelIdx
    lvFolder.Parent = courseFolder

    for row = 0, TILE_N - 1 do
        for col = 0, TILE_N - 1 do
            local tx = ARENA_X + origin + col * step
            local tz = ARENA_Z + origin + row * step

            local tile = Instance.new("Part")
            tile.Name       = string.format("T%d_%d_%d", levelIdx, row, col)
            tile.Size       = Vector3.new(TILE_W - 0.1, TILE_H, TILE_W - 0.1)
            tile.CFrame     = CFrame.new(tx, lv.y, tz)
            tile.Color      = ((row + col) % 2 == 0) and lv.c1 or lv.c2
            tile.Material   = Enum.Material.SmoothPlastic
            tile.Anchored   = true
            tile.CastShadow = false
            tile.Parent     = lvFolder

            -- ── Disparition au contact ────────────────────────────
            tile.Touched:Connect(function(hit)
                if tile:GetAttribute("Gone") then return end
                local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then return end

                tile:SetAttribute("Gone", true)

                task.spawn(function()
                    -- Grace period
                    task.wait(0.45)
                    if not tile.Parent then return end
                    -- Avertissement rouge
                    tile.Color = Color3.fromRGB(230, 50, 40)
                    task.wait(0.35)
                    if not tile.Parent then return end
                    -- Disparition
                    tile.CanCollide   = false
                    tile.Transparency = 1
                    Debris:AddItem(tile, 3)
                end)
            end)
        end
    end
end

-- ────────────────────────────────────────────────────────────
-- PLATEFORMES INDIVIDUELLES DE DÉPART (10 joueurs)
-- 2 rangées de 5, au-dessus du niveau 1 (Y=68)
-- Elles tombent au lancement de la manche.
-- ────────────────────────────────────────────────────────────
local spawnPlatforms = {}

local SPAWN_ROW_Z = { ARENA_Z - 14, ARENA_Z + 14 }

for row = 1, 2 do
    for col = 1, 5 do
        local sx = ARENA_X + (col - 3) * 13   -- X : -26, -13, 0, 13, 26
        local sz = SPAWN_ROW_Z[row]

        local sp = Instance.new("Part")
        sp.Name       = string.format("SpawnPlat_%d_%d", row, col)
        sp.Size       = Vector3.new(9, 1.2, 9)
        sp.CFrame     = CFrame.new(sx, SPAWN_Y, sz)
        sp.Color      = Color3.fromRGB(255, 220, 60)
        sp.Material   = Enum.Material.SmoothPlastic
        sp.Anchored   = true
        sp.CastShadow = false
        sp.Parent     = courseFolder

        table.insert(spawnPlatforms, sp)
    end
end

-- ────────────────────────────────────────────────────────────
-- API PUBLIQUE (_G.Course3)
-- ────────────────────────────────────────────────────────────
local Course3 = {}
_G.Course3    = Course3

-- Positions de spawn : au-dessus des plateformes individuelles
Course3.GetSpawnCFrames = function(n)
    local spawns = {}
    for i = 1, n do
        local sp = spawnPlatforms[i]
        if sp then
            table.insert(spawns, sp.CFrame + Vector3.new(0, 3.5, 0))
        else
            -- Fallback : disperse sur le niveau 1
            local tx = ARENA_X + (math.random() - 0.5) * totalW
            local tz = ARENA_Z + (math.random() - 0.5) * totalW
            table.insert(spawns, CFrame.new(tx, LEVELS[1].y + 5, tz))
        end
    end
    return spawns
end

-- Lâche les plateformes individuelles (appelé au démarrage de la manche)
Course3.LaunchSpawnPlatforms = function()
    for _, sp in ipairs(spawnPlatforms) do
        if sp and sp.Parent then
            sp.Anchored = false
        end
    end
    -- Nettoyage après la chute
    task.delay(10, function()
        for _, sp in ipairs(spawnPlatforms) do
            if sp and sp.Parent then sp:Destroy() end
        end
    end)
    print("[Course3] ▶ Plateformes de départ lâchées !")
end

Course3.KILL_Y = KILL_Y

-- ────────────────────────────────────────────────────────────
print("[Course3] ✅ Hex-a-Gone prêt")
print(string.format("  %d niveaux | %d tuiles/niveau | Y=%d/%d/%d/%d | Kill Y=%d",
    #LEVELS, TILE_N * TILE_N,
    LEVELS[1].y, LEVELS[2].y, LEVELS[3].y, LEVELS[4].y, KILL_Y))
