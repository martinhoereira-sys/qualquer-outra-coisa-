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

	Entra-se como num estadio a serio: por uma porta da muralha, e depois por
	um vomitorio nas costas da bancada. Cada claque tem a sua porta, a sua
	bancada e o seu sector vedado — as duas nao se misturam nem a entrar.

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
local STEEL = Color3.fromRGB(152, 156, 162)
local ROOF = Color3.fromRGB(108, 112, 120)
local PLINTH = Color3.fromRGB(112, 114, 120)
local SEAT_A = Color3.fromRGB(122, 124, 128)
local SEAT_B = Color3.fromRGB(106, 108, 112)
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

-- Letras brancas numa face de uma peca: placas das portas e dos vomitorios.
local function label(on: BasePart, face: Enum.NormalId, text: string)
	local sign = Instance.new("SurfaceGui")
	sign.Face = face
	local sideways = face == Enum.NormalId.Left or face == Enum.NormalId.Right
	sign.CanvasSize = Vector2.new((sideways and on.Size.Z or on.Size.X) * 40, on.Size.Y * 40)
	sign.Parent = on

	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(0.94, 0.8)
	caption.Position = UDim2.fromScale(0.03, 0.1)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.GothamBlack
	caption.Text = text
	caption.TextScaled = true
	caption.TextColor3 = Color3.fromRGB(248, 248, 248)
	caption.Parent = sign
end

-- Uma peca esticada entre dois pontos: rampas, corrimaos, vedacoes na diagonal.
local function span(name: string, from: Vector3, to: Vector3, width: number, height: number, colour: Color3, parent: Instance, opts: Opts?): Part
	local length = (to - from).Magnitude
	return part(name, Vector3.new(width, height, length), CFrame.lookAt((from + to) / 2, to), colour, parent, opts)
end

type Block = { centre: number, width: number }

--[[
	Os blocos de uma bancada e as escadas entre eles, medidos ao longo dela.

	Com `middle`, o bloco do meio tem essa largura e os outros dividem o resto:
	e o bloco da claque, que mede o mesmo seja qual for o tamanho do campo.
]]
local function layout(run: number, blocks: number, middle: number?): ({ Block }, { number })
	local free = run - (blocks + 1) * S.gangwayWidth
	local mid = (blocks + 1) // 2
	local hasMiddle = middle ~= nil and blocks % 2 == 1 and blocks > 1

	local list: { Block } = {}
	local gangways: { number } = {}
	local x = -run / 2
	for b = 1, blocks do
		local width = free / blocks
		if hasMiddle and middle then
			width = (b == mid) and middle or (free - middle) / (blocks - 1)
		end

		table.insert(gangways, x + S.gangwayWidth / 2)
		x += S.gangwayWidth
		table.insert(list, { centre = x + width / 2, width = width })
		x += width
	end
	table.insert(gangways, x + S.gangwayWidth / 2)

	return list, gangways
end

--------------------------------------------------------------------------------
-- Fim de tarde
--------------------------------------------------------------------------------

