-- FinishLineTest.server.lua
-- TP debug vers la fin du Parcours 1 (avant la ligne d'arrivée)
-- Touche Y (client) → FireServer → TP ici
--
-- Section 12 (hasFinalZone) : zStart = 200 + 11*120 = 1520
-- PlateformeArrivee : Z ≈ 1528→1563, surface Y ≈ 49-50 (estimé d'après les sections précédentes)
-- On spawn légèrement en hauteur pour atterrir proprement.

local Players = game:GetService("Players")

-- ── Position spawn ──────────────────────────────────────────
-- Z = 1530 : début de la plateforme d'arrivée, avant la ligne
-- Y = 65   : assez haut pour tomber sur la plateforme sans la traverser
-- X = 0    : centre du parcours
local FINISH_SPAWN = CFrame.new(0, 65, 1530)

-- ── RemoteEvent ─────────────────────────────────────────────
local reTeleport = game.ReplicatedStorage:WaitForChild("Events")
                     :WaitForChild("TeleportToFinish")

reTeleport.OnServerEvent:Connect(function(player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = FINISH_SPAWN end
end)

print("[FinishLineTest] ✅ Prêt  |  [Y] = TP fin Parcours 1  (Z=1530, Y=65)")
