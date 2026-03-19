-- CountdownController.client.lua — Décompte WAITING isolé
-- Script minimal, indépendant de UIController.
-- Crée son propre ScreenGui (DisplayOrder 100) pour être sûr d'être au premier plan.

local Players    = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local playerGui  = localPlayer:WaitForChild("PlayerGui")

local Events       = game.ReplicatedStorage:WaitForChild("Events")
local reRoundState = Events:WaitForChild("RoundStateChanged")

-- ScreenGui dédié, toujours au premier plan
local gui = Instance.new("ScreenGui")
gui.Name           = "CountdownGui"
gui.DisplayOrder   = 100
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = playerGui

local frame = Instance.new("Frame")
frame.Size                   = UDim2.new(0, 500, 0, 180)
frame.Position               = UDim2.new(0.5, -250, 0.35, -90)
frame.BackgroundColor3       = Color3.fromRGB(10, 10, 20)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel        = 0
frame.Visible                = false
frame.Parent                 = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent       = frame

local roundLabel = Instance.new("TextLabel")
roundLabel.Size                   = UDim2.new(1, -20, 0, 55)
roundLabel.Position               = UDim2.new(0, 10, 0, 8)
roundLabel.BackgroundTransparency = 1
roundLabel.Text                   = "MANCHE 1"
roundLabel.TextColor3             = Color3.fromRGB(255, 215, 0)
roundLabel.Font                   = Enum.Font.GothamBold
roundLabel.TextScaled             = true
roundLabel.Parent                 = frame

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Size                   = UDim2.new(1, -20, 0, 90)
countdownLabel.Position               = UDim2.new(0, 10, 0, 72)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Text                   = "5"
countdownLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
countdownLabel.Font                   = Enum.Font.GothamBold
countdownLabel.TextScaled             = true
countdownLabel.Parent                 = frame

-- ============================================================
-- HANDLER
-- ============================================================

reRoundState.OnClientEvent:Connect(function(payload)
    print("[CountdownController] Event reçu :", payload and payload.state)

    if type(payload) ~= "table" then return end
    local st   = payload.state
    local data = payload.data or {}

    if st == "WAITING" then
        frame.Visible = true
        if data.countdown then
            local label = data.label or "Parcours"
            roundLabel.Text      = string.format("MANCHE %d — %s", data.round or 1, string.upper(label))
            countdownLabel.Text  = tostring(data.countdown)
            countdownLabel.TextColor3 = data.countdown <= 3
                and Color3.fromRGB(255, 60, 60)
                or  Color3.fromRGB(255, 255, 255)
        end
    else
        frame.Visible = false
    end
end)

print("[CountdownController] ✅ Prêt")
