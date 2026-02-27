-- DiscManager.server.lua
-- Anime tous les bras taguées "SpinningDisc" dans le workspace.
-- Les bras sont créés par MapBuilder (sections hasDisc = true).
-- Lit les attributs PosX/Y/Z, Speed, SpinDir sur chaque bras.

local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local entries = {}  -- { disc, pos, spd, dir }

-- ============================================================
-- SETUP
-- ============================================================

local function setupDisc(disc)
    local posX  = disc:GetAttribute("PosX")    or disc.Position.X
    local posY  = disc:GetAttribute("PosY")    or disc.Position.Y
    local posZ  = disc:GetAttribute("PosZ")    or disc.Position.Z
    local speed = disc:GetAttribute("Speed")   or math.rad(35)
    local dir   = disc:GetAttribute("SpinDir") or 1

    table.insert(entries, {
        disc = disc,
        pos  = Vector3.new(posX, posY, posZ),
        spd  = speed,
        dir  = dir,
    })
    print("[DiscManager] ✅ Bras prêt :", disc:GetFullName())
end

for _, disc in ipairs(CollectionService:GetTagged("SpinningDisc")) do
    setupDisc(disc)
end
CollectionService:GetInstanceAddedSignal("SpinningDisc"):Connect(setupDisc)

print(string.format("[DiscManager] %d bras trouvé(s)", #entries))

-- ============================================================
-- ANIMATION (Heartbeat — frame-rate indépendant)
-- Rotation autour de Y monde : CFrame.new(pos) * CFrame.Angles(0, angle, 0)
-- Les joueurs posés sur le bras sont entraînés automatiquement par la physique.
-- ============================================================

local t = 0
RunService.Heartbeat:Connect(function(dt)
    t = t + dt
    for _, e in ipairs(entries) do
        if e.disc and e.disc.Parent then
            e.disc.CFrame = CFrame.new(e.pos) * CFrame.Angles(0, t * e.spd * e.dir, 0)
        end
    end
end)
