-- UIController.client.lua — Interface utilisateur complète
-- Couvre E6-S1 (Timer), S2 (Position), S3 (Titre Karma), S4 (Notifs Karma),
-- S5 (Résultats), S6 (Lobby UI), S7 (Salle d'attente),
-- S8 (Profil Karma), S9 (Défis - stub), S10 (Message sacrifice)

local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

local Events          = game.ReplicatedStorage:WaitForChild("Events")
local reRoundState    = Events:WaitForChild("RoundStateChanged")
local reUpdatePos     = Events:WaitForChild("UpdatePosition")
local reUpdateKarma   = Events:WaitForChild("UpdateKarma")
local reShowNotif     = Events:WaitForChild("ShowKarmaNotification")
local reSacrifice        = Events:WaitForChild("SacrificeActivated")
local reUpdateChallenges = Events:WaitForChild("UpdateChallenges")
local fnGetPlayerData    = Events:WaitForChild("GetPlayerData")
local fnGetChallenges    = Events:WaitForChild("GetChallenges")

local hudGui   = playerGui:WaitForChild("HUD")
local menuGui  = playerGui:WaitForChild("Menus")
local notifGui = playerGui:WaitForChild("Notifications")

-- ============================================================
-- ÉTAT LOCAL
-- ============================================================

local currentState      = "LOBBY"
local currentKarma      = { traitor = 0, martyr = 0 }
local karmaAtRoundStart = { traitor = 0, martyr = 0 }

local notifQueue  = {}
local notifBusy   = false

-- Seuils de titres (copie côté client pour les barres de progression)
local TRAITOR_TITLES = {
    { 150, "Traître Légendaire" }, { 75, "Grand Traître" },
    { 30,  "Traître Confirmé"  }, { 10, "Faux Ami"      }, { 0, "Novice" },
}
local MARTYR_TITLES = {
    { 150, "Martyr Légendaire" }, { 75, "Grand Martyr" },
    { 30,  "Martyr Confirmé"  }, { 10, "Âme Pure"     }, { 0, "Novice" },
}
local THRESHOLDS = { 0, 10, 30, 75, 150 }

-- Cache des éléments UI créés dynamiquement
local ui      = {}
local screens = {}   -- [name] = Frame

-- Forward declarations (fonctions qui se référencent mutuellement)
local refreshProfileScreen
local refreshChallengesScreen

-- ============================================================
-- HELPERS
-- ============================================================

local function make(className, parent, props)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do inst[k] = v end
    inst.Parent = parent
    return inst
end

local function ordinal(n)
    return n == 1 and "1er" or (n .. "ème")
end

local function formatTime(s)
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function getTitle(list, score)
    for _, entry in ipairs(list) do
        if score >= entry[1] then return entry[2] end
    end
    return "Novice"
end

-- Progression (0–1) vers le prochain seuil de titre
local function titleProgress(score)
    for i = #THRESHOLDS, 1, -1 do
        if score >= THRESHOLDS[i] then
            local next = THRESHOLDS[i + 1]
            if not next then return 1 end
            return math.clamp((score - THRESHOLDS[i]) / (next - THRESHOLDS[i]), 0, 1)
        end
    end
    return 0
end

-- Affiche / cache tous les écrans du menuGui
local function showScreen(name)
    for n, frame in pairs(screens) do
        frame.Visible = (n == name)
    end
end

local function hideAllScreens()
    for _, frame in pairs(screens) do
        frame.Visible = false
    end
end

-- Crée un Frame d'écran de base (plein écran) avec titre
local function makeScreen(name, titleText, bg)
    local frame = make("Frame", menuGui, {
        Name                   = name,
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundColor3       = bg or Color3.fromRGB(12, 12, 22),
        BackgroundTransparency = 0.08,
        BorderSizePixel        = 0,
        Visible                = false,
    })
    if titleText then
        make("TextLabel", frame, {
            Name                   = "Title",
            Size                   = UDim2.new(1, 0, 0, 68),
            BackgroundTransparency = 1,
            Text                   = titleText,
            TextColor3             = Color3.fromRGB(255, 215, 0),
            Font                   = Enum.Font.GothamBold,
            TextScaled             = true,
        })
    end
    screens[name] = frame
    return frame
end

-- Crée un bouton stylé
local function makeBtn(parent, text, color, size, pos)
    local btn = make("TextButton", parent, {
        Size             = size or UDim2.new(0, 240, 0, 52),
        Position         = pos  or UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = color,
        BorderSizePixel  = 0,
        Text             = text,
        TextColor3       = Color3.fromRGB(255, 255, 255),
        Font             = Enum.Font.GothamBold,
        TextScaled       = true,
    })
    make("UICorner", btn, { CornerRadius = UDim.new(0, 10) })
    return btn
end

-- ============================================================
-- HUD (E6-S1, S2, S3)
-- ============================================================

local function buildHUD()
    -- Timer — haut centre (E6-S1)
    local timerBg = make("Frame", hudGui, {
        Size                   = UDim2.new(0, 160, 0, 50),
        Position               = UDim2.new(0.5, -80, 0, 10),
        BackgroundColor3       = Color3.fromRGB(15, 15, 25),
        BackgroundTransparency = 0.35,
        BorderSizePixel        = 0,
        Visible                = false,
    })
    make("UICorner", timerBg, { CornerRadius = UDim.new(0, 8) })
    ui.timerLabel = make("TextLabel", timerBg, {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = "5:00", TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold, TextScaled = true,
    })
    ui.timerFrame = timerBg

    -- Position — haut gauche (E6-S2)
    local posBg = make("Frame", hudGui, {
        Size                   = UDim2.new(0, 145, 0, 44),
        Position               = UDim2.new(0, 10, 0, 10),
        BackgroundColor3       = Color3.fromRGB(15, 15, 25),
        BackgroundTransparency = 0.35,
        BorderSizePixel        = 0,
        Visible                = false,
    })
    make("UICorner", posBg, { CornerRadius = UDim.new(0, 8) })
    ui.positionLabel = make("TextLabel", posBg, {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = "— / —", TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.Gotham, TextScaled = true,
    })
    ui.positionFrame = posBg

    -- Titre Karma — haut droite (E6-S3)
    local karmaBg = make("Frame", hudGui, {
        Size                   = UDim2.new(0, 190, 0, 44),
        Position               = UDim2.new(1, -200, 0, 10),
        BackgroundColor3       = Color3.fromRGB(15, 15, 25),
        BackgroundTransparency = 0.35,
        BorderSizePixel        = 0,
        Visible                = false,
    })
    make("UICorner", karmaBg, { CornerRadius = UDim.new(0, 8) })
    ui.karmaTitleLabel = make("TextLabel", karmaBg, {
        Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 5, 0, 0),
        BackgroundTransparency = 1,
        Text = "Novice", TextColor3 = Color3.fromRGB(200, 200, 200),
        Font = Enum.Font.GothamBold, TextScaled = true,
    })
    ui.karmaFrame = karmaBg
