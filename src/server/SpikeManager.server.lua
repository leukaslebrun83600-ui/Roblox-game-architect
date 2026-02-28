-- SpikeManager.server.lua
-- Anime les piques taguées "Spike" (créées par MapBuilder).
-- Contact avec un pique → mort instantanée → respawn checkpoint.
-- Attributs lus :
--   PosX    (number) — X du pique au repos
--   PosY_ret (number) — Y rétracté (caché sous le sol)
--   PosY_ext (number) — Y étendu (sorti au-dessus du sol)
--   PosZ    (number) — Z du pique
--   Phase   (number) — décalage de phase (évite que tous sortent ensemble)
--   SpikeUp (number) — durée sortie (secondes)
--   SpikeDn (number) — durée rétractée (secondes)

local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local spikeEntries = {}

local function setupSpike(spike)
    local posX   = spike:GetAttribute("PosX")     or spike.Position.X
    local retY   = spike:GetAttribute("PosY_ret") or spike.Position.Y
    local extY   = spike:GetAttribute("PosY_ext") or spike.Position.Y + 4
    local posZ   = spike:GetAttribute("PosZ")     or spike.Position.Z
    local phase  = spike:GetAttribute("Phase")    or 0
    local upTime = spike:GetAttribute("SpikeUp")  or 1.0
    local dnTime = spike:GetAttribute("SpikeDn")  or 2.5

    -- Mort au contact
    spike.Touched:Connect(function(hit)
        if not spike.CanCollide then return end
        local char = hit.Parent
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        hum.Health = 0
    end)

    table.insert(spikeEntries, {
        part   = spike,
        posX   = posX,
        retY   = retY,
        extY   = extY,
        posZ   = posZ,
        phase  = phase,
        upTime = upTime,
        cycle  = upTime + dnTime,
    })
end

for _, spike in ipairs(CollectionService:GetTagged("Spike")) do
    setupSpike(spike)
end
CollectionService:GetInstanceAddedSignal("Spike"):Connect(setupSpike)

-- Animation Heartbeat
local t = 0
RunService.Heartbeat:Connect(function(dt)
    t = t + dt
    for _, sp in ipairs(spikeEntries) do
        if sp.part and sp.part.Parent then
            local cycle_t = (t + sp.phase) % sp.cycle
            local isOut   = cycle_t < sp.upTime

            sp.part.CFrame       = CFrame.new(sp.posX, isOut and sp.extY or sp.retY, sp.posZ)
                                    * CFrame.Angles(0, 0, math.pi / 2)
            sp.part.CanCollide   = isOut
            sp.part.Transparency = isOut and 0 or 1
        end
    end
end)

print(string.format("[SpikeManager] %d pique(s)", #CollectionService:GetTagged("Spike")))
