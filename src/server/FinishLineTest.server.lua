-- FinishLineTest.server.lua
-- TP debug vers la plateforme de départ du Parcours 3 (Finale Étoile)
-- Touche Y (client) → FireServer → TP ici

local Players = game:GetService("Players")

-- ── Position spawn ──────────────────────────────────────────
-- Course3 : START_Z=10000, PLAT_D=40 → plateforme Z=9960→10000
-- On spawn au milieu de la plateforme, 3 studs au-dessus
local FINISH_SPAWN = CFrame.new(0, 16, 9975)

-- ── RemoteEvent ─────────────────────────────────────────────
local reTeleport = game.ReplicatedStorage:WaitForChild("Events")
                     :WaitForChild("TeleportToFinish")

reTeleport.OnServerEvent:Connect(function(player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = FINISH_SPAWN end
end)

print("[FinishLineTest] ✅ Prêt  |  [Y] = TP Parcours 3 / Finale Étoile  (Z=9975, Y=16)")