end

local function showHUD(show)
    ui.timerFrame.Visible    = show
    ui.positionFrame.Visible = show
    ui.karmaFrame.Visible    = show
end

local function updateTimer(seconds)
    ui.timerLabel.Text = formatTime(seconds)
    ui.timerLabel.TextColor3 = seconds <= 30
        and Color3.fromRGB(255, 60, 60)
        or  Color3.fromRGB(255, 255, 255)
end

-- ============================================================
-- LOBBY SCREEN (E6-S6)
-- ============================================================

local function buildLobbyScreen()
    -- Frame transparent : le monde 3D reste entièrement visible
    local frame = make("Frame", menuGui, {
        Name                   = "Lobby",
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Visible                = false,
    })
    screens["Lobby"] = frame

    -- Boutons flottants sur la gauche — aucun fond
    local btnList = make("Frame", frame, {
        Size                   = UDim2.new(0, 220, 0, 280),
        Position               = UDim2.new(0, 10, 0.5, -140),
        BackgroundTransparency = 1,
    })
    make("UIListLayout", btnList, {
        FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 12),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    })

    -- Référence dummy (lobbyStatus utilisé ailleurs dans le code)
    ui.lobbyStatus = make("TextLabel", frame, {
        Size = UDim2.new(0, 1, 0, 1), BackgroundTransparency = 1,
        Text = "", Visible = false,
    })

    local btnDefs = {
        { "PROFIL KARMA",     Color3.fromRGB(70, 100, 190), "Profile"    },
        { "DÉFIS QUOTIDIENS", Color3.fromRGB(60, 150, 80),  "Challenges" },
        { "🛒 BOUTIQUE",      Color3.fromRGB(190, 130, 20), "Shop"       },
        { "⚙ PARAMÈTRES",    Color3.fromRGB(70, 70, 90),   "Settings"   },
    }

    for _, def in ipairs(btnDefs) do
        local btn = makeBtn(btnList, def[1], def[2], UDim2.new(1, 0, 0, 58))
        local targetName = def[3]
        btn.MouseButton1Click:Connect(function()
            if targetName == "Profile" then
                local data = fnGetPlayerData:InvokeServer()
                refreshProfileScreen(data)
            elseif targetName == "Challenges" then
                refreshChallengesScreen()
            end
            showScreen(targetName)
        end)
    end
end

-- ============================================================
-- WAITING SCREEN (E6-S7)
-- ============================================================

local function buildWaitingScreen()
    -- Bandeau compact non-intrusif en haut au centre (affiché pendant WAITING)
    -- Le lobby reste entièrement visible et interactif derrière
    local banner = make("Frame", hudGui, {
        Name                   = "WaitingBanner",
        Size                   = UDim2.new(0, 260, 0, 46),
        Position               = UDim2.new(0.5, -130, 0, 10),
        BackgroundColor3       = Color3.fromRGB(15, 15, 25),
        BackgroundTransparency = 0.35,
        BorderSizePixel        = 0,
        Visible                = false,
    })
    make("UICorner", banner, { CornerRadius = UDim.new(0, 8) })
    ui.waitingBanner = banner

    ui.waitingCountdown = make("TextLabel", banner, {
        Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 5, 0, 0),
        BackgroundTransparency = 1,
        Text = "Manche dans 30s",
        TextColor3 = Color3.fromRGB(255, 215, 0),
        Font = Enum.Font.GothamBold, TextScaled = true,
    })
