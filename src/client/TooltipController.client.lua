-- TooltipController.client.lua — Système de tooltips contextuels (onboarding)
-- E10-S1 (système de base), S2 (but du jeu), S3 (piège),
-- S4 (+1 Traître), S5 (sacrifice), S6 (défis lobby)

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")
local hudGui      = playerGui:WaitForChild("HUD")

local Events          = game.ReplicatedStorage:WaitForChild("Events")
local reRoundState    = Events:WaitForChild("RoundStateChanged")
local reShowKarmaNotif = Events:WaitForChild("ShowKarmaNotification")
local reShowTooltip   = Events:WaitForChild("ShowTooltip")   -- client → server
local fnGetPlayerData = Events:WaitForChild("GetPlayerData")

-- ============================================================
-- ÉTAT LOCAL
-- ============================================================

-- Cache des tooltips déjà vus (synchronisé depuis le serveur au démarrage)
local seen = {
    goalTooltip      = true,  -- true = déjà vu (sécurité : on bloque tout par défaut)
    trapTooltip      = true,
    karmaTooltip     = true,
    sacrificeTooltip = true,
    challengeTooltip = true,
}

local currentState      = "LOBBY"
local hasPlayedOneRound = false  -- pour E10-S6 (premier retour au lobby)
local tooltipQueue      = {}
local tooltipBusy       = false

-- ============================================================
-- CRÉATION DU PANNEAU TOOLTIP (E10-S1)
-- ============================================================

local panel = Instance.new("Frame")
panel.Name                  = "TooltipPanel"
panel.Size                  = UDim2.new(0, 340, 0, 110)
panel.Position              = UDim2.new(0.5, -170, 1, 80)  -- départ hors écran (bas)
panel.BackgroundColor3      = Color3.fromRGB(18, 18, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel       = 0
panel.ZIndex                = 30
panel.Visible               = false
panel.Parent                = hudGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent       = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = Color3.fromRGB(255, 215, 0)
panelStroke.Thickness = 2
panelStroke.Parent    = panel

local titleLabel = Instance.new("TextLabel")
titleLabel.Name                  = "Title"
titleLabel.Size                  = UDim2.new(1, -16, 0, 32)
titleLabel.Position              = UDim2.new(0, 8, 0, 4)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3            = Color3.fromRGB(255, 215, 0)
titleLabel.Font                  = Enum.Font.GothamBold
titleLabel.TextScaled            = true
titleLabel.TextXAlignment        = Enum.TextXAlignment.Left
titleLabel.Parent                = panel

local bodyLabel = Instance.new("TextLabel")
bodyLabel.Name                  = "Body"
bodyLabel.Size                  = UDim2.new(1, -16, 0, 62)
bodyLabel.Position              = UDim2.new(0, 8, 0, 36)
bodyLabel.BackgroundTransparency = 1
bodyLabel.TextColor3            = Color3.fromRGB(210, 210, 220)
bodyLabel.Font                  = Enum.Font.Gotham
bodyLabel.TextScaled            = true
bodyLabel.TextWrapped           = true
bodyLabel.TextXAlignment        = Enum.TextXAlignment.Left
bodyLabel.TextYAlignment        = Enum.TextYAlignment.Top
bodyLabel.Parent                = panel

-- Barre de progression auto-fermeture (fine ligne en bas du panel)
local progressBar = Instance.new("Frame")
progressBar.Size             = UDim2.new(1, -4, 0, 3)
progressBar.Position         = UDim2.new(0, 2, 1, -5)
progressBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
progressBar.BorderSizePixel  = 0
progressBar.Parent           = panel
Instance.new("UICorner", progressBar).CornerRadius = UDim.new(0, 2)

-- ============================================================
-- AFFICHAGE / MASQUAGE DU TOOLTIP
-- ============================================================

local hideConn = nil  -- connexion auto-hide

local function showTooltipNow(title, body, duration, key)
    -- Arrête le timer précédent si actif
    if hideConn then hideConn:Disconnect(); hideConn = nil end

    titleLabel.Text = title
    bodyLabel.Text  = body

    -- Slide vers le haut
    panel.Position = UDim2.new(0.5, -170, 1, 80)
    panel.Visible  = true
    TweenService:Create(panel,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, -170, 1, -130) }
    ):Play()

    -- Barre de progression (rétrécit sur la durée)
    progressBar.Size = UDim2.new(1, -4, 0, 3)
    TweenService:Create(progressBar,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { Size = UDim2.new(0, 0, 0, 3) }
    ):Play()

    -- Marque comme vu côté serveur (persistance)
    if key then
        seen[key] = true
        reShowTooltip:FireServer(key)
    end

    -- Auto-fermeture après `duration` secondes
    tooltipBusy = true
    task.delay(duration, function()
        TweenService:Create(panel,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(0.5, -170, 1, 80) }
        ):Play()
        task.delay(0.25, function()
            panel.Visible  = false
            tooltipBusy    = false

            -- Traite le suivant dans la file
            if #tooltipQueue > 0 then
                local next = table.remove(tooltipQueue, 1)
                showTooltipNow(next.title, next.body, next.duration, next.key)
            end
        end)
    end)
end

-- Met en file d'attente si un tooltip est déjà affiché
local function queueTooltip(title, body, duration, key)
    -- Ne montre pas si déjà vu
    if key and seen[key] then return end

    if tooltipBusy then
        table.insert(tooltipQueue, { title = title, body = body, duration = duration, key = key })
    else
        showTooltipNow(title, body, duration, key)
    end
end

-- ============================================================
-- CONTENU DES TOOLTIPS
-- ============================================================

