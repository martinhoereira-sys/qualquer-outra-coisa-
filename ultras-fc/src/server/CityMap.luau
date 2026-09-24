--!strict
--[[
	O mapa da cidade: ruas, quarteiroes, predios, as duas sedes, a praca e os
	caminhos do corteo.

	Isto gera a cidade UMA vez, para dentro do mapa (Workspace.Cidade), e o que
	la fica e o que conta. Quem abre o place no Studio ve-a sem carregar em
	Play, e pode mudar predios de sitio, apaga-los, mexer nas sedes ou nos
	pontos do caminho do corteo: o jogo le o que estiver no mapa (City.luau).
	So se nao houver cidade nenhuma no mapa e que o jogo a gera ao arrancar.

	A cidade nao e simetrica, de proposito:
	- a poente, o bairro velho: casas baixas e estreitas, de tijolo, telhados de
	  duas aguas, tascas no res-do-chao. E la a sede vermelha, no canto noroeste;
	- a nascente, a zona nova: predios altos de betao e vidro. E la a sede azul,
	  no canto sudeste — as duas sedes nas pontas opostas da cidade;
	- ao meio, a norte do estadio, o centro, com lojas e a praca da chegada;
	- ao meio, a sul, a zona industrial e um parque.

	Tudo o que e da cidade e uma peca so ou um modelo, com nome, para se
	perceber no Explorer o que e o que.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CityMap = {}

local S = Config.Stadium
local STAND = S.rows * S.rowDepth
local OUT_X = S.pitchLength / 2 + S.standGap + STAND + 26
local OUT_Z = S.pitchWidth / 2 + S.standGap + STAND + 26

--[[
	A grelha das ruas. As linhas das pontas sao o fim da cidade, nao ruas; as
	outras sao ruas. O espacamento nao e regular, e os dois lados nao sao
	iguais: quarteiroes pequenos no bairro velho, grandes na zona nova.
]]
local XS = { -780, -630, -480, -330, -200, 200, 340, 490, 630, 770 }
local ZS = { -750, -600, -450, -300, -165, 165, 300, 440, 580, 720 }

local SIDEWALK = 7
local PAD_TOP = 0.3 -- o passeio e os quarteiroes, acima da estrada

-- A largura de cada rua. O anel a volta do estadio e a avenida sao largos.
local function streetWidth(axis: string, value: number): number
	if (axis == "x" and math.abs(value) == 200) or (axis == "z" and math.abs(value) == 165) then
		return 30 -- o anel do estadio
	end
	if axis == "z" and value == 300 then
		return 40 -- a avenida, a norte
	end
	if (axis == "x" and (value == -330 or value == 490)) then
		return 34
	end
	return 26
end

local function isEdge(list: { number }, i: number): boolean
	return i == 1 or i == #list
end

--------------------------------------------------------------------------------
-- Pecas
--------------------------------------------------------------------------------

local function block(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function detail(p: Part): Part
	p.CastShadow = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function signOn(p: BasePart, face: Enum.NormalId, text: string, colour: Color3, canvas: Vector2)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = canvas
	gui.LightInfluence = 0.8
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = colour
	label.Text = text
	label.Parent = gui
end

--------------------------------------------------------------------------------
-- Bairros
--------------------------------------------------------------------------------

type District = {
	name: string,
	floors: NumberRange,
	floorHeight: number,
	width: NumberRange,
	depth: number,
	walls: { Color3 },
	material: Enum.Material,
	pitched: number, -- probabilidade de telhado de duas aguas
	shops: number, -- probabilidade de loja no res-do-chao
	curtain: boolean, -- fachadas de vidro inteiras (predios modernos)
	towers: number, -- probabilidade de um predio muito alto
}

local OLD: District = {
	name = "Bairro Velho",
	floors = NumberRange.new(2, 4),
	floorHeight = 10,
	width = NumberRange.new(20, 32),
	depth = 30,
	walls = {
		Color3.fromRGB(142, 72, 56),
		Color3.fromRGB(158, 92, 70),
		Color3.fromRGB(120, 64, 52),
		Color3.fromRGB(196, 176, 150),
		Color3.fromRGB(214, 200, 176),
		Color3.fromRGB(170, 150, 128),
	},
	material = Enum.Material.Brick,
	pitched = 0.6,
	shops = 0.35,
	curtain = false,
	towers = 0,
}

local NEW: District = {
	name = "Zona Nova",
	floors = NumberRange.new(5, 12),
	floorHeight = 10,
	width = NumberRange.new(34, 58),
	depth = 40,
	walls = {
		Color3.fromRGB(200, 202, 206),
		Color3.fromRGB(170, 174, 180),
		Color3.fromRGB(122, 128, 136),
		Color3.fromRGB(226, 226, 222),
		Color3.fromRGB(92, 96, 104),
	},
	material = Enum.Material.Concrete,
	pitched = 0,
	shops = 0.25,
	curtain = true,
	towers = 0.12,
}

local CENTRE: District = {
	name = "Centro",
	floors = NumberRange.new(3, 7),
	floorHeight = 10,
	width = NumberRange.new(24, 40),
	depth = 34,
	walls = {
		Color3.fromRGB(214, 206, 190),
		Color3.fromRGB(186, 170, 150),
		Color3.fromRGB(150, 110, 90),
		Color3.fromRGB(200, 196, 188),
		Color3.fromRGB(120, 112, 104),
	},
	material = Enum.Material.Concrete,
	pitched = 0.15,
	shops = 0.8,
	curtain = false,
	towers = 0,
}

local INDUSTRIAL: District = {
	name = "Zona Industrial",
	floors = NumberRange.new(1, 2),
	floorHeight = 14,
	width = NumberRange.new(48, 78),
	depth = 50,
	walls = {
		Color3.fromRGB(120, 124, 128),
		Color3.fromRGB(96, 100, 104),
		Color3.fromRGB(140, 122, 96),
		Color3.fromRGB(88, 110, 120),
	},
	material = Enum.Material.Metal,
	pitched = 0,
	shops = 0,
	curtain = false,
	towers = 0,
}

local function districtAt(x: number, z: number): District
	if x < -200 then
		return OLD
	elseif x > 200 then
		return NEW
	elseif z > 0 then
		return CENTRE
	end
	return INDUSTRIAL
end

local SHOPS = {
	"TASCA DO ZE",
	"CAFE CENTRAL",
	"CERVEJARIA",
	"MERCEARIA",
	"BARBEARIA",
	"FARMACIA",
	"PADARIA",
	"TABACARIA",
	"O CANTINHO",
	"SNACK-BAR",
	"LOJA DO ADEPTO",
	"CHURRASQUEIRA",
}

local WINDOW = Color3.fromRGB(92, 112, 132)


--------------------------------------------------------------------------------
-- Um predio
--------------------------------------------------------------------------------

--[[
	Um predio, de frente para a rua. `base` e o centro do chao, com o -Z local
	virado para a rua (CFrame.lookAt para a rua). `width` e ao longo da rua.
]]
local function building(base: CFrame, width: number, depth: number, d: District, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Predio"

	local floors = rng:NextInteger(d.floors.Min, d.floors.Max)
	if d.towers > 0 and rng:NextNumber() < d.towers then
		floors = rng:NextInteger(15, 22)
	end
	local height = floors * d.floorHeight
	local colour = d.walls[rng:NextInteger(1, #d.walls)]
	local material = d.material
	if d == OLD and colour.R > 0.7 then
		material = Enum.Material.Concrete -- as casas de pedra clara nao sao de tijolo
	end

	local body = block("Corpo", Vector3.new(width, height, depth), base * CFrame.new(0, height / 2, 0), colour, material, model)
	model.PrimaryPart = body

	-- O topo: cornija, ou telhado de duas aguas nas casas velhas.
	if rng:NextNumber() < d.pitched then
		local rise = math.min(depth * 0.35, 9)
		local roof = Color3.fromRGB(96, 52, 42):Lerp(Color3.fromRGB(60, 60, 64), rng:NextNumber() * 0.6)
		for _, s in { -1, 1 } do
			local wedge = Instance.new("WedgePart")
			wedge.Name = "Telhado"
			wedge.Size = Vector3.new(width + 1, rise, depth / 2 + 0.5)
			wedge.CFrame = base * CFrame.new(0, height + rise / 2, s * depth / 4) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0)
			wedge.Color = roof
			wedge.Material = Enum.Material.Slate
			wedge.Anchored = true
			wedge.Parent = model
		end
	else
		detail(block("Cornija", Vector3.new(width + 1.2, 1.2, depth + 1.2), base * CFrame.new(0, height + 0.6, 0), colour:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Concrete, model))
	end

	local front = -depth / 2 - 0.2
	local shop = d.shops > 0 and rng:NextNumber() < d.shops

	if d.curtain then
		--[[
			Vidro em faixas ao alto, com colunas de betao entre elas, na frente e
			nas traseiras; as laterais ficam em betao com uma faixa so. O vidro
			muda de cor de predio para predio: um bairro todo do mesmo azul
			lia-se como caixas.
		]]
		local glassHeight = height - d.floorHeight - 2
		local y = d.floorHeight + glassHeight / 2
		local tints = {
			Color3.fromRGB(70, 96, 122),
			Color3.fromRGB(60, 108, 112),
			Color3.fromRGB(96, 100, 106),
			Color3.fromRGB(120, 104, 86),
			Color3.fromRGB(46, 56, 70),
		}
		local glass = tints[rng:NextInteger(1, #tints)]
		local strips = if width > 40 then 3 else 2
		local pitch = width / strips
		for _, z in { front, -front } do
			for i = 1, strips do
				local x = -width / 2 + pitch * (i - 0.5)
				local pane = detail(block("Vidro", Vector3.new(pitch - 3, glassHeight, 0.4), base * CFrame.new(x, y, z), glass, Enum.Material.Glass, model))
				pane.Reflectance = 0.2
			end
		end
		for _, x in { width / 2 + 0.2, -width / 2 - 0.2 } do
			local pane = detail(block("Vidro", Vector3.new(0.4, glassHeight, math.max(depth * 0.4, 4)), base * CFrame.new(x, y, 0), glass, Enum.Material.Glass, model))
			pane.Reflectance = 0.2
		end
	else
		-- Uma faixa de janelas por andar, na fachada da rua.
		local first = if shop then 2 else 1
		for floor = first, floors do
			local y = (floor - 1) * d.floorHeight + d.floorHeight * 0.55
			local band = detail(block("Janelas", Vector3.new(width - 4, d.floorHeight * 0.42, 0.4), base * CFrame.new(0, y, front), WINDOW, Enum.Material.Glass, model))
			band.Reflectance = 0.3
		end
	end

	if shop then
		local name = SHOPS[rng:NextInteger(1, #SHOPS)]
		local tint = Color3.fromHSV(rng:NextNumber(), 0.55, 0.8)
		local window = detail(block("Montra", Vector3.new(width - 5, 6, 0.4), base * CFrame.new(0, 3.3, front), Color3.fromRGB(70, 90, 100), Enum.Material.Glass, model))
		window.Reflectance = 0.2
		local board = detail(block("Letreiro", Vector3.new(width - 6, 2, 0.5), base * CFrame.new(0, 7.4, front - 0.1), tint, Enum.Material.SmoothPlastic, model))
		signOn(board, Enum.NormalId.Front, name, Color3.fromRGB(250, 250, 250), Vector2.new(600, 80))
	elseif d == INDUSTRIAL then
		-- O portao de enrolar do armazem.
		detail(block("Portao", Vector3.new(math.min(16, width - 10), 11, 0.4), base * CFrame.new(0, 5.8, front), Color3.fromRGB(150, 152, 150), Enum.Material.DiamondPlate, model))
	else
		detail(block("Porta", Vector3.new(4, 7, 0.4), base * CFrame.new(0, 3.8, front), Color3.fromRGB(58, 40, 30), Enum.Material.Wood, model))
	end

	model.Parent = parent
end

--------------------------------------------------------------------------------
-- Aderecos
--------------------------------------------------------------------------------

local function lamp(at: Vector3, towards: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Candeeiro"
	local pole = block("Poste", Vector3.new(0.7, 18, 0.7), CFrame.new(at + Vector3.new(0, 9 + PAD_TOP, 0)), Color3.fromRGB(34, 36, 40), Enum.Material.Metal, model)
	model.PrimaryPart = pole
	detail(block("Luz", Vector3.new(1.4, 0.6, 3.2), CFrame.lookAt(at + Vector3.new(0, 18 + PAD_TOP, 0), at + towards + Vector3.new(0, 18 + PAD_TOP, 0)) * CFrame.new(0, 0, -1.6), Color3.fromRGB(150, 150, 146), Enum.Material.SmoothPlastic, model))
	model.Parent = parent
end

local function tree(at: Vector3, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Arvore"
	local h = rng:NextNumber(8, 13)
	local trunk = block("Tronco", Vector3.new(1.2, h, 1.2), CFrame.new(at + Vector3.new(0, h / 2 + PAD_TOP, 0)), Color3.fromRGB(86, 62, 44), Enum.Material.Wood, model)
	model.PrimaryPart = trunk
	local size = rng:NextNumber(9, 14)
	local crown = block("Copa", Vector3.new(size, size * 0.85, size), CFrame.new(at + Vector3.new(0, h + size * 0.3 + PAD_TOP, 0)), Color3.fromRGB(60, 104, 52):Lerp(Color3.fromRGB(96, 124, 60), rng:NextNumber()), Enum.Material.Grass, model)
	crown.Shape = Enum.PartType.Ball
	crown.CastShadow = true
	model.Parent = parent
end

local CAR_COLOURS = {
	Color3.fromRGB(180, 30, 30),
	Color3.fromRGB(30, 60, 140),
	Color3.fromRGB(230, 230, 230),
	Color3.fromRGB(30, 30, 34),
	Color3.fromRGB(120, 124, 130),
	Color3.fromRGB(70, 110, 70),
	Color3.fromRGB(210, 170, 60),
}

-- Um carro estacionado, virado ao longo da rua.
local function car(at: Vector3, along: Vector3, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Carro"
	local base = CFrame.lookAt(at, at + along)
	local colour = CAR_COLOURS[rng:NextInteger(1, #CAR_COLOURS)]
	local body = block("Carrocaria", Vector3.new(5, 2.2, 10.5), base * CFrame.new(0, 1.9, 0), colour, Enum.Material.SmoothPlastic, model)
	model.PrimaryPart = body
	detail(block("Cabine", Vector3.new(4.6, 1.8, 5.4), base * CFrame.new(0, 3.9, 0.6), Color3.fromRGB(40, 48, 56), Enum.Material.Glass, model))
	for _, z in { -3.4, 3.4 } do
		local wheels = detail(block("Rodas", Vector3.new(5.4, 1.8, 1.8), base * CFrame.new(0, 0.9, z), Color3.fromRGB(20, 20, 22), Enum.Material.SmoothPlastic, model))
		wheels.Shape = Enum.PartType.Cylinder
	end
	model.Parent = parent
end

local function bench(at: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Banco"
	local seat = block("Assento", Vector3.new(6, 0.6, 2), at * CFrame.new(0, 1.8, 0), Color3.fromRGB(110, 80, 56), Enum.Material.Wood, model)
	model.PrimaryPart = seat
	block("Costas", Vector3.new(6, 1.6, 0.4), at * CFrame.new(0, 2.9, 0.9), Color3.fromRGB(110, 80, 56), Enum.Material.Wood, model)
	model.Parent = parent
end

--------------------------------------------------------------------------------
-- As sedes, a praca e os caminhos
--------------------------------------------------------------------------------

--[[
	Onde fica cada sede: o centro do chao e a rotacao. A frente (+Z local) e a
	porta, virada para a rua. E so isto que o jogo precisa de saber; o resto
	(balcao, tambor, portao) poe-no a sede quando o jogo arranca (Clubhouse).
]]
local SEDE_WIDTH, SEDE_DEPTH, SEDE_HEIGHT = 46, 34, 14

local SEDES: { [string]: CFrame } = {
	home = CFrame.new(-705, PAD_TOP, 540), -- bairro velho, canto noroeste, porta para norte
	away = CFrame.new(700, PAD_TOP, -640), -- zona nova, canto sudeste, porta para norte
}

-- O caminho de sempre, da porta da sede ate ao anel do estadio. A porta da
-- claque no estadio junta-a o March no fim.
local ROUTES: { [string]: { Vector3 } } = {
	home = {
		Vector3.new(-705, 3, 580),
		Vector3.new(-330, 3, 580),
		Vector3.new(-330, 3, 0),
		Vector3.new(-200, 3, 0),
	},
	away = {
		Vector3.new(700, 3, -600),
		Vector3.new(490, 3, -600),
		Vector3.new(490, 3, -165),
		Vector3.new(200, 3, -165),
		Vector3.new(200, 3, 0),
	},
}

local function sedeBuilding(teamId: string, pivot: CFrame, parent: Instance): Model
	local team = Config.Teams[teamId]
	local model = Instance.new("Model")
	model.Name = "Sede_" .. teamId
	model:SetAttribute("Team", teamId)

	local w, d, h = SEDE_WIDTH, SEDE_DEPTH, SEDE_HEIGHT
	local floor = block("Base", Vector3.new(w, 1, d), pivot * CFrame.new(0, 0.5, 0), Color3.fromRGB(38, 38, 42), Enum.Material.Concrete, model)
	model.PrimaryPart = floor
	block("Telhado", Vector3.new(w + 3, 1.5, d + 3), pivot * CFrame.new(0, h, 0), Color3.fromRGB(24, 26, 30), Enum.Material.Concrete, model)

	-- Tres paredes e a frente aberta, com a cor da claque na fachada toda.
	block("Tras", Vector3.new(w, h, 2), pivot * CFrame.new(0, h / 2, -d / 2), team.color, Enum.Material.Concrete, model)
	block("Esquerda", Vector3.new(2, h, d), pivot * CFrame.new(-w / 2, h / 2, 0), team.color, Enum.Material.Concrete, model)
	block("Direita", Vector3.new(2, h, d), pivot * CFrame.new(w / 2, h / 2, 0), team.color, Enum.Material.Concrete, model)

	local banner = block("Faixa", Vector3.new(w - 6, 4, 0.6), pivot * CFrame.new(0, h - 3, d / 2), team.color, Enum.Material.Fabric, model)
	signOn(banner, Enum.NormalId.Back, team.name, Color3.fromRGB(245, 245, 245), Vector2.new(800, 140))
	signOn(banner, Enum.NormalId.Front, team.name, Color3.fromRGB(245, 245, 245), Vector2.new(800, 140))

	local glow = detail(block("Luz", Vector3.new(w - 8, 0.5, d - 8), pivot * CFrame.new(0, h - 1.5, 0), Color3.fromRGB(255, 226, 164), Enum.Material.Neon, model))
	local light = Instance.new("PointLight")
	light.Brightness = 1
	light.Range = 32
	light.Color = team.color:Lerp(Color3.fromRGB(255, 230, 190), 0.6)
	light.Parent = glow

	model.Parent = parent
	return model
end

local function routeMarkers(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Rotas"
	folder.Parent = parent
	for teamId, points in ROUTES do
		local team = Config.Teams[teamId]
		local route = Instance.new("Folder")
		route.Name = teamId
		route.Parent = folder
		for i, point in points do
			local p = detail(block(tostring(i), Vector3.new(4, 4, 4), CFrame.new(point), team.color, Enum.Material.Neon, route))
			p.Shape = Enum.PartType.Ball
			p.Transparency = 0.3
			p:SetAttribute("Nota", "Ponto do caminho do corteo. Pela ordem dos numeros; so se ve no Studio.")
		end
	end
end

--------------------------------------------------------------------------------
-- A cidade toda
--------------------------------------------------------------------------------

type Rect = { x0: number, x1: number, z0: number, z1: number }

local function overlaps(a: Rect, b: Rect): boolean
	return a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1
end

function CityMap.generate(parent: Instance): Model
	local rng = Random.new(2026)
	local city = Instance.new("Model")
	city.Name = "Cidade"

	local ground = Instance.new("Folder")
	ground.Name = "Chao"
	ground.Parent = city
	local blocks = Instance.new("Folder")
	blocks.Name = "Quarteiroes"
	blocks.Parent = city
	local props = Instance.new("Folder")
	props.Name = "Aderecos"
	props.Parent = city
	local sedes = Instance.new("Folder")
	sedes.Name = "Sedes"
	sedes.Parent = city

	local minX, maxX, minZ, maxZ = XS[1], XS[#XS], ZS[1], ZS[#ZS]

	-- A estrada: uma laje so, da cidade inteira. Os quarteiroes e passeios
	-- assentam por cima, e o que fica a vista entre eles e a rua.
	block("Estrada", Vector3.new(maxX - minX + 80, 4, maxZ - minZ + 80), CFrame.new((minX + maxX) / 2, -2.6, (minZ + maxZ) / 2), Color3.fromRGB(34, 35, 40), Enum.Material.Asphalt, ground)

	-- As linhas ao meio das ruas.
	for i, x in XS do
		if not isEdge(XS, i) then
			local z0, z1 = minZ, maxZ
			detail(block("Linha", Vector3.new(0.5, 0.05, z1 - z0), CFrame.new(x, -0.47, (z0 + z1) / 2), Color3.fromRGB(220, 220, 210), Enum.Material.SmoothPlastic, ground))
		end
	end
	for i, z in ZS do
		if not isEdge(ZS, i) then
			detail(block("Linha", Vector3.new(maxX - minX, 0.05, 0.5), CFrame.new((minX + maxX) / 2, -0.47, z), Color3.fromRGB(220, 220, 210), Enum.Material.SmoothPlastic, ground))
		end
	end

	-- Onde nao se constroi: a volta das sedes (com a rua da frente livre).
	local reserved: { Rect } = {}
	for _, pivot in SEDES do
		local p = pivot.Position
		table.insert(reserved, { x0 = p.X - SEDE_WIDTH / 2 - 14, x1 = p.X + SEDE_WIDTH / 2 + 14, z0 = p.Z - SEDE_DEPTH / 2 - 10, z1 = p.Z + SEDE_DEPTH / 2 + 30 })
	end

	-- Os quarteiroes, celula a celula da grelha.
	for xi = 1, #XS - 1 do
		for zi = 1, #ZS - 1 do
			local cx0, cx1, cz0, cz1 = XS[xi], XS[xi + 1], ZS[zi], ZS[zi + 1]
			local midX, midZ = (cx0 + cx1) / 2, (cz0 + cz1) / 2

			-- O estadio ocupa a celula do meio; constroi-se no Play.
			local stadium = cx0 == -200 and cz0 == -165
			if stadium then
				continue
			end

			local wl = if isEdge(XS, xi) then 0 else streetWidth("x", cx0) / 2
			local wr = if isEdge(XS, xi + 1) then 0 else streetWidth("x", cx1) / 2
			local wb = if isEdge(ZS, zi) then 0 else streetWidth("z", cz0) / 2
			local wt = if isEdge(ZS, zi + 1) then 0 else streetWidth("z", cz1) / 2
			local px0, px1, pz0, pz1 = cx0 + wl, cx1 - wr, cz0 + wb, cz1 - wt

			local cell = Instance.new("Folder")
			cell.Name = string.format("Quarteirao_%d_%d", xi, zi)
			cell.Parent = blocks

			local isSquare = cx0 == -200 and cz0 == 165 -- a norte do estadio
			local isPark = cx0 == -200 and cz0 == -300 -- a sul do estadio

			-- O passeio: o quarteirao inteiro, um pouco acima da estrada.
			block("Passeio", Vector3.new(px1 - px0, 0.8, pz1 - pz0), CFrame.new((px0 + px1) / 2, PAD_TOP - 0.4, (pz0 + pz1) / 2), Color3.fromRGB(150, 148, 142), Enum.Material.Concrete, cell)

			local ix0, ix1, iz0, iz1 = px0 + SIDEWALK, px1 - SIDEWALK, pz0 + SIDEWALK, pz1 - SIDEWALK

			if isSquare or isPark then
				-- Relva, arvores e bancos.
				detail(block("Relva", Vector3.new(ix1 - ix0, 0.2, iz1 - iz0), CFrame.new(midX, PAD_TOP + 0.1, midZ), Color3.fromRGB(78, 112, 60), Enum.Material.Grass, cell))
				local count = if isPark then 26 else 14
				for _ = 1, count do
					local at = Vector3.new(rng:NextNumber(ix0 + 8, ix1 - 8), 0, rng:NextNumber(iz0 + 8, iz1 - 8))
					if isSquare and (at - Vector3.new(0, 0, 232)).Magnitude < 45 then
						continue -- o meio da praca fica livre
					end
					tree(at, rng, cell)
				end
				if isSquare then
					-- A praca: calcada ao meio, fonte, e o sitio onde se chega.
					detail(block("Calcada", Vector3.new(80, 0.25, 70), CFrame.new(0, PAD_TOP + 0.15, 232), Color3.fromRGB(196, 190, 176), Enum.Material.Cobblestone, cell))
					local basin = block("Fonte", Vector3.new(1.6, 16, 16), CFrame.new(0, PAD_TOP + 0.8, 232) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(170, 168, 160), Enum.Material.Concrete, cell)
					basin.Shape = Enum.PartType.Cylinder
					local water = detail(block("Agua", Vector3.new(0.3, 14, 14), CFrame.new(0, PAD_TOP + 1.7, 232) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 130, 170), Enum.Material.Glass, cell))
					water.Shape = Enum.PartType.Cylinder
					water.Transparency = 0.3
					for _, spot in { Vector3.new(-30, 0, 214), Vector3.new(30, 0, 214), Vector3.new(-30, 0, 252), Vector3.new(30, 0, 252) } do
						bench(CFrame.new(spot + Vector3.new(0, PAD_TOP, 0)), cell)
					end
				end
				continue
			end

			local d = districtAt(midX, midZ)
			local depth = math.min(d.depth, (iz1 - iz0) / 2 - 2, (ix1 - ix0) / 2 - 2)
			if depth < 12 then
				continue
			end

			local function place(rect: Rect, base: CFrame, width: number, deep: number)
				for _, r in reserved do
					if overlaps(rect, r) then
						return
					end
				end
				building(base, width, deep, d, rng, cell)
			end

			-- Fila de predios ao longo de uma fachada da rua.
			local function row(fromA: number, toA: number, alongX: boolean, edge: number, outward: number)
				local a = fromA
				while toA - a >= d.width.Min do
					local w = math.min(rng:NextNumber(d.width.Min, d.width.Max), toA - a)
					if toA - a - w < d.width.Min then
						w = toA - a -- o ultimo estica ate a esquina
					end
					local deep = depth * rng:NextNumber(0.75, 1)
					local centreA = a + w / 2
					local centre: Vector3
					local facing: Vector3
					if alongX then
						centre = Vector3.new(centreA, PAD_TOP, edge - outward * deep / 2)
						facing = Vector3.new(0, 0, outward)
					else
						centre = Vector3.new(edge - outward * deep / 2, PAD_TOP, centreA)
						facing = Vector3.new(outward, 0, 0)
					end
					local base = CFrame.lookAt(centre, centre + facing)
					local rect: Rect = if alongX
						then { x0 = a, x1 = a + w, z0 = math.min(edge, edge - outward * deep), z1 = math.max(edge, edge - outward * deep) }
						else { x0 = math.min(edge, edge - outward * deep), x1 = math.max(edge, edge - outward * deep), z0 = a, z1 = a + w }
					place(rect, base, w - 0.6, deep)
					a += w
				end
			end

			-- Norte e sul de ponta a ponta; nascente e poente entre eles.
			row(ix0, ix1, true, iz1, 1)
			row(ix0, ix1, true, iz0, -1)
			row(iz0 + depth, iz1 - depth, false, ix1, 1)
			row(iz0 + depth, iz1 - depth, false, ix0, -1)

			-- Umas arvores no passeio dos bairros com espaco.
			if d == NEW or d == CENTRE then
				for _ = 1, 1 do
					tree(Vector3.new(rng:NextNumber(px0 + 3, px1 - 3), 0, pz1 - 3.5), rng, cell)
				end
			end
		end
	end

	-- Candeeiros ao longo das ruas, um lado e outro alternados.
	local lamps = Instance.new("Folder")
	lamps.Name = "Candeeiros"
	lamps.Parent = props
	local toggle = 1
	for i, x in XS do
		if not isEdge(XS, i) then
			local off = streetWidth("x", x) / 2 + 2.5
			local z = minZ + 40
			while z < maxZ - 40 do
				local inStadium = math.abs(x) < OUT_X + 30 and math.abs(z) < OUT_Z + 30
				if not inStadium then
					lamp(Vector3.new(x + off * toggle, 0, z), Vector3.new(-toggle, 0, 0), lamps)
				end
				toggle = -toggle
				z += 110
			end
		end
	end
	for i, z in ZS do
		if not isEdge(ZS, i) then
			local off = streetWidth("z", z) / 2 + 2.5
			local x = minX + 40
			while x < maxX - 40 do
				local inStadium = math.abs(x) < OUT_X + 30 and math.abs(z) < OUT_Z + 30
				if not inStadium then
					lamp(Vector3.new(x, 0, z + off * toggle), Vector3.new(0, 0, -toggle), lamps)
				end
				toggle = -toggle
				x += 110
			end
		end
	end

	-- Carros estacionados junto ao passeio.
	local cars = Instance.new("Folder")
	cars.Name = "Carros"
	cars.Parent = props
	for _ = 1, 40 do
		local vertical = rng:NextNumber() < 0.5
		if vertical then
			local i = rng:NextInteger(2, #XS - 1)
			local x = XS[i]
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local z = rng:NextNumber(minZ + 30, maxZ - 30)
			if not (math.abs(x) < OUT_X + 40 and math.abs(z) < OUT_Z + 40) and math.abs(z % 150) > 25 then
				car(Vector3.new(x + side * (streetWidth("x", x) / 2 - 3.5), -0.5, z), Vector3.new(0, 0, side), rng, cars)
			end
		else
			local i = rng:NextInteger(2, #ZS - 1)
			local z = ZS[i]
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local x = rng:NextNumber(minX + 30, maxX - 30)
			if not (math.abs(x) < OUT_X + 40 and math.abs(z) < OUT_Z + 40) then
				car(Vector3.new(x, -0.5, z + side * (streetWidth("z", z) / 2 - 3.5)), Vector3.new(-side, 0, 0), rng, cars)
			end
		end
	end

	-- As sedes.
	for teamId, pivot in SEDES do
		sedeBuilding(teamId, pivot, sedes)
	end

	-- A praca: onde se chega quando ainda nao se e de ninguem, e o posto do arbitro.
	local arrival = detail(block("Chegada", Vector3.new(6, 1, 6), CFrame.new(0, PAD_TOP + 0.5, 232), Color3.fromRGB(236, 200, 96), Enum.Material.Neon, city))
	arrival.Transparency = 0.5
	arrival:SetAttribute("Nota", "Onde aparece quem ainda nao escolheu lado. So se ve no Studio.")
	local post = detail(block("PostoArbitragem", Vector3.new(8, 1, 6), CFrame.new(34, PAD_TOP + 0.5, 240), Color3.fromRGB(236, 200, 96), Enum.Material.Neon, city))
	post.Transparency = 0.5
	post:SetAttribute("Nota", "Onde fica a cabine do arbitro. So se ve no Studio.")

	routeMarkers(city)

	-- O sitio do estadio, so para se ver no Studio: e construido no Play.
	local stadiumArea = detail(block("EstadioArea", Vector3.new(OUT_X * 2, 1, OUT_Z * 2), CFrame.new(0, 0, 0), Color3.fromRGB(60, 140, 60), Enum.Material.SmoothPlastic, city))
	stadiumArea.Transparency = 0.6
	stadiumArea:SetAttribute("Nota", "O estadio aparece aqui ao carregar em Play. Nao construas por cima.")
	signOn(stadiumArea, Enum.NormalId.Top, "ESTADIO (aparece no Play)", Color3.fromRGB(255, 255, 255), Vector2.new(800, 400))

	city.Parent = parent
	return city
end

return CityMap