end

-- ============================================================
-- RESULTS SCREEN (E6-S5)
-- ============================================================

local function buildResultsScreen()
    local frame = makeScreen("Results", nil, Color3.fromRGB(8, 8, 18))

    -- Titre dynamique (affiche le numéro de manche)
    ui.resultsTitle = make("TextLabel", frame, {
        Size = UDim2.new(1, 0, 0, 52), Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1, Text = "RÉSULTATS",
        TextColor3 = Color3.fromRGB(255, 215, 0), Font = Enum.Font.GothamBold, TextScaled = true,
    })

    -- Bandeau QUALIFIÉ / ÉLIMINÉ (pour le joueur local)
    ui.resultsStatus = make("Frame", frame, {
        Size = UDim2.new(0.9, 0, 0, 44), Position = UDim2.new(0.05, 0, 0, 56),
        BackgroundColor3 = Color3.fromRGB(20, 20, 30), BorderSizePixel = 0,
        BackgroundTransparency = 0.2,
    })
    make("UICorner", ui.resultsStatus, { CornerRadius = UDim.new(0, 10) })
    ui.resultsStatusLabel = make("TextLabel", ui.resultsStatus, {
        Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1, Text = "",
        TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextScaled = true,
    })

    ui.resultsKarmaGain = make("TextLabel", frame, {
        Size = UDim2.new(0.9, 0, 0, 30), Position = UDim2.new(0.05, 0, 0, 106),
        BackgroundTransparency = 1, Text = "",
        TextColor3 = Color3.fromRGB(255, 215, 0), Font = Enum.Font.GothamBold, TextScaled = true,
    })

    ui.resultsScroll = make("ScrollingFrame", frame, {
        Size = UDim2.new(0.9, 0, 0.58, 0), Position = UDim2.new(0.05, 0, 0, 142),
        BackgroundColor3 = Color3.fromRGB(18, 18, 30), BackgroundTransparency = 0.3,
        BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 0),
    })
    make("UIListLayout", ui.resultsScroll, { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 3) })
    make("UIPadding", ui.resultsScroll, { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) })

    make("TextLabel", frame, {
        Size = UDim2.new(0.9, 0, 0, 28), Position = UDim2.new(0.05, 0, 1, -36),
        BackgroundTransparency = 1, Text = "Retour au lobby dans quelques secondes...",
        TextColor3 = Color3.fromRGB(120, 120, 130), Font = Enum.Font.Gotham, TextScaled = true,
    })
end

