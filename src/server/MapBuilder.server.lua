-- MapBuilder.server.lua — Générateur de squelette fonctionnel
-- Génère toutes les sections avec les bons tags CollectionService.
-- Le visuel candy est à faire manuellement dans Studio autour de ce squelette.
--
-- ════════════════════════════════════════════════════════════
-- WORKFLOW (à faire UNE SEULE FOIS) :
--   1. Dans l'Explorer Studio → ce Script → Properties → décocher "Disabled"
--   2. Appuie sur Play ▶
--   3. Dans l'Explorer : clic droit sur "Course" → Copy, puis "Lobby" → Copy
--   4. Stop ■
--   5. Colle (Ctrl+V) dans Workspace
--   6. Re-coche "Disabled" sur ce Script
-- ════════════════════════════════════════════════════════════

local CollectionService = game:GetService("CollectionService")
local Workspace         = game.Workspace

-- ============================================================
-- CONFIGURATION
-- ============================================================

-- Chaque section fait SECTION_LENGTH studs le long de l'axe Z.
-- Le lobby est autour de Z=0, le parcours commence à Z=COURSE_START_Z.
local SECTION_LENGTH  = 120   -- (studs) longueur d'une section
local COURSE_START_Z  = 200   -- Z du point de départ du parcours
local BASE_Y          = 10    -- hauteur du sol de base
local LOBBY_OFFSET_X  = 10000 -- déplace le lobby 10 000 studs sur X → invisible depuis le parcours

-- Définition des 9 sections (source : PRD 03)
local SECTIONS = {
    {
        name   = "Section_01_Caramel",
        color  = Color3.fromRGB(255, 213,  79),  -- caramel doré
        traps  = { "FloorCollapse" },
        sac    = false,
        yBias  = 0,
        note   = "Intro tutoriel — sauts larges, difficulté facile",
    },
    {
        name   = "Section_02_Disques",
        color  = Color3.fromRGB(80, 210, 220),   -- turquoise bonbon
        traps  = {},
        sac    = false,
        yBias  = 0,
        hasDisc = true,
        note   = "Plateforme tournante — saute et ride !",
    },
    {
        name   = "Section_03_Boules",
        color  = Color3.fromRGB(255, 120, 180),  -- rose bonbon
        traps  = {},
        sac    = false,
        yBias  = 0,
        hasBalls = true,
        note   = "Boules en ligne — saute de sphère en sphère !",
    },
    {
        name   = "Section_04_Cascade",
        color  = Color3.fromRGB(255, 140,  80),  -- orange bonbon
        traps  = { "Projectile" },
        sac    = true,
        yBias  = -8,  -- escalier descendant
        note   = "Première introduction au bouton Sacrifice",
    },
    {
        name   = "Section_05_Cylindres",
        color  = Color3.fromRGB(240, 240, 255),  -- guimauve blanche
        traps  = {},
        sac    = false,
        yBias  = 0,
        hasCylinders = true,
        note   = "Cylindres tournants — cours ou tombe !",
    },
    {
        name   = "Section_06_Sucette",
        color  = Color3.fromRGB(255, 100, 200),  -- rose vif
        traps  = { "FloorCollapse" },
        sac    = true,
        yBias  = 20,  -- section qui monte (tour verticale)
        note   = "Première section verticale — montée en spirale",
    },
    {
        name   = "Section_07_Pendules",
        color  = Color3.fromRGB(80, 200, 120),   -- vert bonbon
        traps  = {},
        sac    = false,
        yBias  = 0,
        hasPendulums = true,
        note   = "Pendules oscillants — passe entre les boules !",
    },
    {
        name   = "Section_08_Chocolat",
        color  = Color3.fromRGB(139, 80, 30),    -- chocolat brun
        traps  = { "WallPusher", "FloorCollapse" },
        sac    = true,
        yBias  = 30,  -- grande pente montante
        note   = "Pente raide — joueurs regroupés, parfait pour les pièges",
    },
    {
        name   = "Section_09_Spinners",
        color  = Color3.fromRGB(197, 193, 227),  -- lavande
        traps  = {},
        sac    = false,
        yBias  = 0,
        hasSpinners = true,
        note   = "Disques rotatifs — saute par-dessus les bras !",
    },
    {
        name   = "Section_10_Chateau",
        color  = Color3.fromRGB(255, 215,   0),  -- château doré
        traps  = {},
        sac    = false,
        yBias  = 0,    -- plat : pas de plateformes flottantes à l'arrivée
        isEnd  = true,
        note   = "Zone d'arrivée — grande plateforme plate",
    },
}

-- ============================================================
-- UTILITAIRES
-- ============================================================

local function part(parent, name, size, cf, color, material, transparency)
    local p = Instance.new("Part")
    p.Name         = name
    p.Size         = size
    p.CFrame       = cf
    p.Color        = color or Color3.fromRGB(200, 200, 200)
    p.Material     = material or Enum.Material.SmoothPlastic
    p.Anchored     = true
    p.Transparency = transparency or 0
    p.CastShadow   = false
    p.Parent       = parent
    return p
end

local function folder(parent, name)
    local f = Instance.new("Folder")
    f.Name   = name
    f.Parent = parent
    return f
end

