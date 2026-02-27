-- LeaderboardManager.server.lua — Classements Traître / Martyr
-- Couvre E5-S6 (OrderedDataStore) + E5-S7 (affichage lobby)
--
-- API publique (_G.LeaderboardManager) :
--   UpdateScore(player, karmaType, score)   → met à jour l'OrderedDataStore
--   GetTop10(karmaType)                     → retourne la table Top 10

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local GameConfig = require(game.ServerStorage.Config.GameConfig)

local dsTraitor = DataStoreService:GetOrderedDataStore(GameConfig.DataStore.LEADERBOARD_TRAITOR)
local dsMartyr  = DataStoreService:GetOrderedDataStore(GameConfig.DataStore.LEADERBOARD_MARTYR)

-- ============================================================
-- UTILITAIRES DATASTORE
-- ============================================================

local function getDS(karmaType)
    return karmaType == "traitor" and dsTraitor or dsMartyr
end

local function withRetry(action, label)
    for attempt = 1, GameConfig.DataStore.RETRY_COUNT do
        local ok, result = pcall(action)
        if ok then return result end
        warn(string.format("[LeaderboardManager] %s — tentative %d : %s", label, attempt, tostring(result)))
        if attempt < GameConfig.DataStore.RETRY_COUNT then
            task.wait(2 ^ (attempt - 1))
        end
    end
    return nil
end

-- ============================================================
-- API PUBLIQUE
-- ============================================================

local LeaderboardManager = {}
_G.LeaderboardManager = LeaderboardManager

-- Met à jour le score d'un joueur dans l'OrderedDataStore correspondant.
function LeaderboardManager.UpdateScore(player, karmaType, score)
    if score <= 0 then return end
    local ds  = getDS(karmaType)
    local key = tostring(player.UserId)
    withRetry(function()
        ds:SetAsync(key, score)
    end, string.format("UpdateScore %s %s", player.Name, karmaType))
end

-- Retourne une table des 10 premiers joueurs.
-- Chaque entrée : { rank, userId, name, score }
function LeaderboardManager.GetTop10(karmaType)
    local ds = getDS(karmaType)
    local pages = withRetry(function()
        return ds:GetSortedAsync(false, 10)  -- false = ordre décroissant
    end, "GetTop10 " .. karmaType)

    if not pages then return {} end

    local data = withRetry(function()
        return pages:GetCurrentPage()
    end, "GetTop10 page " .. karmaType)

    if not data then return {} end

    local results = {}
    for rank, entry in ipairs(data) do
        local userId = tonumber(entry.key)
        local name   = "Joueur"
        -- Tente de résoudre le nom (peut échouer si le joueur est hors ligne)
        local ok, n = pcall(function()
            return Players:GetNameFromUserIdAsync(userId)
        end)
        if ok then name = n end

        table.insert(results, {
            rank  = rank,
            userId = userId,
            name  = name,
            score = entry.value,
        })
    end

    return results
end

-- ============================================================
-- AFFICHAGE DANS LE LOBBY (E5-S7)
-- Panneaux taguée LeaderboardType="traitor" ou "martyr"
-- ============================================================

-- Met à jour le contenu textuel d'un panneau SurfaceGui
local function updatePanel(panel, karmaType, top10)
    -- Le panneau doit contenir un SurfaceGui > Frame > TextLabel
    local gui   = panel:FindFirstChildOfClass("SurfaceGui")
    if not gui then
        -- Crée le SurfaceGui à la volée si absent
        gui = Instance.new("SurfaceGui")
        gui.Face       = Enum.NormalId.Front
        gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        gui.PixelsPerStud = 50
        gui.Parent     = panel

        local frame = Instance.new("Frame")
        frame.Size            = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        frame.BorderSizePixel  = 0
        frame.Parent           = gui

        local title = Instance.new("TextLabel")
        title.Name            = "Title"
        title.Size            = UDim2.new(1, 0, 0.15, 0)
        title.Position        = UDim2.new(0, 0, 0, 0)
        title.BackgroundTransparency = 1
        title.TextColor3      = Color3.fromRGB(255, 215, 0)
        title.Font            = Enum.Font.GothamBold
        title.TextScaled      = true
        title.Parent          = frame

        local content = Instance.new("TextLabel")
        content.Name           = "Content"
        content.Size           = UDim2.new(1, 0, 0.85, 0)
        content.Position       = UDim2.new(0, 0, 0.15, 0)
        content.BackgroundTransparency = 1
        content.TextColor3     = Color3.fromRGB(230, 230, 230)
        content.Font           = Enum.Font.Gotham
        content.TextScaled     = true
        content.TextXAlignment = Enum.TextXAlignment.Left
        content.Parent         = frame
    end

    local frame = gui:FindFirstChildOfClass("Frame")
    if not frame then return end

    local titleLabel   = frame:FindFirstChild("Title")
    local contentLabel = frame:FindFirstChild("Content")
    if not titleLabel or not contentLabel then return end

    -- Titre du panneau
    if karmaType == "traitor" then
        titleLabel.Text = "🗡 TOP TRAÎTRES"
    else
        titleLabel.Text = "✨ TOP MARTYRS"
    end

    -- Contenu : liste numérotée
    if #top10 == 0 then
        contentLabel.Text = "Aucun classement encore."
        return
    end

    local lines = {}
    for _, entry in ipairs(top10) do
        local medal = entry.rank <= 3 and ({ "🥇", "🥈", "🥉" })[entry.rank] or (entry.rank .. ".")
        table.insert(lines, string.format("%s  %s — %d pts", medal, entry.name, entry.score))
    end
    contentLabel.Text = table.concat(lines, "\n")
end

-- Rafraîchit tous les panneaux du lobby
local function refreshPanels()
    local lobby = workspace:FindFirstChild("Lobby")
    if not lobby then return end

    local top10Traitor = LeaderboardManager.GetTop10("traitor")
    local top10Martyr  = LeaderboardManager.GetTop10("martyr")

    -- Cherche les parts ayant l'attribut LeaderboardType
    for _, obj in ipairs(lobby:GetDescendants()) do
        if obj:IsA("BasePart") then
            local lbType = obj:GetAttribute("LeaderboardType")
            if lbType == "traitor" then
                updatePanel(obj, "traitor", top10Traitor)
            elseif lbType == "martyr" then
                updatePanel(obj, "martyr", top10Martyr)
            end
        end
    end
end

-- ============================================================
-- BOUCLE DE REFRESH (toutes les 60s)
-- ============================================================

task.spawn(function()
    -- Attend que le Lobby soit présent dans le workspace
    local lobby = workspace:FindFirstChild("Lobby")
    if not lobby then
        lobby = workspace:WaitForChild("Lobby", 60)
    end
    if not lobby then
        warn("[LeaderboardManager] Lobby introuvable — panneaux désactivés")
        return
    end

    while true do
        local ok, err = pcall(refreshPanels)
        if not ok then
            warn("[LeaderboardManager] Erreur refresh : " .. tostring(err))
        end
        task.wait(GameConfig.DataStore.LEADERBOARD_REFRESH)
    end
end)

print("[LeaderboardManager] ✅ Prêt")
