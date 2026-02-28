-- FadeManager.server.lua
-- Gère les plateformes disparaissantes taguées "FadePlat" (créées par MapBuilder).
-- Attributs lus :
--   FadeDelay  (number) — secondes après contact avant disparition
--   FadeReturn (number) — secondes avant réapparition

local CollectionService = game:GetService("CollectionService")

local fadeCooldown = {}

local function setupFadePlat(p)
    local fadeDelay  = p:GetAttribute("FadeDelay")  or 0.5
    local fadeReturn = p:GetAttribute("FadeReturn") or 3.5
    local origColor  = p.Color
    local uid        = tostring(p)

    p.Touched:Connect(function(hit)
        local char = hit.Parent
        if not char:FindFirstChildOfClass("Humanoid") then return end
        if fadeCooldown[uid] then return end
        fadeCooldown[uid] = true

        -- Flash rouge immédiat
        if p and p.Parent then p.Color = Color3.fromRGB(220, 80, 80) end

        -- Disparition
        task.delay(fadeDelay, function()
            if p and p.Parent then
                p.Transparency = 1
                p.CanCollide   = false
            end
        end)

        -- Réapparition
        task.delay(fadeDelay + fadeReturn, function()
            if p and p.Parent then
                p.Transparency = 0
                p.CanCollide   = true
                p.Color        = origColor
                fadeCooldown[uid] = nil
            end
        end)
    end)
end

for _, p in ipairs(CollectionService:GetTagged("FadePlat")) do
    setupFadePlat(p)
end
CollectionService:GetInstanceAddedSignal("FadePlat"):Connect(setupFadePlat)

print(string.format("[FadeManager] %d plateforme(s) disparaissante(s)", #CollectionService:GetTagged("FadePlat")))