local function tag(instance, tagName)
    CollectionService:AddTag(instance, tagName)
end

-- ============================================================
-- GÉNÉRATION D'UNE SECTION
-- ============================================================

--[[
  Layout d'une section (vue de dessus, axe Z = avant) :

  [Plat A]──gap──[Plat B + TrapButton1]──gap──[Plat C + SacButton]
       ──gap──[Plat D + TrapButton2]──gap──[Plat E + Checkpoint]

  TrapZone = grande zone qui couvre la plateforme affectée.
  TrapButton et TrapZone sont liés par l'attribut "LinkedZone".
]]

local function buildSection(courseFolder, sectionDef, index, startY)
    local zStart = COURSE_START_Z + (index - 1) * SECTION_LENGTH
    local yBase  = startY  -- chaîné depuis la section précédente (plus de saut vertical)

    local secFolder  = folder(courseFolder, sectionDef.name)
    local platFolder = folder(secFolder, "Plateformes")
    local trapFolder = folder(secFolder, "TrapButtons")
    local sacFolder  = folder(secFolder, "SacrificeButtons")
    local cpFolder   = folder(secFolder, "Checkpoints")

    -- ── Largeur des plateformes ──────────────────────────────
    local platW = sectionDef.narrow and 8 or 20

    -- ── Section plateforme tournante (disc) ──────────────────
    -- Layout : Plat_A →[8]→ ArmTip ←Bras tournant→ ArmTip →[6]→ Plat_E → Links
    -- Le bras est tagué "SpinningDisc" → animé par DiscManager.server.lua
    if sectionDef.hasDisc then
        local ARM_LEN = 20    -- demi-longueur du bras (studs depuis le centre)
        local ARM_W   = 8     -- largeur du bras (perpendiculaire à la rotation)
        local ARM_H   = 1.2   -- épaisseur = même que les plateformes normales

        -- Plateforme d'approche
        -- Bord avant à dz=15 → gap=8 studs jusqu'au tip approche (dz=23) ✓
        part(platFolder, "Plat_A",
            Vector3.new(platW, 1.2, 14),
            CFrame.new(0, yBase, zStart + 8), sectionDef.color)

        -- Centre du bras à dz=43
        -- Tip approche : dz=23 → gap=8 depuis Plat_A ✓
        -- Tip sortie   : dz=63 → gap=6 vers Plat_E  ✓
        local armCenterZ = zStart + 43
        local armCenterY = yBase  -- surface bras = yBase+0.6 = surface des plateformes

        -- Moyeu visuel (décoratif, ne bloque pas les joueurs)
        local hub = part(platFolder, "Hub",
            Vector3.new(3, 5, 3),
            CFrame.new(0, armCenterY - 2, armCenterZ),
            Color3.fromRGB(60, 60, 60))
        hub.CanCollide = false

        -- Bras tournant (tagué "SpinningDisc")
        -- Size (ARM_W, ARM_H, ARM_LEN*2) : s'étend en ±Z quand angle=0
        local arm = part(platFolder, "Arm",
            Vector3.new(ARM_W, ARM_H, ARM_LEN * 2),
            CFrame.new(0, armCenterY, armCenterZ),
            Color3.fromRGB(255, 90, 180))  -- rose vif
        arm:SetAttribute("PosX",    0)
        arm:SetAttribute("PosY",    armCenterY)
        arm:SetAttribute("PosZ",    armCenterZ)
        arm:SetAttribute("Speed",   math.rad(60))
        arm:SetAttribute("SpinDir", 1)
        CollectionService:AddTag(arm, "SpinningDisc")

        -- Plateforme de sortie (bord gauche dz=69 → gap=6 depuis tip sortie dz=63)
        part(platFolder, "Plat_E",
            Vector3.new(platW, 1.2, 14),
            CFrame.new(0, yBase, zStart + 76), sectionDef.color)

        -- Liaisons vers la section suivante
        part(platFolder, "Plat_Link1",
            Vector3.new(platW - 4, 1.2, 14),
            CFrame.new(0, yBase, zStart + 95), sectionDef.color)
        part(platFolder, "Plat_Link2",
            Vector3.new(platW - 4, 1.2, 14),
            CFrame.new(0, yBase, zStart + 112), sectionDef.color)

        -- Checkpoint
        local cpName = string.format("Checkpoint_%02d", index)
        local cp = part(cpFolder, cpName,
            Vector3.new(platW + 4, 8, 10),
            CFrame.new(0, yBase + 4, zStart + 90),
            Color3.fromRGB(0, 210, 100), Enum.Material.Neon, 0.6)
        cp.CanCollide = false
        cp:SetAttribute("SectionIdx", index)
        cp:SetAttribute("CheckpointLabel", cpName)
        tag(cp, "Checkpoint")

        return yBase  -- section plate
    end

    -- ── Section boules en ligne (style Total Wipeout) ────────
    -- Layout : Plat_A →[5]→ Ball1 →[3]→ Ball2 →[3]→ Ball3 →[3]→ Ball4 →[4]→ Plat_E → Links
    -- Sphères statiques : le défi vient de la surface courbe (glissant, imprécis)
    if sectionDef.hasBalls then
        local BALL_R  = 5      -- rayon des boules (diamètre 10 studs)
        local SPACING = 13     -- centre-à-centre (gap surface = 3 studs)
        local N_BALLS = 4
        local PED_R   = 2.5    -- rayon du pied
        local PED_H   = 8      -- hauteur du pied

        -- Plateforme d'approche
        -- Bord avant à dz=15, gap=5 jusqu'au bord de Ball1 (dz=20) ✓
        part(platFolder, "Plat_A",
            Vector3.new(platW, 1.2, 14),
            CFrame.new(0, yBase, zStart + 8), sectionDef.color)

        -- 4 boules + pieds blancs
        -- Ball1 center : dz=25  |  Ball4 center : dz=64  |  Ball4 far edge : dz=69
        local ball1Z = zStart + 25
        for i = 1, N_BALLS do
            local bz = ball1Z + (i - 1) * SPACING

            -- Pied (cylindre vertical blanc)
            -- Size (PED_H, PED_R*2, PED_R*2) : PED_H le long de l'axe (local X → world Y)
            local pedY = yBase - BALL_R - PED_H / 2
            local ped = part(platFolder, "Pedestal_" .. i,
                Vector3.new(PED_H, PED_R * 2, PED_R * 2),
                CFrame.new(0, pedY, bz) * CFrame.Angles(0, 0, math.pi / 2),
                Color3.fromRGB(240, 240, 240))  -- blanc
            ped.Shape = Enum.PartType.Cylinder

            -- Boule (sphère, couleur de la section)
            local ball = part(platFolder, "Ball_" .. i,
                Vector3.new(BALL_R * 2, BALL_R * 2, BALL_R * 2),
                CFrame.new(0, yBase, bz),
                sectionDef.color)
            ball.Shape = Enum.PartType.Ball
        end

        -- Plateforme de sortie
        -- Ball4 far edge = dz=69, Plat_E left = dz=73 (gap=4), Plat_E center = dz=80
        part(platFolder, "Plat_E",
            Vector3.new(platW, 1.2, 14),
            CFrame.new(0, yBase, zStart + 80), sectionDef.color)

        -- Liaisons vers la section suivante
        -- Plat_E right = dz=87 → Link1 left = dz=88 (contigu) ✓
        part(platFolder, "Plat_Link1",
            Vector3.new(platW - 4, 1.2, 14),
            CFrame.new(0, yBase, zStart + 95), sectionDef.color)
        part(platFolder, "Plat_Link2",
            Vector3.new(platW - 4, 1.2, 14),
            CFrame.new(0, yBase, zStart + 112), sectionDef.color)

        -- Checkpoint
        local cpName = string.format("Checkpoint_%02d", index)
        local cp = part(cpFolder, cpName,
            Vector3.new(platW + 4, 8, 10),
            CFrame.new(0, yBase + 4, zStart + 90),
            Color3.fromRGB(0, 210, 100), Enum.Material.Neon, 0.6)
        cp.CanCollide = false
        cp:SetAttribute("SectionIdx", index)
        cp:SetAttribute("CheckpointLabel", cpName)
        tag(cp, "Checkpoint")

        return yBase  -- section plate
    end

    -- ── Section cylindres tournants ──────────────────────────
    -- Layout (joueur avance +Z) :
    --   Plat_A →[7]→ Cyl1 →[5]→ Plat_B →[6]→ Cyl2 →[5]→ Plat_Sortie → Checkpoint → Links
    if sectionDef.hasCylinders then
        local CYL_R    = 5
        local CYL_LEN  = 24
        local cylColor = Color3.fromRGB(139, 80, 30)   -- brun chocolat
        -- Centre Y des cylindres : surface = yBase + 0.6 (niveau du dessus des plateformes)
        local cylY     = yBase - (CYL_R - 0.6)

        -- Plateforme d'approche
        part(platFolder, "Plat_A",
            Vector3.new(platW, 1.2, 18),
            CFrame.new(0, yBase, zStart + 12), sectionDef.color)

        -- Cylindre 1 (tagué pour RotatingCylinders.server.lua)
        local cyl1 = part(platFolder, "Cyl_1",
            Vector3.new(CYL_LEN, CYL_R * 2, CYL_R * 2),
            CFrame.new(0, cylY, zStart + 33), cylColor)
        cyl1.Shape = Enum.PartType.Cylinder
        CollectionService:AddTag(cyl1, "RotatingCylinder")

        -- Plateforme intermédiaire
        part(platFolder, "Plat_B",
            Vector3.new(platW, 1.2, 4),
            CFrame.new(0, yBase, zStart + 45), sectionDef.color)

        -- Cylindre 2
        local cyl2 = part(platFolder, "Cyl_2",
            Vector3.new(CYL_LEN, CYL_R * 2, CYL_R * 2),
            CFrame.new(0, cylY, zStart + 58), cylColor)
        cyl2.Shape = Enum.PartType.Cylinder
        CollectionService:AddTag(cyl2, "RotatingCylinder")

        -- Plateforme de sortie
        part(platFolder, "Plat_E",
            Vector3.new(platW, 1.2, 16),
            CFrame.new(0, yBase, zStart + 76), sectionDef.color)

        -- Plateformes de liaison (mêmes dz que les sections normales)
        part(platFolder, "Plat_Link1",
            Vector3.new(platW - 4, 1.2, 14),
            CFrame.new(0, yBase, zStart + 95), sectionDef.color)
        part(platFolder, "Plat_Link2",
            Vector3.new(platW - 4, 1.2, 14),
            CFrame.new(0, yBase, zStart + 112), sectionDef.color)

        -- Checkpoint (même dz=90 que les autres sections)
        local cpName = string.format("Checkpoint_%02d", index)
        local cp = part(cpFolder, cpName,
            Vector3.new(platW + 4, 8, 10),
            CFrame.new(0, yBase + 4, zStart + 90),
            Color3.fromRGB(0, 210, 100), Enum.Material.Neon, 0.6)
        cp.CanCollide = false
        cp:SetAttribute("SectionIdx", index)
        cp:SetAttribute("CheckpointLabel", cpName)
        tag(cp, "Checkpoint")

        return yBase  -- section plate (pas de variation verticale)
    end

    -- ── Section pendules oscillants ──────────────────────────
    -- Layout : Plat_A →[gap]→ Plat_B (grande, 3 pendules au-dessus) →[cont.]→ Plat_E → Checkpoint → Links
    -- Les boules sont taguées "PendulumBall" → animées par PendulumManager.server.lua
    if sectionDef.hasPendulums then
        local PEND_PIVOT_H = 15    -- hauteur du pivot au-dessus de la surface
        local PEND_ROPE    = 12    -- longueur de la corde
        local PEND_BALL_R  = 2     -- rayon de la boule
        local BASE_SPD     = 0.55  -- cycles/seconde
        local pendW        = 20    -- légèrement réduite → amplitude plus faible → boules moins hautes

        -- surface Y = yBase + 0.6, pivot au-dessus
        local pivotY = yBase + 0.6 + PEND_PIVOT_H  -- yBase + 15.6

        -- Plateforme d'approche
        part(platFolder, "Plat_A",
            Vector3.new(pendW, 1.2, 14),
            CFrame.new(0, yBase, zStart + 8), sectionDef.color)

        -- Grande plateforme principale (couvre toute la zone des 3 pendules)
        -- dz=21 à dz=79 (58 studs)
        part(platFolder, "Plat_B",
            Vector3.new(pendW, 1.2, 58),
            CFrame.new(0, yBase, zStart + 50), sectionDef.color)

        -- Plateforme de sortie
        part(platFolder, "Plat_E",
            Vector3.new(pendW, 1.2, 12),
            CFrame.new(0, yBase, zStart + 84), sectionDef.color)

        -- 3 pendules espacés de 18 studs, phases décalées → jamais tous du même côté
        local pendConfigs = {
            { dz = 32, phase = 0,           speed = BASE_SPD,       color = Color3.fromRGB(220, 50,  50)  },
            { dz = 50, phase = math.pi,     speed = BASE_SPD,       color = Color3.fromRGB(50,  200, 200) },
            { dz = 68, phase = math.pi / 2, speed = BASE_SPD * 0.9, color = Color3.fromRGB(80,  200, 80)  },
        }

        for i, cfg in ipairs(pendConfigs) do
            local px = 0
            local py = pivotY
            local pz = zStart + cfg.dz

            -- Traverse horizontale (support visuel)
            part(platFolder, "Traverse_" .. i,
                Vector3.new(pendW, 0.8, 0.8),
                CFrame.new(px, py, pz),
                Color3.fromRGB(100, 100, 220))

            -- Corde (visuel statique initial — PendulumManager l'anime)
            local rope = part(platFolder, "Corde_" .. i,
                Vector3.new(0.25, PEND_ROPE, 0.25),
                CFrame.new(px, py - PEND_ROPE / 2, pz),
                Color3.fromRGB(150, 150, 150))
            rope.CanCollide = false

            -- Boule (taguée pour PendulumManager)
            local ballName = string.format("Pendule_%d_%d", index, i)
            local ball = part(platFolder, ballName,
                Vector3.new(PEND_BALL_R * 2, PEND_BALL_R * 2, PEND_BALL_R * 2),
                CFrame.new(px, py - PEND_ROPE, pz),
                cfg.color)
            ball.Shape = Enum.PartType.Ball
            -- Attributs lus par PendulumManager
            ball:SetAttribute("PivotX",    px)
            ball:SetAttribute("PivotY",    py)
            ball:SetAttribute("PivotZ",    pz)
            ball:SetAttribute("Phase",     cfg.phase)
            ball:SetAttribute("Speed",     cfg.speed)
            ball:SetAttribute("Amplitude", math.rad(42))
            ball:SetAttribute("RopeLen",   PEND_ROPE)
            ball:SetAttribute("RopeName",  "Corde_" .. i)
            CollectionService:AddTag(ball, "PendulumBall")
        end

        -- Liens et checkpoint (même structure que hasCylinders)
        part(platFolder, "Plat_Link1",
            Vector3.new(pendW - 4, 1.2, 14),
            CFrame.new(0, yBase, zStart + 95), sectionDef.color)
        part(platFolder, "Plat_Link2",
            Vector3.new(pendW - 4, 1.2, 14),
            CFrame.new(0, yBase, zStart + 112), sectionDef.color)

        local cpName = string.format("Checkpoint_%02d", index)
        local cp = part(cpFolder, cpName,
            Vector3.new(pendW + 4, 8, 10),
            CFrame.new(0, yBase + 4, zStart + 90),
            Color3.fromRGB(0, 210, 100), Enum.Material.Neon, 0.6)
        cp.CanCollide = false
        cp:SetAttribute("SectionIdx", index)
        cp:SetAttribute("CheckpointLabel", cpName)
        tag(cp, "Checkpoint")

        return yBase  -- section plate
    end

    -- ── Section disques rotatifs (spinners) ──────────────────
    -- Layout : [Plat_A] → [2 rangées × 3 disques] → [Plat_E] → Checkpoint → Links
    -- SpinnerHub taguées "SpinnerHub" → animées par SpinnerManager.server.lua
    -- Bras taguées "SpinnerArm"       → kill on touch géré par SpinnerManager
    if sectionDef.hasSpinners then
        local DISC_R  = 10
        local DISC_T  = 2
        local STEP    = DISC_R * 2 + 2    -- 22 (c-to-c, gap=2 studs)
        local HUB_R   = 1
        local HUB_H   = 2
        local NUM_ARMS = 3
        local ARM_LEN = 8
        local ARM_H   = 2
        local ARM_W   = 1.2
        local spinW   = STEP * 2 + DISC_R * 2 + 2  -- 66 (couvre les 3 disques + marge)

        local DISC_SURF_Y = yBase + DISC_T / 2        -- yBase + 1
        local ARM_Y       = DISC_SURF_Y + ARM_H / 2   -- yBase + 2
        local armColor    = Color3.fromRGB(255, 90, 180)  -- rose vif

        -- Plateforme d'approche
        -- bord droit à zStart+15, gap de 3 studs avec la rangée 1 (zStart+18)
        part(platFolder, "Plat_A",
            Vector3.new(spinW, 1.2, 14),
            CFrame.new(0, yBase, zStart + 8), sectionDef.color)

        -- 2 rangées de 3 disques (gauche / centre / droite)
        -- Rangée 1 : dz=28  |  Rangée 2 : dz=50  (gap entre rangées = 2 studs)
        local rowDefs = {
            { dz = 28, dirs = { 1, -1,  1} },
            { dz = 50, dirs = {-1,  1, -1} },
        }

        for _, row in ipairs(rowDefs) do
            for i, dx in ipairs({-STEP, 0, STEP}) do
                local discX   = dx
                local discZ   = zStart + row.dz
                local spinDir = row.dirs[i]

                -- Disque (cylindre horizontal)
                local disc = part(platFolder, "Disc",
                    Vector3.new(DISC_T, DISC_R * 2, DISC_R * 2),
                    CFrame.new(discX, yBase, discZ) * CFrame.Angles(0, 0, math.pi / 2),
                    sectionDef.color)
                disc.Shape = Enum.PartType.Cylinder

                -- Moyeu visuel (même couleur lavande que le disque)
                local hubV = part(platFolder, "HubVisual",
                    Vector3.new(HUB_H, HUB_R * 2, HUB_R * 2),
                    CFrame.new(discX, DISC_SURF_Y + HUB_H / 2, discZ) * CFrame.Angles(0, 0, math.pi / 2),
                    sectionDef.color)
                hubV.Shape    = Enum.PartType.Cylinder
                hubV.CanCollide = false

                -- Moyeu tournant invisible (animé par SpinnerManager)
                local spinHub = part(platFolder, "SpinHub",
                    Vector3.new(0.1, 0.1, 0.1),
                    CFrame.new(discX, ARM_Y, discZ),
                    Color3.new(0, 0, 0))
                spinHub.Transparency = 1
                spinHub.CanCollide   = false
                spinHub:SetAttribute("SpinDir", spinDir)
                spinHub:SetAttribute("Speed",   math.rad(100))
                spinHub:SetAttribute("PosX",    discX)
                spinHub:SetAttribute("PosY",    ARM_Y)
                spinHub:SetAttribute("PosZ",    discZ)
                CollectionService:AddTag(spinHub, "SpinnerHub")

                -- Bras (non-anchored, suivent via WeldConstraint)
                for j = 1, NUM_ARMS do
                    local ai    = (j - 1) * (2 * math.pi / NUM_ARMS)
                    local cos_a = math.cos(ai)
                    local sin_a = math.sin(ai)
                    local armCX = discX + cos_a * (HUB_R + ARM_LEN / 2)
                    local armCZ = discZ + sin_a * (HUB_R + ARM_LEN / 2)

                    local arm = part(platFolder, "Arm_" .. j,
                        Vector3.new(ARM_LEN, ARM_H, ARM_W),
                        CFrame.fromMatrix(
                            Vector3.new(armCX, ARM_Y, armCZ),
                            Vector3.new(cos_a, 0, sin_a),
                            Vector3.new(0, 1, 0)
                        ),
                        armColor)
                    arm.Anchored = false

                    local weld  = Instance.new("WeldConstraint")
                    weld.Part0  = spinHub
                    weld.Part1  = arm
                    weld.Parent = arm
                    CollectionService:AddTag(arm, "SpinnerArm")
                end
            end
        end

        -- 3 plateformes de sortie identiques à Plat_A (spinW × 1.2 × 14, couleur lavande)
        -- Gaps de 6 studs entre chaque → facilement franchissables
        -- dz=72 : bord gauche=65 → gap=5 avec rangée 2 (bord droit à dz=60)
        part(platFolder, "Plat_E",
            Vector3.new(spinW, 1.2, 14),
            CFrame.new(0, yBase, zStart + 72), sectionDef.color)
        -- dz=92 : bord gauche=85 → gap=6 avec Plat_E (bord droit=79)
        part(platFolder, "Plat_Link1",
            Vector3.new(spinW, 1.2, 14),
            CFrame.new(0, yBase, zStart + 92), sectionDef.color)
        -- dz=112 : bord gauche=105 → gap=6 avec Plat_Link1 (bord droit=99)
        --          bord droit=119 → gap=3 avec Plat_A Section 8 (bord gauche=122)
        part(platFolder, "Plat_Link2",
            Vector3.new(spinW, 1.2, 14),
            CFrame.new(0, yBase, zStart + 112), sectionDef.color)

        -- Checkpoint au milieu de la sortie
        local cpName = string.format("Checkpoint_%02d", index)
        local cp = part(cpFolder, cpName,
            Vector3.new(spinW + 4, 8, 10),
            CFrame.new(0, yBase + 4, zStart + 90),
            Color3.fromRGB(0, 210, 100), Enum.Material.Neon, 0.6)
        cp.CanCollide = false
        cp:SetAttribute("SectionIdx", index)
        cp:SetAttribute("CheckpointLabel", cpName)
        tag(cp, "Checkpoint")

        return yBase  -- section plate
    end

    -- ── Plateformes (5 par section) ──────────────────────────
    -- Gaps de 6-8 studs entre plateformes (jumpable avec JumpPower=60)
    local yRise = sectionDef.yBias ~= 0 and (sectionDef.yBias * 0.08) or 0
    local platDefs = {
        { dz =  8,  dy = 0,         w = platW,     d = 12, label = "A" },
        { dz = 26,  dy = yRise,     w = platW - 2, d = 10, label = "B" },
        { dz = 44,  dy = yRise * 2, w = platW,     d = 10, label = "C" },
        { dz = 60,  dy = yRise * 3, w = platW - 2, d = 8,  label = "D" },
        { dz = 76,  dy = yRise * 4, w = platW,     d = 12, label = "E" },
    }

    local platParts = {}
    for _, pd in ipairs(platDefs) do
        local p = part(
            platFolder,
            "Plat_" .. pd.label,
            Vector3.new(pd.w, 1.2, pd.d),
            CFrame.new(0, yBase + pd.dy, zStart + pd.dz),
            sectionDef.color
        )
        platParts[pd.label] = p
    end

    -- ── Plateformes de liaison vers la section suivante ──────
    -- Gap total Plat_E → Plat_A suivante = 40 studs en Z.
    -- Deux tremplins comblent ce gap en créant de petits sauts faciles :
    --   Plat_E (dz=76, end=82) →[6]→ Link1 (dz=95) →[5]→ Link2 (dz=112) →[5]→ Plat_A suivante (dz=128)
    -- Le Checkpoint trigger (dz=90, CanCollide=false) est traversé naturellement entre Plat_E et Link1.
    local platEY = yBase + yRise * 4
    if not sectionDef.isEnd then
        part(platFolder, "Plat_Link1",
            Vector3.new(platW - 4, 1.2, 14),
            CFrame.new(0, platEY, zStart + 95),
            sectionDef.color
        )
        part(platFolder, "Plat_Link2",
            Vector3.new(platW - 4, 1.2, 14),
            CFrame.new(0, platEY, zStart + 112),
            sectionDef.color
        )
    end

    -- ── TrapButtons + TrapZones ──────────────────────────────
    -- Le bouton est sur la plateforme AVANT la zone affectée :
    -- l'activateur appuie depuis derrière et le piège frappe devant lui.
    -- Trap 1 : bouton sur B (dz=26), zone sur A (dz=8)  → frappe les joueurs DERRIÈRE
    -- Trap 2 : bouton sur D (dz=60), zone sur C (dz=44) → idem
    -- Le joueur en avance active le piège pour éliminer ceux qui le suivent.
    local trapPositions = {
        { btnDz = 26, btnLabel = "B", zoneDz = 8,  zoneLabel = "A", side =  3 },
        { btnDz = 60, btnLabel = "D", zoneDz = 44, zoneLabel = "C", side = -3 },
    }

    for t, trapDef in ipairs(sectionDef.traps) do
        local tp = trapPositions[t]
        if not tp then break end

        local btnPart   = platParts[tp.btnLabel]
        local btnPlatY  = btnPart  and btnPart.Position.Y  or yBase
        local zonePart  = platParts[tp.zoneLabel]
        local zonePlatY = zonePart and zonePart.Position.Y or yBase

        -- Bouton piège (sur la plateforme AVANT la zone)
        local btnName = string.format("TrapButton_%s_%d", sectionDef.name, t)
        local btn = part(
            trapFolder,
            btnName,
            Vector3.new(3, 1.5, 3),
            CFrame.new(tp.side, btnPlatY + 1.35, zStart + tp.btnDz),
            Color3.fromRGB(220, 50, 50),
            Enum.Material.Neon
        )
        btn:SetAttribute("TrapType",   trapDef)
        btn:SetAttribute("Used",       false)
        btn:SetAttribute("SectionIdx", index)
        tag(btn, "TrapButton")

        -- Zone affectée (sur la plateforme SUIVANTE)
        local zoneName = string.format("TrapZone_%s_%d", sectionDef.name, t)
        local zone = part(
            trapFolder,
            zoneName,
            Vector3.new(platW, 8, 12),
            CFrame.new(0, zonePlatY + 4, zStart + tp.zoneDz),
            Color3.fromRGB(255, 80, 80),
            Enum.Material.Neon,
            0.85
        )
        zone.CanCollide = false
        zone:SetAttribute("TrapType", trapDef)
        tag(zone, "TrapZone")

        -- Lien bouton → zone
        btn:SetAttribute("LinkedZone", zoneName)
    end

    -- ── Bouton Sacrifice ────────────────────────────────────
    if sectionDef.sac then
        local platC    = platParts["C"]
        local platY    = platC and platC.Position.Y or yBase

        local sacName  = string.format("SacrificeButton_%s", sectionDef.name)
        local sac = part(
            sacFolder,
            sacName,
            Vector3.new(3, 1.5, 3),
            CFrame.new(-5, platY + 1.35, zStart + 44),  -- dz=44 = Plat C
            Color3.fromRGB(255, 215, 0),  -- doré
            Enum.Material.Neon
        )
        sac:SetAttribute("Used",       false)
        sac:SetAttribute("SectionIdx", index)
        tag(sac, "SacrificeButton")
    end

    -- ── Checkpoint (fin de section, sauf arrivée) ────────────
    if not sectionDef.isEnd then
        local platE = platParts["E"]
        local platY = platE and platE.Position.Y or yBase

        local cpName = string.format("Checkpoint_%02d", index)
        local cp = part(
            cpFolder,
            cpName,
            Vector3.new(platW + 4, 8, 10),
            CFrame.new(0, platY + 4, zStart + 90),  -- juste après Plat E (dz=76)
            Color3.fromRGB(0, 210, 100),
            Enum.Material.Neon,
            0.6
        )
        cp.CanCollide = false
        cp:SetAttribute("SectionIdx", index)
        cp:SetAttribute("CheckpointLabel", cpName)
        tag(cp, "Checkpoint")

    -- ── ArrivalZone (Section 8) ──────────────────────────────
    else
        -- platEY = hauteur réelle de Plat_E (la dernière plateforme de la section)
        -- L'arrivée est POSÉE sur cette plateforme, pas à yBase qui est bien plus bas

        -- Grande plateforme d'arrivée au niveau de Plat_E (dz=76 → prolonge vers +Z)
        part(
            secFolder,
            "PlateformeArrivee",
            Vector3.new(30, 1.2, 50),
            CFrame.new(0, platEY, zStart + 98),  -- centre à dz=98, couvre dz=73→123
            sectionDef.color
        )

        -- Zone de déclenchement (trigger invisible, traversée par le joueur)
        local arrival = part(
            secFolder,
            "ArrivalZone",
            Vector3.new(30, 10, 8),
            CFrame.new(0, platEY + 5, zStart + 110),  -- au-dessus de la plateforme d'arrivée
            Color3.fromRGB(255, 215, 0),
            Enum.Material.Neon,
            0.4
        )
        arrival.CanCollide = false
        tag(arrival, "ArrivalZone")
    end

    return platEY  -- la section suivante démarre à cette hauteur
end

-- ============================================================
-- LOBBY
-- ============================================================

local function buildLobby(ws)
    local lob = folder(ws, "Lobby")

    -- Sol du lobby (surface marchable, même hauteur qu'avant)
    part(lob, "SolLobby",
        Vector3.new(140, 1, 140),
        CFrame.new(0, BASE_Y - 0.5, 0),
        Color3.fromRGB(255, 166, 201),  -- carnation pink
        Enum.Material.SmoothPlastic
    )

    -- Kill floor invisible — tue le joueur quand il tombe (Y=-15, entre plateformes basses≈0 et sol chocolat)
    local kf = part(lob, "KillFloor",
        Vector3.new(6000, 1, 6000),
        CFrame.new(0, -15, 500),
        Color3.fromRGB(255, 0, 0),
        Enum.Material.SmoothPlastic,
        1  -- totalement transparent
    )
    kf.CanCollide = true
    tag(kf, "KillFloor")

    -- Sol chocolat étendu — arrière-plan visuel SOUS tout le parcours
    -- CanCollide=false : les joueurs tombent à travers (respawn géré par CheckpointManager)
    -- Positionné à Y=-25 : bien en dessous des plateformes les plus basses (Y≈0)
    local sol = part(lob, "Sol",
        Vector3.new(4000, 4, 4000),
        CFrame.new(0, -25, 500),
        Color3.fromRGB(255, 166, 201),  -- carnation pink
        Enum.Material.SmoothPlastic
    )
    sol.CanCollide = false

    local tex = Instance.new("Texture")
    tex.Texture       = "rbxassetid://12516487920"
    tex.Transparency  = 0
    tex.Face          = Enum.NormalId.Top
    tex.StudsPerTileU = 10
    tex.StudsPerTileV = 10
    tex.Parent        = sol

    -- Murs de l'arène (4 murs)
    local arene = folder(lob, "Arena")
    local walls = {
        { Vector3.new(140, 22, 2), Vector3.new(  0, BASE_Y + 11, -70) },
        { Vector3.new(140, 22, 2), Vector3.new(  0, BASE_Y + 11,  70) },
        { Vector3.new(2, 22, 140), Vector3.new(-70, BASE_Y + 11,   0) },
        { Vector3.new(2, 22, 140), Vector3.new( 70, BASE_Y + 11,   0) },
    }
    for i, w in ipairs(walls) do
        part(arene, "Mur_" .. i, w[1], CFrame.new(w[2]),
            Color3.fromRGB(255, 180, 200))
    end

    -- SpawnLocations (16 spots, grille 4×4)
    local spawnFolder = folder(lob, "SpawnLocations")
    for i = 1, 16 do
        local row = math.floor((i - 1) / 4)
        local col = (i - 1) % 4
        local sp  = Instance.new("SpawnLocation")
        sp.Name      = "Spawn_" .. i
        sp.Size      = Vector3.new(5, 1, 5)
        sp.CFrame    = CFrame.new(-15 + col * 10, BASE_Y + 0.5, -25 + row * 10)
        sp.Anchored      = true
        sp.Neutral       = true
        sp.Duration      = 0
        sp.Transparency  = 1        -- invisible mais toujours fonctionnel
        sp.TopSurface    = Enum.SurfaceType.Smooth
        sp.BottomSurface = Enum.SurfaceType.Smooth
        sp.Parent        = spawnFolder
    end

    -- Panneaux Leaderboard (2 panneaux face aux joueurs)
    local lbFolder = folder(lob, "Leaderboards")
    for i, pos in ipairs({
        Vector3.new(-30, BASE_Y + 10, 55),
        Vector3.new( 30, BASE_Y + 10, 55),
    }) do
        local board = part(lbFolder, "Leaderboard_" .. i,
            Vector3.new(14, 18, 1),
            CFrame.new(pos),
            Color3.fromRGB(20, 20, 30),
            Enum.Material.SmoothPlastic
        )
        board:SetAttribute("LeaderboardType", i == 1 and "Traitor" or "Martyr")

        -- Pied du panneau
        part(lbFolder, "Pied_" .. i,
            Vector3.new(3, BASE_Y, 3),
            CFrame.new(pos.X, BASE_Y / 2, pos.Z),
            Color3.fromRGB(60, 40, 20)
        )
    end

    -- Portail de départ
    local portal = part(lob, "Portail",
        Vector3.new(20, 14, 2),
        CFrame.new(0, BASE_Y + 7, 58),
        Color3.fromRGB(100, 60, 255),
        Enum.Material.Neon,
        0.35
    )
    portal:SetAttribute("IsPortal", true)

    return lob
end

-- ============================================================
-- GÉNÉRATION PRINCIPALE
-- ============================================================

-- Nettoyage si re-run
if Workspace:FindFirstChild("Course") then Workspace.Course:Destroy() end
if Workspace:FindFirstChild("Lobby")  then Workspace.Lobby:Destroy()  end

print("[MapBuilder] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("[MapBuilder] Génération du squelette map...")

-- Lobby (construit à X=0 puis déplacé loin du parcours)
buildLobby(Workspace)
do
    local lob = Workspace:FindFirstChild("Lobby")
    if lob then
        for _, desc in ipairs(lob:GetDescendants()) do
            if desc:IsA("BasePart")
               and desc.Name ~= "Sol"       -- sol chocolat reste sous le parcours (X=0)
               and desc.Name ~= "KillFloor" -- kill floor reste sous le parcours (X=0)
            then
                desc.CFrame = desc.CFrame + Vector3.new(LOBBY_OFFSET_X, 0, 0)
            end
        end
    end
end
print("[MapBuilder] ✅ Lobby généré (spawns, panneaux, portail) — déplacé à X=" .. LOBBY_OFFSET_X)

-- Parcours
local courseFolder = folder(Workspace, "Course")
local currentY = BASE_Y   -- hauteur chaînée entre sections
for i, sectionDef in ipairs(SECTIONS) do
    currentY = buildSection(courseFolder, sectionDef, i, currentY)
    print(string.format("[MapBuilder] ✅ %d/%d — %s  (fin Y=%.1f)  %s",
        i, #SECTIONS, sectionDef.name, currentY, sectionDef.note))
end

-- Résumé des tags créés
local counts = { TrapButton = 0, SacrificeButton = 0, Checkpoint = 0, TrapZone = 0 }
for tagName in pairs(counts) do
    counts[tagName] = #CollectionService:GetTagged(tagName)
end

print("[MapBuilder] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print(string.format("[MapBuilder] Tags créés → TrapButton: %d | SacrificeButton: %d | Checkpoint: %d | TrapZone: %d",
    counts.TrapButton, counts.SacrificeButton, counts.Checkpoint, counts.TrapZone))
print("[MapBuilder] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("[MapBuilder] → Copie 'Course' et 'Lobby' depuis l'Explorer")
print("[MapBuilder] → Stop ■ → Colle dans Workspace → Re-coche 'Disabled'")