local function fillResultsScreen(data)
    local rankings = data.rankings or {}
    local roundNum = data.round    or 0

    -- Titre avec numéro et type de manche
    local label = data.label
    ui.resultsTitle.Text = roundNum > 0
        and (label and string.format("MANCHE %d — %s", roundNum, string.upper(label))
                    or string.format("MANCHE %d — RÉSULTATS", roundNum))
        or  "RÉSULTATS"

    -- Bandeau statut local (QUALIFIÉ / ÉLIMINÉ)
    local myStatus = nil
    for _, entry in ipairs(rankings) do
        if entry.name == localPlayer.Name then myStatus = entry.qualified break end
    end
    if myStatus == true then
        ui.resultsStatus.BackgroundColor3    = Color3.fromRGB(20, 90, 30)
        ui.resultsStatusLabel.Text           = "✅  QUALIFIÉ — tu passes à la manche suivante !"
        ui.resultsStatusLabel.TextColor3     = Color3.fromRGB(130, 255, 130)
    elseif myStatus == false then
        ui.resultsStatus.BackgroundColor3    = Color3.fromRGB(90, 20, 20)
        ui.resultsStatusLabel.Text           = "❌  ÉLIMINÉ — meilleure chance au prochain tournoi !"
        ui.resultsStatusLabel.TextColor3     = Color3.fromRGB(255, 120, 120)
    else
        ui.resultsStatus.BackgroundColor3    = Color3.fromRGB(20, 20, 30)
        ui.resultsStatusLabel.Text           = ""
    end

    -- Vider les anciennes lignes
    for _, c in ipairs(ui.resultsScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end

    -- Remplir le classement
    local medals = { "🥇", "🥈", "🥉" }
    for _, entry in ipairs(rankings) do
        local medal     = medals[entry.rank] or (tostring(entry.rank) .. ".")
        local isMe      = (entry.name == localPlayer.Name)
        local qualified = entry.qualified

        local row = make("Frame", ui.resultsScroll, {
            Size             = UDim2.new(1, -10, 0, 42),
            BackgroundColor3 = isMe and Color3.fromRGB(55, 55, 90) or Color3.fromRGB(25, 25, 40),
            BackgroundTransparency = isMe and 0.3 or 0.65,
            BorderSizePixel  = 0,
        })
        if isMe then make("UICorner", row, { CornerRadius = UDim.new(0, 6) }) end

        -- Nom + médaille
        make("TextLabel", row, {
            Size = UDim2.new(0.65, 0, 1, 0), Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = string.format("%s  %s", medal, entry.name),
            TextColor3 = isMe and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(215, 215, 215),
            Font = isMe and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
        })

        -- Badge QUALIFIÉ / ÉLIMINÉ
        if qualified ~= nil then
            local badge = make("TextLabel", row, {
                Size             = UDim2.new(0.33, 0, 0.68, 0),
                Position         = UDim2.new(0.66, 0, 0.16, 0),
                BackgroundColor3 = qualified
                    and Color3.fromRGB(25, 110, 35)
                    or  Color3.fromRGB(110, 25, 25),
                BackgroundTransparency = 0.15,
                BorderSizePixel  = 0,
                Text             = qualified and "✅ QUALIFIÉ" or "❌ ÉLIMINÉ",
                TextColor3       = Color3.fromRGB(255, 255, 255),
                Font             = Enum.Font.GothamBold,
                TextScaled       = true,
            })
            make("UICorner", badge, { CornerRadius = UDim.new(0, 5) })
        end
    end

    ui.resultsScroll.CanvasSize = UDim2.new(0, 0, 0, #rankings * 45)

    -- Karma gagné cette manche
    local gT = currentKarma.traitor - karmaAtRoundStart.traitor
    local gM = currentKarma.martyr  - karmaAtRoundStart.martyr
    local parts = {}
    if gT > 0 then table.insert(parts, string.format("+%d Traître 🗡", gT)) end
    if gM > 0 then table.insert(parts, string.format("+%d Martyr ✨",  gM)) end
    if #parts > 0 then
        ui.resultsKarmaGain.Text       = "Karma : " .. table.concat(parts, "   ")
        ui.resultsKarmaGain.TextColor3 = Color3.fromRGB(255, 215, 0)
    else
        ui.resultsKarmaGain.Text       = "Aucun Karma cette manche"
        ui.resultsKarmaGain.TextColor3 = Color3.fromRGB(130, 130, 130)
    end
end

-- ============================================================
-- PROFILE SCREEN (E6-S8)
-- ============================================================

local function buildProfileScreen()
    local frame = makeScreen("Profile", "MON PROFIL KARMA", Color3.fromRGB(8, 8, 18))

    local content = make("Frame", frame, {
        Size = UDim2.new(0.8, 0, 0.72, 0), Position = UDim2.new(0.1, 0, 0.12, 0),
        BackgroundTransparency = 1,
    })

    -- Section Traître
    ui.profileTraitorLabel = make("TextLabel", content, {
        Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "🗡 Traître — 0 pts (Novice)",
        TextColor3 = Color3.fromRGB(255, 90, 90), Font = Enum.Font.GothamBold,
        TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local tBg = make("Frame", content, {
        Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, 38),
        BackgroundColor3 = Color3.fromRGB(50, 18, 18), BorderSizePixel = 0,
    })
    make("UICorner", tBg, { CornerRadius = UDim.new(0, 6) })
    ui.profileTraitorBar = make("Frame", tBg, {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(220, 55, 55),
        BorderSizePixel = 0,
    })
    make("UICorner", ui.profileTraitorBar, { CornerRadius = UDim.new(0, 6) })

    -- Section Martyr
    ui.profileMartyrLabel = make("TextLabel", content, {
        Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 68),
        BackgroundTransparency = 1,
        Text = "✨ Martyr — 0 pts (Novice)",
        TextColor3 = Color3.fromRGB(255, 215, 0), Font = Enum.Font.GothamBold,
        TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local mBg = make("Frame", content, {
        Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, 106),
        BackgroundColor3 = Color3.fromRGB(45, 38, 8), BorderSizePixel = 0,
    })
    make("UICorner", mBg, { CornerRadius = UDim.new(0, 6) })
    ui.profileMartyrBar = make("Frame", mBg, {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 195, 30),
        BorderSizePixel = 0,
    })
    make("UICorner", ui.profileMartyrBar, { CornerRadius = UDim.new(0, 6) })

    -- Stats
    ui.profileStats = make("TextLabel", content, {
        Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 138),
        BackgroundTransparency = 1,
        Text = "Manches jouées : 0   |   Victoires : 0",
        TextColor3 = Color3.fromRGB(170, 170, 170), Font = Enum.Font.Gotham, TextScaled = true,
    })

    local closeBtn = makeBtn(frame, "FERMER", Color3.fromRGB(70, 70, 95),
        UDim2.new(0, 140, 0, 44), UDim2.new(0.5, -70, 1, -58))
    closeBtn.MouseButton1Click:Connect(function() showScreen("Lobby") end)
end

-- Assignation de la fonction forward-déclarée
refreshProfileScreen = function(data)
    if not data then return end
    local tScore = (data.karma and data.karma.traitor) or 0
    local mScore = (data.karma and data.karma.martyr)  or 0
    local tTitle = getTitle(TRAITOR_TITLES, tScore)
    local mTitle = getTitle(MARTYR_TITLES,  mScore)

    ui.profileTraitorLabel.Text = string.format("🗡 Traître — %d pts (%s)", tScore, tTitle)
    ui.profileMartyrLabel.Text  = string.format("✨ Martyr — %d pts (%s)",  mScore, mTitle)

    TweenService:Create(ui.profileTraitorBar,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad),
        { Size = UDim2.new(titleProgress(tScore), 0, 1, 0) }
    ):Play()
    TweenService:Create(ui.profileMartyrBar,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad),
        { Size = UDim2.new(titleProgress(mScore), 0, 1, 0) }
    ):Play()

    if data.stats then
        ui.profileStats.Text = string.format("Manches jouées : %d   |   Victoires : %d",
            data.stats.roundsPlayed or 0, data.stats.roundsWon or 0)
    end
