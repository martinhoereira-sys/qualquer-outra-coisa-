--!strict
--[[
	Constroi o estadio novo em Workspace.Estadio.

	Corre uma vez, no Studio (para o estadio ficar no mapa, a ver-se e a
	mexer-se sem Play), e o jogo depois usa o que la esta. So se o mapa nao
	tiver Estadio e que o jogo o constroi ao arrancar, com isto mesmo.

	Inspirado no novo estadio do Torreense: uma casca branca continua que da a
	volta toda — fachada e cobertura na mesma peca de cor — com a base de vidro
	quente, as bancadas a curvar nos cantos, e a principal com dois andares e
	camarotes de madeira entre eles.

	As medidas (e a posicao de tudo o que o jogo usa: curvas das claques,
	portas, tunel) vem do StadiumPlan.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Plan = require(Shared:WaitForChild("StadiumPlan"))

local Builder = {}

local S = Config.Stadium
local G = Config.Football

local INNER_X = Plan.innerX
local INNER_Z = Plan.innerZ
local STAND_DEPTH = Plan.standDepth
local TOP_Y = Plan.topY
local R = Plan.cornerRadius
local MAIN_SIDE = Plan.mainSide

local GRASS_A = Color3.fromRGB(64, 122, 62)
local GRASS_B = Color3.fromRGB(76, 138, 72)
local LINE = Color3.fromRGB(236, 240, 236)
local STEP = Color3.fromRGB(186, 186, 184) -- betao claro dos degraus
local STEP_DARK = Color3.fromRGB(150, 150, 150) -- escadas
local SEAT_A = Color3.fromRGB(58, 56, 92) -- cadeiras azul-arroxeado escuro, como nas fotos
local SEAT_B = Color3.fromRGB(48, 46, 80)
local WHITE = Color3.fromRGB(240, 240, 236) -- a casca
local WHITE_SHADE = Color3.fromRGB(222, 222, 218)
local GLASS_WARM = Color3.fromRGB(236, 184, 116) -- o vidro da base, com luz quente por dentro
local RAIL = Color3.fromRGB(210, 212, 216)
local STEEL = Color3.fromRGB(150, 154, 160)
local BOARD = Color3.fromRGB(34, 36, 42)
local WOOD = Color3.fromRGB(176, 124, 76)
local PRESIDENT_RED = Color3.fromRGB(150, 26, 34)
local GOLD = Color3.fromRGB(212, 170, 80)
local PLAZA = Color3.fromRGB(176, 172, 164)

local TUNNEL_HALF = 4
local TUNNEL_HEIGHT = 7
local ROOM_HALF = 15
local ROOM_HEIGHT = 8

type Opts = { material: Enum.Material?, transparency: number?, collide: boolean?, shadow: boolean? }

local function part(name: string, size: Vector3, cf: CFrame, colour: Color3, parent: Instance, opts: Opts?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Anchored = true
	p.Material = (opts and opts.material) or Enum.Material.Concrete
	p.Transparency = (opts and opts.transparency) or 0
	if opts and opts.collide == false then
		p.CanCollide = false
	end
	if opts and opts.shadow == false then
		p.CastShadow = false
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function span(name: string, from: Vector3, to: Vector3, width: number, height: number, colour: Color3, parent: Instance, opts: Opts?): Part
	return part(name, Vector3.new(width, height, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), colour, parent, opts)
end

-- Letras numa face: placas das portas, dos setores, das curvas.
local function label(on: BasePart, face: Enum.NormalId, text: string, colour: Color3?)
	local sign = Instance.new("SurfaceGui")
	sign.Face = face
	local sideways = face == Enum.NormalId.Left or face == Enum.NormalId.Right
	sign.CanvasSize = Vector2.new((sideways and on.Size.Z or on.Size.X) * 40, on.Size.Y * 40)
	sign.LightInfluence = 0.3
	sign.Parent = on
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(0.94, 0.8)
	caption.Position = UDim2.fromScale(0.03, 0.1)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.GothamBlack
	caption.Text = text
	caption.TextScaled = true
	caption.TextColor3 = colour or Color3.fromRGB(248, 248, 248)
	caption.Parent = sign
end

local function folderIn(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

type Block = { centre: number, width: number }

-- Os blocos (setores) de uma recta e as escadas entre eles.
local function layout(run: number, blocks: number): ({ Block }, { number })
	local free = run - (blocks + 1) * S.gangwayWidth
	local list: { Block } = {}
	local gangways: { number } = {}
	local x = -run / 2
	for _ = 1, blocks do
		local width = free / blocks
		table.insert(gangways, x + S.gangwayWidth / 2)
		x += S.gangwayWidth
		table.insert(list, { centre = x + width / 2, width = width })
		x += width
	end
	table.insert(gangways, x + S.gangwayWidth / 2)
	return list, gangways
end

-- Numeracao a volta do estadio, como num a serio.
local doorNumber = 0
local sectorNumber = 0

--------------------------------------------------------------------------------
-- A fachada: parede branca com a base de vidro quente
--------------------------------------------------------------------------------

--[[
	Um pano de fachada entre dois pontos (no chao), virado para fora em
	`outward`. Parede branca ate `height`; em baixo, por fora, uma banda de
	vidro ambar com montantes brancos, que e o que da ao estadio o ar das
	fotos ao fim da tarde.
]]
local function facade(from: Vector3, to: Vector3, outward: Vector3, height: number, parent: Instance)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local mid = (from + to) / 2
	local base = CFrame.lookAt(mid, mid + outward) -- -Z para fora
	part("Fachada", Vector3.new(length, height, 1.5), base * CFrame.new(0, height / 2, 0), WHITE, parent, {
		material = Enum.Material.SmoothPlastic,
	})
	local glass = part("VidroBase", Vector3.new(length, 6.5, 0.3), base * CFrame.new(0, 3.75, -0.9), GLASS_WARM, parent, {
		material = Enum.Material.Glass,
		transparency = 0.1,
		shadow = false,
	})
	glass.Reflectance = 0.05
	part("Friso", Vector3.new(length, 0.8, 0.5), base * CFrame.new(0, 7.3, -1), WHITE_SHADE, parent, {
		material = Enum.Material.SmoothPlastic,
	})
	local mullions = math.floor(length / 7)
	for i = 1, mullions - 1 do
		part("Montante", Vector3.new(0.35, 6.5, 0.5), base * CFrame.new(-length / 2 + i * (length / mullions), 3.75, -1), WHITE, parent, {
			material = Enum.Material.SmoothPlastic,
		})
	end
end

--[[
	Uma porta na fachada: o vao, a verga por cima, e a placa numerada por fora.
	`across` e a distancia ao longo da parede onde ela fica.
]]
local function doorway(at: CFrame, width: number, height: number, wallHeight: number, text: string, parent: Instance, tone: Color3?)
	-- A verga, da porta ao topo da parede.
	part("Verga", Vector3.new(width, wallHeight - height, 1.5), at * CFrame.new(0, height + (wallHeight - height) / 2, 0), WHITE, parent, {
		material = Enum.Material.SmoothPlastic,
	})
	local plate = part("PlacaPorta", Vector3.new(width + 1, 2.4, 0.2), at * CFrame.new(0, height + 1.8, -0.9), tone or BOARD, parent, {
		material = Enum.Material.SmoothPlastic,
	})
	label(plate, Enum.NormalId.Front, text)
end

--------------------------------------------------------------------------------
-- Relvado
--------------------------------------------------------------------------------

local function buildPitch(parent: Instance)
	local folder = folderIn(parent, "Relvado")

	local stripes = 12
	local stripeWidth = S.pitchLength / stripes
	for i = 1, stripes do
		local x = -S.pitchLength / 2 + (i - 0.5) * stripeWidth
		part("Faixa" .. i, Vector3.new(stripeWidth, 1, S.pitchWidth + 16), CFrame.new(x, -0.5, 0), (i % 2 == 0) and GRASS_B or GRASS_A, folder, {
			material = Enum.Material.Grass,
		})
	end
	-- A relva continua ate as bancadas, nos topos.
	for _, sign in { -1, 1 } do
		part("RelvaFundo", Vector3.new(S.endGap + 1, 1, S.pitchWidth + 16), CFrame.new(sign * (S.pitchLength / 2 + S.endGap / 2), -0.5, 0), GRASS_A, folder, {
			material = Enum.Material.Grass,
		})
	end

	local function line(name: string, size: Vector3, cf: CFrame)
		part(name, size, cf, LINE, folder, { material = Enum.Material.SmoothPlastic, collide = false, shadow = false })
	end

	line("MeioCampo", Vector3.new(0.5, 1.04, S.pitchWidth), CFrame.new(0, -0.48, 0))
	line("LinhaN", Vector3.new(S.pitchLength, 1.04, 0.5), CFrame.new(0, -0.48, S.pitchWidth / 2))
	line("LinhaS", Vector3.new(S.pitchLength, 1.04, 0.5), CFrame.new(0, -0.48, -S.pitchWidth / 2))
	line("MarcaCentral", Vector3.new(1.2, 1.05, 1.2), CFrame.new(0, -0.48, 0))

	local radius = S.pitchLength * 9.15 / 105
	local boxDepth = S.pitchLength * 16.5 / 105
	local boxWidth = S.pitchWidth * 40.3 / 68
	local smallDepth = S.pitchLength * 5.5 / 105
	local smallWidth = S.pitchWidth * 18.3 / 68
	local spot = S.pitchLength * 11 / 105

	local segments = 40
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		line("Circulo", Vector3.new(0.5, 1.04, (math.pi * 2 * radius) / segments + 0.3), CFrame.new(math.cos(angle) * radius, -0.48, math.sin(angle) * radius) * CFrame.Angles(0, -angle, 0))
	end

	for _, sign in { 1, -1 } do
		local goalLine = S.pitchLength / 2 * sign
		local boxX = goalLine - boxDepth * sign
		line("Area", Vector3.new(0.5, 1.04, boxWidth), CFrame.new(boxX, -0.48, 0))
		line("AreaA", Vector3.new(boxDepth, 1.04, 0.5), CFrame.new(boxX + boxDepth / 2 * sign, -0.48, boxWidth / 2))
		line("AreaB", Vector3.new(boxDepth, 1.04, 0.5), CFrame.new(boxX + boxDepth / 2 * sign, -0.48, -boxWidth / 2))
		local smallX = goalLine - smallDepth * sign
		line("PequenaArea", Vector3.new(0.5, 1.04, smallWidth), CFrame.new(smallX, -0.48, 0))
		line("PequenaAreaA", Vector3.new(smallDepth, 1.04, 0.5), CFrame.new(smallX + smallDepth / 2 * sign, -0.48, smallWidth / 2))
		line("PequenaAreaB", Vector3.new(smallDepth, 1.04, 0.5), CFrame.new(smallX + smallDepth / 2 * sign, -0.48, -smallWidth / 2))
		line("LinhaGolo", Vector3.new(0.5, 1.04, S.pitchWidth), CFrame.new(goalLine, -0.48, 0))
		line("MarcaPenalti", Vector3.new(1, 1.05, 1), CFrame.new(goalLine - spot * sign, -0.48, 0))
		-- A meia-lua da area.
		-- So o pedaco do circulo (centrado no penalti) que fica fora da area.
		local stepAngle = math.rad(6)
		for i = -9, 9 do
			local a = i * stepAngle
			local x = goalLine - spot * sign - math.cos(a) * radius * sign
			if math.abs(x) < math.abs(boxX) - 0.2 then
				line("MeiaLua", Vector3.new(0.5, 1.04, radius * stepAngle + 0.15), CFrame.new(x, -0.48, math.sin(a) * radius) * CFrame.Angles(0, a * sign, 0))
			end
		end

		--[[
			A baliza, como as de verdade: postes e trave redondos e brancos, a
			armacao de tras (dois postes, a barra de cima e as do chao) e a rede em
			quadricula no fundo, nos lados e no tecto. A rede sao paineis finos
			(e neles que a bola bate) com a quadricula desenhada por cima; oca
			por dentro, porque e a bola a entrar que marca.
		]]
		local goalX = (S.pitchLength / 2 + 0.35) * sign
		local backX = (S.pitchLength / 2 + G.goalDepth) * sign
		local midX = (goalX + backX) / 2
		local w = G.goalHalfWidth
		local h = G.goalHeight
		local d = G.goalDepth
		local goal = folderIn(folder, "Baliza" .. (if sign > 0 then "Pos" else "Neg"))
		local metal: Opts = { material = Enum.Material.SmoothPlastic }
		local function tube(name: string, from: Vector3, to: Vector3, thick: number)
			span(name, from, to, thick, thick, LINE, goal, metal)
		end
		-- Postes e trave, grossos.
		part("PosteE", Vector3.new(0.7, h, 0.7), CFrame.new(goalX, h / 2, -w - 0.35), LINE, goal, metal)
		part("PosteD", Vector3.new(0.7, h, 0.7), CFrame.new(goalX, h / 2, w + 0.35), LINE, goal, metal)
		part("Trave", Vector3.new(0.7, 0.7, w * 2 + 1.4), CFrame.new(goalX, h + 0.35, 0), LINE, goal, metal)
		-- A armacao de tras, fina.
		for _, s in { -1, 1 } do
			local z = s * (w + 0.35)
			tube("PosteTras", Vector3.new(backX, 0, z), Vector3.new(backX, h + 0.35, z), 0.35)
			tube("BarraLado", Vector3.new(goalX, h + 0.35, z), Vector3.new(backX, h + 0.35, z), 0.3)
			tube("BarraChaoLado", Vector3.new(goalX, 0.15, z), Vector3.new(backX, 0.15, z), 0.3)
		end
		tube("BarraTras", Vector3.new(backX, h + 0.35, -w - 0.35), Vector3.new(backX, h + 0.35, w + 0.35), 0.35)
		tube("BarraChaoTras", Vector3.new(backX, 0.15, -w - 0.35), Vector3.new(backX, 0.15, w + 0.35), 0.3)

		--[[
			Um painel de rede: invisivel (a bola bate nele) e, desenhada nas duas
			faces, a quadricula de fios brancos com `cell` studs de lado.
		]]
		local CELL = 0.9
		local function net(name: string, size: Vector3, cf: CFrame, faces: { Enum.NormalId })
			local panel = part(name, size, cf, LINE, goal, { material = Enum.Material.SmoothPlastic, transparency = 1, shadow = false })
			for _, face in faces do
				local across, up
				if face == Enum.NormalId.Front or face == Enum.NormalId.Back then
					across, up = size.X, size.Y
				elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then
					across, up = size.Z, size.Y
				else
					across, up = size.X, size.Z
				end
				local gui = Instance.new("SurfaceGui")
				gui.Face = face
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 20
				gui.LightInfluence = 0.6
				gui.Parent = panel
				local wire = Color3.fromRGB(236, 240, 244)
				for i = 0, math.floor(across / CELL) do
					local line = Instance.new("Frame")
					line.BorderSizePixel = 0
					line.BackgroundColor3 = wire
					line.Size = UDim2.new(0, 2, 1, 0)
					line.Position = UDim2.fromOffset(math.floor(i * CELL * 20), 0)
					line.Parent = gui
				end
				for i = 0, math.floor(up / CELL) do
					local line = Instance.new("Frame")
					line.BorderSizePixel = 0
					line.BackgroundColor3 = wire
					line.Size = UDim2.new(1, 0, 0, 2)
					line.Position = UDim2.fromOffset(0, math.floor(i * CELL * 20))
					line.Parent = gui
				end
			end
			return panel
		end
		local width = w * 2 + 0.7
		net("RedeFundo", Vector3.new(0.15, h, width), CFrame.new(backX + 0.1 * sign, h / 2, 0), { Enum.NormalId.Left, Enum.NormalId.Right })
		net("RedeTopo", Vector3.new(d - 0.35, 0.15, width), CFrame.new(midX, h + 0.35, 0), { Enum.NormalId.Top, Enum.NormalId.Bottom })
		for _, edge in { -1, 1 } do
			net("RedeLado", Vector3.new(d - 0.35, h, 0.15), CFrame.new(midX, h / 2, (w + 0.45) * edge), { Enum.NormalId.Front, Enum.NormalId.Back })
		end
	end

	-- Placards a volta; na principal abrem-se na boca do tunel.
	local boardOpts: Opts = { material = Enum.Material.SmoothPlastic }
	for _, side in { 1, -1 } do
		local boardZ = (S.pitchWidth / 2 + 3) * side
		if side == MAIN_SIDE then
			local gap = TUNNEL_HALF + 1
			local length = (S.pitchLength + 6) / 2 - gap
			for _, s in { -1, 1 } do
				part("Placard", Vector3.new(length, 2.6, 0.5), CFrame.new(s * (gap + length / 2), 1.3, boardZ), BOARD, folder, boardOpts)
			end
		else
			part("Placard", Vector3.new(S.pitchLength + 6, 2.6, 0.5), CFrame.new(0, 1.3, boardZ), BOARD, folder, boardOpts)
		end
		part("Placard", Vector3.new(0.5, 2.6, S.pitchWidth + 6), CFrame.new((S.pitchLength / 2 + 3) * side, 1.3, 0), BOARD, folder, boardOpts)
	end

	-- Bancos de suplentes, com cobertura de vidro, na principal.
	for _, s in { 1, -1 } do
		local z = -(S.pitchWidth / 2 + 5.5)
		part("BancoCobertura", Vector3.new(20, 0.3, 5), CFrame.new(s * 18, 4.4, z), STEEL, folder, { material = Enum.Material.Glass, transparency = 0.4 })
		part("BancoCostas", Vector3.new(20, 4.4, 0.4), CFrame.new(s * 18, 2.2, z - 2.4), WHITE, folder, { material = Enum.Material.SmoothPlastic })
		part("BancoAssento", Vector3.new(19, 0.8, 1.6), CFrame.new(s * 18, 1.4, z - 1.2), SEAT_A, folder, { material = Enum.Material.SmoothPlastic })
	end
end

--------------------------------------------------------------------------------
-- As rectas
--------------------------------------------------------------------------------

type StandOpts = {
	tunnel: boolean?, -- a principal: oca por baixo do bloco do meio
	main: boolean?, -- a principal: sem fachada nem cobertura propria (tem as dela)
}

local function hollowFor(row: number): (number, number?)
	if row <= 4 then
		return TUNNEL_HALF, nil
	elseif row == 5 then
		return TUNNEL_HALF, TUNNEL_HEIGHT
	end
	return ROOM_HALF, ROOM_HEIGHT
end

--[[
	Uma bancada recta. `alongZ`: corre ao longo de Z (topos) ou de X
	(laterais). `side`: de que lado do relvado. `run`: o comprimento (acaba onde
	comecam as curvas). Blocos = setores, numerados; entre eles escadas, e nas
	escadas do meio os vomitorios, que dao para as portas numeradas.
]]
local function buildStand(alongZ: boolean, side: number, run: number, blocks: number, parent: Instance, opts: StandOpts?)
	local folder = folderIn(parent, (alongZ and "Topo" or "Lateral") .. (side > 0 and "Pos" or "Neg"))
	local inner = alongZ and INNER_X or INNER_Z
	local blockList, centres = layout(run, blocks)
	local gangways = #centres
	local tunnel = opts and opts.tunnel
	local main = opts and opts.main

	local function place(name: string, length: number, depth: number, height: number, along: number, across: number, y: number, colour: Color3, o: Opts?): Part
		local size = alongZ and Vector3.new(depth, height, length) or Vector3.new(length, height, depth)
		local cf = alongZ and CFrame.new(across, y, along) or CFrame.new(along, y, across)
		return part(name, size, cf, colour, folder, o)
	end
	local function at(along: number, across: number, y: number): Vector3
		return alongZ and Vector3.new(across, y, along) or Vector3.new(along, y, across)
	end
	local outward = alongZ and Vector3.new(side, 0, 0) or Vector3.new(0, 0, side)

	local function hasVomitory(g: number): boolean
		return g > 1 and g < gangways
	end
	local exitRow = Plan.exitRow
	local mouthTop = Plan.mouthTop
	local tunnelTop = mouthTop * S.rowHeight
	local seats: Opts = { material = Enum.Material.SmoothPlastic }

	for row = 1, S.rows do
		local topY = row * S.rowHeight
		local across = (inner + (row - 0.5) * S.rowDepth) * side
		for index, block in blockList do
			local seatColour = (row % 2 == 0) and SEAT_A or SEAT_B
			if tunnel and index == (#blockList + 1) // 2 then
				local half, ceiling = hollowFor(row)
				local left = block.centre - block.width / 2
				local right = block.centre + block.width / 2
				local sideWidth = block.centre - half - left
				for _, s in { -1, 1 } do
					place("Degrau", sideWidth, S.rowDepth, topY, block.centre + s * (half + sideWidth / 2), across, topY / 2, STEP)
				end
				if ceiling then
					place("Teto", half * 2, S.rowDepth, topY - ceiling, block.centre, across, (topY + ceiling) / 2, STEP)
					place("Cadeiras", block.width - 1.2, S.rowDepth - 0.8, 0.4, block.centre, across, topY + 0.2, seatColour, seats)
				else
					for _, s in { -1, 1 } do
						local from = if s < 0 then left + 0.6 else block.centre + half
						local to = if s < 0 then block.centre - half else right - 0.6
						place("Cadeiras", to - from, S.rowDepth - 0.8, 0.4, (from + to) / 2, across, topY + 0.2, seatColour, seats)
					end
				end
				continue
			end
			place("Degrau", block.width, S.rowDepth, topY, block.centre, across, topY / 2, STEP)
			place("Cadeiras", block.width - 1.2, S.rowDepth - 0.8, 0.4, block.centre, across, topY + 0.2, seatColour, seats)
		end
		for g, centre in centres do
			if not hasVomitory(g) or row <= exitRow then
				place("Escada", S.gangwayWidth, S.rowDepth, topY, centre, across, topY / 2, STEP_DARK)
			elseif row > mouthTop then
				place("TetoVomitorio", S.gangwayWidth, S.rowDepth, topY - tunnelTop, centre, across, (topY + tunnelTop) / 2, STEP_DARK)
			end
		end
	end

	-- A frente: guarda de vidro com corrimao, a toda a largura.
	local frontAcross = (inner - 0.3) * side
	place("GuardaVidro", run, 0.2, 3.2, 0, frontAcross, S.rowHeight + 1.6, RAIL, { material = Enum.Material.Glass, transparency = 0.55, shadow = false })
	place("GuardaCorrimao", run, 0.35, 0.3, 0, frontAcross, S.rowHeight + 3.3, RAIL, { material = Enum.Material.Metal })

	-- Vomitorios: rampa por baixo das filas, corrimaos na boca, placa do setor por cima.
	local backAcross = (inner + Plan.backAt) * side
	for g, centre in centres do
		if not hasVomitory(g) then
			continue
		end
		local low = at(centre, (inner + STAND_DEPTH + 3) * side, -0.5)
		local high = at(centre, (inner + exitRow * S.rowDepth) * side, exitRow * S.rowHeight)
		local ramp = span("Rampa", low, high, S.gangwayWidth, 1, STEP_DARK, folder)
		ramp.CFrame *= CFrame.new(0, -0.5, 0)
		for _, edge in { -1, 1 } do
			local a = centre + edge * S.gangwayWidth / 2
			span("CorrimaoBoca", at(a, (inner + exitRow * S.rowDepth) * side, (exitRow + 1) * S.rowHeight + 1.2), at(a, (inner + mouthTop * S.rowDepth) * side, mouthTop * S.rowHeight + 1.2), 0.3, 0.3, RAIL, folder, { material = Enum.Material.Metal })
		end
	end

	-- Placa de cada setor, na frente do degrau de cima do bloco, virada para o campo.
	for _, block in blockList do
		sectorNumber += 1
		local plate = place("PlacaSetor", 7, 0.2, 1.4, block.centre, (inner + (S.rows - 1) * S.rowDepth - 0.12) * side, (S.rows - 1) * S.rowHeight + 0.8, BOARD, { material = Enum.Material.SmoothPlastic })
		local face = if alongZ then (side > 0 and Enum.NormalId.Left or Enum.NormalId.Right) else (side > 0 and Enum.NormalId.Front or Enum.NormalId.Back)
		label(plate, face, "SETOR " .. sectorNumber)
	end

	if main then
		return centres, blockList
	end

	--[[
		As costas: a fachada branca, aberta so nas portas dos vomitorios. Por
		fora, o numero da porta.
	]]
	local wallHeight = Plan.backHeight
	local edges = { -run / 2 - 0.75 }
	for g, centre in centres do
		if hasVomitory(g) then
			table.insert(edges, centre - S.gangwayWidth / 2)
			table.insert(edges, centre + S.gangwayWidth / 2)
		end
	end
	table.insert(edges, run / 2 + 0.75)
	for i = 1, #edges, 2 do
		facade(at(edges[i], backAcross, 0), at(edges[i + 1], backAcross, 0), outward, wallHeight, folder)
	end
	for g, centre in centres do
		if hasVomitory(g) then
			doorNumber += 1
			local base = CFrame.lookAt(at(centre, backAcross, 0), at(centre, backAcross, 0) + outward)
			doorway(base, S.gangwayWidth, tunnelTop, wallHeight, "PORTA " .. doorNumber, folder)
		end
	end

	-- A cobertura: a casca branca pousa na fachada e avanca dois tercos da bancada.
	local roofDepth = STAND_DEPTH * 0.7 + 2
	local roofAcross = (inner + Plan.backAt - roofDepth / 2 + 0.75) * side
	place("Cobertura", run + 1.5, roofDepth, 1.4, 0, roofAcross, wallHeight + 0.7, WHITE, { material = Enum.Material.SmoothPlastic })
	-- A aba da frente, grossa: e ela que desenha a linha branca nas fotos.
	place("Aba", run + 1.5, 1, 4, 0, (inner + Plan.backAt - roofDepth + 1.25) * side, wallHeight - 0.6, WHITE, { material = Enum.Material.SmoothPlastic })
	return centres, blockList
end

--------------------------------------------------------------------------------
-- As curvas
--------------------------------------------------------------------------------

--[[
	Um pedaco de anel: de t0 a t1 da curva (cx, cz), entre os raios r0 e r1,
	de y0 a y1. Aproximado por pecas rectas (Config.Stadium.curveSegments por
	quarto de volta), um pouco sobrepostas para nao haver frinchas.
]]
local function ring(name: string, cx: number, cz: number, t0: number, t1: number, r0: number, r1: number, y0: number, y1: number, colour: Color3, parent: Instance, opts: Opts?)
	local pieces = math.max(1, math.round((t1 - t0) * S.curveSegments))
	local step = (t1 - t0) / pieces
	local made = {}
	for i = 0, pieces - 1 do
		local ta = t0 + i * step
		local tm = ta + step / 2
		local angle = step * math.pi / 2
		local width = 2 * r1 * math.sin(angle / 2) + 0.25
		local radius = (r0 + r1) / 2
		local centre = Plan.curvePoint(cx, cz, tm, radius, (y0 + y1) / 2)
		local out = Plan.dir(cx, cz, tm)
		table.insert(made, part(name, Vector3.new(width, y1 - y0, r1 - r0), CFrame.lookAt(centre, centre + out), colour, parent, opts))
	end
	return made
end

--[[
	Uma curva de canto. Degraus em anel; o vomitorio sai a meio (t = 0.5).
	Na claque, em vez de cadeiras, uma barra de seguranca em cada fila (e a
	bancada de pe das claques, "safe standing"), vedacao nas duas pontas para
	o setor ser so dela, e a vedacao alta a frente com a tarja.
]]
local function buildCurve(cx: number, cz: number, claque: string?, parent: Instance)
	local folder = folderIn(parent, if claque then "Curva_" .. claque else "Curva")
	local exitRow = Plan.exitRow
	local mouthTop = Plan.mouthTop
	local tunnelTop = mouthTop * S.rowHeight
	local team = claque and Config.Teams[claque]

	for row = 1, S.rows do
		local r0 = R + (row - 1) * S.rowDepth
		local r1 = r0 + S.rowDepth
		local topY = row * S.rowHeight
		local hw = Plan.vomitoryHalfT((r0 + r1) / 2)
		local arcs = if row <= exitRow then { { 0, 1 } } else { { 0, 0.5 - hw }, { 0.5 + hw, 1 } }
		for _, arc in arcs do
			ring("Degrau", cx, cz, arc[1], arc[2], r0, r1, 0, topY, STEP, folder)
			if team then
				-- A barra de cada fila, a frente do degrau, a altura da cintura.
				ring("Barreira", cx, cz, arc[1], arc[2], r0 + 0.2, r0 + 0.45, topY + 0.95, topY + 1.2, RAIL, folder, { material = Enum.Material.Metal })
			else
				ring("Cadeiras", cx, cz, arc[1], arc[2], r0 + 0.4, r1 - 0.4, topY, topY + 0.4, (row % 2 == 0) and SEAT_A or SEAT_B, folder, { material = Enum.Material.SmoothPlastic })
			end
		end
		if row > mouthTop then
			ring("TetoVomitorio", cx, cz, 0.5 - hw, 0.5 + hw, r0, r1, tunnelTop, topY, STEP_DARK, folder)
		end
	end

	-- O vomitorio: a rampa da rua ate a fila de saida.
	local low = Plan.curvePoint(cx, cz, 0.5, R + Plan.backAt + 2, -0.5)
	local high = Plan.curvePoint(cx, cz, 0.5, R + exitRow * S.rowDepth, exitRow * S.rowHeight)
	local ramp = span("Rampa", low, high, S.gangwayWidth, 1, STEP_DARK, folder)
	ramp.CFrame *= CFrame.new(0, -0.5, 0)

	-- A frente.
	if team then
		ring("VedacaoMalha", cx, cz, 0, 1, R - 1.6, R - 1.4, 0, 6, RAIL, folder, { material = Enum.Material.DiamondPlate, transparency = 0.6, collide = true, shadow = false })
		ring("VedacaoTopo", cx, cz, 0, 1, R - 1.7, R - 1.3, 6, 6.3, RAIL, folder, { material = Enum.Material.Metal })
		-- A tarja da claque, atada a vedacao, com o nome virado para o campo.
		local a = Plan.curvePoint(cx, cz, 0.28, R - 1.9, 2.8)
		local b = Plan.curvePoint(cx, cz, 0.72, R - 1.9, 2.8)
		local banner = span("Tarja", a, b, 0.2, 3, team.color, folder, { material = Enum.Material.Fabric })
		banner.CFrame = CFrame.lookAt(banner.Position, banner.Position + (b - a).Unit) -- ao comprido
		local toPitch = -Plan.dir(cx, cz, 0.5)
		local face = if banner.CFrame.RightVector:Dot(toPitch) > 0 then Enum.NormalId.Right else Enum.NormalId.Left
		local sign = Instance.new("SurfaceGui")
		sign.Face = face
		sign.CanvasSize = Vector2.new(1200, 150)
		sign.Parent = banner
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.Text = string.upper(team.name)
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(248, 248, 248)
		text.Parent = sign

		-- As pontas vedadas: o setor e so da claque.
		for _, t in { 0, 1 } do
			local out = Plan.dir(cx, cz, t)
			for row = 1, S.rows do
				local topY = row * S.rowHeight
				local centre = Plan.curvePoint(cx, cz, t, Plan.rowRadius(row), topY + 3.5)
				part("VedacaoSetor", Vector3.new(0.15, 7, S.rowDepth), CFrame.lookAt(centre, centre + out), RAIL, folder, { material = Enum.Material.DiamondPlate, transparency = 0.6, shadow = false })
				local rail = Plan.curvePoint(cx, cz, t, Plan.rowRadius(row), topY + 7.1)
				part("VedacaoSetorTopo", Vector3.new(0.4, 0.3, S.rowDepth), CFrame.lookAt(rail, rail + out), team.color, folder, { material = Enum.Material.Metal })
			end
		end
	else
		ring("GuardaVidro", cx, cz, 0, 1, R - 0.4, R - 0.2, S.rowHeight, S.rowHeight + 3.2, RAIL, folder, { material = Enum.Material.Glass, transparency = 0.55, shadow = false })
		ring("GuardaCorrimao", cx, cz, 0, 1, R - 0.45, R - 0.15, S.rowHeight + 3.2, S.rowHeight + 3.5, RAIL, folder, { material = Enum.Material.Metal })
	end

	-- Por tras: fachada em curva, aberta a meio na porta do vomitorio.
	local backR = R + Plan.backAt
	local wallHeight = Plan.backHeight
	local hwBack = Plan.vomitoryHalfT(backR)
	local pieces = S.curveSegments
	for i = 0, pieces - 1 do
		local ta, tb = i / pieces, (i + 1) / pieces
		-- Parte o pedaco que tem a porta.
		local ranges = { { ta, tb } }
		if ta < 0.5 + hwBack and tb > 0.5 - hwBack then
			ranges = { { ta, math.min(tb, 0.5 - hwBack) }, { math.max(ta, 0.5 + hwBack), tb } }
		end
		for _, rng in ranges do
			if rng[2] - rng[1] > 0.005 then
				local p0 = Plan.curvePoint(cx, cz, rng[1], backR, 0)
				local p1 = Plan.curvePoint(cx, cz, rng[2], backR, 0)
				-- Alarga um pouco para as juntas fecharem.
				local d = (p1 - p0).Unit * 0.4
				facade(p0 - d, p1 + d, Plan.dir(cx, cz, (rng[1] + rng[2]) / 2), wallHeight, folder)
			end
		end
	end
	doorNumber += 1
	local doorAt = Plan.curvePoint(cx, cz, 0.5, backR, 0)
	local title = if team then "PORTA " .. doorNumber .. " · CURVA " .. string.upper(team.short or team.name) else "PORTA " .. doorNumber
	doorway(CFrame.lookAt(doorAt, doorAt + Plan.dir(cx, cz, 0.5)), S.gangwayWidth, tunnelTop, wallHeight, title, folder, team and team.color)

	-- A cobertura em curva, com a aba.
	local roofDepth = STAND_DEPTH * 0.7 + 2
	ring("Cobertura", cx, cz, 0, 1, backR - roofDepth + 0.75, backR + 0.75, wallHeight, wallHeight + 1.4, WHITE, folder, { material = Enum.Material.SmoothPlastic })
	ring("Aba", cx, cz, 0, 1, backR - roofDepth + 0.75, backR - roofDepth + 1.75, wallHeight - 2.6, wallHeight + 1.4, WHITE, folder, { material = Enum.Material.SmoothPlastic })

	-- O nome da curva, na placa do topo das filas, virado para o campo.
	sectorNumber += 1
	local mid = Plan.curvePoint(cx, cz, 0.5, R + (S.rows - 1) * S.rowDepth - 0.12, (S.rows - 1) * S.rowHeight + 0.8)
	local plate = part("PlacaSetor", Vector3.new(9, 1.4, 0.2), CFrame.lookAt(mid, mid - Plan.dir(cx, cz, 0.5)), if team then team.color else BOARD, folder, { material = Enum.Material.SmoothPlastic })
	label(plate, Enum.NormalId.Front, if team then "CURVA " .. string.upper(team.short or team.name) else "SETOR " .. sectorNumber)
end

--------------------------------------------------------------------------------
-- A principal: camarotes, tribuna presidencial e segundo andar
--------------------------------------------------------------------------------

local function buildMainUpper(parent: Instance, centres: { number }, blockList: { Block })
	local folder = folderIn(parent, "Principal")
	local side = MAIN_SIDE
	local run = Plan.sideRun
	local function zAt(across: number): number
		return across * side
	end

	-- Os camarotes: uma fila de caixas de vidro atras do primeiro andar, com
	-- madeira e luz quente por dentro. Ao meio, a tribuna presidencial.
	local boxY = TOP_Y
	local boxH = S.boxHeight
	local boxMid = (Plan.boxFront + Plan.boxBack) / 2
	part("CamarotesChao", Vector3.new(run, 0.6, S.boxDepth), CFrame.new(0, boxY - 0.3, zAt(boxMid)), Color3.fromRGB(120, 96, 70), folder, { material = Enum.Material.WoodPlanks })
	part("CamarotesFundo", Vector3.new(run, boxH, 0.6), CFrame.new(0, boxY + boxH / 2, zAt(Plan.boxBack)), WOOD, folder, { material = Enum.Material.Wood })
	part("CamarotesTeto", Vector3.new(run, 1, S.boxDepth), CFrame.new(0, boxY + boxH + 0.5, zAt(boxMid)), WHITE, folder, { material = Enum.Material.SmoothPlastic })
	local lamp = part("CamarotesLuz", Vector3.new(run - 4, 0.2, 1.2), CFrame.new(0, boxY + boxH - 0.2, zAt(boxMid)), Color3.fromRGB(255, 214, 160), folder, { material = Enum.Material.Neon, shadow = false })
	lamp.Transparency = 0.2
	part("CamarotesVidro", Vector3.new(run, boxH - 1.2, 0.2), CFrame.new(0, boxY + (boxH - 1.2) / 2 + 1.2, zAt(Plan.boxFront + 0.1)), Color3.fromRGB(190, 210, 220), folder, { material = Enum.Material.Glass, transparency = 0.6, shadow = false })
	part("CamarotesParapeito", Vector3.new(run, 1.2, 0.5), CFrame.new(0, boxY + 0.6, zAt(Plan.boxFront + 0.1)), WHITE, folder, { material = Enum.Material.SmoothPlastic })
	-- Divisorias de madeira de 12 em 12 studs.
	local boxes = math.floor(run / 12)
	for i = 1, boxes - 1 do
		local x = -run / 2 + i * (run / boxes)
		if math.abs(x) > 17 then
			part("Divisoria", Vector3.new(0.4, boxH, S.boxDepth - 0.6), CFrame.new(x, boxY + boxH / 2, zAt(boxMid)), WOOD, folder, { material = Enum.Material.Wood })
		end
	end

	-- A tribuna presidencial: mais larga, varanda para fora, cadeiras vermelhas e a placa dourada.
	local tribune = folderIn(folder, "TribunaPresidencial")
	for _, s in { -1, 1 } do
		part("TribunaParede", Vector3.new(0.6, boxH, S.boxDepth), CFrame.new(s * 17, boxY + boxH / 2, zAt(boxMid)), WOOD, tribune, { material = Enum.Material.Wood })
	end
	part("TribunaVaranda", Vector3.new(30, 0.6, 4), CFrame.new(0, boxY - 0.3, zAt(Plan.boxFront - 2)), Color3.fromRGB(120, 96, 70), tribune, { material = Enum.Material.WoodPlanks })
	part("TribunaVidro", Vector3.new(30, 2.6, 0.2), CFrame.new(0, boxY + 1.3, zAt(Plan.boxFront - 4)), Color3.fromRGB(200, 214, 224), tribune, { material = Enum.Material.Glass, transparency = 0.5, shadow = false })
	part("TribunaCorrimao", Vector3.new(30, 0.25, 0.4), CFrame.new(0, boxY + 2.7, zAt(Plan.boxFront - 4)), GOLD, tribune, { material = Enum.Material.Metal })
	for rowIndex = 0, 1 do
		part("TribunaCadeiras", Vector3.new(26, 1, 1.4), CFrame.new(0, boxY + 0.5, zAt(Plan.boxFront - 1 + rowIndex * 2.6)), PRESIDENT_RED, tribune, { material = Enum.Material.Fabric })
		part("TribunaEncostos", Vector3.new(26, 1.6, 0.4), CFrame.new(0, boxY + 1.3, zAt(Plan.boxFront - 0.1 + rowIndex * 2.6)), PRESIDENT_RED, tribune, { material = Enum.Material.Fabric })
	end
	local sign = part("TribunaPlaca", Vector3.new(16, 1.6, 0.2), CFrame.new(0, boxY + boxH - 1, zAt(Plan.boxFront - 0.05)), Color3.fromRGB(30, 26, 22), tribune, { material = Enum.Material.SmoothPlastic })
	label(sign, if side < 0 then Enum.NormalId.Back else Enum.NormalId.Front, "TRIBUNA PRESIDENCIAL", GOLD)

	-- O segundo andar, por cima dos camarotes.
	local upper = folderIn(folder, "SegundoAndar")
	local upperList, upperGangways = layout(run, #blockList)
	for row = 1, S.upperRows do
		local topY = Plan.upperBase + row * S.upperRowHeight
		local across = Plan.upperFront + (row - 0.5) * S.rowDepth
		for _, block in upperList do
			part("Degrau", Vector3.new(block.width, topY - Plan.upperBase + 1, S.rowDepth), CFrame.new(block.centre, (topY + Plan.upperBase - 1) / 2, zAt(across)), STEP, upper)
			part("Cadeiras", Vector3.new(block.width - 1.2, 0.4, S.rowDepth - 0.8), CFrame.new(block.centre, topY + 0.2, zAt(across)), (row % 2 == 0) and SEAT_A or SEAT_B, upper, { material = Enum.Material.SmoothPlastic })
		end
		for _, g in upperGangways do
			part("Escada", Vector3.new(S.gangwayWidth, topY - Plan.upperBase + 1, S.rowDepth), CFrame.new(g, (topY + Plan.upperBase - 1) / 2, zAt(across)), STEP_DARK, upper)
		end
	end
	-- A guarda de vidro a frente do segundo andar.
	local upperFrontY = Plan.upperBase + S.upperRowHeight
	part("GuardaVidro", Vector3.new(run, 3, 0.2), CFrame.new(0, upperFrontY + 1.5, zAt(Plan.upperFront - 0.2)), RAIL, upper, { material = Enum.Material.Glass, transparency = 0.55, shadow = false })
	part("GuardaCorrimao", Vector3.new(run, 0.3, 0.4), CFrame.new(0, upperFrontY + 3.1, zAt(Plan.upperFront - 0.2)), RAIL, upper, { material = Enum.Material.Metal })
	-- Por baixo do segundo andar, a laje branca que se ve do campo.
	part("LajeInferior", Vector3.new(run, 1, Plan.upperDepth + 2), CFrame.new(0, Plan.upperBase - 0.5, zAt(Plan.upperFront + Plan.upperDepth / 2)), WHITE, upper, { material = Enum.Material.SmoothPlastic })


	-- A fachada da principal: alta, branca, vidro quente em baixo, portas numeradas.
	local facadeFolder = folderIn(folder, "Fachada")
	local wallHeight = Plan.upperTop + 7
	local mouthTop = Plan.mouthTop
	local tunnelTop = mouthTop * S.rowHeight
	local doorWidth = S.gangwayWidth + 2
	-- Portas: uma por vomitorio do primeiro andar, e a presidencial ao meio.
	local doors: { { x: number, text: string, tone: Color3? } } = {}
	for g, centre in centres do
		if g > 1 and g < #centres then
			doorNumber += 1
			table.insert(doors, { x = centre, text = "PORTA " .. doorNumber })
		end
	end
	table.insert(doors, { x = 0, text = "PRESIDENCIAL", tone = PRESIDENT_RED })
	table.sort(doors, function(a, b)
		return a.x < b.x
	end)
	local x = -run / 2 - 0.75
	local out = Vector3.new(0, 0, side)
	for _, d in doors do
		facade(Vector3.new(x, 0, zAt(Plan.mainBack)), Vector3.new(d.x - doorWidth / 2, 0, zAt(Plan.mainBack)), out, wallHeight, facadeFolder)
		doorway(CFrame.lookAt(Vector3.new(d.x, 0, zAt(Plan.mainBack)), Vector3.new(d.x, 0, zAt(Plan.mainBack)) + out), doorWidth, tunnelTop + 1, wallHeight, d.text, facadeFolder, d.tone)
		x = d.x + doorWidth / 2
	end
	facade(Vector3.new(x, 0, zAt(Plan.mainBack)), Vector3.new(run / 2 + 0.75, 0, zAt(Plan.mainBack)), out, wallHeight, facadeFolder)
	-- A passadeira vermelha ate a porta presidencial.
	part("Passadeira", Vector3.new(doorWidth - 1, 0.1, 16), CFrame.new(0, 0.05, zAt(Plan.mainBack + 8.5)), PRESIDENT_RED, facadeFolder, { material = Enum.Material.Fabric })
	-- O atrio: a sala por baixo do segundo andar, entre os camarotes e a fachada.
	part("AtrioChao", Vector3.new(run, 0.2, Plan.mainBack - Plan.boxFront), CFrame.new(0, 0.1, zAt((Plan.mainBack + Plan.boxFront) / 2)), Color3.fromRGB(196, 194, 190), facadeFolder, { material = Enum.Material.SmoothPlastic })
	-- Paredes de ponta, para o atrio ser uma sala.
	for _, s in { -1, 1 } do
		part("AtrioPonta", Vector3.new(1.5, wallHeight, Plan.mainBack - Plan.boxFront + 1.5), CFrame.new(s * (run / 2 + 0.75), wallHeight / 2, zAt((Plan.mainBack + Plan.boxFront) / 2)), WHITE, facadeFolder, { material = Enum.Material.SmoothPlastic })
	end

	-- A cobertura da principal, mais alta, cobre o segundo andar e metade do primeiro.
	local roofFront = Plan.innerZ + STAND_DEPTH * 0.45
	local roofDepth = Plan.mainBack - roofFront + 1
	part("Cobertura", Vector3.new(run + 1.5, 1.6, roofDepth), CFrame.new(0, wallHeight + 0.8, zAt(roofFront + roofDepth / 2 - 0.25)), WHITE, folder, { material = Enum.Material.SmoothPlastic })
	part("Aba", Vector3.new(run + 1.5, 5, 1.2), CFrame.new(0, wallHeight - 0.9, zAt(roofFront)), WHITE, folder, { material = Enum.Material.SmoothPlastic })
	-- As pontas da principal fecham em cunha, como nas fotos (a casca dobra-se).
	for _, s in { -1, 1 } do
		local from = Vector3.new(s * (run / 2 + 0.75), wallHeight, zAt(roofFront))
		local to = Vector3.new(s * (run / 2 + 0.75), Plan.backHeight + 1.4, zAt(Plan.innerZ + Plan.backAt - STAND_DEPTH * 0.7))
		span("Cunha", from, to, 1.5, 6, WHITE, folder, { material = Enum.Material.SmoothPlastic })
	end
end

--------------------------------------------------------------------------------
-- Balneario e tunel (por baixo do bloco do meio da principal)
--------------------------------------------------------------------------------

local function buildLockerRoom(parent: Instance)
	local folder = folderIn(parent, "Balneario")
	local z = MAIN_SIDE
	local roomFront = INNER_Z + 5 * S.rowDepth
	local roomBack = INNER_Z + STAND_DEPTH
	local floorY = -0.5
	part("Chao", Vector3.new(ROOM_HALF * 2, 0.2, roomBack - roomFront), CFrame.new(0, floorY + 0.1, z * (roomFront + roomBack) / 2), Color3.fromRGB(196, 198, 204), folder, { material = Enum.Material.SmoothPlastic })
	part("Cacifos", Vector3.new(ROOM_HALF * 2 - 2, 6, 1.2), CFrame.new(0, floorY + 3, z * (roomBack - 0.8)), Color3.fromRGB(58, 84, 120), folder, { material = Enum.Material.Metal })
	part("BancoFundo", Vector3.new(ROOM_HALF * 2 - 4, 1.4, 1.6), CFrame.new(0, floorY + 0.7, z * (roomBack - 3)), WOOD, folder, { material = Enum.Material.Wood })
	for _, s in { -1, 1 } do
		part("BancoLado", Vector3.new(1.6, 1.4, 8), CFrame.new(s * (ROOM_HALF - 1.5), floorY + 0.7, z * (roomFront + 7)), WOOD, folder, { material = Enum.Material.Wood })
	end
	-- A parede de tras do balneario (a principal nao tem fachada a esta distancia).
	part("ParedeFundo", Vector3.new(ROOM_HALF * 2, ROOM_HEIGHT, 1), CFrame.new(0, floorY + ROOM_HEIGHT / 2, z * (roomBack + 0.5)), WHITE_SHADE, folder, { material = Enum.Material.SmoothPlastic })
	local lamp = part("Lampada", Vector3.new(10, 0.3, 2), CFrame.new(0, ROOM_HEIGHT - 0.3, z * (roomFront + roomBack) / 2), Color3.fromRGB(255, 244, 214), folder, { material = Enum.Material.Neon, shadow = false })
	local light = Instance.new("PointLight")
	light.Brightness = 1.4
	light.Range = 26
	light.Shadows = false
	light.Parent = lamp
	for _, s in { -1, 1 } do
		span("CorrimaoTunel", Vector3.new(s * (TUNNEL_HALF + 0.2), S.rowHeight + 1.1, z * (INNER_Z + 0.2)), Vector3.new(s * (TUNNEL_HALF + 0.2), 4 * S.rowHeight + 1.1, z * (INNER_Z + 4 * S.rowDepth)), 0.3, 0.3, RAIL, folder, { material = Enum.Material.Metal })
	end
	part("TunnelGate", Vector3.new(TUNNEL_HALF * 2, TUNNEL_HEIGHT, 0.3), CFrame.new(0, floorY + TUNNEL_HEIGHT / 2, z * (INNER_Z - 0.2)), STEEL, folder, { material = Enum.Material.DiamondPlate, transparency = 0.35 })
end

--------------------------------------------------------------------------------
-- A volta: explanada, torres de iluminacao
--------------------------------------------------------------------------------

local function buildSurround(parent: Instance)
	local folder = folderIn(parent, "Explanada")
	local halfX, zNear, zMain = Plan.grounds()
	part("Explanada", Vector3.new(halfX * 2, 2, zNear + zMain), CFrame.new(0, -1.5, (zNear - zMain) / 2), PLAZA, folder, { material = Enum.Material.Pavement })

	--[[
		As torres de iluminacao, nos quatro cantos, por tras das curvas: finas
		e altas, com a grelha de holofotes virada para o relvado. De dia sao so
		estrutura; a noite o DayNight acende-as (pelas pecas chamadas "Rig").
	]]
	for _, cx in { 1, -1 } do
		for _, cz in { 1, -1 } do
			local foot = Plan.curvePoint(cx, cz, 0.5, R + Plan.backAt + 5, 0)
			local height = Plan.upperTop + 32
			part("Torre", Vector3.new(1.6, height, 1.6), CFrame.new(foot.X, height / 2, foot.Z), STEEL, folder, { material = Enum.Material.Metal })
			local head = Vector3.new(foot.X, height + 3, foot.Z)
			local rig = part("Rig", Vector3.new(10, 6, 1), CFrame.lookAt(head, Vector3.new(0, 0, 0)), STEEL, folder, { material = Enum.Material.Metal, shadow = false })
			local lamps = part("Holofotes", Vector3.new(9, 5, 0.3), rig.CFrame * CFrame.new(0, 0, -0.6), Color3.fromRGB(236, 240, 244), folder, { material = Enum.Material.SmoothPlastic, shadow = false })
			lamps.Name = "Holofotes"
		end
	end
end

--------------------------------------------------------------------------------

function Builder.build(parent: Instance): Folder
	local old = parent:FindFirstChild("Estadio")
	if old then
		old:Destroy()
	end
	doorNumber = 0
	sectorNumber = 0

	local root = Instance.new("Folder")
	root.Name = "Estadio"

	buildSurround(root)
	buildPitch(root)

	-- As rectas: a principal (com tunel e balneario), a lateral do publico e os dois topos.
	local mainCentres, mainBlocks = buildStand(false, MAIN_SIDE, Plan.sideRun, S.blocksLong, root, { tunnel = true, main = true })
	buildStand(false, -MAIN_SIDE, Plan.sideRun, S.blocksLong, root)
	buildStand(true, 1, Plan.endRun, S.blocksEnd, root)
	buildStand(true, -1, Plan.endRun, S.blocksEnd, root)

	-- As curvas: duas das claques (na diagonal) e duas do publico.
	local claqueAt: { [string]: string } = {}
	for _, teamId in Config.TeamOrder do
		local cx, cz = Plan.claqueCorner(teamId)
		claqueAt[cx .. "," .. cz] = teamId
	end
	for _, cx in { 1, -1 } do
		for _, cz in { 1, -1 } do
			buildCurve(cx, cz, claqueAt[cx .. "," .. cz], root)
		end
	end

	buildMainUpper(root, mainCentres, mainBlocks)
	buildLockerRoom(root)

	root.Parent = parent
	return root
end

return Builder
