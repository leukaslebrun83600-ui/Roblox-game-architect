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
local COURSE_START_Z  = 200   -- Z du point de départ du parcours (loin du lobby)
local BASE_Y          = 10    -- hauteur du sol de base

-- Définition exacte des 8 sections (source : PRD 03)
local SECTIONS = {
    {
        name   = "Section_01_Caramel",
        color  = Color3.fromRGB(255, 213,  79),  -- caramel doré
        traps  = { "FloorCollapse" },
        sac    = false,
        yBias  = 0,   -- décalage Y par rapport au sol de base
        note   = "Intro tutoriel — sauts larges, difficulté facile",
    },
    {
        name   = "Section_02_Cascade",
        color  = Color3.fromRGB(255, 140,  80),  -- orange bonbon
        traps  = { "Projectile" },
        sac    = true,
        yBias  = -8,  -- escalier descendant
        note   = "Première introduction au bouton Sacrifice",
    },
    {
        name   = "Section_03_Guimauve",
        color  = Color3.fromRGB(240, 240, 255),  -- guimauve blanche
        traps  = { "WallPusher", "WallPusher" },
        sac    = false,
        yBias  = -8,
        narrow = true,  -- pont étroit (largeur réduite)
        note   = "Pont étroit — murs pousseurs des deux côtés",
    },
    {
        name   = "Section_04_Sucette",
        color  = Color3.fromRGB(255, 100, 200),  -- rose vif
        traps  = { "FloorCollapse" },
        sac    = true,
        yBias  = 20,  -- section qui monte (tour verticale)
        note   = "Première section verticale — montée en spirale",
    },
    {
        name   = "Section_05_Berlingots",
        color  = Color3.fromRGB(80, 200, 120),   -- vert bonbon
        traps  = { "FloorCollapse", "Projectile" },
        sac    = true,
        yBias  = 20,
        note   = "Obstacles visuels denses — sauts plus précis",
    },
    {
        name   = "Section_06_Chocolat",
        color  = Color3.fromRGB(139, 80, 30),    -- chocolat brun
        traps  = { "WallPusher", "FloorCollapse" },
        sac    = true,
        yBias  = 30,  -- grande pente montante
        note   = "Pente raide — joueurs regroupés, parfait pour les pièges",
    },
    {
        name   = "Section_07_Barbe",
        color  = Color3.fromRGB(255, 182, 255),  -- barbe à papa rose
        traps  = { "Projectile", "FloorCollapse" },
        sac    = true,
        yBias  = 50,  -- très haute — plateformes flottantes
        note   = "Section la plus difficile — hauteur maximale",
    },
    {
        name   = "Section_08_Chateau",
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
        Color3.fromRGB(87, 45, 7),
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
        Color3.fromRGB(87, 45, 7),
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
        sp.Anchored  = true
        sp.Neutral   = true
        sp.Duration  = 0
        sp.Parent    = spawnFolder
    end

    -- Pont reliant le lobby au parcours (plancher solide de Z=68 à Z=200)
    part(lob, "Pont",
        Vector3.new(20, 1, 134),
        CFrame.new(0, BASE_Y - 0.5, 134),  -- couvre Z=67 à Z=201
        Color3.fromRGB(210, 190, 150)
    )

    -- Point de départ de manche (marqueur visuel + plateforme physique)
    local depart = part(lob, "DebutManche",
        Vector3.new(30, 1, 10),
        CFrame.new(0, BASE_Y + 0.5, COURSE_START_Z - 20),
        Color3.fromRGB(100, 200, 255),
        Enum.Material.Neon,
        0.5
    )
    depart:SetAttribute("IsStartPad", true)

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

-- Lobby
buildLobby(Workspace)
print("[MapBuilder] ✅ Lobby généré (spawns, panneaux, portail)")

-- Parcours
local courseFolder = folder(Workspace, "Course")
local currentY = BASE_Y   -- hauteur chaînée entre sections
for i, sectionDef in ipairs(SECTIONS) do
    currentY = buildSection(courseFolder, sectionDef, i, currentY)
    print(string.format("[MapBuilder] ✅ %d/8 — %s  (fin Y=%.1f)  %s",
        i, sectionDef.name, currentY, sectionDef.note))
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
