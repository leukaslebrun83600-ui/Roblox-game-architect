-- RoundManager.server.lua — Tournoi Fall Guys style
-- Cycle : LOBBY → (WAITING → ACTIVE → RESULTS) × N manches → LOBBY
-- Chaque manche élimine les 50% les plus lents.
-- Le tournoi continue jusqu'à 1 seul survivant = champion.
--
-- API publique (_G.RoundManager) :
--   GetState()         → string état actuel
--   GetActivePlayers() → table des joueurs dans la manche en cours

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(game.ServerStorage.Config.GameConfig)

local Events             = game.ReplicatedStorage:WaitForChild("Events")
local reRoundState       = Events:WaitForChild("RoundStateChanged")
local reUpdatePosition   = Events:WaitForChild("UpdatePosition")

-- ============================================================
-- ÉTAT INTERNE
-- ============================================================

local state             = "LOBBY"
local roundActive       = false
local activePlayers     = {}   -- [player] = true  (dans la manche en cours)
local arrivalOrder      = {}   -- ordre d'arrivée à la fin du parcours

local tournamentPlayers = {}   -- [player] = true  (encore dans le tournoi)
local roundNumber       = 0    -- numéro de la manche dans le tournoi en cours

-- Z de départ par identifiant de course (doit correspondre aux constantes MapBuilder)
local COURSE_START_Z_BY_COURSE = { [1] = 200, [2] = 5000 }
-- Mapping manche → identifiant de course
local ROUND_COURSE = { [1] = 1, [2] = 2 }

local arrivalZByCourse = {}  -- [courseId] = Z minimum de l'ArrivalZone (calculé au démarrage)

-- ============================================================
-- API PUBLIQUE
-- ============================================================

local RoundManager = {}
_G.RoundManager = RoundManager

function RoundManager.GetState()
    return state
end

function RoundManager.GetActivePlayers()
    local list = {}
    for player in pairs(activePlayers) do
        table.insert(list, player)
    end
    return list
end

