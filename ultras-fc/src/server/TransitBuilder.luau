--!strict
--[[
	Poe no mapa os transportes publicos (Workspace.Transportes), para se verem
	e mexerem no Studio sem Play:

	- Rotas/<Linha>: os pontos de cada percurso ("Ponto", pela ordem do
	  atributo Order), no meio da rua, nos cruzamentos. O Transit faz a faixa
	  (pela direita) e as curvas a partir deles. Uma pasta "Tracado" desenha o
	  percurso no chao a cores, so para se ver no Studio; no Play some.
	- Paragens: um abrigo por paragem, com o nome e as linhas que la param.
	- Autocarros: os autocarros parados onde comecam; no Play arrancam.

	A Linha 1 da a volta a cidade pelas duas sedes; a Linha 2 anda a volta do
	estadio e passa na academia. O autocarro da equipa (E) leva quem joga da
	academia ao estadio no corteo, e depois volta.

	Corre-se uma vez no Studio. Refazer apaga o que la estiver.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BusBuilder = require(script.Parent:WaitForChild("BusBuilder"))

local Builder = {}

local T = Config.Transit

type Stop = { name: string, lines: string, at: Vector2 }
type Line = {
	id: string,
	colour: Color3,
	destination: string,
	nodes: { Vector2 },
	stops: { Stop },
	buses: number,
	team: string?, -- o autocarro de um clube (leva quem joga da academia ao estadio)
}

local LINES: { Line } = {
	{
		id = "1",
		colour = Color3.fromRGB(226, 176, 30),
		destination = "CIRCULAR · SEDES",
		nodes = { Vector2.new(-630, -600), Vector2.new(-630, 580), Vector2.new(630, 580), Vector2.new(630, -600) },
		stops = {
			{ name = "Sede Vermelha", lines = "1", at = Vector2.new(-630, 500) },
			{ name = "Avenida Norte", lines = "1", at = Vector2.new(0, 580) },
			{ name = "Zona Nova", lines = "1", at = Vector2.new(630, 250) },
			{ name = "Sede Azul", lines = "1", at = Vector2.new(630, -540) },
			{ name = "Academia LES", lines = "1", at = Vector2.new(-110, -600) },
			{ name = "Bairro Velho", lines = "1", at = Vector2.new(-630, -100) },
		},
		buses = 2,
	},
	{
		id = "2",
		colour = Color3.fromRGB(40, 120, 210),
		destination = "ESTADIO · ACADEMIA",
		nodes = { Vector2.new(-200, -165), Vector2.new(200, -165), Vector2.new(200, 440), Vector2.new(-200, 440) },
		stops = {
			{ name = "Estadio Principal", lines = "2", at = Vector2.new(0, -165) },
			{ name = "Estadio Nascente", lines = "2", at = Vector2.new(200, 20) },
			{ name = "Academia AGN", lines = "2", at = Vector2.new(100, 440) },
			{ name = "Estadio Poente", lines = "2", at = Vector2.new(-200, 20) },
		},
		buses = 1,
	},
	{
		id = "EN",
		team = "home",
		colour = Config.Teams.home.color,
		destination = "EQUIPA · ESTADIO",
		nodes = { Vector2.new(-200, 440), Vector2.new(200, 440), Vector2.new(200, -165), Vector2.new(-200, -165) },
		stops = {
			{ name = "Academia AGN · Equipa", lines = "EN", at = Vector2.new(40, 440) },
			{ name = "Estadio · Jogadores AGN", lines = "EN", at = Vector2.new(60, -165) },
		},
		buses = 1,
	},
	{
		id = "ES",
		team = "away",
		colour = Config.Teams.away.color,
		destination = "EQUIPA · ESTADIO",
		nodes = { Vector2.new(200, -600), Vector2.new(-200, -600), Vector2.new(-200, -165), Vector2.new(200, -165) },
		stops = {
			{ name = "Academia LES · Equipa", lines = "ES", at = Vector2.new(-40, -600) },
			{ name = "Estadio · Jogadores LES", lines = "ES", at = Vector2.new(-60, -165) },
		},
		buses = 1,
	},
}

local ROAD_Y = -0.6 -- o topo da estrada
local KERB_Y = 0.3 -- o topo do passeio

-- Meia largura da rua (as mesmas contas do CityMap).
local function halfWidth(axis: string, value: number): number
	if (axis == "x" and math.abs(value) == 200) or (axis == "z" and math.abs(value) == 165) then
		return 15
	elseif axis == "z" and value == 300 then
		return 20
	elseif axis == "x" and (value == -330 or value == 490) then
		return 17
	end
	return 13
end

local function part(name: string, size: Vector3, cf: CFrame, colour: Color3, parent: Instance, material: Enum.Material?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function v3(p: Vector2, y: number): Vector3
	return Vector3.new(p.X, y, p.Y)
end

-- O segmento do percurso onde fica este ponto, e para onde ele anda.
local function segmentAt(nodes: { Vector2 }, at: Vector2): (Vector2?, Vector2?)
	for i = 1, #nodes do
		local a = nodes[i]
		local b = nodes[i % #nodes + 1]
		local ab = b - a
		local t = (at - a):Dot(ab) / ab:Dot(ab)
		local closest = a + ab * math.clamp(t, 0, 1)
		if (closest - at).Magnitude < 1 then
			return a, b
		end
	end
	return nil, nil
end

-- O abrigo da paragem, no passeio do lado da faixa, virado para a rua.
local function buildStop(stop: Stop, line: Line, parent: Instance)
	local a, b = segmentAt(line.nodes, stop.at)
	if not a or not b then
		warn("[Ultras FC] Paragem fora do percurso: " .. stop.name)
		return
	end
	local dir = (b - a).Unit
	local d3 = Vector3.new(dir.X, 0, dir.Y)
	local right = d3:Cross(Vector3.yAxis)
	local axis = if math.abs(dir.X) < 0.5 then "x" else "z"
	local value = if axis == "x" then a.X else a.Y
	local out = halfWidth(axis, value) + 3.5
	local base = v3(stop.at, KERB_Y) + right * out
	local cf = CFrame.lookAt(base, base - right) -- de frente para a rua

	local model = Instance.new("Model")
	model.Name = "Paragem " .. stop.name
	model:SetAttribute("Nome", stop.name)
	model:SetAttribute("Linhas", stop.lines)

	local STEEL = Color3.fromRGB(70, 74, 80)
	local glass = Color3.fromRGB(200, 214, 224)
	part("Chao", Vector3.new(12, 0.2, 5), cf * CFrame.new(0, 0.1, 0), Color3.fromRGB(150, 150, 146), model, Enum.Material.Concrete)
	local pivot = part("Pivo", Vector3.new(1, 1, 1), cf * CFrame.new(0, 0.5, 0), STEEL, model)
	pivot.Transparency = 1
	pivot.CanCollide = false
	model.PrimaryPart = pivot
	part("Telhado", Vector3.new(12, 0.4, 4.4), cf * CFrame.new(0, 8.8, 0.3), Color3.fromRGB(236, 236, 232), model)
	part("Fundo", Vector3.new(11.6, 7.4, 0.2), cf * CFrame.new(0, 4.9, 2.3), glass, model, Enum.Material.Glass, 0.55)
	for _, s in { -1, 1 } do
		part("Poste", Vector3.new(0.35, 8.6, 0.35), cf * CFrame.new(s * 5.8, 4.4, 2.3), STEEL, model, Enum.Material.Metal)
		part("PosteFrente", Vector3.new(0.35, 8.6, 0.35), cf * CFrame.new(s * 5.8, 4.4, -1.6), STEEL, model, Enum.Material.Metal)
		part("Lado", Vector3.new(0.2, 7.4, 3.6), cf * CFrame.new(s * 5.8, 4.9, 0.4), glass, model, Enum.Material.Glass, 0.55)
	end
	part("Banco", Vector3.new(8, 0.3, 1.4), cf * CFrame.new(0, 1.8, 1.5), Color3.fromRGB(150, 110, 70), model, Enum.Material.Wood)
	part("BancoCostas", Vector3.new(8, 1.4, 0.2), cf * CFrame.new(0, 2.6, 2.15), Color3.fromRGB(150, 110, 70), model, Enum.Material.Wood)

	-- A placa com o nome e as linhas, por cima, e o poste com o simbolo do autocarro.
	local board = part("Placa", Vector3.new(8, 1.4, 0.2), cf * CFrame.new(0, 9.9, -0.6), line.colour, model)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(640, 110)
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(250, 250, 250)
		label.Text = string.upper(stop.name) .. "   ·   " .. (if line.team then "SO EQUIPA" else "LINHA " .. stop.lines)
		label.Parent = gui
	end
	part("PosteSinal", Vector3.new(0.3, 10, 0.3), cf * CFrame.new(-7.5, 5, -1.6), STEEL, model, Enum.Material.Metal)
	local disc = part("Sinal", Vector3.new(0.2, 2.2, 2.2), cf * CFrame.new(-7.5, 9.4, -1.6) * CFrame.Angles(0, math.rad(90), 0), line.colour, model)
	disc.Shape = Enum.PartType.Cylinder
	local busSign = part("SinalBus", Vector3.new(1.6, 1, 0.1), cf * CFrame.new(-7.5, 9.4, -1.72), line.colour, model)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(160, 100)
		gui.Parent = busSign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Text = "BUS"
		label.Parent = gui
	end
	-- A faixa amarela na estrada, onde o autocarro encosta.
	local lane = v3(stop.at, ROAD_Y + 0.03) + right * T.laneOffset
	part("MarcaParagem", Vector3.new(0.2, 0.05, 30), CFrame.lookAt(lane + right * 4.5, lane + right * 4.5 + d3), Color3.fromRGB(240, 200, 40), model, Enum.Material.SmoothPlastic)

	model.Parent = parent
end

-- Os pontos do percurso e o tracado a cores na faixa (so para se ver no Studio).
local function buildRoute(line: Line, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = line.id
	folder:SetAttribute("Colour", line.colour)
	folder:SetAttribute("Destination", line.destination)
	folder.Parent = parent
	for i, node in line.nodes do
		local p = part("Ponto", Vector3.new(3, 3, 3), CFrame.new(v3(node, 1)), line.colour, folder, Enum.Material.Neon, 0.3)
		p.Shape = Enum.PartType.Ball
		p.CanCollide = false
		p.CanQuery = false
		p:SetAttribute("Order", i)
	end
	local drawn = Instance.new("Folder")
	drawn.Name = "Tracado"
	drawn.Parent = folder
	for i = 1, #line.nodes do
		local a = line.nodes[i]
		local b = line.nodes[i % #line.nodes + 1]
		local d = (b - a).Unit
		local right = Vector3.new(d.X, 0, d.Y):Cross(Vector3.yAxis)
		local from = v3(a, ROAD_Y + 0.05) + right * T.laneOffset
		local to = v3(b, ROAD_Y + 0.05) + right * T.laneOffset
		local strip = part("Faixa", Vector3.new(1.2, 0.05, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), line.colour, drawn, Enum.Material.Neon, 0.35)
		strip.CanCollide = false
		strip.CanQuery = false
	end
end

-- Tira os carros estacionados que ficavam no caminho dos autocarros.
local function clearCars(lines: { Line })
	local city = workspace:FindFirstChild("Cidade")
	local cars = city and city:FindFirstChild("Carros", true)
	if not cars then
		return 0
	end
	local removed = 0
	for _, car in cars:GetChildren() do
		local p = if car:IsA("Model") then car:GetPivot().Position elseif car:IsA("BasePart") then car.Position else nil
		if p then
			local flat = Vector2.new(p.X, p.Z)
			for _, line in lines do
				local hit = false
				for i = 1, #line.nodes do
					local a = line.nodes[i]
					local b = line.nodes[i % #line.nodes + 1]
					local ab = b - a
					local t = math.clamp((flat - a):Dot(ab) / ab:Dot(ab), 0, 1)
					if (a + ab * t - flat).Magnitude < 12 then
						hit = true
					end
				end
				if hit then
					car:Destroy()
					removed += 1
					break
				end
			end
		end
	end
	return removed
end

function Builder.build(parent: Instance): (Folder, number)
	local old = parent:FindFirstChild("Transportes")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Transportes"
	local routes = Instance.new("Folder")
	routes.Name = "Rotas"
	routes.Parent = root
	local stops = Instance.new("Folder")
	stops.Name = "Paragens"
	stops.Parent = root
	local buses = Instance.new("Folder")
	buses.Name = "Autocarros"
	buses.Parent = root

	for _, line in LINES do
		buildRoute(line, routes)
		for _, stop in line.stops do
			buildStop(stop, line, stops)
		end
		-- Os autocarros, parados na faixa, espalhados pelo percurso.
		for n = 1, line.buses do
			local i = ((n - 1) * 2) % #line.nodes + 1
			local a = line.nodes[i]
			local b = line.nodes[i % #line.nodes + 1]
			local d = (b - a).Unit
			local right = Vector3.new(d.X, 0, d.Y):Cross(Vector3.yAxis)
			local at = v3(a + d * 60, ROAD_Y) + right * T.laneOffset
			if line.team then
				-- O da equipa espera na paragem da academia.
				at = v3(line.stops[1].at, ROAD_Y) + right * T.laneOffset
			end
			local bus = BusBuilder.build({ colour = line.colour, line = line.id, destination = line.destination }, CFrame.lookAt(at, at + Vector3.new(d.X, 0, d.Y)), buses)
			bus.Name = "Autocarro " .. line.id .. (if line.buses > 1 then "-" .. n else "")
			bus:SetAttribute("Line", line.id)
			bus:SetAttribute("Team", line.team)
		end
	end

	local removed = clearCars(LINES)
	root.Parent = parent
	return root, removed
end

return Builder
