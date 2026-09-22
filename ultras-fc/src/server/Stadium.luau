--!strict
--[[
	O estadio.

	Um jogo de ultras e a noite: bancada escura, relvado a brilhar debaixo dos
	holofotes, e as cores da claque a ler-se de longe. Por isso quase tudo aqui e
	escuro de proposito — o betao claro ao meio-dia fazia isto parecer um parque
	de estacionamento, e apagava as tochas, que sao o que interessa ver.

	Continua a ser feito de pecas soltas. Quando construires o teu a mao, poe
	Config.Stadium.build a false para o codigo nao te apagar o trabalho.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Stadium = {}

local S = Config.Stadium

-- Escuros, e escolhidos: o cinzento neutro e o que faz isto parecer betao barato.
local PITCH_DARK = Color3.fromRGB(34, 74, 43)
local PITCH_LIGHT = Color3.fromRGB(43, 92, 52)
local LINE = Color3.fromRGB(222, 228, 224)
local TERRACE = Color3.fromRGB(46, 49, 56)
local TERRACE_EDGE = Color3.fromRGB(32, 35, 41)
local STRUCTURE = Color3.fromRGB(26, 28, 33)

type PartOpts = {
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
}

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	parent: Instance,
	opts: PartOpts?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Anchored = true
	p.CastShadow = true
	p.Material = (opts and opts.material) or Enum.Material.Concrete
	p.Transparency = (opts and opts.transparency) or 0
	p.Reflectance = (opts and opts.reflectance) or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

--------------------------------------------------------------------------------
-- Noite
--------------------------------------------------------------------------------

local function setNight()
	Lighting.ClockTime = 20.2
	Lighting.Brightness = 1.1
	Lighting.Ambient = Color3.fromRGB(28, 31, 38)
	Lighting.OutdoorAmbient = Color3.fromRGB(32, 36, 44)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 900
	Lighting.FogColor = Color3.fromRGB(18, 20, 26)

	-- Da o ar pesado por cima dos holofotes. E o que faz um estadio nocturno
	-- parecer um estadio nocturno e nao um modelo iluminado.
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	local atmosphere = existing or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(150, 158, 175)
	atmosphere.Decay = Color3.fromRGB(70, 78, 95)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting

	local bloomExisting = Lighting:FindFirstChildOfClass("BloomEffect")
	local bloom = bloomExisting or Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
end

--------------------------------------------------------------------------------
-- Relvado
--------------------------------------------------------------------------------

local function buildPitch(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Pitch"
	folder.Parent = parent

	-- As faixas do corte sao o detalhe que faz um relvado parecer tratado. Sao
	-- baratas: dois verdes alternados, nada mais.
	local stripes = 10
	local stripeWidth = S.pitchWidth / stripes
	for i = 1, stripes do
		local z = -S.pitchWidth / 2 + (i - 0.5) * stripeWidth
		part(
			"Stripe" .. i,
			Vector3.new(S.pitchLength, 1, stripeWidth),
			CFrame.new(0, -0.5, z),
			(i % 2 == 0) and PITCH_LIGHT or PITCH_DARK,
			folder,
			{ material = Enum.Material.Grass }
		)
	end

	local function line(name: string, size: Vector3, cf: CFrame)
		part(name, size, cf, LINE, folder, { material = Enum.Material.Grass })
	end

	line("Halfway", Vector3.new(0.5, 1.05, S.pitchWidth), CFrame.new(0, -0.47, 0))
	line("TouchNorth", Vector3.new(S.pitchLength, 1.05, 0.5), CFrame.new(0, -0.47, S.pitchWidth / 2))
	line("TouchSouth", Vector3.new(S.pitchLength, 1.05, 0.5), CFrame.new(0, -0.47, -S.pitchWidth / 2))

	-- Circulo central, feito de segmentos curtos em roda.
	local segments = 36
	local radius = 10
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local cf = CFrame.new(math.cos(angle) * radius, -0.47, math.sin(angle) * radius)
			* CFrame.Angles(0, -angle, 0)
		line("Circle" .. i, Vector3.new(0.5, 1.05, (math.pi * 2 * radius) / segments + 0.3), cf)
	end

	-- Grandes areas e balizas.
	for _, sign in { 1, -1 } do
		local boxX = (S.pitchLength / 2 - 8) * sign
		line("BoxLine" .. sign, Vector3.new(0.5, 1.05, 40), CFrame.new(boxX, -0.47, 0))
		line("BoxSide" .. sign .. "A", Vector3.new(16, 1.05, 0.5), CFrame.new(boxX + 8 * sign, -0.47, 20))
		line("BoxSide" .. sign .. "B", Vector3.new(16, 1.05, 0.5), CFrame.new(boxX + 8 * sign, -0.47, -20))
		line("Goalline" .. sign, Vector3.new(0.5, 1.05, S.pitchWidth), CFrame.new((S.pitchLength / 2) * sign, -0.47, 0))

		local goalX = (S.pitchLength / 2 - 0.5) * sign
		local goal = Instance.new("Folder")
		goal.Name = "Goal" .. (sign > 0 and "East" or "West")
		goal.Parent = folder

		local metal: PartOpts = { material = Enum.Material.Metal, reflectance = 0.05 }
		part("PostLeft", Vector3.new(0.8, 9, 0.8), CFrame.new(goalX, 4.5, -8), LINE, goal, metal)
		part("PostRight", Vector3.new(0.8, 9, 0.8), CFrame.new(goalX, 4.5, 8), LINE, goal, metal)
		part("Crossbar", Vector3.new(0.8, 0.8, 16.8), CFrame.new(goalX, 9, 0), LINE, goal, metal)
		part(
			"Net",
			Vector3.new(4, 9, 16.8),
			CFrame.new(goalX + 2 * sign, 4.5, 0),
			Color3.fromRGB(210, 214, 220),
			goal,
			{ material = Enum.Material.Fabric, transparency = 0.72 }
		)
	end
end

--------------------------------------------------------------------------------
-- Bancadas
--------------------------------------------------------------------------------

local spawnPoints: { [string]: Vector3 } = {}

local function buildStand(teamId: string, parent: Instance)
	local team = Config.Teams[teamId]
	local side = team.side

	local folder = Instance.new("Folder")
	folder.Name = "Stand_" .. teamId
	folder.Parent = parent

	local firstRowZ = (S.pitchWidth / 2 + S.standGap) * side
	local width = S.pitchLength + 26

	for row = 1, S.standRows do
		-- Cada fila e um bloco macico do chao ate ao seu topo. Blocos soltos a
		-- alturas diferentes ficavam a flutuar; e assentarem no chao que faz uma
		-- escadaria.
		local topY = row * S.rowHeight
		local z = firstRowZ + (row - 1) * S.rowDepth * side

		part(
			"Row" .. row,
			Vector3.new(width, topY, S.rowDepth),
			CFrame.new(0, topY / 2, z),
			TERRACE,
			folder
		)

		-- A beira do degrau, mais escura: e o que separa uma fila da seguinte
		-- quando se olha de longe.
		part(
			"Lip" .. row,
			Vector3.new(width, 0.35, 0.5),
			CFrame.new(0, topY + 0.18, z - (S.rowDepth / 2 - 0.25) * side),
			TERRACE_EDGE,
			folder
		)

		-- Faixas da claque de tres em tres filas. Poucas e melhor do que todas:
		-- a bancada le-se na mesma e nao fica um arco-iris.
		if row % 3 == 0 then
			part(
				"Colours" .. row,
				Vector3.new(width - 8, 0.5, 1.2),
				CFrame.new(0, topY + 0.25, z + 0.6 * side),
				team.color,
				folder,
				{ material = Enum.Material.SmoothPlastic }
			)
		end
	end

	local topY = S.standRows * S.rowHeight
	local backZ = firstRowZ + (S.standRows - 1) * S.rowDepth * side + (S.rowDepth / 2 + 1) * side

	part("BackWall", Vector3.new(width, topY + 16, 2), CFrame.new(0, (topY + 16) / 2, backZ), STRUCTURE, folder)

	-- A faixa da claque na parede do fundo, bem visivel do relvado.
	part(
		"Banner",
		Vector3.new(width - 20, 6, 0.6),
		CFrame.new(0, topY + 8, backZ - 1.2 * side),
		team.color,
		folder,
		{ material = Enum.Material.Fabric }
	)

	-- Cobertura. Fecha a bancada por cima, o que prende a luz e o fumo la dentro
	-- em vez de se perderem no ceu.
	local depth = S.standRows * S.rowDepth + 6
	part(
		"Roof",
		Vector3.new(width + 4, 1.2, depth),
		CFrame.new(0, topY + 17, firstRowZ + (depth / 2 - S.rowDepth) * side),
		STRUCTURE,
		folder,
		{ material = Enum.Material.Metal }
	)

	local spawnRow = math.ceil(S.standRows / 2)
	spawnPoints[teamId] = Vector3.new(
		0,
		spawnRow * S.rowHeight + 3.5,
		firstRowZ + (spawnRow - 1) * S.rowDepth * side
	)
end

--------------------------------------------------------------------------------
-- Holofotes
--------------------------------------------------------------------------------

local function buildFloodlights(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Floodlights"
	folder.Parent = parent

	local standDepth = S.standRows * S.rowDepth
	local height = 54

	for _, corner in { Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) } do
		local x = corner.X * (S.pitchLength / 2 + 20)
		local z = corner.Y * (S.pitchWidth / 2 + standDepth + 16)

		part(
			"Mast",
			Vector3.new(2.5, height, 2.5),
			CFrame.new(x, height / 2, z),
			STRUCTURE,
			folder,
			{ material = Enum.Material.Metal }
		)

		local rig = part(
			"Rig",
			Vector3.new(16, 8, 2),
			CFrame.new(x, height, z),
			STRUCTURE,
			folder,
			{ material = Enum.Material.Metal }
		)

		-- O painel que se ve aceso da bancada.
		local lamp = part(
			"Lamps",
			Vector3.new(15, 7, 0.6),
			CFrame.new(x, height, z - 1.2 * corner.Y),
			Color3.fromRGB(255, 252, 235),
			folder,
			{ material = Enum.Material.Neon }
		)
		lamp.CastShadow = false

		-- Apontado ao centro do relvado, que e o que ilumina a coisa toda.
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 105
		light.Brightness = 4.5
		light.Range = 260
		light.Color = Color3.fromRGB(238, 244, 255)
		light.Shadows = true
		light.Parent = rig

		rig.CFrame = CFrame.lookAt(Vector3.new(x, height, z), Vector3.new(0, 0, 0))
	end
end

--------------------------------------------------------------------------------

function Stadium.spawnPoint(teamId: string): Vector3?
	return spawnPoints[teamId]
end

function Stadium.build()
	if not S.build then
		return
	end

	local existing = workspace:FindFirstChild("Stadium")
	if existing then
		existing:Destroy()
	end

	setNight()

	local root = Instance.new("Folder")
	root.Name = "Stadium"
	root.Parent = workspace

	buildPitch(root)
	for _, teamId in Config.TeamOrder do
		buildStand(teamId, root)
	end
	buildFloodlights(root)
end

return Stadium
