--!strict
--[[
	Constroi um estadio de pecas soltas: relvado, duas bancadas em degraus,
	balizas e holofotes.

	Nao e para ficar assim. E para haver um sitio, e sobretudo para se perceber
	de que lado se esta — sem isso, cantar numa bancada nao quer dizer nada.
	Quando construires o teu a mao, poe Config.Stadium.build a false.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Stadium = {}

local S = Config.Stadium

local function part(name: string, size: Vector3, cf: CFrame, colour: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local GRASS = Color3.fromRGB(58, 122, 64)
local LINE = Color3.fromRGB(226, 230, 226)
local CONCRETE = Color3.fromRGB(122, 126, 132)

--[[
	Uma bancada: filas em degrau a subir e a afastar-se do relvado.
	Devolve o ponto onde os adeptos desta equipa aparecem.
]]
local function buildStand(teamId: string, parent: Instance): Vector3
	local team = Config.Teams[teamId]
	local side = team.side

	local folder = Instance.new("Folder")
	folder.Name = "Stand_" .. teamId
	folder.Parent = parent

	local firstRowZ = (S.pitchWidth / 2 + S.standGap) * side

	for row = 1, S.standRows do
		-- Cada fila e um bloco macico do chao ate ao seu topo. Blocos da altura
		-- de um degrau so, colocados a alturas diferentes, ficavam a flutuar com
		-- vazio por baixo — e o que faz uma escadaria e cada um assentar no chao.
		local topY = row * S.rowHeight
		local z = firstRowZ + (row - 1) * S.rowDepth * side

		part(
			"Row" .. row,
			Vector3.new(S.pitchLength + 20, topY, S.rowDepth),
			CFrame.new(0, topY / 2, z),
			CONCRETE,
			folder
		)

		-- Faixa da cor da equipa na beira do degrau, virada para o relvado. E o
		-- que torna a bancada reconhecivel de longe, que e metade do efeito.
		part(
			"Stripe" .. row,
			Vector3.new(S.pitchLength + 20, 0.4, 0.9),
			CFrame.new(0, topY + 0.2, z - (S.rowDepth / 2 - 0.45) * side),
			team.color,
			folder
		)
	end

	local topY = S.standRows * S.rowHeight
	local topZ = firstRowZ + (S.standRows - 1) * S.rowDepth * side

	-- Parede ao fundo, para nao se cair para tras nem se ver o vazio.
	part(
		"BackWall",
		Vector3.new(S.pitchLength + 20, topY + 12, 2),
		CFrame.new(0, (topY + 12) / 2, topZ + (S.rowDepth / 2 + 1) * side),
		team.color,
		folder
	)

	-- A meio da bancada, alto o suficiente para se ver o relvado.
	local spawnRow = math.ceil(S.standRows / 2)
	return Vector3.new(
		0,
		spawnRow * S.rowHeight + 3.5, -- em cima do degrau, com folga para assentar
		firstRowZ + (spawnRow - 1) * S.rowDepth * side
	)
end

local function buildGoal(xSign: number, parent: Instance)
	local x = (S.pitchLength / 2 - 1) * xSign
	local folder = Instance.new("Folder")
	folder.Name = "Goal" .. (xSign > 0 and "East" or "West")
	folder.Parent = parent

	part("PostLeft", Vector3.new(1, 8, 1), CFrame.new(x, 4, -7), LINE, folder)
	part("PostRight", Vector3.new(1, 8, 1), CFrame.new(x, 4, 7), LINE, folder)
	part("Crossbar", Vector3.new(1, 1, 15), CFrame.new(x, 8, 0), LINE, folder)
end

-- Guardado por equipa para o Main poder por cada um no seu lado.
local spawnPoints: { [string]: Vector3 } = {}

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

	local root = Instance.new("Folder")
	root.Name = "Stadium"
	root.Parent = workspace

	part(
		"Pitch",
		Vector3.new(S.pitchLength, 1, S.pitchWidth),
		CFrame.new(0, -0.5, 0),
		GRASS,
		root
	)
	part("HalfwayLine", Vector3.new(0.6, 1.1, S.pitchWidth), CFrame.new(0, -0.45, 0), LINE, root)

	for _, teamId in Config.TeamOrder do
		spawnPoints[teamId] = buildStand(teamId, root)
	end

	buildGoal(1, root)
	buildGoal(-1, root)

	-- Luz alta e fria, que e o que faz um relvado nocturno parecer um relvado.
	for _, corner in { Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) } do
		local mast = part(
			"Floodlight",
			Vector3.new(3, 46, 3),
			CFrame.new(
				corner.X * (S.pitchLength / 2 + 14),
				23,
				corner.Y * (S.pitchWidth / 2 + S.standRows * S.rowDepth + 14)
			),
			CONCRETE,
			root
		)

		local light = Instance.new("PointLight")
		light.Brightness = 3
		light.Range = 120
		light.Color = Color3.fromRGB(235, 242, 255)
		light.Parent = mast
	end
end

return Stadium
