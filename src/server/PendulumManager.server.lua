-- PendulumManager.server.lua
-- Anime tous les pendules taguées "PendulumBall" dans le workspace.
-- Les pendules sont créés par MapBuilder (sections hasPendulums = true).
-- Lit les attributs stockés sur chaque boule pour connaître pivot, phase, vitesse, etc.

local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local entries = {}  -- { ball, rope, pivotX, pivotY, pivotZ, phase, speed, amp, ropeLen }

local function setupPendulum(ball)
    local pivotX  = ball:GetAttribute("PivotX")    or 0
    local pivotY  = ball:GetAttribute("PivotY")    or 30
    local pivotZ  = ball:GetAttribute("PivotZ")    or 0
    local phase   = ball:GetAttribute("Phase")     or 0
    local speed   = ball:GetAttribute("Speed")     or 0.55
    local amp     = ball:GetAttribute("Amplitude") or math.rad(42)
    local ropeLen = ball:GetAttribute("RopeLen")   or 12
    local ropeName = ball:GetAttribute("RopeName")

    -- La corde est un sibling dans le même dossier (même parent = platFolder)
    local rope = ropeName and ball.Parent:FindFirstChild(ropeName)

    -- Mort au contact
    ball.Touched:Connect(function(hit)
        local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then hum.Health = 0 end
    end)

    table.insert(entries, {
        ball    = ball,
        rope    = rope,
        pivotX  = pivotX,
        pivotY  = pivotY,
        pivotZ  = pivotZ,
        phase   = phase,
        speed   = speed,
        amp     = amp,
        ropeLen = ropeLen,
    })
    print("[PendulumManager] ✅ Pendule prêt :", ball:GetFullName())
end

-- Pendules déjà présents (parcours copy-collé)
for _, ball in ipairs(CollectionService:GetTagged("PendulumBall")) do
    setupPendulum(ball)
end

-- Pendules ajoutés dynamiquement (si MapBuilder activé)
CollectionService:GetInstanceAddedSignal("PendulumBall"):Connect(setupPendulum)

print(string.format("[PendulumManager] %d pendule(s) trouvé(s)", #entries))

-- ============================================================
-- ANIMATION (Heartbeat — frame-rate indépendant)
-- Formule pendule :
--   ballX = pivotX + sin(angle) * ropeLen
--   ballY = pivotY - cos(angle) * ropeLen
-- Orientation corde : CFrame.Angles(0, 0, angle) → axe Y suit la corde ✓
-- ============================================================

local t = 0
RunService.Heartbeat:Connect(function(dt)
    t = t + dt
    for _, e in ipairs(entries) do
        if e.ball and e.ball.Parent then
            local angle = e.amp * math.sin(t * e.speed * math.pi * 2 + e.phase)

            local bx = e.pivotX + math.sin(angle) * e.ropeLen
            local by = e.pivotY - math.cos(angle) * e.ropeLen

            e.ball.CFrame = CFrame.new(bx, by, e.pivotZ)

            if e.rope and e.rope.Parent then
                local midX = (e.pivotX + bx) / 2
                local midY = (e.pivotY + by) / 2
                e.rope.CFrame = CFrame.new(midX, midY, e.pivotZ) * CFrame.Angles(0, 0, angle)
            end
        end
    end
end)