local TOOLTIPS = {
    -- E10-S2 : But du jeu
    goal = {
        key      = "goalTooltip",
        title    = "🎯 Objectif",
        body     = "Course jusqu'à la fin du parcours ! Utilise les boutons rouges pour activer des pièges sur tes adversaires. Mais gare aux traîtres derrière toi…",
        duration = 8,
    },
    -- E10-S3 : Activer piège
    trap = {
        key      = "trapTooltip",
        title    = "🗡 Bouton Piège [E]",
        body     = "Appuie sur [E] pour activer ce piège. Les joueurs dans la zone sont éliminés ! +1 Karma Traître à chaque kill.",
        duration = 6,
    },
    -- E10-S4 : +1 Traître expliqué
    karma = {
        key      = "karmaTooltip",
        title    = "🗡 Karma Traître !",
        body     = "Tu as éliminé un joueur. Accumule du Karma Traître pour débloquer des titres : Faux Ami → Grand Traître → Traître Légendaire !",
        duration = 7,
    },
    -- E10-S5 : Bouton Sacrifice
    sacrifice = {
        key      = "sacrificeTooltip",
        title    = "✨ Bouton Sacrifice [E]",
        body     = "Appuie sur [E] pour te sacrifier. Tu ouvres un passage secret pour tes alliés, mais tu retournes à ton dernier checkpoint. +1 Karma Martyr.",
        duration = 6,
    },
    -- E10-S6 : Défis disponibles
    challenge = {
        key      = "challengeTooltip",
        title    = "📋 Défis Quotidiens !",
        body     = "Tu as des défis à compléter aujourd'hui ! Clique sur DÉFIS dans le lobby pour voir ta progression et gagner du Karma bonus.",
        duration = 8,
    },
}

-- ============================================================
-- SYNCHRONISATION DEPUIS LE SERVEUR (E10-S1)
-- Charge l'état "vu / pas vu" depuis les données joueur
-- ============================================================

local dataLoaded = false

local function loadSeenState()
    -- Retente jusqu'à 5s pour que DataManager finisse de charger
    for _ = 1, 10 do
        local ok, data = pcall(function() return fnGetPlayerData:InvokeServer() end)
        if ok and data and data.tooltipsShown then
            for key, value in pairs(data.tooltipsShown) do
                seen[key] = value
            end
            dataLoaded = true
            return
        end
        task.wait(0.5)
    end
    -- Si toujours pas de données → on laisse les flags à true (sécurité : n'affiche rien)
    warn("[TooltipController] Impossible de charger tooltipsShown")
end

-- ============================================================
-- TRIGGERS ÉVÉNEMENTS
-- ============================================================

-- E10-S2 : But du jeu → premier spawn en manche
local goalTriggered = false

reRoundState.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then return end
    local state = payload.state

    currentState = state

    if state == "ACTIVE" and not goalTriggered then
        goalTriggered = true
        task.delay(1.5, function()  -- laisse le temps de charger le spawn
            queueTooltip(TOOLTIPS.goal.title, TOOLTIPS.goal.body, TOOLTIPS.goal.duration, TOOLTIPS.goal.key)
        end)
    end

    -- E10-S6 : premier retour lobby après au moins une manche
    if state == "RESULTS" then
        hasPlayedOneRound = true
    end
    if state == "LOBBY" and hasPlayedOneRound then
        task.delay(1, function()
            queueTooltip(TOOLTIPS.challenge.title, TOOLTIPS.challenge.body, TOOLTIPS.challenge.duration, TOOLTIPS.challenge.key)
        end)
    end
end)

-- E10-S4 : +1 Traître expliqué → premier kill
reShowKarmaNotif.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then return end
    if payload.karmaType == "traitor" then
        task.delay(2.5, function()  -- laisse la notif "+1 Traître" s'afficher d'abord
            queueTooltip(TOOLTIPS.karma.title, TOOLTIPS.karma.body, TOOLTIPS.karma.duration, TOOLTIPS.karma.key)
        end)
    end
end)

-- ============================================================
-- DÉTECTION DE PROXIMITÉ (E10-S3, E10-S5)
-- Vérifie toutes les 0.5s si le joueur est près d'un bouton
-- ============================================================

local PROXIMITY_CHECK_INTERVAL = 0.5
local lastProximityCheck = 0

RunService.Heartbeat:Connect(function()
    -- Ne vérifie qu'en ACTIVE et si les données sont chargées
    if currentState ~= "ACTIVE" then return end
    if not dataLoaded then return end

    local now = os.clock()
    if now - lastProximityCheck < PROXIMITY_CHECK_INTERVAL then return end
    lastProximityCheck = now

    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local pos = root.Position

    -- E10-S3 : proximité TrapButton
    if not seen["trapTooltip"] then
        for _, btn in ipairs(CollectionService:GetTagged("TrapButton")) do
            if not btn:GetAttribute("Used") then
                local dist = (btn.Position - pos).Magnitude
                if dist <= 5 then
                    queueTooltip(TOOLTIPS.trap.title, TOOLTIPS.trap.body, TOOLTIPS.trap.duration, TOOLTIPS.trap.key)
                    break
                end
            end
        end
    end

    -- E10-S5 : proximité SacrificeButton
    if not seen["sacrificeTooltip"] then
        for _, btn in ipairs(CollectionService:GetTagged("SacrificeButton")) do
            if not btn:GetAttribute("Used") then
                local dist = (btn.Position - pos).Magnitude
                if dist <= 5 then
                    queueTooltip(TOOLTIPS.sacrifice.title, TOOLTIPS.sacrifice.body, TOOLTIPS.sacrifice.duration, TOOLTIPS.sacrifice.key)
                    break
                end
            end
        end
    end
end)

-- ============================================================
-- INIT
-- ============================================================

-- Charge l'état des tooltips depuis le serveur (asynchrone)
task.spawn(loadSeenState)

print("[TooltipController] ✅ Prêt")