local function setAfternoon()
	--[[
		Sol ainda alto mas ja a cair, como as cinco da tarde.

		A latitude conta tanto como a hora: com 41 graus o sol do fim de tarde
		mergulha logo abaixo do horizonte e o que se via era noite. Perto do
		equador mantem-se alto, e ai a hora le-se como tarde e nao como noite.
	]]
	Lighting.ClockTime = 16.6
	Lighting.GeographicLatitude = 8
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(138, 134, 126)
	Lighting.OutdoorAmbient = Color3.fromRGB(176, 172, 162)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 2600
	Lighting.FogColor = Color3.fromRGB(214, 212, 204)

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

	-- As marcacoes crescem com o campo, nas proporcoes de um relvado oficial
	-- (105 x 68 m): circulo de 9,15 m, grande area de 16,5 x 40,3 m.
	local radius = S.pitchLength * 9.15 / 105
	local boxDepth = S.pitchLength * 16.5 / 105
	local boxWidth = S.pitchWidth * 40.3 / 68

	local segments = 48
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		line(
			"Circle" .. i,
			Vector3.new(0.5, 1.04, (math.pi * 2 * radius) / segments + 0.3),
			CFrame.new(math.cos(angle) * radius, -0.48, math.sin(angle) * radius) * CFrame.Angles(0, -angle, 0)
		)
	end

	for _, sign in { 1, -1 } do
		local boxX = (S.pitchLength / 2 - boxDepth) * sign
		line("Box" .. sign, Vector3.new(0.5, 1.04, boxWidth), CFrame.new(boxX, -0.48, 0))
		line("BoxA" .. sign, Vector3.new(boxDepth, 1.04, 0.5), CFrame.new(boxX + boxDepth / 2 * sign, -0.48, boxWidth / 2))
		line("BoxB" .. sign, Vector3.new(boxDepth, 1.04, 0.5), CFrame.new(boxX + boxDepth / 2 * sign, -0.48, -boxWidth / 2))
		line("Goalline" .. sign, Vector3.new(0.5, 1.04, S.pitchWidth), CFrame.new((S.pitchLength / 2) * sign, -0.48, 0))

		--[[
			A baliza. Postes e trave em cima da linha, e a rede em paineis finos
			por tras: fundo, lados e tecto. Tem de ser oca — e a bola a entrar
			nela que marca, e uma rede macica devolvia-a a linha.
		]]
		local G = Config.Football
		local goalX = (S.pitchLength / 2 + 0.35) * sign
		local backX = (S.pitchLength / 2 + G.goalDepth) * sign
		local midX = (goalX + backX) / 2
		local metal: Opts = { material = Enum.Material.Metal }
		local net: Opts = { material = Enum.Material.Fabric, transparency = 0.6 }
		local NET = Color3.fromRGB(222, 226, 232)
		local w = G.goalHalfWidth
		part("PostL", Vector3.new(0.7, G.goalHeight, 0.7), CFrame.new(goalX, G.goalHeight / 2, -w - 0.35), LINE, folder, metal)
		part("PostR", Vector3.new(0.7, G.goalHeight, 0.7), CFrame.new(goalX, G.goalHeight / 2, w + 0.35), LINE, folder, metal)
		part("Bar", Vector3.new(0.7, 0.7, w * 2 + 1.4), CFrame.new(goalX, G.goalHeight + 0.35, 0), LINE, folder, metal)
		part("NetBack", Vector3.new(0.2, G.goalHeight, w * 2 + 1.4), CFrame.new(backX, G.goalHeight / 2, 0), NET, folder, net)
		part("NetTop", Vector3.new(G.goalDepth, 0.2, w * 2 + 1.4), CFrame.new(midX, G.goalHeight + 0.6, 0), NET, folder, net)
		for _, edge in { -1, 1 } do
			part("NetSide", Vector3.new(G.goalDepth, G.goalHeight, 0.2), CFrame.new(midX, G.goalHeight / 2, (w + 0.7) * edge), NET, folder, net)
		end
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

-- As portas dos vomitorios numeram-se seguidas a volta do recinto todo.
local doorNumber = 0

