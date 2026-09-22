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
local City = require(script.Parent:WaitForChild("City"))

local Stadium = {}

local S = Config.Stadium

-- Escuros, e escolhidos: o cinzento neutro e o que faz isto parecer betao barato.
local PITCH_DARK = Color3.fromRGB(38, 86, 46)
local PITCH_LIGHT = Color3.fromRGB(54, 112, 63)
local CONCOURSE = Color3.fromRGB(28, 30, 35)
local SEAT_A = Color3.fromRGB(108, 114, 128)
local SEAT_B = Color3.fromRGB(92, 98, 112)
local BOARD = Color3.fromRGB(34, 37, 44)
local RAIL = Color3.fromRGB(226, 228, 232)
local LINE = Color3.fromRGB(222, 228, 224)
local TERRACE = Color3.fromRGB(150, 152, 156)
local TERRACE_EDGE = Color3.fromRGB(118, 120, 126)
local STRUCTURE = Color3.fromRGB(176, 178, 182)

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
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(72, 76, 86)
	Lighting.OutdoorAmbient = Color3.fromRGB(78, 84, 96)
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

--[[
	Uma fila e um anel a volta do relvado, nao quatro blocos encostados.

	Cada fila esta a uma distancia do centro (inset) e a uma altura. Como todas
	as pecas de uma fila nascem desse mesmo inset, nunca se atravessam: o que
	fazia as bancadas passarem umas por cima das outras era cada lado ser
	construido por sua conta e encontrarem-se nos cantos.

	`inset` cresce a cada fila, e a altura sobe: e isso que da a inclinacao.
]]
--[[
	Uma parede com um vao ao meio.

	Faz-se em tres pecas: duas ancas ate ao chao e uma ponte por cima da altura
	de uma pessoa. E assim que se abre uma passagem a serio — o que la estava
	antes era uma peca invisivel por cima de betao macico, ou seja, decoracao.

	`along` e o eixo em que a parede se estende; a espessura fica no outro.
]]
local function wallWithGap(
	name: string,
	span: number,
	height: number,
	thickness: number,
	centre: CFrame,
	alongZ: boolean,
	colour: Color3,
	parent: Instance
)
	local gap = S.tunnelWidth
	local clear = math.min(S.tunnelHeight, height)
	local flank = (span - gap) / 2

	local function size(length: number): Vector3
		return alongZ and Vector3.new(thickness, height, length) or Vector3.new(length, height, thickness)
	end

	for _, dir in { 1, -1 } do
		local offset = (gap / 2 + flank / 2) * dir
		local shift = alongZ and CFrame.new(0, 0, offset) or CFrame.new(offset, 0, 0)
		part(name, size(flank), centre * shift, colour, parent)
	end

	if height > clear then
		local bridge = alongZ and Vector3.new(thickness, height - clear, gap)
			or Vector3.new(gap, height - clear, thickness)
		-- A ponte assenta em cima do vao: vai de `clear` ate ao topo, e `centre`
		-- esta a meia altura da parede, logo o desvio e metade do vao livre.
		part(name .. "Bridge", bridge, centre * CFrame.new(0, clear / 2, 0), colour, parent)
	end
end

