--!strict
--[[
	A cidade a volta, e as duas sedes.

	Isto existe por uma razao: nao se entra num estadio por magia. Apareces na
	sede da tua claque, sais para a rua, e andas ate la — e no caminho que o
	corteo ha-de acontecer. Um jogo que te punha ja sentado na bancada perdia a
	melhor parte.

	As sedes ficam em pontas opostas da avenida, de proposito: as duas claques
	nao se cruzam antes do estadio, e cada uma faz o seu percurso.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local City = {}

local S = Config.Stadium

local ASPHALT = Color3.fromRGB(22, 23, 27)
local KERB = Color3.fromRGB(44, 46, 52)
local WINDOW_ON = Color3.fromRGB(255, 226, 164)
local WINDOW_OFF = Color3.fromRGB(38, 42, 52)

local WALLS = {
	Color3.fromRGB(58, 56, 54),
	Color3.fromRGB(48, 50, 56),
	Color3.fromRGB(66, 60, 54),
	Color3.fromRGB(42, 44, 50),
	Color3.fromRGB(72, 66, 58),
}

local spawnPoints: { [string]: Vector3 } = {}

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	parent: Instance,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Anchored = true
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function streetLamp(x: number, z: number, facing: number, parent: Instance)
	part("Pole", Vector3.new(0.8, 18, 0.8), CFrame.new(x, 9, z), Color3.fromRGB(26, 28, 33), parent, Enum.Material.Metal)

	local lamp = part(
		"Lamp",
		Vector3.new(3.4, 0.6, 1.6),
		CFrame.new(x + math.sin(facing) * 1.8, 18, z + math.cos(facing) * 1.8),
		WINDOW_ON,
		parent,
		Enum.Material.Neon
	)
	lamp.CastShadow = false

	local light = Instance.new("PointLight")
	light.Brightness = 2.4
	light.Range = 44
	light.Color = Color3.fromRGB(255, 214, 152)
	light.Parent = lamp
end

--[[
	Um predio. Janelas acesas ao acaso — e isso que separa uma cidade de uma
	fila de caixas: uma fachada toda igual le-se como cenario, uma com luzes
	trocadas le-se como gente la dentro.
]]
local function building(centre: Vector3, footprint: Vector2, floors: number, parent: Instance)
	local floorHeight = 5
	local height = floors * floorHeight
	local colour = WALLS[math.random(1, #WALLS)]

	part(
		"Walls",
		Vector3.new(footprint.X, height, footprint.Y),
		CFrame.new(centre.X, height / 2, centre.Z),
		colour,
		parent
	)

	-- Cornija, para o topo nao ser um corte seco.
	part(
		"Cornice",
		Vector3.new(footprint.X + 1.5, 1, footprint.Y + 1.5),
		CFrame.new(centre.X, height + 0.5, centre.Z),
		colour:Lerp(Color3.new(0, 0, 0), 0.35),
		parent
	)

	for floor = 1, floors do
		local y = (floor - 0.5) * floorHeight
		for _, spec in {
			{ normal = Vector3.new(0, 0, 1), span = footprint.X, depth = footprint.Y / 2 },
			{ normal = Vector3.new(0, 0, -1), span = footprint.X, depth = footprint.Y / 2 },
			{ normal = Vector3.new(1, 0, 0), span = footprint.Y, depth = footprint.X / 2 },
			{ normal = Vector3.new(-1, 0, 0), span = footprint.Y, depth = footprint.X / 2 },
		} do
			local count = math.max(2, math.floor(spec.span / 7))
			for i = 1, count do
				local offset = (i - (count + 1) / 2) * (spec.span / count)
				local along = Vector3.new(spec.normal.Z, 0, spec.normal.X) * offset
				local position = Vector3.new(centre.X, y, centre.Z) + along + spec.normal * (spec.depth + 0.15)

				local pane = part(
					"Window",
					Vector3.new(
						spec.normal.X ~= 0 and 0.4 or 2.6,
						2.4,
						spec.normal.Z ~= 0 and 0.4 or 2.6
					),
					CFrame.new(position),
					math.random() < 0.55 and WINDOW_ON or WINDOW_OFF,
					parent,
					Enum.Material.Neon
				)
				pane.CastShadow = false
			end
		end
	end
end

--[[
	A sede da claque. E daqui que se sai, por isso tem de se perceber de quem e
	antes sequer de se ler o nome: a cor esta na fachada toda, nao num cartaz.
]]
local function clubhouse(teamId: string, centre: Vector3, parent: Instance)
	local team = Config.Teams[teamId]
	local folder = Instance.new("Folder")
	folder.Name = "Clubhouse_" .. teamId
	folder.Parent = parent

	local width, depth, height = 46, 34, 14

	part("Floor", Vector3.new(width, 2, depth), CFrame.new(centre.X, 0, centre.Z), Color3.fromRGB(38, 38, 42), folder)
	part("Roof", Vector3.new(width + 3, 1.5, depth + 3), CFrame.new(centre.X, height, centre.Z), Color3.fromRGB(24, 26, 30), folder)

	-- Tres paredes e a frente aberta: entra-se e sai-se sem porta nenhuma.
	part("Back", Vector3.new(width, height, 2), CFrame.new(centre.X, height / 2, centre.Z - depth / 2), team.color, folder)
	part("Left", Vector3.new(2, height, depth), CFrame.new(centre.X - width / 2, height / 2, centre.Z), team.color, folder)
	part("Right", Vector3.new(2, height, depth), CFrame.new(centre.X + width / 2, height / 2, centre.Z), team.color, folder)

	-- Faixa por cima da entrada.
	local banner = part(
		"Banner",
		Vector3.new(width - 6, 4, 0.6),
		CFrame.new(centre.X, height - 3, centre.Z + depth / 2),
		team.color,
		folder,
		Enum.Material.Fabric
	)

	local sign = Instance.new("SurfaceGui")
	sign.Face = Enum.NormalId.Front
	sign.CanvasSize = Vector2.new(800, 140)
	sign.Parent = banner

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.Text = team.name
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(245, 245, 245)
	text.Parent = sign

	-- Luz quente la dentro, que e o que faz uma sede parecer aberta a noite.
	local glow = part("Glow", Vector3.new(width - 8, 0.5, depth - 8), CFrame.new(centre.X, height - 1.5, centre.Z), WINDOW_ON, folder, Enum.Material.Neon)
	glow.CastShadow = false

	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 60
	light.Color = team.color:Lerp(Color3.fromRGB(255, 230, 190), 0.6)
	light.Parent = glow

	-- Sai-se de frente para a rua, virado para o estadio.
	spawnPoints[teamId] = Vector3.new(centre.X, 4, centre.Z + depth / 2 + 8)
end

function City.spawnPoint(teamId: string): Vector3?
	return spawnPoints[teamId]
end

function City.build(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "City"
	folder.Parent = parent

	local outerZ = S.pitchWidth / 2 + S.standGap + S.standRows * S.rowDepth + 30
	local roadZ = outerZ + 70
	local roadLength = 900

	-- Quarteiroes dos dois lados da avenida, deixando a faixa da estrada livre.
	local blockDepth = 90
	for _, side in { 1, -1 } do
		local rowZ = roadZ + (50 + blockDepth / 2) * side

		for i = 1, 9 do
			local x = -roadLength / 2 + 40 + (i - 1) * 100
			-- Deixa um vao a meio: e por ali que se corta para o estadio.
			if math.abs(x) > 70 then
				local width = math.random(38, 62)
				local depth = math.random(34, 54)
				building(Vector3.new(x, 0, rowZ), Vector2.new(width, depth), math.random(3, 9), folder)
			end
		end

		-- Passeio virado a avenida.
		part("Pavement", Vector3.new(roadLength, 2.6, 14), CFrame.new(0, -1.1, roadZ + 44 * side), KERB, folder)
	end

	-- Rua transversal, do vao dos quarteiroes ate a avenida.
	part("CrossStreet", Vector3.new(60, 2, 200), CFrame.new(0, -1.45, roadZ + 120), ASPHALT, folder, Enum.Material.Asphalt)
	for i = 1, 6 do
		streetLamp(34, roadZ + 40 + i * 28, math.pi, folder)
		streetLamp(-34, roadZ + 40 + i * 28, 0, folder)
	end

	-- As sedes, em pontas opostas: as duas claques nao se cruzam antes do jogo.
	local order = Config.TeamOrder
	clubhouse(order[1], Vector3.new(-roadLength / 2 + 90, 0, roadZ + 110), folder)
	clubhouse(order[2], Vector3.new(roadLength / 2 - 90, 0, roadZ + 110), folder)
end

return City
