-- RotatingCylinders.server.lua
-- Anime tous les cylindres tagués "RotatingCylinder" dans le workspace.
-- Les cylindres sont créés par MapBuilder (sections hasCylinders = true).
-- Ce script ajoute les pointes roses et tourne les cylindres en temps réel.

local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Vitesse : surface recule à CYL_R × SPEED studs/s → joueur doit avancer
local SPEED = math.rad(80)   -- ~7 studs/s

-- ============================================================
-- POINTES
-- ============================================================

local function addSpikes(cyl)
    local r        = cyl.Size.Y / 2
    local len      = cyl.Size.X
    local rng      = Random.new()

    local NUM_SPIKES = 18      -- même nombre qu'avant (3×6)
    local MIN_DIST   = 1.6     -- distance min entre centres (studs) → les spikes ne se touchent pas

    -- Vérifie qu'un nouveau spike est assez loin de tous les spikes déjà placés
    local placed = {}
    local function isFarEnough(xNew, angNew)
        for _, p in ipairs(placed) do
            local dx     = xNew - p[1]
            local dAng   = math.abs(angNew - p[2])
            if dAng > math.pi then dAng = 2 * math.pi - dAng end
            -- Distance 3D approximée entre deux centres sur la surface
            local chord  = 2 * (r + 0.9) * math.sin(dAng / 2)
            if math.sqrt(dx * dx + chord * chord) < MIN_DIST then
                return false
            end
        end
        return true
    end

    local count    = 0
    local attempts = 0
    while count < NUM_SPIKES and attempts < NUM_SPIKES * 100 do
        attempts = attempts + 1
        local xOff = rng:NextNumber(-len / 2 + 0.5, len / 2 - 0.5)
        local angle = rng:NextNumber(0, 2 * math.pi)

        if isFarEnough(xOff, angle) then
            table.insert(placed, { xOff, angle })
            count = count + 1

            local sp              = Instance.new("Part")
            sp.Name               = "Spike"
            sp.Size               = Vector3.new(0.8, 2.6, 0.8)
            sp.Anchored           = false
            sp.CanCollide         = true
            sp.BrickColor         = BrickColor.new("Hot pink")
            sp.Material           = Enum.Material.SmoothPlastic
            sp.TopSurface         = Enum.SurfaceType.Smooth
            sp.BottomSurface      = Enum.SurfaceType.Smooth
            sp.CastShadow         = false
            sp.CFrame = CFrame.new(
                cyl.Position.X + xOff,
                cyl.Position.Y + math.sin(angle) * (r + 0.9),
                cyl.Position.Z + math.cos(angle) * (r + 0.9)
            ) * CFrame.Angles(angle, 0, 0)
            sp.Parent = cyl.Parent

            local weld   = Instance.new("WeldConstraint")
            weld.Part0   = cyl
            weld.Part1   = sp
            weld.Parent  = sp

            sp.Touched:Connect(function(hit)
                local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    hum.Health = 0
                end
            end)
        end
    end
    print(string.format("[RotatingCylinders] %d spikes placés sur %s", count, cyl.Name))
end

-- ============================================================
-- COLLECTE DES CYLINDRES
-- ============================================================

local entries = {}  -- { part = cyl, baseCF = CFrame }

local function setupCylinder(cyl)
    addSpikes(cyl)
    table.insert(entries, { part = cyl, baseCF = cyl.CFrame })
    print("[RotatingCylinders] ✅ Cylindre prêt :", cyl:GetFullName())
end

-- Cylindres déjà présents dans le workspace (course copy-pasteé)
for _, cyl in ipairs(CollectionService:GetTagged("RotatingCylinder")) do
    setupCylinder(cyl)
end

-- Cylindres ajoutés dynamiquement (si MapBuilder est activé)
CollectionService:GetInstanceAddedSignal("RotatingCylinder"):Connect(setupCylinder)

print(string.format("[RotatingCylinders] %d cylindre(s) trouvé(s)", #entries))

-- ============================================================
-- ROTATION (Heartbeat — frame-rate indépendant)
-- Rotation négative autour de X → surface du dessus part vers -Z (arrière)
-- ============================================================

local angle = 0

RunService.Heartbeat:Connect(function(dt)
    angle = angle - SPEED * dt
    for _, e in ipairs(entries) do
        if e.part and e.part.Parent then
            e.part.CFrame = e.baseCF * CFrame.Angles(angle, 0, 0)
        end
    end
end)