local function ringRow(row: number, parent: Instance)
	local topY = row * S.rowHeight
	local step = (row - 1) * S.rowDepth

	local insetX = S.pitchLength / 2 + S.standGap + step
	local insetZ = S.pitchWidth / 2 + S.standGap + step
	local depth = S.rowDepth

	local function block(name: string, size: Vector3, cf: CFrame)
		part(name, size, cf, TERRACE, parent)
	end

	--[[
		Os quatro lados, cada um com a sua passagem ao meio.

		Antes so as pontas abriam, e quem vem da cidade chega pelo lado comprido
		— ia contra betao. Um recinto tem entradas onde as pessoas chegam.
	]]
	for _, side in { 1, -1 } do
		wallWithGap(
			"RowZ",
			insetX * 2,
			topY,
			depth,
			CFrame.new(0, topY / 2, (insetZ + depth / 2) * side),
			false,
			TERRACE,
			parent
		)
		wallWithGap(
			"RowX",
			insetZ * 2,
			topY,
			depth,
			CFrame.new((insetX + depth / 2) * side, topY / 2, 0),
			true,
			TERRACE,
			parent
		)
	end

	--[[
		Os cantos. Sao um quarto de circunferencia de blocos pequenos, cada um
		rodado para a tangente — e isso que faz a curva em vez de um canto seco.
		Sem eles a taca tem quatro buracos, que e onde todos os estadios a serio
		tem exactamente isto.
	]]
	local segments = S.cornerSegments
	for _, sx in { 1, -1 } do
		for _, sz in { 1, -1 } do
			for i = 1, segments do
				local angle = ((i - 0.5) / segments) * math.pi / 2
				local x = (insetX + depth / 2) * math.cos(angle) * sx
				local z = (insetZ + depth / 2) * math.sin(angle) * sz
				local arc = (math.pi / 2) * ((insetX + insetZ) / 2) / segments + 1.5

				block(
					"Corner",
					Vector3.new(depth, topY, arc),
					CFrame.new(x, topY / 2, z) * CFrame.Angles(0, math.atan2(x, z), 0)
				)
			end
		end
	end

	--[[
		Os assentos, por cima do degrau.

		Cinzentos, nao das cores dos clubes. Um estadio a serio tem bancada
		neutra — a cor vem das pessoas, das faixas e das tochas, e e isso que faz
		uma bancada cheia valer alguma coisa. Pintada de fabrica, parece cheia
		mesmo quando nao esta ninguem.

		Duas tonalidades alternadas por fila: e o que se ve de longe num estadio
		vazio, e e o que impede isto de ser uma rampa lisa.
	]]
	local seatColour = (row % 2 == 0) and SEAT_A or SEAT_B
	local gap = S.tunnelWidth
	local clear = math.min(S.tunnelHeight, topY)

	for _, side in { 1, -1 } do
		--[[
			Os assentos param aos lados do vao enquanto a fila estiver abaixo do
			tecto do tunel. Uma tampa inteira por cima da boca voltava a trancar
			a entrada que a fila acabou de abrir.
		]]
		local spanZ = insetX * 2 - 4
		local spanX = insetZ * 2 - 4

		if topY <= clear then
			local flankZ = (spanZ - gap) / 2
			local flankX = (spanX - gap) / 2
			for _, dir in { 1, -1 } do
				part(
					"SeatsZ",
					Vector3.new(flankZ, 0.45, depth - 0.7),
					CFrame.new((gap / 2 + flankZ / 2) * dir, topY + 0.22, (insetZ + depth / 2) * side),
					seatColour,
					parent,
					{ material = Enum.Material.SmoothPlastic }
				)
				part(
					"SeatsX",
					Vector3.new(depth - 0.7, 0.45, flankX),
					CFrame.new((insetX + depth / 2) * side, topY + 0.22, (gap / 2 + flankX / 2) * dir),
					seatColour,
					parent,
					{ material = Enum.Material.SmoothPlastic }
				)
			end
		else
			part("SeatsZ", Vector3.new(spanZ, 0.45, depth - 0.7), CFrame.new(0, topY + 0.22, (insetZ + depth / 2) * side), seatColour, parent, {
				material = Enum.Material.SmoothPlastic,
			})
			part("SeatsX", Vector3.new(depth - 0.7, 0.45, spanX), CFrame.new((insetX + depth / 2) * side, topY + 0.22, 0), seatColour, parent, {
				material = Enum.Material.SmoothPlastic,
			})
		end
	end
end