--[[
	Uma bancada recta, dividida em blocos.

	`alongZ` diz se ela corre ao longo do eixo Z (bancadas de topo) ou do X
	(laterais). `side` e de que lado do relvado esta. `claque` e a equipa dona
	dela, se for bancada de claque — e so essas levam sector vedado.

	Cada bloco e um troco de degraus; entre blocos fica uma escada. E essa
	grelha, escada-bloco-escada, que faz uma bancada ler-se como arrumada.
]]
local function buildStand(alongZ: boolean, side: number, blocks: number, parent: Instance, claque: string?)
	local folder = Instance.new("Folder")
	folder.Name = (alongZ and "EndStand" or "SideStand") .. (side > 0 and "A" or "B")
	folder.Parent = parent

	local run = alongZ and S.pitchWidth or S.pitchLength -- largura da bancada
	local inner = alongZ and INNER_X or INNER_Z

	-- Os topos tem o bloco da claque ao meio, com medida propria.
	local blockList, centres = layout(run, blocks, alongZ and S.claqueBlockWidth or nil)
	local gangways = #centres

	local function place(name: string, length: number, depth: number, height: number, along: number, across: number, y: number, colour: Color3, opts: Opts?): Part
		local size = alongZ and Vector3.new(depth, height, length) or Vector3.new(length, height, depth)
		local cf = alongZ and CFrame.new(across, y, along) or CFrame.new(along, y, across)
		return part(name, size, cf, colour, folder, opts)
	end

	local function at(along: number, across: number, y: number): Vector3
		return alongZ and Vector3.new(across, y, along) or Vector3.new(along, y, across)
	end

	-- As escadas das pontas descem ate a frente; as do meio tem vomitorio.
	local function hasVomitory(g: number): boolean
		return g > 1 and g < gangways
	end

	--[[
		O vomitorio, em corte: a rampa sobe por baixo das filas de tras, abre-se
		em trincheira nas quatro filas acima da de saida, e desemboca na escada
		ao nivel de `vomitoryRow`. As filas mais altas ficam por cima como tecto.
	]]
	local exitRow = S.vomitoryRow
	local mouthTop = math.min(exitRow + 4, S.rows - 1)
	local tunnelTop = mouthTop * S.rowHeight

	for row = 1, S.rows do
		local topY = row * S.rowHeight
		local across = (inner + (row - 0.5) * S.rowDepth) * side

		-- Os degraus de cada bloco.
		for _, block in blockList do
			place("Step", block.width, S.rowDepth, topY, block.centre, across, topY / 2, CONCRETE)

			local seatColour = (row % 2 == 0) and SEAT_A or SEAT_B
			place("Seats", block.width - 1.2, S.rowDepth - 0.8, 0.4, block.centre, across, topY + 0.2, seatColour, {
				material = Enum.Material.SmoothPlastic,
			})
		end

		for g, centre in centres do
			if not hasVomitory(g) or row <= exitRow then
				place("Gangway", S.gangwayWidth, S.rowDepth, topY, centre, across, topY / 2, CONCRETE_DARK)
			elseif row > mouthTop then
				place("TunnelRoof", S.gangwayWidth, S.rowDepth, topY - tunnelTop, centre, across, (topY + tunnelTop) / 2, CONCRETE_DARK)
			end
		end
	end

	local backAcross = (inner + STAND_DEPTH + 1) * side
	local backHeight = TOP_Y + 9

	for g, centre in centres do
		if not hasVomitory(g) then
			continue
		end

		-- A rampa, da rua ate ao degrau da fila de saida.
		local low = at(centre, (inner + STAND_DEPTH + 3) * side, -0.5)
		local high = at(centre, (inner + exitRow * S.rowDepth) * side, exitRow * S.rowHeight)
		local ramp = span("Ramp", low, high, S.gangwayWidth, 1, CONCRETE_DARK, folder)
		ramp.CFrame *= CFrame.new(0, -0.5, 0)

		-- Corrimao dos dois lados da boca, que e um buraco no meio da bancada.
		for _, edge in { -1, 1 } do
			local a = centre + edge * S.gangwayWidth / 2
			span(
				"MouthRail",
				at(a, (inner + exitRow * S.rowDepth) * side, (exitRow + 1) * S.rowHeight + 1.2),
				at(a, (inner + mouthTop * S.rowDepth) * side, mouthTop * S.rowHeight + 1.2),
				0.3,
				0.3,
				RAIL,
				folder,
				{ material = Enum.Material.Metal }
			)
		end
	end

	--[[
		A parede do fundo. Abre-se so onde ha vomitorio, a toda a altura do
		tunel: e por ali que se entra, e e o unico sitio por onde se entra.
	]]
	local edges = { -run / 2 - 4 }
	for g, centre in centres do
		if hasVomitory(g) then
			table.insert(edges, centre - S.gangwayWidth / 2)
			table.insert(edges, centre + S.gangwayWidth / 2)
		end
	end
	table.insert(edges, run / 2 + 4)

	for i = 1, #edges, 2 do
		local from, to = edges[i], edges[i + 1]
		place("Back", to - from, 1.5, backHeight, (from + to) / 2, backAcross, backHeight / 2, CONCRETE)
		place("Plinth", to - from, 2.5, 4, (from + to) / 2, backAcross, 2, PLINTH)
	end

	-- A face da parede virada para fora, para as placas das portas.
	local outward = if alongZ then (side > 0 and Enum.NormalId.Right or Enum.NormalId.Left)
		else (side > 0 and Enum.NormalId.Back or Enum.NormalId.Front)

	for g, centre in centres do
		if hasVomitory(g) then
			doorNumber += 1
			local lintel = place("Lintel", S.gangwayWidth, 1.5, backHeight - tunnelTop, centre, backAcross, tunnelTop + (backHeight - tunnelTop) / 2, CONCRETE_DARK)
			local plate = place("DoorPlate", S.gangwayWidth, 0.2, 2.2, centre, backAcross + 0.85 * side, tunnelTop + 1.8, BOARD, {
				material = Enum.Material.SmoothPlastic,
			})
			label(plate, outward, "PORTA " .. doorNumber)
			lintel.Name = "Lintel" .. doorNumber
		end
	end

	--[[
		Cobertura. Nao cobre a bancada toda: pousa no fundo e avanca dois tercos,
		para se continuar a ver o interior de fora e o sol ainda entrar nas filas
		da frente. Uma pala a tapar tudo transformava a bancada numa caixa.
	]]
	local roofDepth = STAND_DEPTH * 0.66
	local roofAcross = (inner + STAND_DEPTH - roofDepth / 2 + 2) * side
	place("Roof", run + 3, roofDepth, 0.7, 0, roofAcross, TOP_Y + 9, ROOF, { material = Enum.Material.Metal })

	--[[
		Vigas, pilares e pilastras vao a meio de cada bloco e nas pontas, nunca
		nas escadas: e ai que estao as portas, e um pilar no meio de uma porta
		tapava-a.
	]]
	local bays = { -run / 2 - 1, run / 2 + 1 }
	for _, block in blockList do
		table.insert(bays, block.centre)
	end

	for _, centre in bays do
		place("Truss", 0.8, roofDepth, 0.8, centre, roofAcross, TOP_Y + 8.4, STEEL, { material = Enum.Material.Metal })
		place("Column", 1.1, 1.1, TOP_Y + 9, centre, backAcross, (TOP_Y + 9) / 2, STEEL, { material = Enum.Material.Metal })
		place("Pilaster", 2.2, 0.8, backHeight - 4, centre, backAcross * 1.01, 4 + (backHeight - 4) / 2, PLINTH)
	end

	place("Cornice", run + 5, 2.2, 1, 0, backAcross, backHeight, PLINTH)

	--[[
		O sector da claque: o bloco do meio e as duas escadas que o ladeiam, que
		sao as suas entradas, vedados do resto por uma malha que acompanha os
		degraus. Os outros blocos, com os seus vomitorios, ficam para o publico.
	]]
	if claque then
		local team = Config.Teams[claque]
		local edge = S.claqueBlockWidth / 2 + S.gangwayWidth

		for _, a in { -edge, edge } do
			for row = 1, S.rows do
				local topY = row * S.rowHeight
				local across = (inner + (row - 0.5) * S.rowDepth) * side
				place("SectorMesh", 0.15, S.rowDepth, 7, a, across, topY + 3.5, RAIL, {
					material = Enum.Material.DiamondPlate,
					transparency = 0.6,
				})
				place("SectorPost", 0.35, 0.35, 7.4, a, (inner + (row - 1) * S.rowDepth + 0.2) * side, topY + 3.7, RAIL, {
					material = Enum.Material.Metal,
				})
				place("SectorRail", 0.4, S.rowDepth, 0.35, a, across, topY + 7.2, team.color, {
					material = Enum.Material.Metal,
				})
			end
		end
	end
