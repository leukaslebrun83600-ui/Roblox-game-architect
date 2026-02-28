-- PunchManager.server.lua
-- Anime les cylindres taguées "PunchCylinder" (créés par MapBuilder).
-- Oscillation sinusoïdale gauche-droite + poussée au contact.
--
-- Attributs lus sur chaque part :
--   PosX  (number) — X de repos du cylindre
--   PosY  (number) — Y du centre du cylindre (fixe)
--   PosZ  (number) — Z du cylindre (fixe)
--   Speed (number) — cycles/seconde
--   Phase (number) — déphasage initial (radians)
--   Swing (number) — amplitude G-D (studs de chaque côté)

local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local PUSH_F = 55    -- force de poussée horizontale (studs/s)
local PUSH_Y = 18    -- légère élévation lors de la poussée

local cylEntries   = {}
local pushCooldown = {}

-- ── Setup d'un cylindre ──────────────────────────────────────
local function setupCyl(cyl)
    local posX  = cyl:GetAttribute("PosX")  or 0
    local posY  = cyl:GetAttribute("PosY")  or cyl.Position.Y
    local posZ  = cyl:GetAttribute("PosZ")  or cyl.Position.Z
    local speed = cyl:GetAttribute("Speed") or 0.45
    local phase = cyl:GetAttribute("Phase") or 0
    local swing = cyl:GetAttribute("Swing") or 8

    -- Poussée au contact
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

    table.insert(cylEntries, {
        cyl   = cyl,
        posX  = posX,
        posY  = posY,
        posZ  = posZ,
        speed = speed,
        phase = phase,
        swing = swing,
    })
end

-- Cylindres déjà présents
for _, cyl in ipairs(CollectionService:GetTagged("PunchCylinder")) do
    setupCyl(cyl)
end
-- Cylindres ajoutés dynamiquement
CollectionService:GetInstanceAddedSignal("PunchCylinder"):Connect(setupCyl)

-- ── Animation (Heartbeat) ────────────────────────────────────
local t = 0
RunService.Heartbeat:Connect(function(dt)
    t = t + dt
    for _, e in ipairs(cylEntries) do
        if e.cyl and e.cyl.Parent then
            local bx = e.posX + e.swing * math.sin(t * e.speed * math.pi * 2 + e.phase)
            e.cyl.CFrame = CFrame.new(bx, e.posY, e.posZ)
                * CFrame.Angles(0, 0, math.pi / 2)
        end
    end
end)

print(string.format("[PunchManager] %d cylindre(s) trouvé(s)",
    #CollectionService:GetTagged("PunchCylinder")))
