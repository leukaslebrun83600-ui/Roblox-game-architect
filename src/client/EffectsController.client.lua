-- EffectsController.client.lua — Sons, musique et VFX côté client
-- E9-S1 (sons pièges), S2 (mort + confettis), S3 (sacrifice doré),
-- S4 (musique lobby), S5 (musique manche + sprint final),
-- S6 (fanfare victoire), S7 (bord rouge < 30s), S8 (flash bouton)

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")
local hudGui      = playerGui:WaitForChild("HUD")

local Events          = game.ReplicatedStorage:WaitForChild("Events")
local reRoundState    = Events:WaitForChild("RoundStateChanged")
local reTrapActivated = Events:WaitForChild("TrapActivated")
local reSacrifice     = Events:WaitForChild("SacrificeActivated")
local reRespawn       = Events:WaitForChild("RespawnAt")
local rePlayEffect    = Events:WaitForChild("PlayEffect")

-- ============================================================
-- IDs SONORES
-- ⚠ Remplace les 0 par des IDs réels depuis :
--   https://create.roblox.com/store/audio  ou  Creator Hub → Audio
-- ============================================================

local SFX_IDS = {
    -- Pièges (E9-S1)
    floorCollapse = 0,   -- craquement, effondrement sucré
    projectile    = 0,   -- whoosh + splat bonbon
    wallPusher    = 0,   -- slam sourd + glissement

    -- Mort & Respawn (E9-S2)
    death         = 0,   -- cartoon pop / splat comique
    respawn       = 0,   -- swoosh de téléportation

    -- Sacrifice (E9-S3)
    sacrifice     = 0,   -- carillon / cloche dorée

    -- Victoire (E9-S6)
    fanfare       = 0,   -- fanfare courte (3-5 secondes)

    -- Bouclier (E8-S5)
    shieldOn      = 0,   -- activation : hum électrique
    shieldOff     = 0,   -- désactivation : pop
}

local MUSIC_IDS = {
    lobby   = 0,   -- chiptune joyeux, boucle (E9-S4)
    round   = 0,   -- action sucrée, boucle (E9-S5)
    intense = 0,   -- variation sprint final, boucle (E9-S5 < 30s)
}

-- ============================================================
-- CRÉATION DES SONS
-- ============================================================

local function makeSound(id, vol, looped, parent)
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(id)
    s.Volume  = vol    or 0.5
    s.Looped  = looped or false
    s.Parent  = parent or workspace
    return s
end

-- SFX : sons ponctuels
local sfx = {}
for name, id in pairs(SFX_IDS) do
    sfx[name] = makeSound(id, 0.65, false)
end

-- Musiques
local musicLobby   = makeSound(MUSIC_IDS.lobby,   0.35, true)
local musicRound   = makeSound(MUSIC_IDS.round,   0.40, true)
local musicIntense = makeSound(MUSIC_IDS.intense, 0.40, true)

local currentMusic  = nil
local intenseModeOn = false

local function playSFX(name)
    local s = sfx[name]
    if s and s.SoundId ~= "rbxassetid://0" then s:Play() end
end

local function crossfade(newMusic, targetVolume)
    if currentMusic == newMusic then return end

    -- Fade out de l'ancienne musique
    if currentMusic then
        local old = currentMusic
        TweenService:Create(old, TweenInfo.new(1.2), { Volume = 0 }):Play()
        task.delay(1.2, function() old:Stop() end)
    end

    -- Fade in de la nouvelle
    currentMusic = newMusic
    newMusic.Volume = 0
    newMusic:Play()
    TweenService:Create(newMusic, TweenInfo.new(1.2), { Volume = targetVolume }):Play()
end

local function stopMusic()
    if not currentMusic then return end
    local old = currentMusic
    currentMusic = nil
    TweenService:Create(old, TweenInfo.new(0.8), { Volume = 0 }):Play()
    task.delay(0.8, function() old:Stop() end)
end

-- ============================================================
-- BORD D'ÉCRAN ROUGE — SPRINT FINAL (E9-S7)
-- ============================================================

local redFrame = Instance.new("Frame")
redFrame.Name                  = "RedBorder"
redFrame.Size                  = UDim2.new(1, 0, 1, 0)
redFrame.BackgroundTransparency = 1
redFrame.BorderSizePixel       = 0
redFrame.ZIndex                = 20
redFrame.Visible               = false
redFrame.Parent                = hudGui

local redStroke = Instance.new("UIStroke")
redStroke.Color       = Color3.fromRGB(220, 20, 20)
redStroke.Thickness   = 24
redStroke.Transparency = 1
redStroke.Parent      = redFrame

local redPulseActive = false