local function buildBowl(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Bowl"
	folder.Parent = parent

	for row = 1, S.standRows do
		ringRow(row, folder)
	end

	local topY = S.standRows * S.rowHeight
	local outerX = S.pitchLength / 2 + S.standGap + S.standRows * S.rowDepth
	local outerZ = S.pitchWidth / 2 + S.standGap + S.standRows * S.rowDepth

	-- Parede do fundo e cobertura, por cima de toda a volta.
	for _, side in { 1, -1 } do
		local backHeight = topY + 16
		wallWithGap("BackZ", outerX * 2 + 8, backHeight, 3, CFrame.new(0, backHeight / 2, (outerZ + 2) * side), false, STRUCTURE, folder)
		wallWithGap("BackX", outerZ * 2 + 8, backHeight, 3, CFrame.new((outerX + 2) * side, backHeight / 2, 0), true, STRUCTURE, folder)

		local roofDepth = S.standRows * S.rowDepth + 8
		part("RoofZ", Vector3.new(outerX * 2, 1.2, roofDepth), CFrame.new(0, topY + 17, (outerZ - roofDepth / 2 + 4) * side), STRUCTURE, folder, { material = Enum.Material.Metal })
		part("RoofX", Vector3.new(roofDepth, 1.2, outerZ * 2), CFrame.new((outerX - roofDepth / 2 + 4) * side, topY + 17, 0), STRUCTURE, folder, { material = Enum.Material.Metal })
	end

	--[[
		A boca de cada tunel: chao, tecto e luz. A passagem ja esta aberta nas
		filas e na parede; isto e o que a faz parecer uma entrada.
	]]
	local depthRun = S.standRows * S.rowDepth + 16

	for _, side in { 1, -1 } do
		for _, alongZ in { true, false } do
			local centre = alongZ
				and CFrame.new((outerX - depthRun / 2 + 8) * side, 0, 0)
				or CFrame.new(0, 0, (outerZ - depthRun / 2 + 8) * side)

			local floorSize = alongZ and Vector3.new(depthRun, 1, S.tunnelWidth)
				or Vector3.new(S.tunnelWidth, 1, depthRun)
			local lintelSize = alongZ and Vector3.new(depthRun, 1.2, S.tunnelWidth + 8)
				or Vector3.new(S.tunnelWidth + 8, 1.2, depthRun)

			part("TunnelFloor", floorSize, centre * CFrame.new(0, -0.5, 0), Color3.fromRGB(128, 130, 136), folder)
			part("TunnelLintel", lintelSize, centre * CFrame.new(0, S.tunnelHeight + 0.6, 0), STRUCTURE, folder)

			for i = 1, 5 do
				local along = -depthRun / 2 + i * (depthRun / 6)
				local shift = alongZ and CFrame.new(along, 0, 0) or CFrame.new(0, 0, along)
				local lamp = part(
					"TunnelLamp",
					alongZ and Vector3.new(4, 0.4, 2.4) or Vector3.new(2.4, 0.4, 4),
					centre * shift * CFrame.new(0, S.tunnelHeight - 0.4, 0),
					Color3.fromRGB(255, 236, 200),
					folder,
					{ material = Enum.Material.Neon }
				)
				lamp.CastShadow = false

				local light = Instance.new("PointLight")
				light.Brightness = 3
				light.Range = 34
				light.Color = Color3.fromRGB(255, 226, 180)
				light.Parent = lamp
			end
		end
	end

	--[[
		Publicidade a volta do relvado e bancos suplentes.

		Sao os dois detalhes que faltam a um estadio de blocos: sem a barreira de
		placards o relvado encosta directamente a bancada, o que nao acontece em
		lado nenhum, e sao os bancos que dizem que ali se joga futebol e nao
		outra coisa qualquer.
	]]
	local boardX = S.pitchLength / 2 + 3
	local boardZ = S.pitchWidth / 2 + 3

	for _, side in { 1, -1 } do
		part("BoardZ", Vector3.new(boardX * 2, 3.2, 0.6), CFrame.new(0, 1.6, boardZ * side), BOARD, folder, {
			material = Enum.Material.SmoothPlastic,
		})
		part("BoardX", Vector3.new(0.6, 3.2, boardZ * 2), CFrame.new(boardX * side, 1.6, 0), BOARD, folder, {
			material = Enum.Material.SmoothPlastic,
		})

		local dugoutZ = (boardZ + 5) * side
		part("DugoutRoof", Vector3.new(26, 0.5, 7), CFrame.new(side * 20, 5, dugoutZ), STRUCTURE, folder, {
			material = Enum.Material.Metal,
		})
		part("DugoutBench", Vector3.new(24, 1, 2), CFrame.new(side * 20, 1.8, dugoutZ), Color3.fromRGB(40, 43, 50), folder)
		part("DugoutBack", Vector3.new(26, 5, 0.6), CFrame.new(side * 20, 2.5, dugoutZ + 3.2 * side), STRUCTURE, folder)
	end

	--[[
		A vedacao a frente da claque, e a faixa presa nela.

		E a imagem de uma bancada de ultras: malha branca a toda a largura, a
		tarja da claque atada por cima, e a tocha a arder por tras. Sem a malha a
		bancada acaba no ar e nao ha onde prender nada — e a tarja so existe
		porque ha uma rede onde a pendurar.
	]]
	for _, teamId in Config.TeamOrder do
		local team = Config.Teams[teamId]
		local side = team.side
		local frontZ = (S.pitchWidth / 2 + S.standGap - 1) * side
		local width = S.pitchLength * 0.86

		-- Prumos de metro e meio em metro e meio, como numa vedacao a serio.
		local posts = 26
		for i = 0, posts do
			local x = -width / 2 + i * (width / posts)
			-- Salta os prumos em frente a boca do tunel, senao a vedacao tranca
			-- a entrada que se acabou de abrir.
			if math.abs(x) > S.tunnelWidth / 2 + 1 then
				part("FencePost", Vector3.new(0.35, 7, 0.35), CFrame.new(x, 3.5, frontZ), RAIL, folder, {
					material = Enum.Material.Metal,
				})
			end
		end

		-- A malha: uma chapa fina e transparente entre os prumos. Ve-se atraves,
		-- que e o que interessa, e continua a marcar o limite.
		local flank = (width - S.tunnelWidth - 2) / 2
		for _, dir in { 1, -1 } do
			local at = (S.tunnelWidth / 2 + 1 + flank / 2) * dir

			local mesh = part("FenceMesh", Vector3.new(flank, 6.4, 0.12), CFrame.new(at, 3.4, frontZ), RAIL, folder, {
				material = Enum.Material.DiamondPlate,
				transparency = 0.55,
			})
			mesh.CanCollide = false

			part("FenceRail", Vector3.new(flank, 0.3, 0.5), CFrame.new(at, 6.9, frontZ), RAIL, folder, {
				material = Enum.Material.Metal,
			})
		end

		-- A tarja da claque, atada a meia altura.
		-- A tarja fica de um lado da entrada, nao a tapar.
		local banner = part(
			"ClaqueBanner",
			Vector3.new(width * 0.34, 3.4, 0.25),
			CFrame.new(-width * 0.26, 3.2, frontZ - 0.25 * side),
			team.color,
			folder,
			{ material = Enum.Material.Fabric }
		)

		local sign = Instance.new("SurfaceGui")
		sign.Face = side > 0 and Enum.NormalId.Back or Enum.NormalId.Front
		sign.CanvasSize = Vector2.new(1200, 180)
		sign.Parent = banner

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.Text = string.upper(team.name)
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(248, 248, 248)
		text.Parent = sign

		--[[
			Escadas a subir pela bancada, entre blocos de lugares.

			Sao os corredores por onde se sobe num estadio, e aqui sao tambem o
			caminho a serio: sem elas subia-se degrau a degrau, o que funciona
			mas nao e o que se faz.
		]]
		-- Sem a do meio: essa caia mesmo em cima da boca do tunel.
		for _, atX in { -S.pitchLength * 0.32, -S.pitchLength * 0.12, S.pitchLength * 0.12, S.pitchLength * 0.32 } do
			for row = 1, S.standRows do
				local topY = row * S.rowHeight
				local step = (row - 1) * S.rowDepth
				local z = (S.pitchWidth / 2 + S.standGap + step + S.rowDepth / 2) * side
				part("Gangway", Vector3.new(4.5, 0.5, S.rowDepth), CFrame.new(atX, topY + 0.25, z), RAIL, folder, {
					material = Enum.Material.Concrete,
				})
			end
		end
	end

	local spawnRow = math.ceil(S.standRows * 0.45)
	for _, teamId in Config.TeamOrder do
		local side = Config.Teams[teamId].side
		local step = (spawnRow - 1) * S.rowDepth
		spawnPoints[teamId] = Vector3.new(
			0,
			spawnRow * S.rowHeight + 3.5,
			(S.pitchWidth / 2 + S.standGap + step + S.rowDepth / 2) * side
		)
	end
end

--------------------------------------------------------------------------------
-- Fora: estrada e estacionamento
--------------------------------------------------------------------------------

local function buildOutside(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Outside"
	folder.Parent = parent

	local outerZ = S.pitchWidth / 2 + S.standGap + S.standRows * S.rowDepth + 30
	local outerX = S.pitchLength / 2 + S.standGap + S.standRows * S.rowDepth + 30

	-- Explanada a volta do estadio.
	part(
		"Concourse",
		Vector3.new(outerX * 2 + 90, 2, outerZ * 2 + 90),
		CFrame.new(0, -1.5, 0),
		CONCOURSE,
		folder,
		{ material = Enum.Material.Asphalt }
	)

	--[[
		A avenida. Corre ao lado do estadio, nao ate a porta: e nela que o corteo
		se junta e sobe, e para isso tem de ser larga e comprida o suficiente para
		caber muita gente a andar junta.
	]]
	local roadZ = outerZ + 70
	local roadLength = 900
	local roadWidth = 60

	part("Avenue", Vector3.new(roadLength, 2, roadWidth), CFrame.new(0, -1.4, roadZ), Color3.fromRGB(22, 23, 27), folder, {
		material = Enum.Material.Asphalt,
	})

	for i = 1, 30 do
		part(
			"Dash" .. i,
			Vector3.new(14, 2.1, 1),
			CFrame.new(-roadLength / 2 + (i - 0.5) * (roadLength / 30), -1.35, roadZ),
			Color3.fromRGB(198, 198, 188),
			folder,
			{ material = Enum.Material.Asphalt }
		)
	end

	for _, side in { 1, -1 } do
		part("Kerb", Vector3.new(roadLength, 2.8, 6), CFrame.new(0, -1.1, roadZ + (roadWidth / 2 + 3) * side), Color3.fromRGB(44, 46, 52), folder)

		for i = 1, 16 do
			local x = -roadLength / 2 + (i - 0.5) * (roadLength / 16)
			local z = roadZ + (roadWidth / 2 + 5) * side

			part("Pole", Vector3.new(0.9, 20, 0.9), CFrame.new(x, 10, z), STRUCTURE, folder, { material = Enum.Material.Metal })

			local lamp = part("Lamp", Vector3.new(4, 0.7, 1.8), CFrame.new(x, 20, z - 2 * side), Color3.fromRGB(255, 224, 168), folder, {
				material = Enum.Material.Neon,
			})
			lamp.CastShadow = false

			local light = Instance.new("PointLight")
			light.Brightness = 2.6
			light.Range = 48
			light.Color = Color3.fromRGB(255, 212, 148)
			light.Parent = lamp
		end
	end

	-- A rampa que liga a avenida a explanada, em frente a uma das entradas.
	part("Approach", Vector3.new(S.tunnelWidth + 20, 2, roadZ - outerZ), CFrame.new(0, -1.45, (roadZ + outerZ) / 2), Color3.fromRGB(26, 27, 32), folder, {
		material = Enum.Material.Asphalt,
	})

	--[[
		Estacionamento do outro lado. Marcado com linhas: um retangulo de asfalto
		sem marcas nao se le como estacionamento, le-se como chao.
	]]
	local parkX = -(outerX + 90)
	local rows = 4
	local baysPerRow = 14
	local bayWidth = 9
	local bayDepth = 18

	part("ParkFloor", Vector3.new(160, 2, rows * (bayDepth + 6)), CFrame.new(parkX, -1.45, 0), Color3.fromRGB(25, 26, 31), folder, {
		material = Enum.Material.Asphalt,
	})

	for r = 1, rows do
		local z = (r - (rows + 1) / 2) * (bayDepth + 6)
		for b = 0, baysPerRow do
			part(
				"Bay",
				Vector3.new(0.5, 2.1, bayDepth),
				CFrame.new(parkX - (baysPerRow * bayWidth) / 2 + b * bayWidth, -1.4, z),
				Color3.fromRGB(180, 182, 172),
				folder,
				{ material = Enum.Material.Asphalt }
			)
		end
	end

	for i = 1, 6 do
		local z = (i - 3.5) * 24
		part("ParkPole", Vector3.new(0.8, 18, 0.8), CFrame.new(parkX, 9, z), STRUCTURE, folder, { material = Enum.Material.Metal })
		local lamp = part("ParkLamp", Vector3.new(3, 0.6, 3), CFrame.new(parkX, 18, z), Color3.fromRGB(255, 230, 180), folder, {
			material = Enum.Material.Neon,
		})
		lamp.CastShadow = false
		local light = Instance.new("PointLight")
		light.Brightness = 2.2
		light.Range = 55
		light.Color = Color3.fromRGB(255, 218, 160)
		light.Parent = lamp
	end
end

--------------------------------------------------------------------------------
-- Holofotes
--------------------------------------------------------------------------------

local function buildFloodlights(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Floodlights"
	folder.Parent = parent

	local standDepth = S.standRows * S.rowDepth
	local height = 58
	local aim = Vector3.new(0, 0, 0)

	for _, corner in { Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) } do
		local x = corner.X * (S.pitchLength / 2 + 22)
		local z = corner.Y * (S.pitchWidth / 2 + standDepth + 14)
		local top = Vector3.new(x, height, z)

		part("Mast", Vector3.new(2.5, height, 2.5), CFrame.new(x, height / 2, z), STRUCTURE, folder, {
			material = Enum.Material.Metal,
		})

		-- A armacao aponta ao centro do relvado. Orientada primeiro, para tudo o
		-- que se lhe prende nascer ja virado ao sitio certo.
		local rigCF = CFrame.lookAt(top, aim)
		local rig = part("Rig", Vector3.new(18, 9, 1.6), rigCF, STRUCTURE, folder, {
			material = Enum.Material.Metal,
		})

		-- Quatro painteis acesos, virados com a armacao. Sao eles que se veem da
		-- bancada; a luz em si nao se ve, ve-se o que ela acerta.
		for i = 1, 4 do
			local offset = (i - 2.5) * 4.2
			local lamp = part(
				"Lamp" .. i,
				Vector3.new(3.6, 7.4, 0.5),
				rigCF * CFrame.new(offset, 0, -1.1),
				Color3.fromRGB(255, 251, 232),
				folder,
				{ material = Enum.Material.Neon }
			)
			lamp.CastShadow = false

			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Front
			spot.Angle = 80
			spot.Brightness = 9
			spot.Range = 400
			spot.Color = Color3.fromRGB(240, 246, 255)
			spot.Shadows = true
			spot.Parent = lamp
		end
	end
end

--[[
	Luz por baixo das coberturas.

	Sem ela a bancada fica um bloco preto: os holofotes apontam ao relvado, e o
	telhado tapa o resto. E preciso ver-se gente na bancada — e uma tocha so se
	le como tocha se houver alguma luz a volta dela para contrastar.
]]
local function buildStandLights(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "StandLights"
	folder.Parent = parent

	local standDepth = S.standRows * S.rowDepth
	local topY = S.standRows * S.rowHeight

	--[[
		Coroa de luz por cima da cobertura e balizadores a volta do recinto.

		Um estadio a noite ve-se antes de se la chegar: e o halo por cima dele
		que diz onde e, e e ele que faz a caminhada ter destino.
	]]
	local outerX = S.pitchLength / 2 + S.standGap + standDepth
	local outerZ = S.pitchWidth / 2 + S.standGap + standDepth

	for i = 0, 35 do
		local angle = (i / 36) * math.pi * 2
		local x = math.cos(angle) * (outerX + 6)
		local z = math.sin(angle) * (outerZ + 6)

		local beacon = part(
			"Crown",
			Vector3.new(3, 1.6, 3),
			CFrame.new(x, topY + 19, z),
			Color3.fromRGB(198, 216, 255),
			folder,
			{ material = Enum.Material.Neon }
		)
		beacon.CastShadow = false

		local glow = Instance.new("PointLight")
		glow.Brightness = 2
		glow.Range = 45
		glow.Color = Color3.fromRGB(190, 212, 255)
		glow.Parent = beacon
	end

	for i = 0, 23 do
		local angle = (i / 24) * math.pi * 2
		local x = math.cos(angle) * (outerX + 26)
		local z = math.sin(angle) * (outerZ + 26)

		part("GroundPole", Vector3.new(0.7, 14, 0.7), CFrame.new(x, 7, z), STRUCTURE, folder, {
			material = Enum.Material.Metal,
		})

		local head = part("GroundLamp", Vector3.new(2.4, 0.5, 2.4), CFrame.new(x, 14, z), Color3.fromRGB(255, 228, 176), folder, {
			material = Enum.Material.Neon,
		})
		head.CastShadow = false

		local light = Instance.new("PointLight")
		light.Brightness = 2.4
		light.Range = 50
		light.Color = Color3.fromRGB(255, 216, 164)
		light.Parent = head
	end

	for _, teamId in Config.TeamOrder do
		local side = Config.Teams[teamId].side
		local z = (S.pitchWidth / 2 + S.standGap + standDepth / 2) * side

		for i = 1, 6 do
			local x = (i - 3.5) * (S.pitchLength / 5)
			local strip = part(
				"Strip",
				Vector3.new(10, 0.4, 2.4),
				CFrame.new(x, topY + 16.2, z),
				Color3.fromRGB(226, 232, 244),
				folder,
				{ material = Enum.Material.Neon }
			)
			strip.CastShadow = false

			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Bottom
			light.Angle = 120
			light.Brightness = 2.4
			light.Range = 70
			light.Color = Color3.fromRGB(196, 210, 235)
			light.Parent = strip
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

	local existing = workspace:FindFirstChild("Stadium")
	if existing then
		existing:Destroy()
	end

	setNight()

	-- O Baseplate do place novo fica por baixo de tudo e estende-se ate ao
	-- horizonte. Enquanto la estiver, e nele que se cai, e nao na bancada.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local root = Instance.new("Folder")
	root.Name = "Stadium"
	root.Parent = workspace

	buildOutside(root)
	buildPitch(root)
	buildBowl(root)
	buildFloodlights(root)
	buildStandLights(root)
	City.build(root)
end

return Stadium
