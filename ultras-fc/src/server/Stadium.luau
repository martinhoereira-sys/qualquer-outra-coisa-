--!strict
--[[
	O estadio.

	Pequeno e arrumado, de proposito. Quatro bancadas rectas com os cantos
	abertos — e assim que sao os recintos pequenos a serio, e evita a geometria
	de cantos curvos que so servia para o fazer enorme e confuso.

	As medidas vem de um recinto real, convertidas para studs: degrau de 0,8 m,
	inclinacao de 34 graus, escadas de 24 em 24 m para ninguem ficar a mais de
	12 m de uma. E dai que vem a divisao em blocos, que e o que faz uma bancada
	parecer arrumada em vez de uma rampa unica.

	Fim de tarde, nao noite: a luz vem do sol, rasante, e quase nao ha candeeiros
	acesos. O estadio anterior tinha luzes a mais por estar escuro de mais — era
	o escuro que estava errado, nao a falta de luz.

	Construido de pecas soltas. Para o substituires pelo teu, poe
	Config.Stadium.build a false.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local City = require(script.Parent:WaitForChild("City"))

local Stadium = {}

local S = Config.Stadium

local STAND_DEPTH = S.rows * S.rowDepth
local TOP_Y = S.rows * S.rowHeight
local INNER_X = S.pitchLength / 2 + S.standGap -- frente das bancadas de topo
local INNER_Z = S.pitchWidth / 2 + S.standGap -- frente das bancadas laterais

local GRASS_A = Color3.fromRGB(64, 122, 62)
local GRASS_B = Color3.fromRGB(76, 138, 72)
local LINE = Color3.fromRGB(236, 240, 236)
local CONCRETE = Color3.fromRGB(168, 170, 174)
local CONCRETE_DARK = Color3.fromRGB(134, 136, 142)
local STEEL = Color3.fromRGB(196, 198, 202)
local SEAT_A = Color3.fromRGB(96, 104, 120)
local SEAT_B = Color3.fromRGB(80, 88, 104)
local RAIL = Color3.fromRGB(232, 234, 238)
local BOARD = Color3.fromRGB(38, 41, 48)
local ASPHALT = Color3.fromRGB(88, 90, 96)

type Opts = { material: Enum.Material?, transparency: number? }

local function part(name: string, size: Vector3, cf: CFrame, colour: Color3, parent: Instance, opts: Opts?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Anchored = true
	p.Material = (opts and opts.material) or Enum.Material.Concrete
	p.Transparency = (opts and opts.transparency) or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

--------------------------------------------------------------------------------
-- Fim de tarde
--------------------------------------------------------------------------------

local function setAfternoon()
	-- Sol baixo, sombras compridas. E a hora a que se joga, e e a unica luz de
	-- que o recinto precisa.
	Lighting.ClockTime = 17.4
	Lighting.GeographicLatitude = 41
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(118, 114, 108)
	Lighting.OutdoorAmbient = Color3.fromRGB(154, 150, 142)
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 2600
	Lighting.FogColor = Color3.fromRGB(198, 196, 190)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(210, 200, 186)
	atmosphere.Decay = Color3.fromRGB(128, 122, 116)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.1
	atmosphere.Parent = Lighting

	-- Um bloom discreto, so para o sol rasante ter peso.
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 18
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
end

--------------------------------------------------------------------------------
-- Relvado
--------------------------------------------------------------------------------

local function buildPitch(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Pitch"
	folder.Parent = parent

	-- Faixas do corte: dois verdes alternados, e o detalhe que faz um relvado
	-- parecer tratado.
	local stripes = 10
	local stripeWidth = S.pitchWidth / stripes
	for i = 1, stripes do
		local z = -S.pitchWidth / 2 + (i - 0.5) * stripeWidth
		part("Stripe" .. i, Vector3.new(S.pitchLength, 1, stripeWidth), CFrame.new(0, -0.5, z), (i % 2 == 0) and GRASS_B or GRASS_A, folder, {
			material = Enum.Material.Grass,
		})
	end

	local function line(name: string, size: Vector3, cf: CFrame)
		part(name, size, cf, LINE, folder, { material = Enum.Material.Grass })
	end

	line("Halfway", Vector3.new(0.5, 1.04, S.pitchWidth), CFrame.new(0, -0.48, 0))
	line("TouchN", Vector3.new(S.pitchLength, 1.04, 0.5), CFrame.new(0, -0.48, S.pitchWidth / 2))
	line("TouchS", Vector3.new(S.pitchLength, 1.04, 0.5), CFrame.new(0, -0.48, -S.pitchWidth / 2))

	for i = 1, 36 do
		local angle = (i / 36) * math.pi * 2
		line(
			"Circle" .. i,
			Vector3.new(0.5, 1.04, (math.pi * 2 * 10) / 36 + 0.3),
			CFrame.new(math.cos(angle) * 10, -0.48, math.sin(angle) * 10) * CFrame.Angles(0, -angle, 0)
		)
	end

	for _, sign in { 1, -1 } do
		local boxX = (S.pitchLength / 2 - 8) * sign
		line("Box" .. sign, Vector3.new(0.5, 1.04, 40), CFrame.new(boxX, -0.48, 0))
		line("BoxA" .. sign, Vector3.new(16, 1.04, 0.5), CFrame.new(boxX + 8 * sign, -0.48, 20))
		line("BoxB" .. sign, Vector3.new(16, 1.04, 0.5), CFrame.new(boxX + 8 * sign, -0.48, -20))
		line("Goalline" .. sign, Vector3.new(0.5, 1.04, S.pitchWidth), CFrame.new((S.pitchLength / 2) * sign, -0.48, 0))

		local goalX = (S.pitchLength / 2 - 0.5) * sign
		local metal: Opts = { material = Enum.Material.Metal }
		part("PostL", Vector3.new(0.7, 8, 0.7), CFrame.new(goalX, 4, -8), LINE, folder, metal)
		part("PostR", Vector3.new(0.7, 8, 0.7), CFrame.new(goalX, 4, 8), LINE, folder, metal)
		part("Bar", Vector3.new(0.7, 0.7, 16.7), CFrame.new(goalX, 8, 0), LINE, folder, metal)
		part("Net", Vector3.new(4, 8, 16.7), CFrame.new(goalX + 2 * sign, 4, 0), Color3.fromRGB(222, 226, 232), folder, {
			material = Enum.Material.Fabric,
			transparency = 0.7,
		})
	end

	-- Placards e bancos de suplentes: sem a barreira o relvado encostava a
	-- bancada, o que nao acontece em lado nenhum.
	for _, side in { 1, -1 } do
		part("BoardZ", Vector3.new(S.pitchLength + 6, 2.6, 0.5), CFrame.new(0, 1.3, (S.pitchWidth / 2 + 3) * side), BOARD, folder, {
			material = Enum.Material.SmoothPlastic,
		})
		part("BoardX", Vector3.new(0.5, 2.6, S.pitchWidth + 6), CFrame.new((S.pitchLength / 2 + 3) * side, 1.3, 0), BOARD, folder, {
			material = Enum.Material.SmoothPlastic,
		})
	end

	for _, side in { 1, -1 } do
		local z = S.pitchWidth / 2 + 5.5
		part("DugoutRoof", Vector3.new(22, 0.4, 6), CFrame.new(side * 18, 4.6, z), STEEL, folder, { material = Enum.Material.Metal })
		part("DugoutBench", Vector3.new(20, 0.9, 1.8), CFrame.new(side * 18, 1.6, z), CONCRETE_DARK, folder)
		part("DugoutBack", Vector3.new(22, 4.6, 0.5), CFrame.new(side * 18, 2.3, z + 2.9), CONCRETE, folder)
	end
end

--------------------------------------------------------------------------------
-- Bancadas
--------------------------------------------------------------------------------

local spawnPoints: { [string]: Vector3 } = {}

--[[
	Uma bancada recta, dividida em blocos.

	`alongZ` diz se ela corre ao longo do eixo Z (bancadas de topo) ou do X
	(laterais). `side` e de que lado do relvado esta.

	Cada bloco e um troco de degraus; entre blocos fica uma escada, e no fundo de
	cada escada abre-se um vomitorio — a porta por onde se entra na bancada. E
	essa grelha, escada-bloco-escada, que faz uma bancada ler-se como arrumada.
]]
local function buildStand(alongZ: boolean, side: number, blocks: number, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = (alongZ and "EndStand" or "SideStand") .. (side > 0 and "A" or "B")
	folder.Parent = parent

	local run = alongZ and S.pitchWidth or S.pitchLength -- largura da bancada
	local inner = alongZ and INNER_X or INNER_Z

	local gangways = blocks + 1
	local blockRun = (run - gangways * S.gangwayWidth) / blocks

	local function place(name: string, length: number, depth: number, height: number, along: number, across: number, y: number, colour: Color3, opts: Opts?)
		local size = alongZ and Vector3.new(depth, height, length) or Vector3.new(length, height, depth)
		local cf = alongZ and CFrame.new(across, y, along) or CFrame.new(along, y, across)
		part(name, size, cf, colour, folder, opts)
	end

	for row = 1, S.rows do
		local topY = row * S.rowHeight
		local across = (inner + (row - 0.5) * S.rowDepth) * side

		-- Os degraus de cada bloco.
		for b = 1, blocks do
			local centre = -run / 2 + b * S.gangwayWidth + (b - 0.5) * blockRun
			place("Step", blockRun, S.rowDepth, topY, centre, across, topY / 2, CONCRETE)

			local seatColour = (row % 2 == 0) and SEAT_A or SEAT_B
			place("Seats", blockRun - 1.2, S.rowDepth - 0.8, 0.4, centre, across, topY + 0.2, seatColour, {
				material = Enum.Material.SmoothPlastic,
			})
		end

		-- As escadas entre blocos, um degrau mais baixas para se verem.
		for g = 1, gangways do
			local centre = -run / 2 + (g - 0.5) * S.gangwayWidth + (g - 1) * blockRun
			place("Gangway", S.gangwayWidth, S.rowDepth, topY, centre, across, topY / 2, CONCRETE_DARK)
		end
	end

	--[[
		A parede do fundo, com um vomitorio por escada.

		Sao vaos ao nivel do chao: entra-se por baixo da bancada e sai-se no topo
		dela. E por isso que as escadas e os vomitorios tem de estar alinhados —
		um vomitorio que nao desemboque numa escada nao leva a lado nenhum.
	]]
	local backAcross = (inner + STAND_DEPTH + 1) * side
	local backHeight = TOP_Y + 9

	for g = 0, gangways do
		local from = -run / 2 + g * (S.gangwayWidth + blockRun) + S.gangwayWidth / 2
		local to = from + blockRun
		if g == 0 then
			from = -run / 2 - 4
			to = -run / 2 + S.gangwayWidth / 2 - S.vomitoryWidth / 2
		elseif g == gangways then
			from = run / 2 - S.gangwayWidth / 2 + S.vomitoryWidth / 2
			to = run / 2 + 4
		end

		if to > from then
			place("Back", to - from, 1.5, backHeight, (from + to) / 2, backAcross, backHeight / 2, CONCRETE_DARK)
		end
	end

	-- A verga por cima de cada vomitorio, para a parede nao ficar com buracos
	-- abertos ate ao telhado.
	for g = 1, gangways - 1 do
		local centre = -run / 2 + (g - 0.5) * S.gangwayWidth + (g - 1) * blockRun
		place("Lintel", S.vomitoryWidth, 1.5, backHeight - 9, centre, backAcross, 9 + (backHeight - 9) / 2, CONCRETE_DARK)
	end

	-- Cobertura: uma pala simples, apoiada em pilares atras.
	local roofAcross = (inner + STAND_DEPTH / 2) * side
	place("Roof", run + 4, STAND_DEPTH + 5, 0.8, 0, roofAcross, TOP_Y + 10, STEEL, { material = Enum.Material.Metal })

	for g = 0, gangways do
		local centre = -run / 2 + g * (S.gangwayWidth + blockRun)
		place("Column", 1.2, 1.2, TOP_Y + 10, centre, backAcross, (TOP_Y + 10) / 2, STEEL, { material = Enum.Material.Metal })
	end

	return blockRun, gangways
end

--------------------------------------------------------------------------------
-- A frente das claques
--------------------------------------------------------------------------------

--[[
	A vedacao a frente das duas bancadas laterais, e a tarja presa nela.

	E a imagem de uma bancada de ultras: malha a toda a largura, a tarja da
	claque atada por cima. Sem a malha a bancada acaba no ar e nao ha onde
	prender nada.
]]
local function buildClaqueFront(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "ClaqueFront"
	folder.Parent = parent

	for _, teamId in Config.TeamOrder do
		local team = Config.Teams[teamId]
		local side = team.side
		local z = (INNER_Z - 1.5) * side
		local width = S.pitchLength

		for i = 0, 22 do
			local x = -width / 2 + i * (width / 22)
			part("Post", Vector3.new(0.3, 6, 0.3), CFrame.new(x, 3, z), RAIL, folder, { material = Enum.Material.Metal })
		end

		local mesh = part("Mesh", Vector3.new(width, 5.4, 0.1), CFrame.new(0, 2.9, z), RAIL, folder, {
			material = Enum.Material.DiamondPlate,
			transparency = 0.6,
		})
		mesh.CanCollide = false

		part("Rail", Vector3.new(width, 0.25, 0.4), CFrame.new(0, 5.9, z), RAIL, folder, { material = Enum.Material.Metal })

		local banner = part("Banner", Vector3.new(width * 0.44, 2.8, 0.2), CFrame.new(0, 2.6, z - 0.2 * side), team.color, folder, {
			material = Enum.Material.Fabric,
		})

		local sign = Instance.new("SurfaceGui")
		sign.Face = side > 0 and Enum.NormalId.Back or Enum.NormalId.Front
		sign.CanvasSize = Vector2.new(1100, 160)
		sign.Parent = banner

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.Text = string.upper(team.name)
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(248, 248, 248)
		text.Parent = sign
	end
end

--------------------------------------------------------------------------------
-- Fora
--------------------------------------------------------------------------------

local function buildSurround(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Surround"
	folder.Parent = parent

	local outX = INNER_X + STAND_DEPTH + 26
	local outZ = INNER_Z + STAND_DEPTH + 26

	part("Concourse", Vector3.new(outX * 2, 2, outZ * 2), CFrame.new(0, -1.5, 0), ASPHALT, folder, {
		material = Enum.Material.Asphalt,
	})

	--[[
		Quatro torres de holofotes, uma por canto aberto. De tarde estao
		apagadas — sao estrutura, nao iluminacao, e e isso que faz o recinto
		parecer um recinto sem encher o ecra de luzes.
	]]
	for _, cx in { 1, -1 } do
		for _, cz in { 1, -1 } do
			local x = cx * (INNER_X + STAND_DEPTH + 6)
			local z = cz * (INNER_Z + STAND_DEPTH + 6)
			part("Mast", Vector3.new(1.8, 46, 1.8), CFrame.new(x, 23, z), STEEL, folder, { material = Enum.Material.Metal })
			local rig = part("Rig", Vector3.new(12, 6, 1.2), CFrame.lookAt(Vector3.new(x, 46, z), Vector3.new(0, 0, 0)), STEEL, folder, {
				material = Enum.Material.Metal,
			})
			rig.CastShadow = false
		end
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

	-- O Baseplate do place novo estende-se ate ao horizonte e e nele que se cai.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local existing = workspace:FindFirstChild("Stadium")
	if existing then
		existing:Destroy()
	end

	setAfternoon()

	local root = Instance.new("Folder")
	root.Name = "Stadium"
	root.Parent = workspace

	buildSurround(root)
	buildPitch(root)

	-- Laterais (as claques) e topos. Cantos abertos, como num recinto pequeno.
	for _, side in { 1, -1 } do
		buildStand(false, side, S.blocksLong, root)
		buildStand(true, side, S.blocksEnd, root)
	end

	buildClaqueFront(root)

	-- A meio da bancada da propria claque, com o relvado a frente.
	local spawnRow = math.ceil(S.rows * 0.5)
	for _, teamId in Config.TeamOrder do
		local side = Config.Teams[teamId].side
		spawnPoints[teamId] = Vector3.new(0, spawnRow * S.rowHeight + 3, (INNER_Z + (spawnRow - 0.5) * S.rowDepth) * side)
	end

	City.build(root)
end

return Stadium