local function startRedPulse()
    if redPulseActive then return end
    redPulseActive  = true
    redFrame.Visible = true

    local function pulse()
        if not redPulseActive then return end
        TweenService:Create(redStroke,
            TweenInfo.new(0.55, Enum.EasingStyle.Sine),
            { Transparency = 0.1 }
        ):Play()
        task.delay(0.55, function()
            if not redPulseActive then return end
            TweenService:Create(redStroke,
                TweenInfo.new(0.55, Enum.EasingStyle.Sine),
                { Transparency = 0.65 }
            ):Play()
            task.delay(0.55, pulse)
        end)
    end
    pulse()
end

local function stopRedPulse()
    if not redPulseActive then return end
    redPulseActive = false
    TweenService:Create(redStroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
    task.delay(0.35, function() redFrame.Visible = false end)
end

-- ============================================================
-- PARTICULES CONFETTIS CANDY (E9-S2)
-- ============================================================

local CANDY_COLORS = {
    Color3.fromRGB(255, 70,  70),
    Color3.fromRGB(255, 200, 50),
    Color3.fromRGB(80,  200, 255),
    Color3.fromRGB(190, 80,  255),
    Color3.fromRGB(80,  240, 130),
}

local function spawnCandyConfetti(cf)
    local root = Instance.new("Part")
    root.Anchored    = true
    root.CanCollide  = false
    root.Transparency = 1
    root.Size        = Vector3.new(1, 1, 1)
    root.CFrame      = cf
    root.Parent      = workspace

    for _, col in ipairs(CANDY_COLORS) do
        local em = Instance.new("ParticleEmitter")
        em.Color        = ColorSequence.new(col, col)
        em.LightEmission = 0.6
        em.Size         = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.45),
            NumberSequenceKeypoint.new(1, 0),
        })
        em.Lifetime     = NumberRange.new(1.2, 2.2)
        em.Speed        = NumberRange.new(10, 24)
        em.SpreadAngle  = Vector2.new(180, 180)
        em.RotSpeed     = NumberRange.new(-240, 240)
        em.Rotation     = NumberRange.new(0, 360)
        em.Rate         = 0
        em.Parent       = root
        em:Emit(6)
    end

    task.delay(2.8, function() root:Destroy() end)
end

-- ============================================================
-- PARTICULES DORÉES — SACRIFICE (E9-S3)
-- ============================================================

local function spawnGoldenSparkles(cf)
    local root = Instance.new("Part")
    root.Anchored    = true
    root.CanCollide  = false
    root.Transparency = 1
    root.Size        = Vector3.new(1, 1, 1)
    root.CFrame      = cf
    root.Parent      = workspace

    local em = Instance.new("ParticleEmitter")
    em.Color        = ColorSequence.new(
        Color3.fromRGB(255, 215, 0),
        Color3.fromRGB(255, 255, 190)
    )
    em.LightEmission = 1
    em.Size         = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(1, 0),
    })
    em.Lifetime     = NumberRange.new(1.8, 2.8)
    em.Speed        = NumberRange.new(5, 14)
    em.SpreadAngle  = Vector2.new(180, 180)
    em.RotSpeed     = NumberRange.new(-180, 180)
    em.Rate         = 0
    em.Parent       = root
    em:Emit(50)

    task.delay(3.2, function() root:Destroy() end)
end

-- ============================================================
-- BOUCLIER VISUEL (E8-S5)
-- ============================================================

local shieldPart = nil

local function showShield(duration)
    if shieldPart then shieldPart:Destroy(); shieldPart = nil end

    local char = localPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local sphere = Instance.new("Part")
    sphere.Name         = "ShieldVFX"
    sphere.Shape        = Enum.PartType.Ball
    sphere.Size         = Vector3.new(8, 8, 8)
    sphere.Color        = Color3.fromRGB(80, 180, 255)
    sphere.Material     = Enum.Material.Neon
    sphere.Transparency = 0.45
    sphere.CanCollide   = false
    sphere.CastShadow   = false
    sphere.CFrame       = hrp.CFrame
    sphere.Parent       = workspace
    shieldPart = sphere

    local weld = Instance.new("WeldConstraint")
    weld.Part0  = hrp
    weld.Part1  = sphere
    weld.Parent = sphere

    -- Pulsation
    TweenService:Create(sphere,
        TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 0.68 }
    ):Play()

    playSFX("shieldOn")
end

local function removeShield()
    if not shieldPart then return end
    local sp = shieldPart
    shieldPart = nil
    TweenService:Create(sp, TweenInfo.new(0.35), { Transparency = 1 }):Play()
    task.delay(0.35, function() sp:Destroy() end)
    playSFX("shieldOff")
end