end

--------------------------------------------------------------------------------
-- A frente das claques
--------------------------------------------------------------------------------

--[[
	A vedacao a frente dos dois topos das claques, e a tarja presa nela.

	E a imagem de uma bancada de ultras: malha a toda a largura, a tarja da
	claque atada por cima, atras da baliza. Sem a malha a bancada acaba no ar e
	nao ha onde prender nada.
]]
local function buildClaqueFront(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "ClaqueFront"
	folder.Parent = parent

	for _, teamId in Config.TeamOrder do
		local team = Config.Teams[teamId]
		local side = team.side
		local x = (INNER_X - 1.5) * side
		local width = S.pitchWidth

		for i = 0, 16 do
			local z = -width / 2 + i * (width / 16)
			part("Post", Vector3.new(0.3, 6, 0.3), CFrame.new(x, 3, z), RAIL, folder, { material = Enum.Material.Metal })
		end

		local mesh = part("Mesh", Vector3.new(0.1, 5.4, width), CFrame.new(x, 2.9, 0), RAIL, folder, {
			material = Enum.Material.DiamondPlate,
			transparency = 0.6,
		})
		mesh.CanCollide = false

		part("Rail", Vector3.new(0.4, 0.25, width), CFrame.new(x, 5.9, 0), RAIL, folder, { material = Enum.Material.Metal })

		-- A tarja fica a frente do bloco da claque, nao a toda a largura, e com
		-- o nome virado para o campo.
		local banner = part("Banner", Vector3.new(0.2, 2.8, S.claqueBlockWidth + 2 * S.gangwayWidth), CFrame.new(x - 0.2 * side, 2.6, 0), team.color, folder, {
			material = Enum.Material.Fabric,
		})

		local sign = Instance.new("SurfaceGui")
		sign.Face = side > 0 and Enum.NormalId.Left or Enum.NormalId.Right
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

	--[[
		A muralha, a toda a volta da explanada, com quatro portas: a de cada
		claque atras do seu topo, e uma em cada lateral para o publico. Com
		torniquetes, para a porta se ler como porta e nao como buraco no muro.
	]]
	local H = S.wallHeight
	local gates = {
		{ centre = Vector3.new(outX, 0, 0), outward = Vector3.xAxis, width = S.claqueGateWidth },
		{ centre = Vector3.new(-outX, 0, 0), outward = -Vector3.xAxis, width = S.claqueGateWidth },
		{ centre = Vector3.new(0, 0, outZ), outward = Vector3.zAxis, width = S.publicGateWidth },
		{ centre = Vector3.new(0, 0, -outZ), outward = -Vector3.zAxis, width = S.publicGateWidth },
	}

	for _, gate in gates do
		-- De que claque e esta porta, se for de alguma.
		local owner: typeof(Config.Teams.home)? = nil
		for _, teamId in Config.TeamOrder do
			if gate.outward.X == Config.Teams[teamId].side then
				owner = Config.Teams[teamId]
			end
		end

		-- Os dois panos de muro, de canto a porta.
		local along = Vector3.new(gate.outward.Z, 0, -gate.outward.X)
		local half = (gate.outward.Z ~= 0) and outX or outZ
		for _, s in { -1, 1 } do
			local from = gate.centre + along * s * (gate.width / 2 + 3)
			local to = gate.centre + along * s * (half + 0.75)
			span("Wall", from + Vector3.new(0, H / 2 - 0.5, 0), to + Vector3.new(0, H / 2 - 0.5, 0), 1.5, H, CONCRETE, folder)
			span("WallCap", from + Vector3.new(0, H, 0), to + Vector3.new(0, H, 0), 2.2, 0.8, PLINTH, folder)
		end

		local base = CFrame.lookAt(gate.centre, gate.centre + gate.outward)
		for _, s in { -1, 1 } do
			part("GatePillar", Vector3.new(6, H + 5, 3), base * CFrame.new(s * (gate.width / 2), (H + 5) / 2 - 0.5, 0), CONCRETE_DARK, folder)
		end

		local beam = part("GateBeam", Vector3.new(gate.width + 6, 3.4, 2), base * CFrame.new(0, H + 3, 0), owner and owner.color or BOARD, folder, {
			material = Enum.Material.SmoothPlastic,
		})
		local title = owner and ("PORTA " .. string.upper(owner.name)) or "PORTA PUBLICO"
		label(beam, Enum.NormalId.Front, title)
		label(beam, Enum.NormalId.Back, title)

		-- Torniquetes de 6 em 6 studs; entre eles passa-se.
		local lanes = math.floor(gate.width / 6)
		for i = 1, lanes - 1 do
			local x = -gate.width / 2 + i * (gate.width / lanes)
			part("Turnstile", Vector3.new(0.8, 3.4, 3.6), base * CFrame.new(x, 1.2, 0), STEEL, folder, { material = Enum.Material.Metal })
		end
	end

	--[[
		A separacao das claques. Uma vedacao alta em cada canto aberto, da
		esquina do relvado ate a esquina da muralha, parte a explanada em quatro:
		o topo de cada claque, com a sua porta e a sua bancada, e as duas
		laterais do publico. Quem entra pela porta de uma claque so chega a
		bancada dessa claque.
	]]
	for _, cx in { 1, -1 } do
		for _, cz in { 1, -1 } do
			local from = Vector3.new(cx * (S.pitchLength / 2 + 3), 0, cz * (S.pitchWidth / 2 + 3))
			local to = Vector3.new(cx * outX, 0, cz * outZ)
			local mesh = span("SplitMesh", from + Vector3.new(0, H / 2 - 0.5, 0), to + Vector3.new(0, H / 2 - 0.5, 0), 0.2, H, RAIL, folder, {
				material = Enum.Material.DiamondPlate,
				transparency = 0.55,
			})
			mesh.CastShadow = false
			span("SplitRail", from + Vector3.new(0, H, 0), to + Vector3.new(0, H, 0), 0.4, 0.4, STEEL, folder, {
				material = Enum.Material.Metal,
			})

			local posts = math.floor((to - from).Magnitude / 8)
			for i = 0, posts do
				local p = from:Lerp(to, i / posts)
				part("SplitPost", Vector3.new(0.4, H + 0.5, 0.4), CFrame.new(p.X, H / 2 - 0.25, p.Z), STEEL, folder, {
					material = Enum.Material.Metal,
				})
			end
		end
	end
end

--------------------------------------------------------------------------------

-- Meia largura do bloco do meio dos topos, que e onde a claque se junta.
function Stadium.claqueHalfWidth(): number
	return S.claqueBlockWidth / 2
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

	-- Laterais (o publico) e topos (as claques). Cantos abertos, como num
	-- recinto pequeno.
	doorNumber = 0
	for _, side in { 1, -1 } do
		local claque: string? = nil
		for _, teamId in Config.TeamOrder do
			if Config.Teams[teamId].side == side then
				claque = teamId
			end
		end
		buildStand(false, side, S.blocksLong, root)
		buildStand(true, side, S.blocksEnd, root, claque)
	end

	buildClaqueFront(root)

	-- A meio do topo da propria claque, com a baliza a frente.
	local spawnRow = math.ceil(S.rows * 0.5)
	for _, teamId in Config.TeamOrder do
		local side = Config.Teams[teamId].side
		spawnPoints[teamId] = Vector3.new((INNER_X + (spawnRow - 0.5) * S.rowDepth) * side, spawnRow * S.rowHeight + 3, 0)
	end

	City.build(root)
end

return Stadium