-- Retourne le nombre de qualifiés pour la manche en cours
local function getQualifyCount(totalPlayers)
    local rounds = GameConfig.Tournament.ROUNDS
    local def    = rounds[roundNumber] or rounds[#rounds]
    -- Ne jamais qualifier plus que le total (important en solo test)
    return math.min(def.qualify, math.max(totalPlayers - 1, 1))
end

-- Élimine immédiatement un joueur (appelé par CheckpointManager — tombé dans le vide)
function RoundManager.EliminatePlayer(player)
    if not roundActive then return end
    if not activePlayers[player] then return end

    activePlayers[player]     = nil
    tournamentPlayers[player] = nil

    -- Téléporte au lobby immédiatement
    local lobby       = workspace:FindFirstChild("Lobby")
    local spawnFolder = lobby and lobby:FindFirstChild("SpawnLocations")
    local spawnList   = spawnFolder and spawnFolder:GetChildren() or {}
    local char = player.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local sp = spawnList[math.random(1, math.max(#spawnList, 1))]
            root.CFrame = sp and (sp.CFrame + Vector3.new(0, 3, 0))
                             or CFrame.new(math.random(-20, 20), 12, math.random(-20, 20))
        end
    end

    print(string.format("[RoundManager] 💀 %s éliminé (tombé)", player.Name))

    -- Vérifier si le quota de qualifiés est déjà atteint ou plus personne sur le parcours
    local remaining = 0
    for _ in pairs(activePlayers) do remaining += 1 end
    if remaining == 0 then
        endRound(arrivalOrder[1])
    end
end

-- ============================================================
-- HELPERS — COURSE ACTIVE
-- ============================================================

local function getCourseId()
    -- Pour les manches au-delà de la table, utilise la dernière course définie
    return ROUND_COURSE[roundNumber] or ROUND_COURSE[#ROUND_COURSE] or 1
end

local function getCourseStartZ()
    return COURSE_START_Z_BY_COURSE[getCourseId()] or 200
end

local function getCourseName()
    local id = getCourseId()
    return id == 1 and "Course" or ("Course" .. id)
end

-- ============================================================
-- UTILITAIRES
-- ============================================================

local function setState(newState, data)
    state = newState
    reRoundState:FireAllClients({ state = newState, data = data or {} })
    print(string.format("[RoundManager] ▶ %s", newState))
end

local function getProgress(player)
    local char = player.Character
    if not char then return 0 end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return 0 end
    return math.max(0, root.Position.Z - getCourseStartZ())
end

local function buildRankings()
    local entries = {}
    for player in pairs(activePlayers) do
        table.insert(entries, {
            player   = player,
            name     = player.Name,
            progress = getProgress(player),
        })
    end
    table.sort(entries, function(a, b) return a.progress > b.progress end)
    return entries
end

-- ============================================================
-- SPAWN & TÉLÉPORTATION
-- ============================================================

local function findFirstPlatform()
    local course = workspace:FindFirstChild(getCourseName())
    if not course then return nil end
    local bestPlat, bestZ = nil, math.huge
    for _, sec in ipairs(course:GetChildren()) do
        local platFolder = sec:FindFirstChild("Plateformes")
        if platFolder then
            local platA = platFolder:FindFirstChild("Plat_A")
            if platA and platA.Position.Z < bestZ then
                bestZ    = platA.Position.Z
                bestPlat = platA
            end
        end
    end
    if bestPlat then
        local spawnPos = bestPlat.Position + Vector3.new(0, bestPlat.Size.Y / 2 + 3, 0)
        return CFrame.new(spawnPos, spawnPos + Vector3.new(0, 0, 1))
    end
    return nil
end

local function spawnAtStart()
    if _G.CheckpointManager then
        _G.CheckpointManager.ResetAll()
    end

    -- Remet les boutons à l'état initial
    local course = workspace:FindFirstChild(getCourseName())
    if course then
        for _, inst in ipairs(course:GetDescendants()) do
            if inst:IsA("BasePart") and inst:GetAttribute("Used") == true then
                local n = inst.Name
                inst:SetAttribute("Used", false)
                if n:sub(1, 11) == "TrapButton_" then
                    inst.Color = Color3.fromRGB(220, 50, 50)
                elseif n:sub(1, 16) == "SacrificeButton_" then
                    inst.Color = Color3.fromRGB(255, 215, 0)
                end
            end
        end
    end

    local baseCF = findFirstPlatform()
                or CFrame.new(
                    Vector3.new(0, 13, getCourseStartZ() + 8),
                    Vector3.new(0, 13, getCourseStartZ() + 9)
                )

    print(string.format("[RoundManager] Spawn départ : Z=%.1f Y=%.1f", baseCF.Position.Z, baseCF.Position.Y))

    -- Seulement les joueurs encore dans le tournoi
    local playerList = {}
    for p in pairs(tournamentPlayers) do
        if p.Parent then table.insert(playerList, p) end
    end

    activePlayers = {}
    for i, player in ipairs(playerList) do
        activePlayers[player] = true
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local col    = (i - 1) % 4
                local row    = math.floor((i - 1) / 4)
                local offset = Vector3.new(col * 5 - 7.5, 0, row * 4)
                root.CFrame  = baseCF + offset
            end
        end
    end
end

local function returnToLobby()
    local lobby     = workspace:FindFirstChild("Lobby")
    local spawns    = lobby and lobby:FindFirstChild("SpawnLocations")
    local spawnList = spawns and spawns:GetChildren() or {}

    for i, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local sp = spawnList[((i - 1) % math.max(#spawnList, 1)) + 1]
                if sp then
                    root.CFrame = sp.CFrame + Vector3.new(0, 3, 0)
                else
                    root.CFrame = CFrame.new(math.random(-20, 20), 12, math.random(-20, 20))
                end
            end
        end
    end

    activePlayers     = {}
    arrivalOrder      = {}
    tournamentPlayers = {}
end

-- ============================================================
-- ÉLIMINATION ENTRE MANCHES
-- ============================================================

-- Téléporte les joueurs éliminés (pas dans tournamentPlayers) au lobby
local function teleportEliminated()
    local lobby       = workspace:FindFirstChild("Lobby")
    local spawnFolder = lobby and lobby:FindFirstChild("SpawnLocations")
    local spawnList   = spawnFolder and spawnFolder:GetChildren() or {}
    local si = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if not tournamentPlayers[p] then
            local char = p.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    si += 1
                    local sp = spawnList[((si - 1) % math.max(#spawnList, 1)) + 1]
                    root.CFrame = sp and (sp.CFrame + Vector3.new(0, 3, 0))
                                     or CFrame.new(math.random(-20, 20), 12, math.random(-20, 20))
                end
            end
        end
    end
end

-- ============================================================
-- FIN DE MANCHE
-- ============================================================

local function endRound(winner)
    if not roundActive then return end
    roundActive = false

    -- Classement final
    local finalRankings = {}

    -- 1. Joueurs arrivés (ordre d'arrivée)
    for rank, player in ipairs(arrivalOrder) do
        table.insert(finalRankings, {
            name  = player.Name,
            rank  = rank,
            cause = "arrived",
        })
    end

    -- 2. Joueurs encore en course (classés par progression Z)
    local ranked = buildRankings()
    local offset = #finalRankings
    for i, entry in ipairs(ranked) do
        local alreadyArrived = false
        for _, arrived in ipairs(arrivalOrder) do
            if arrived == entry.player then alreadyArrived = true break end
        end
        if not alreadyArrived then
            table.insert(finalRankings, {
                name  = entry.name,
                rank  = offset + i,
                cause = winner and "in_progress" or "timer",
            })
        end
    end

    -- ── Qualification selon la structure du tournoi ──────────────
    local qualifyCount = math.min(
        (GameConfig.Tournament.ROUNDS[roundNumber] or GameConfig.Tournament.ROUNDS[#GameConfig.Tournament.ROUNDS]).qualify,
        math.max(#finalRankings - 1, 1)
    )

    for i, entry in ipairs(finalRankings) do
        entry.qualified = (i <= qualifyCount)
        if not entry.qualified then
            local p = Players:FindFirstChild(entry.name)
            if p then tournamentPlayers[p] = nil end
        end
    end

    local roundLabel = (GameConfig.Tournament.ROUNDS[roundNumber] or {}).label or "Manche"
    print(string.format("[RoundManager] %s — %d qualifiés / %d éliminés",
        roundLabel, qualifyCount, #finalRankings - qualifyCount))

    -- Stats + bonus
    for _, entry in ipairs(finalRankings) do
        local p = Players:FindFirstChild(entry.name)
        if p and _G.DataManager then
            local data = _G.DataManager.GetData(p)
            if data then
                data.stats.roundsPlayed += 1
                if entry.rank == 1 then
                    data.stats.roundsWon += 1
                    if _G.KarmaManager then _G.KarmaManager.AwardVictoryBonus(p) end
                    if _G.ChallengeManager then _G.ChallengeManager.UpdateProgress(p, "win", 1) end
                end
            end
        end
        if _G.BadgeManager then
            local bp = Players:FindFirstChild(entry.name)
            task.spawn(function() _G.BadgeManager.CheckBadges(bp) end)
        end
    end

    setState("RESULTS", {
        rankings  = finalRankings,
        round     = roundNumber,
        qualified = qualifyCount,
        label     = roundLabel,
    })
end

-- ============================================================
-- DÉTECTION DE L'ARRIVÉE
-- ============================================================

-- arrivalZByCourse est déclaré en haut avec les autres variables d'état

-- Logique commune : enregistre l'arrivée d'un joueur
local function processArrival(player, zoneId)
    if not roundActive then return end
    if not activePlayers[player] then return end
    if (zoneId or 1) ~= getCourseId() then return end  -- mauvaise course, ignoré
    for _, arrived in ipairs(arrivalOrder) do
        if arrived == player then return end  -- déjà compté
    end

    table.insert(arrivalOrder, player)
    activePlayers[player] = nil

    -- Téléporte immédiatement au lobby
    local lobby       = workspace:FindFirstChild("Lobby")
    local spawnFolder = lobby and lobby:FindFirstChild("SpawnLocations")
    local spawnList   = spawnFolder and spawnFolder:GetChildren() or {}
    local char = player.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local sp = spawnList[math.random(1, math.max(#spawnList, 1))]
            root.CFrame = sp and (sp.CFrame + Vector3.new(0, 3, 0))
                             or CFrame.new(math.random(-20, 20), 12, math.random(-20, 20))
        end
    end

    local remaining = 0
    for _ in pairs(activePlayers) do remaining += 1 end
    local qualifyCount = getQualifyCount(#arrivalOrder + remaining)

    print(string.format("[RoundManager] ✅ %s qualifié — position %d / quota %d (reste %d en course)",
        player.Name, #arrivalOrder, qualifyCount, remaining))

    -- Notifie le client : affiche "QUALIFIÉ !" en vert
    reRoundState:FireClient(player, {
        state = "QUALIFIED",
        data  = { position = #arrivalOrder },
    })

    if #arrivalOrder >= qualifyCount or remaining == 0 then
        endRound(arrivalOrder[1])
    end
end

local function setupArrivalZone()
    local zones = CollectionService:GetTagged("ArrivalZone")
    if #zones == 0 then
        warn("[RoundManager] Aucune ArrivalZone trouvée dans la map !")
        return
    end

    -- Groupe les zones par courseId, calcule le Z minimum par course
    for _, zone in ipairs(zones) do
        local courseId = zone:GetAttribute("CourseId") or 1
        local zMin = zone.Position.Z - zone.Size.Z / 2
        if not arrivalZByCourse[courseId] or zMin < arrivalZByCourse[courseId] then
            arrivalZByCourse[courseId] = zMin
        end

        -- Touched : déclencheur principal (filtré par courseId dans processArrival)
        zone.Touched:Connect(function(hit)
            local char   = hit.Parent
            local player = Players:GetPlayerFromCharacter(char)
            if player then processArrival(player, courseId) end
        end)
    end

    print(string.format("[RoundManager] %d ArrivalZone(s) — Course1 Z=%.0f | Course2 Z=%.0f",
        #zones,
        arrivalZByCourse[1] or 0,
        arrivalZByCourse[2] or 0))
end

-- Vérifie chaque seconde si un joueur a dépassé le seuil Z (fallback fiable)
local function checkArrivalsByZ()
    local courseId  = getCourseId()
    local threshold = arrivalZByCourse[courseId]
    if not threshold then return end
    for player in pairs(activePlayers) do
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root and root.Position.Z >= threshold then
                processArrival(player, courseId)
            end
        end
    end
end

-- ============================================================
-- MISE À JOUR POSITIONS
-- ============================================================

local function broadcastPositions()
    local rankings = buildRankings()
    local total    = #rankings
    for rank, entry in ipairs(rankings) do
        reUpdatePosition:FireClient(entry.player, {
            position = rank,
            total    = total,
        })
    end
end

-- ============================================================
-- BOUCLE DE MANCHE
-- ============================================================

local function runRound()
    arrivalOrder = {}

    -- ── WAITING ──────────────────────────────────────────────
    local roundDef   = GameConfig.Tournament.ROUNDS[roundNumber] or GameConfig.Tournament.ROUNDS[#GameConfig.Tournament.ROUNDS]
    local roundLabel = roundDef.label
    setState("WAITING", { countdown = GameConfig.Round.WAITING_COUNTDOWN, round = roundNumber, label = roundLabel })

    for i = GameConfig.Round.WAITING_COUNTDOWN, 1, -1 do
        task.wait(1)
        reRoundState:FireAllClients({
            state = "WAITING",
            data  = { countdown = i, round = roundNumber, label = roundLabel },
        })
    end

    -- Reset Karma / Défis
    if _G.KarmaManager then _G.KarmaManager.ResetRoundTracking() end
    if _G.ChallengeManager then
        for _, p in ipairs(Players:GetPlayers()) do
            _G.ChallengeManager.ResetRoundProgress(p)
        end
    end

    spawnAtStart()
    task.wait(0.5)

    -- ── ACTIVE ────────────────────────────────────────────────
    roundActive = true
    setState("ACTIVE", { duration = GameConfig.Round.DURATION, round = roundNumber })

    task.spawn(function()
        local elapsed = 0
        while roundActive and elapsed < GameConfig.Round.DURATION do
            task.wait(1)
            elapsed += 1
            reRoundState:FireAllClients({
                state = "ACTIVE",
                data  = {
                    timeLeft = GameConfig.Round.DURATION - elapsed,
                    elapsed  = elapsed,
                    round    = roundNumber,
                },
            })
            if elapsed % 3 == 0 then broadcastPositions() end
        end
        if roundActive then endRound(nil) end
    end)

    repeat task.wait(0.5) until not roundActive

    -- ── RESULTS ───────────────────────────────────────────────
    task.wait(GameConfig.Round.RESULTS_DURATION)

    -- Éliminés → lobby
    teleportEliminated()

    activePlayers = {}
    arrivalOrder  = {}
end

-- ============================================================
-- BOUCLE PRINCIPALE — TOURNOI
-- ============================================================

local function mainLoop()
    setupArrivalZone()
    setState("LOBBY", {})

    while true do
        -- Attente du minimum de joueurs
        if #Players:GetPlayers() < GameConfig.Round.MIN_PLAYERS then
            print(string.format("[RoundManager] En attente de joueurs... (%d/%d)",
                #Players:GetPlayers(), GameConfig.Round.MIN_PLAYERS))
            repeat task.wait(5) until #Players:GetPlayers() >= GameConfig.Round.MIN_PLAYERS
        end

        -- Nouveau tournoi : tous les joueurs présents participent
        tournamentPlayers = {}
        roundNumber       = 0
        for _, p in ipairs(Players:GetPlayers()) do
            tournamentPlayers[p] = true
        end
        print(string.format("[RoundManager] ══ Nouveau tournoi — %d joueurs ══",
            #Players:GetPlayers()))

        -- Manches jusqu'à 1 seul survivant (ou 0)
        while true do
            -- Vérifie qu'il y a au moins 1 joueur pour jouer
            local remaining = 0
            for p in pairs(tournamentPlayers) do
                if p.Parent then remaining += 1 end
            end
            if remaining < 1 then break end

            roundNumber += 1
            print(string.format("[RoundManager] ── Manche %d — %d joueurs ──",
                roundNumber, remaining))
            runRound()

            -- Après la manche : on s'arrête si tout le monde est éliminé
            -- ou si toutes les manches définies ont été jouées
            local stillIn = 0
            for p in pairs(tournamentPlayers) do
                if p.Parent then stillIn += 1 end
            end
            if stillIn == 0 then break end  -- plus personne
            if roundNumber >= #GameConfig.Tournament.ROUNDS then break end  -- toutes les manches jouées
        end

        -- Champion
        local champion = nil
        for p in pairs(tournamentPlayers) do
            if p.Parent then champion = p break end
        end
        if champion then
            print(string.format("[RoundManager] 🏆 Champion : %s", champion.Name))
        end

        returnToLobby()
        setState("LOBBY", { champion = champion and champion.Name or nil })
    end
end

-- ============================================================
-- NETTOYAGE SI UN JOUEUR QUITTE
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
    activePlayers[player]     = nil
    tournamentPlayers[player] = nil
    if roundActive then
        local remaining = 0
        for _ in pairs(activePlayers) do remaining += 1 end
        if remaining < 1 then
            print("[RoundManager] Plus assez de joueurs — fin de manche forcée")
            endRound(nil)
        end
    end
end)

-- ============================================================
-- DÉMARRAGE
-- ============================================================

task.spawn(mainLoop)
print("[RoundManager] ✅ Prêt (Fall Guys — 100 joueurs)")