end

-- ============================================================
-- CHALLENGES SCREEN (E6-S9 — reçoit données de ChallengeManager E7)
-- ============================================================

local function buildChallengesScreen()
    local frame = makeScreen("Challenges", "DÉFIS QUOTIDIENS", Color3.fromRGB(8, 14, 8))

    ui.challengesList = make("ScrollingFrame", frame, {
        Size = UDim2.new(0.88, 0, 0.72, 0), Position = UDim2.new(0.06, 0, 0.12, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 0),
    })
    make("UIListLayout", ui.challengesList, {
        FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10),
    })

    ui.challengesEmpty = make("TextLabel", frame, {
        Size = UDim2.new(0.8, 0, 0, 44), Position = UDim2.new(0.1, 0, 0.44, 0),
        BackgroundTransparency = 1, Text = "Chargement des défis...",
        TextColor3 = Color3.fromRGB(130, 130, 130), Font = Enum.Font.Gotham, TextScaled = true,
    })

    local closeBtn = makeBtn(frame, "FERMER", Color3.fromRGB(60, 90, 60),
        UDim2.new(0, 140, 0, 44), UDim2.new(0.5, -70, 1, -58))
    closeBtn.MouseButton1Click:Connect(function() showScreen("Lobby") end)
end

-- Assignation de la fonction forward-déclarée
refreshChallengesScreen = function()
    for _, c in ipairs(ui.challengesList:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end

    local ok, challenges = pcall(function() return fnGetChallenges:InvokeServer() end)
    if not ok or not challenges or #challenges == 0 then
        ui.challengesEmpty.Text    = "Aucun défi disponible (reviens demain !)"
        ui.challengesEmpty.Visible = true
        ui.challengesList.CanvasSize = UDim2.new(0, 0, 0, 0)
        return
    end

    ui.challengesEmpty.Visible = false
    local cardColors = {
        kill = Color3.fromRGB(100, 30, 30), sacrifice = Color3.fromRGB(90, 75, 10),
        win  = Color3.fromRGB(30, 80, 30),  default   = Color3.fromRGB(40, 40, 60),
    }

    for _, c in ipairs(challenges) do
        local card = make("Frame", ui.challengesList, {
            Size = UDim2.new(1, 0, 0, 88),
            BackgroundColor3 = cardColors[c.type] or cardColors.default,
            BackgroundTransparency = 0.35, BorderSizePixel = 0,
        })
        make("UICorner", card, { CornerRadius = UDim.new(0, 8) })

        make("TextLabel", card, {
            Size = UDim2.new(0.72, -10, 0.5, 0), Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1, Text = c.description or c.id,
            TextColor3 = Color3.fromRGB(240, 240, 240), Font = Enum.Font.GothamBold,
            TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
        })

        local progress = math.clamp((c.progress or 0) / math.max(c.goal or 1, 1), 0, 1)
        local barBg = make("Frame", card, {
            Size = UDim2.new(0.88, 0, 0, 14), Position = UDim2.new(0.06, 0, 0.68, 0),
            BackgroundColor3 = Color3.fromRGB(25, 25, 25), BorderSizePixel = 0,
        })
        make("UICorner", barBg, { CornerRadius = UDim.new(0, 4) })
        local barFill = make("Frame", barBg, {
            Size = UDim2.new(progress, 0, 1, 0),
            BackgroundColor3 = progress >= 1 and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(60, 180, 60),
            BorderSizePixel = 0,
        })
        make("UICorner", barFill, { CornerRadius = UDim.new(0, 4) })

        make("TextLabel", card, {
            Size = UDim2.new(0.28, -10, 0.5, 0), Position = UDim2.new(0.72, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = string.format("%d / %d", c.progress or 0, c.goal or 1),
            TextColor3 = Color3.fromRGB(190, 190, 190), Font = Enum.Font.Gotham,
            TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right,
        })

        if c.reward then
            make("TextLabel", card, {
                Size = UDim2.new(0.5, 0, 0, 18), Position = UDim2.new(0.5, 0, 0, 4),
                BackgroundTransparency = 1,
                Text = "Récompense : +" .. tostring(c.reward) .. " Karma",
                TextColor3 = Color3.fromRGB(255, 200, 50), Font = Enum.Font.Gotham,
                TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right,
            })
        end
    end

    ui.challengesList.CanvasSize = UDim2.new(0, 0, 0, #challenges * 98)
end

-- ============================================================
-- SHOP SCREEN (E8-S6) — Boutique in-game
-- ============================================================
-- ⚠ Les IDs ci-dessous doivent correspondre à ceux de GameConfig.
--   Remplace les 0 par tes vrais IDs Roblox avant de publier.
local SHOP_PASS_IDS = { 0, 0, 0 }        -- Karma, Death Effects, Radio
local SHOP_PRODUCT_IDS = { 0, 0 }        -- Skip Checkpoint, Bouclier

local SHOP_PASSES = {
    { name = "Karma Pass",        price = "299 R$", desc = "×2 sur tous tes points Karma",             id = SHOP_PASS_IDS[1] },
    { name = "Effets de Mort",    price = "149 R$", desc = "Animations de mort exclusives",             id = SHOP_PASS_IDS[2] },
    { name = "Radio / Boombox",   price = "249 R$", desc = "Joue ta musique dans le lobby",             id = SHOP_PASS_IDS[3] },
}
local SHOP_PRODUCTS = {
    { name = "Skip Checkpoint",   price = "50 R$",  desc = "Téléporte-toi au prochain checkpoint",     id = SHOP_PRODUCT_IDS[1] },
    { name = "Bouclier Défensif", price = "25 R$",  desc = "Invincible pendant 10 secondes",           id = SHOP_PRODUCT_IDS[2] },
}

local function buildShopScreen()
    local frame = makeScreen("Shop", "🛒 BOUTIQUE", Color3.fromRGB(10, 10, 16))

    -- Section Game Passes
    make("TextLabel", frame, {
        Size = UDim2.new(0.88, 0, 0, 28), Position = UDim2.new(0.06, 0, 0, 76),
        BackgroundTransparency = 1, Text = "— GAME PASSES (achats permanents) —",
        TextColor3 = Color3.fromRGB(255, 215, 0), Font = Enum.Font.GothamBold, TextScaled = true,
    })

    for i, item in ipairs(SHOP_PASSES) do
        local yOff = 108 + (i - 1) * 70
        local card = make("Frame", frame, {
            Size = UDim2.new(0.88, 0, 0, 60), Position = UDim2.new(0.06, 0, 0, yOff),
            BackgroundColor3 = Color3.fromRGB(30, 28, 12), BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
        })
        make("UICorner", card, { CornerRadius = UDim.new(0, 8) })
        make("TextLabel", card, {
            Size = UDim2.new(0.55, 0, 0.55, 0), Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1, Text = item.name,
            TextColor3 = Color3.fromRGB(255, 215, 0), Font = Enum.Font.GothamBold,
            TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
        })
        make("TextLabel", card, {
            Size = UDim2.new(0.55, 0, 0.42, 0), Position = UDim2.new(0, 10, 0.55, 0),
            BackgroundTransparency = 1, Text = item.desc,
            TextColor3 = Color3.fromRGB(170, 170, 170), Font = Enum.Font.Gotham,
            TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
        })
        local btn = makeBtn(card, item.price, Color3.fromRGB(180, 130, 0),
            UDim2.new(0, 110, 0, 40), UDim2.new(1, -120, 0.5, -20))
        local passId = item.id
        btn.MouseButton1Click:Connect(function()
            if passId ~= 0 then
                MarketplaceService:PromptGamePassPurchase(localPlayer, passId)
            end
        end)
    end

    -- Section Dev Products
    make("TextLabel", frame, {
        Size = UDim2.new(0.88, 0, 0, 28), Position = UDim2.new(0.06, 0, 0, 330),
        BackgroundTransparency = 1, Text = "— PRODUITS (achats répétables) —",
        TextColor3 = Color3.fromRGB(180, 220, 255), Font = Enum.Font.GothamBold, TextScaled = true,
    })

    for i, item in ipairs(SHOP_PRODUCTS) do
        local yOff = 362 + (i - 1) * 70
        local card = make("Frame", frame, {
            Size = UDim2.new(0.88, 0, 0, 60), Position = UDim2.new(0.06, 0, 0, yOff),
            BackgroundColor3 = Color3.fromRGB(12, 22, 35), BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
        })
        make("UICorner", card, { CornerRadius = UDim.new(0, 8) })
        make("TextLabel", card, {
            Size = UDim2.new(0.55, 0, 0.55, 0), Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1, Text = item.name,
            TextColor3 = Color3.fromRGB(180, 220, 255), Font = Enum.Font.GothamBold,
            TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
        })
        make("TextLabel", card, {
            Size = UDim2.new(0.55, 0, 0.42, 0), Position = UDim2.new(0, 10, 0.55, 0),
            BackgroundTransparency = 1, Text = item.desc,
            TextColor3 = Color3.fromRGB(170, 170, 170), Font = Enum.Font.Gotham,
            TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
        })
        local btn = makeBtn(card, item.price, Color3.fromRGB(50, 110, 180),
            UDim2.new(0, 110, 0, 40), UDim2.new(1, -120, 0.5, -20))
        local productId = item.id
        btn.MouseButton1Click:Connect(function()
            if productId ~= 0 then
                MarketplaceService:PromptProductPurchase(localPlayer, productId)
            end
        end)
    end

    local closeBtn = makeBtn(frame, "FERMER", Color3.fromRGB(70, 70, 95),
        UDim2.new(0, 140, 0, 44), UDim2.new(0.5, -70, 1, -58))
    closeBtn.MouseButton1Click:Connect(function() showScreen("Lobby") end)
end

-- ============================================================
-- SETTINGS SCREEN (E6-S6 ⚙)
-- ============================================================

local function buildSettingsScreen()
    local frame = makeScreen("Settings", "⚙ PARAMÈTRES", Color3.fromRGB(10, 10, 16))

    make("TextLabel", frame, {
        Size = UDim2.new(0.7, 0, 0, 40), Position = UDim2.new(0.15, 0, 0.35, 0),
        BackgroundTransparency = 1, Text = "Paramètres disponibles dans une prochaine mise à jour.",
        TextColor3 = Color3.fromRGB(130, 130, 130), Font = Enum.Font.Gotham, TextScaled = true,
    })

    local closeBtn = makeBtn(frame, "FERMER", Color3.fromRGB(70, 70, 95),
        UDim2.new(0, 140, 0, 44), UDim2.new(0.5, -70, 1, -58))
    closeBtn.MouseButton1Click:Connect(function() showScreen("Lobby") end)
end

-- ============================================================
-- NOTIFICATIONS (E6-S4, E6-S10)
-- ============================================================

local function showQualifiedBanner(position)
    -- Grand banner vert centré "QUALIFIÉ !"
    local banner = make("Frame", notifGui, {
        Name                   = "QualifiedBanner",
        Size                   = UDim2.new(0, 420, 0, 90),
        Position               = UDim2.new(0.5, -210, 0.5, -45),
        BackgroundColor3       = Color3.fromRGB(20, 140, 40),
        BackgroundTransparency = 0.1,
        BorderSizePixel        = 0,
        ZIndex                 = 20,
    })
    make("UICorner", banner, { CornerRadius = UDim.new(0, 16) })

    make("TextLabel", banner, {
        Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "✅  QUALIFIÉ",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold, TextScaled = true,
        ZIndex = 21,
    })

    -- Apparition + disparition après 3s
    banner.BackgroundTransparency = 1
    TweenService:Create(banner,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0.1 }
    ):Play()

    task.delay(3, function()
        TweenService:Create(banner,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { BackgroundTransparency = 1 }
        ):Play()
        task.delay(0.5, function() banner:Destroy() end)
    end)
end

local function buildNotifications()
    -- Popup Karma +N (slide depuis le haut, E6-S4)
    ui.karmaNotif = make("Frame", notifGui, {
        Name = "KarmaNotif",
        Size = UDim2.new(0, 240, 0, 64),
        Position = UDim2.new(0.5, -120, 0, -80),  -- caché hors écran
        BackgroundColor3 = Color3.fromRGB(20, 20, 30),
        BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false,
    })
    make("UICorner", ui.karmaNotif, { CornerRadius = UDim.new(0, 12) })
    ui.karmaNotifLabel = make("TextLabel", ui.karmaNotif, {
        Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1, Text = "+1 Traître 🗡",
        TextColor3 = Color3.fromRGB(255, 80, 80), Font = Enum.Font.GothamBold,
        TextScaled = true,
    })

    -- Bandeau sacrifice (E6-S10)
    ui.sacrificeBanner = make("Frame", notifGui, {
        Name = "SacrificeBanner",
        Size = UDim2.new(0, 520, 0, 52),
        Position = UDim2.new(0.5, -260, 0, 72),
        BackgroundColor3 = Color3.fromRGB(120, 90, 5),
        BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false,
    })
    make("UICorner", ui.sacrificeBanner, { CornerRadius = UDim.new(0, 8) })
    ui.sacrificeBannerLabel = make("TextLabel", ui.sacrificeBanner, {
        Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1, Text = "✨ ... s'est sacrifié(e) !",
        TextColor3 = Color3.fromRGB(255, 230, 100), Font = Enum.Font.GothamBold, TextScaled = true,
    })
end

-- Affiche une notif Karma avec animation slide (file d'attente)
local function showKarmaNotif(karmaType, points, newTitle)
    local color = karmaType == "traitor"
        and Color3.fromRGB(255, 75, 75)
        or  Color3.fromRGB(255, 215, 0)
    local icon  = karmaType == "traitor" and "🗡" or "✨"
    local label = karmaType == "traitor" and "Traître" or "Martyr"
    local text  = string.format("+%d %s %s", points, label, icon)
    if newTitle then text = text .. "\n" .. newTitle .. " !" end

    table.insert(notifQueue, { color = color, text = text })
    if notifBusy then return end

    local function processNext()
        if #notifQueue == 0 then notifBusy = false; return end
        notifBusy = true
        local item = table.remove(notifQueue, 1)

        ui.karmaNotifLabel.Text       = item.text
        ui.karmaNotifLabel.TextColor3 = item.color
        ui.karmaNotif.Position        = UDim2.new(0.5, -120, 0, -80)
        ui.karmaNotif.Visible         = true

        -- Slide depuis le haut vers Y=10
        TweenService:Create(ui.karmaNotif,
            TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Position = UDim2.new(0.5, -120, 0, 10) }
        ):Play()

        task.delay(2.2, function()
            TweenService:Create(ui.karmaNotif,
                TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Position = UDim2.new(0.5, -120, 0, -80) }
            ):Play()
            task.delay(0.25, function()
                ui.karmaNotif.Visible = false
                task.delay(0.08, processNext)
            end)
        end)
    end

    processNext()
end

local function showSacrificeBanner(playerName)
    ui.sacrificeBannerLabel.Text = string.format("✨ %s s'est sacrifié(e) pour ouvrir le passage !", playerName)
    ui.sacrificeBanner.Visible = true
    task.delay(3.5, function() ui.sacrificeBanner.Visible = false end)
end

-- ============================================================
-- GESTIONNAIRE D'ÉTATS CENTRALISÉ
-- ============================================================

local function onStateChanged(payload)
    if type(payload) ~= "table" then return end
    local newState = payload.state
    local data     = payload.data or {}

    local prevState = currentState
    currentState    = newState

    if newState == "LOBBY" then
        showHUD(false)
        ui.waitingBanner.Visible = false
        showScreen("Lobby")

    elseif newState == "WAITING" then
        -- Transition initiale seulement : on ne ferme pas les menus ouverts à chaque tick
        if prevState ~= "WAITING" then
            showHUD(false)
            showScreen("Lobby")
            ui.waitingBanner.Visible = true
        end
        if data.countdown then
            local label = data.label and string.format(" — %s", data.label) or ""
            ui.waitingCountdown.Text = string.format("Manche %d%s  |  %ds",
                data.round or 1, label, data.countdown)
        end

    elseif newState == "ACTIVE" then
        -- Snapshot Karma au départ de la manche (pour calcul gain en fin)
        karmaAtRoundStart = { traitor = currentKarma.traitor, martyr = currentKarma.martyr }
        ui.waitingBanner.Visible = false
        hideAllScreens()
        showHUD(true)
        if data.duration then updateTimer(data.duration) end
        if data.timeLeft  then updateTimer(data.timeLeft)  end

    elseif newState == "QUALIFIED" then
        showQualifiedBanner(data.position or 1)
        return  -- ne change pas l'état courant

    elseif newState == "RESULTS" then
        showHUD(false)
        ui.waitingBanner.Visible = false
        if data.rankings then fillResultsScreen(data) end
        showScreen("Results")
    end

    if newState == "ACTIVE" and data.timeLeft ~= nil then
        updateTimer(data.timeLeft)
    end
end

-- ============================================================
-- CONNEXION AUX REMOTE EVENTS
-- ============================================================

reRoundState.OnClientEvent:Connect(onStateChanged)

reUpdatePos.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then return end
    if payload.position and payload.total then
        ui.positionLabel.Text = string.format("%s / %d", ordinal(payload.position), payload.total)
    end
end)

