-- BounceManager.server.lua
-- Gère le rebond sur les soucoupes taguées "BounceDisc" dans le workspace.
-- Les soucoupes sont créées par MapBuilder (sections hasBounce = true).
-- Lit l'attribut "BounceVY" sur chaque disque pour calibrer la force.

local CollectionService = game:GetService("CollectionService")
local Debris            = game:GetService("Debris")

local bounceCooldown = {}

-- ============================================================
-- SETUP
-- ============================================================

local function setupDisc(disc)
    local bounceVY = disc:GetAttribute("BounceVY") or 85

    disc.Touched:Connect(function(hit)
        local char = hit.Parent
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Debounce : évite plusieurs rebonds par atterrissage
        local uid = char.Name
        if bounceCooldown[uid] then return end
        bounceCooldown[uid] = true

        -- BodyVelocity : seule méthode fiable pour launcher un Humanoid
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(0, math.huge, 0)
        bv.Velocity  = Vector3.new(0, bounceVY, 0)
        bv.P         = math.huge
        bv.Parent    = hrp
        Debris:AddItem(bv, 0.1)

        task.delay(0.4, function() bounceCooldown[uid] = nil end)
    end)
end

for _, disc in ipairs(CollectionService:GetTagged("BounceDisc")) do
    setupDisc(disc)
end
CollectionService:GetInstanceAddedSignal("BounceDisc"):Connect(setupDisc)

print(string.format("[BounceManager] %d soucoupe(s) trouvée(s)", #CollectionService:GetTagged("BounceDisc")))