-- ============================================================
-- FLASH BOUTON PIÈGE (E9-S8)
-- ============================================================

local function flashButton(buttonName, trapType)
    local btn = nil
    for _, b in ipairs(CollectionService:GetTagged("TrapButton")) do
        if b.Name == buttonName then btn = b; break end
    end

    if not btn then return end

    local flashColor = Color3.fromRGB(255, 255, 100)
    if trapType == "Projectile" then
        flashColor = Color3.fromRGB(255, 120, 50)
    elseif trapType == "WallPusher" then
        flashColor = Color3.fromRGB(240, 80, 220)
    end

    local origColor = btn.Color
    TweenService:Create(btn, TweenInfo.new(0.08), { Color = flashColor }):Play()
    task.delay(0.1, function()
        TweenService:Create(btn, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Color = origColor }):Play()
    end)
end

-- ============================================================
-- GESTION DE L'ÉTAT DE JEU (musique + bord rouge)
-- ============================================================

local function onStateChanged(payload)
    if type(payload) ~= "table" then return end
    local state = payload.state
    local data  = payload.data or {}

    if state == "LOBBY" or state == "WAITING" then
        stopRedPulse()
        intenseModeOn = false
        crossfade(musicLobby, 0.35)

    elseif state == "ACTIVE" then
        if data.duration then
            -- Démarrage de manche → musique action
            if not intenseModeOn then
                crossfade(musicRound, 0.40)
            end
        end
        if data.timeLeft ~= nil then
            local t = data.timeLeft
            if t <= 30 and not intenseModeOn then
                intenseModeOn = true
                startRedPulse()
                crossfade(musicIntense, 0.40)
            elseif t > 30 and intenseModeOn then
                intenseModeOn = false
                stopRedPulse()
                crossfade(musicRound, 0.40)
            end
        end

    elseif state == "RESULTS" then
        stopRedPulse()
        intenseModeOn = false
        stopMusic()
        task.delay(0.5, function() playSFX("fanfare") end)
    end
end

-- ============================================================
-- MORT & RESPAWN DU PERSONNAGE LOCAL (E9-S2)
-- ============================================================

local function setupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    -- Nettoyage du bouclier si le personnage meurt
    humanoid.Died:Connect(function()
        if shieldPart then removeShield() end

        playSFX("death")

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            spawnCandyConfetti(hrp.CFrame)
        end
    end)
end

localPlayer.CharacterAdded:Connect(function(character)
    task.delay(0.05, function() setupCharacter(character) end)
end)
if localPlayer.Character then
    setupCharacter(localPlayer.Character)
end

-- ============================================================
-- CONNEXION AUX EVENTS
-- ============================================================

reRoundState.OnClientEvent:Connect(onStateChanged)

-- Sons + flash bouton pour les pièges (E9-S1, E9-S8)
reTrapActivated.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then return end
    local tt = payload.trapType or "FloorCollapse"

    if tt == "FloorCollapse" then
        playSFX("floorCollapse")
    elseif tt == "Projectile" then
        playSFX("projectile")
    elseif tt == "WallPusher" then
        playSFX("wallPusher")
    end

    if payload.trapId then
        flashButton(payload.trapId, tt)
    end
end)

-- Son + particules dorées du sacrifice (E9-S3)
reSacrifice.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then return end
    playSFX("sacrifice")

    -- Particules uniquement sur le sacrifié local
    if payload.playerId == localPlayer.UserId then
        local char = localPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then spawnGoldenSparkles(hrp.CFrame) end
    end
end)

-- Son + caméra au respawn (E9-S2)
reRespawn.OnClientEvent:Connect(function(payload)
    playSFX("respawn")

    -- Réorienter la caméra vers la ligne d'arrivée (+Z)
    task.wait(0.1)  -- laisse le serveur appliquer root.CFrame
    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local camera = workspace.CurrentCamera
    local lookDir = (type(payload) == "table" and payload.checkpointCFrame)
        and payload.checkpointCFrame.LookVector
        or root.CFrame.LookVector  -- fallback : direction actuelle du perso

    local charPos = root.Position
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.new(
        charPos - lookDir * 16 + Vector3.new(0, 8, 0),
        charPos + lookDir * 5
    )
    task.wait(0.05)
    camera.CameraType = Enum.CameraType.Custom
end)

-- Effets génériques : bouclier, fin bouclier (E8-S5)
rePlayEffect.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then return end

    if payload.type == "shield" then
        showShield(payload.duration or 10)
    elseif payload.type == "shieldEnd" then
        removeShield()
    end
end)

-- ============================================================
-- INIT
-- ============================================================

crossfade(musicLobby, 0.35)

print("[EffectsController] ✅ Prêt")