reUpdateKarma.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then return end
    currentKarma.traitor = payload.traitor or currentKarma.traitor
    currentKarma.martyr  = payload.martyr  or currentKarma.martyr

    -- Titre HUD = titre du style dominant (E6-S3)
    local title, color
    if currentKarma.traitor >= currentKarma.martyr then
        title = payload.traitorTitle or getTitle(TRAITOR_TITLES, currentKarma.traitor)
        color = Color3.fromRGB(255, 90, 90)
    else
        title = payload.martyrTitle  or getTitle(MARTYR_TITLES,  currentKarma.martyr)
        color = Color3.fromRGB(255, 215, 0)
    end
    ui.karmaTitleLabel.Text       = title
    ui.karmaTitleLabel.TextColor3 = color
end)

reShowNotif.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then return end
    showKarmaNotif(payload.karmaType, payload.points or 1, payload.title)
end)

reSacrifice.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then return end
    if currentState == "ACTIVE" then
        showSacrificeBanner(payload.playerName or "Un joueur")
    end
end)

-- Mise à jour liste en WAITING quand un joueur rejoint/quitte
-- Mise à jour en temps réel de l'écran des défis si ouvert (E7-S3)
reUpdateChallenges.OnClientEvent:Connect(function()
    if screens["Challenges"] and screens["Challenges"].Visible then
        refreshChallengesScreen()
    end
end)


-- ============================================================
-- INIT
-- ============================================================

buildHUD()
buildLobbyScreen()
buildWaitingScreen()
buildResultsScreen()
buildProfileScreen()
buildChallengesScreen()
buildShopScreen()
buildSettingsScreen()
buildNotifications()

showScreen("Lobby")

print("[UIController] ✅ Prêt")
