-- SpinnerManager.server.lua
-- Anime tous les disques taguées "SpinnerHub" dans le workspace.
-- Les spinners sont créés par MapBuilder (sections hasSpinners = true).
-- Les bras "SpinnerArm" sont welded aux hubs → suivent automatiquement.

local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local hubs = {}  -- { hub, pos, dir, spd }

-- ============================================================
-- HUBS (animation)
-- ============================================================

local function setupHub(hub)
    local spinDir = hub:GetAttribute("SpinDir") or 1
    local speed   = hub:GetAttribute("Speed")   or math.rad(100)
    local px      = hub:GetAttribute("PosX")    or hub.Position.X
    local py      = hub:GetAttribute("PosY")    or hub.Position.Y
    local pz      = hub:GetAttribute("PosZ")    or hub.Position.Z

    table.insert(hubs, {
        hub = hub,
        pos = Vector3.new(px, py, pz),
        dir = spinDir,
        spd = speed,
    })
    print("[SpinnerManager] ✅ Hub prêt :", hub:GetFullName())
end

for _, hub in ipairs(CollectionService:GetTagged("SpinnerHub")) do
    setupHub(hub)
end
CollectionService:GetInstanceAddedSignal("SpinnerHub"):Connect(setupHub)

-- ============================================================
-- BRAS (kill on touch)
-- ============================================================

local function setupArm(arm)
    arm.Touched:Connect(function(hit)
        local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then hum.Health = 0 end
    end)
end

for _, arm in ipairs(CollectionService:GetTagged("SpinnerArm")) do
    setupArm(arm)
end
CollectionService:GetInstanceAddedSignal("SpinnerArm"):Connect(setupArm)

print(string.format("[SpinnerManager] %d hub(s) trouvé(s)", #hubs))

-- ============================================================
-- ANIMATION (Heartbeat — frame-rate indépendant)
-- Rotation autour de Y monde : CFrame.new(pos) * CFrame.Angles(0, angle, 0)
-- Les bras suivent via WeldConstraint.
-- ============================================================

local t = 0
RunService.Heartbeat:Connect(function(dt)
    t = t + dt
    for _, e in ipairs(hubs) do
        if e.hub and e.hub.Parent then
            e.hub.CFrame = CFrame.new(e.pos) * CFrame.Angles(0, t * e.spd * e.dir, 0)
        end
    end
end)
