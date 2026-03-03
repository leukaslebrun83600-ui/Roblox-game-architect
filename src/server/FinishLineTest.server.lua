-- FinishLineTest.server.lua
-- TP debug vers la plateforme de départ du Parcours 3 (Finale Étoile)
-- Touche Y (client) → FireServer → TP ici

local Players = game:GetService("Players")

-- ── Position spawn ──────────────────────────────────────────
-- Course3 : Hex-a-Gone centré en (0, ?, 10000)
-- Spawn sur une plateforme individuelle au-dessus du niveau 1 (Y≈94)
local FINISH_SPAWN = CFrame.new(0, 94, 10000)

-- ── RemoteEvent ─────────────────────────────────────────────
local reTeleport = game.ReplicatedStorage:WaitForChild("Events")
                     :WaitForChild("TeleportToFinish")

reTeleport.OnServerEvent:Connect(function(player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = FINISH_SPAWN end
end)

print("[FinishLineTest] ✅ Prêt  |  [Y] = TP Arène Couronne (Z=10070, Y=15)")
