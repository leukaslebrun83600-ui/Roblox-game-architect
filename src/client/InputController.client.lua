-- InputController.client.lua — Interactions joueur (boutons pièges & sacrifices)
-- Crée des ProximityPrompts sur tous les boutons du parcours.
-- Utilise ProximityPromptService.PromptTriggered (handler global) pour la détection
-- des activations — plus fiable que pp.Triggered dans un LocalScript.

local Players               = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService       = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer

local Events           = game.ReplicatedStorage:WaitForChild("Events")
local reqActivateTrap  = Events:WaitForChild("RequestActivateTrap")
local reqSacrifice     = Events:WaitForChild("RequestSacrifice")
local reButtonUsed     = Events:WaitForChild("ButtonUsed")
local reRoundState     = Events:WaitForChild("RoundStateChanged")
local reTeleportFinish    = Events:WaitForChild("TeleportToFinish")

-- ============================================================
-- CRÉATION DES PROXIMITYPROMPTS
-- ============================================================

local PROMPT_DISTANCE = 5   -- studs (= GameConfig.Traps.ACTIVATION_RADIUS)

local function makePrompt(button, issacrifice)
    if button:FindFirstChildOfClass("ProximityPrompt") then return end

    local pp = Instance.new("ProximityPrompt")
    pp.ActionText            = issacrifice and "Se sacrifier" or "Activer le piège"
    pp.ObjectText            = issacrifice and "Bouton Sacrifice" or (button:GetAttribute("TrapType") or "Piège")
    pp.KeyboardKeyCode       = Enum.KeyCode.E
    pp.HoldDuration          = 0
    pp.MaxActivationDistance = PROMPT_DISTANCE
    pp.RequiresLineOfSight   = false
    pp.Enabled               = not button:GetAttribute("Used")
    pp.Parent                = button
    -- Note : on n'utilise PAS pp.Triggered ici.
    -- L'activation est capturée globalement via ProximityPromptService.PromptTriggered.
end

-- ============================================================
-- HANDLER GLOBAL D'ACTIVATION (remplace les pp.Triggered individuels)
-- ============================================================

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    -- Ne réagit qu'aux actions du joueur local
    if player ~= localPlayer then return end

    local button = prompt.Parent
    if not button or not button:IsA("BasePart") then return end

    local n = button.Name
    if n:sub(1, 11) == "TrapButton_" then
        print("[InputController] E pressé sur " .. button.Name)
        reqActivateTrap:FireServer({ buttonName = button.Name })
    elseif n:sub(1, 16) == "SacrificeButton_" then
        print("[InputController] E pressé sur " .. button.Name)
        reqSacrifice:FireServer({ buttonName = button.Name })
    end
end)

-- ============================================================
-- SCAN INITIAL DES BOUTONS
-- ============================================================

local function scanButtons()
    local course = workspace:WaitForChild("Course", 10)
    if not course then
        warn("[InputController] Dossier 'Course' introuvable")
        return
    end
    local trapCount = 0
    local sacrificeCount = 0
    for _, inst in ipairs(course:GetDescendants()) do
        if inst:IsA("BasePart") then
            local n = inst.Name
            if n:sub(1, 11) == "TrapButton_" then
                makePrompt(inst, false)
                trapCount += 1
            elseif n:sub(1, 16) == "SacrificeButton_" then
                makePrompt(inst, true)
                sacrificeCount += 1
            end
        end
    end
    print(string.format("[InputController] Scan : %d TrapButton(s), %d SacrificeButton(s)", trapCount, sacrificeCount))
end

-- Boutons ajoutés dynamiquement (ex: re-run MapBuilder)
workspace.DescendantAdded:Connect(function(inst)
    if not inst:IsA("BasePart") then return end
    local n = inst.Name
    if n:sub(1, 11) == "TrapButton_" then
        makePrompt(inst, false)
    elseif n:sub(1, 16) == "SacrificeButton_" then
        makePrompt(inst, true)
    end
end)

-- ============================================================
-- DÉSACTIVATION DES PROMPTS QUAND UN BOUTON EST UTILISÉ (E4-S7)
-- ============================================================

reButtonUsed.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" or type(payload.buttonId) ~= "string" then return end

    local course = workspace:FindFirstChild("Course")
    if not course then return end
    for _, inst in ipairs(course:GetDescendants()) do
        if inst:IsA("BasePart") and inst.Name == payload.buttonId then
            local pp = inst:FindFirstChildOfClass("ProximityPrompt")
            if pp then pp.Enabled = false end
            return
        end
    end
end)

-- ============================================================
-- RÉACTIVATION DES PROMPTS AU DÉBUT DE CHAQUE MANCHE
-- ============================================================

reRoundState.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" or payload.state ~= "ACTIVE" then return end
    local course = workspace:FindFirstChild("Course")
    if not course then return end
    for _, inst in ipairs(course:GetDescendants()) do
        if inst:IsA("BasePart") then
            local pp = inst:FindFirstChildOfClass("ProximityPrompt")
            if pp and not inst:GetAttribute("Used") then
                pp.Enabled = true
            end
        end
    end
end)

-- ============================================================
-- INIT
-- ============================================================

-- ============================================================
-- TOUCHE Y — TP vers la fin du Parcours 1 (debug)
-- ============================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Y then
        reTeleportFinish:FireServer()
    end
end)

scanButtons()

print("[InputController] ✅ Prêt  |  [Y] = Fin Parcours 1")
