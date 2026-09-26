--!strict
--[[
	Um autocarro urbano, de pecas: carrocaria de piso rebaixado, faixa de
	vidro escuro a toda a volta, duas portas duplas de correr do lado direito,
	rodas que giram, bancos onde se senta, varoes, farois e o letreiro da
	linha a frente e atras.

	A origem e o meio do autocarro ao nivel da estrada, virado para -Z (para
	a frente). Constroi-se ancorado (para ficar parado no mapa, a ver-se no
	Studio); quem o poe a andar e o Transit.

	Pecas com nome que o Transit usa:
	- "Chassis" (PrimaryPart), a que tudo esta preso;
	- "Roda" (4), para girar;
	- "Porta" (4), com atributos Door (1 ou 2) e Slide (para que lado corre);
	- os "Banco" sao Seats.
]]

local Builder = {}

local LENGTH = 40
local WIDTH = 10
local FLOOR = 2.6 -- a altura do piso acima da estrada
local ROOF = 11.2
local WHEEL_R = 1.8

local GLASS = Color3.fromRGB(34, 40, 48)
local WHITE = Color3.fromRGB(240, 240, 238)
local DARK = Color3.fromRGB(28, 30, 34)
local GREY = Color3.fromRGB(120, 124, 130)
local SEAT = Color3.fromRGB(46, 70, 120)
local POLE = Color3.fromRGB(230, 190, 40)

export type Livery = {
	colour: Color3, -- a faixa de baixo e a frente
	line: string, -- o numero ou a letra da linha
	destination: string, -- o que se le no letreiro
}

-- As duas portas: onde ficam (z do meio da porta) e a largura.
local DOORS = { { z = -15.2, width = 4.2 }, { z = 2.5, width = 4.2 } }

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

local function sign(on: BasePart, face: Enum.NormalId, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(600, 80)
	gui.LightInfluence = 0
	gui.Parent = on
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 176, 40)
	label.Text = text
	label.Parent = gui
end

--[[
	Os paineis de um lado, partidos onde ha portas (so do lado direito, +X).
	`y0`/`y1` a altura do painel; `inset` quanto fica para dentro.
]]
local function sidePanels(name: string, x: number, doors: boolean, y0: number, y1: number, colour: Color3, parent: Instance, material: Enum.Material?, transparency: number?, thick: number?)
	local edges = { -LENGTH / 2 + 0.6 }
	if doors then
		for _, d in DOORS do
			table.insert(edges, d.z - d.width / 2)
			table.insert(edges, d.z + d.width / 2)
		end
	end
	table.insert(edges, LENGTH / 2 - 0.6)
	for i = 1, #edges, 2 do
		local a, b = edges[i], edges[i + 1]
		part(name, Vector3.new(thick or 0.3, y1 - y0, b - a), CFrame.new(x, (y0 + y1) / 2, (a + b) / 2), colour, parent, material, transparency)
	end
end

--------------------------------------------------------------------------------
-- O autocarro a serio: o MAN Lion's City do Toolbox, sem scripts
--------------------------------------------------------------------------------

--[[
	Se houver o modelo em ServerStorage.ModelosAutocarro.MAN (a carrocaria e
	o interior em malha, limpos de scripts), o autocarro e esse. A malha e so
	o aspeto: nao choca com nada. Quem choca sao pecas invisiveis simples a
	mesma forma (piso, paredes, tecto, frente e tras), para se poder entrar,
	andar la dentro e sentar sem ficar preso na malha.

	O modelo esta com a frente para +X e as portas em +Z; aqui roda-se para a
	frente ficar em -Z e as portas a direita (+X), como o resto do jogo.
]]
local MESH = {
	length = 50,
	floor = 3.75, -- o chao por dentro, acima da estrada
	roof = 11.6,
	side = 4.55,
	wheelRadius = 1.95,
	doors = { { from = -21.5, to = -18.0 }, { from = 1.1, to = 6.6 } }, -- em z, ja rodado
}

local function template(): Model?
	local ServerStorage = game:GetService("ServerStorage")
	local store = ServerStorage:FindFirstChild("ModelosAutocarro")
	local m = store and store:FindFirstChild("MAN")
	return if m and m:IsA("Model") then m else nil
end

local function buildMesh(source: Model, livery: Livery, at: CFrame, parent: Instance): Model
	local model = source:Clone()
	model.Name = "Autocarro"
	model:SetAttribute("Info", nil)
	model:SetAttribute("Line", livery.line)
	model:SetAttribute("Length", MESH.length)
	model:SetAttribute("Ride", 2)
	model:SetAttribute("WheelRadius", MESH.wheelRadius)

	-- Tudo no referencial do modelo: pivo no chao, entre as rodas; rodado.
	local turn = CFrame.Angles(0, math.rad(90), 0)
	local frame = source.WorldPivot
	local driverAt: CFrame? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = turn * frame:ToObjectSpace(d.CFrame)
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("VehicleSeat") then
			driverAt = d.CFrame
			d:Destroy()
		elseif d:IsA("Seat") then
			d.Name = "Banco"
			d.CanCollide = true
			d.CanTouch = true
		elseif d:IsA("BasePart") then
			local lower = string.lower(d.Name)
			if d.Parent and d.Parent.Name == "Wheels" then
				d.Name = "Roda"
				d.Transparency = 1
			elseif d.Parent and d.Parent:IsA("BasePart") and d.Parent.Name == "Roda" then
				d.Name = "Jante"
			elseif string.find(lower, "door_front") or string.find(lower, "door_back") then
				-- As portas: saem um pouco para fora e correm para os lados.
				local door = if string.find(lower, "door_front") then 1 else 2
				local range = MESH.doors[door]
				local centre = (range.from + range.to) / 2
				local slide = if d.Position.Z < centre then -1 else 1
				d.Name = "Porta"
				d:SetAttribute("Door", door)
				d:SetAttribute("OpenOffset", Vector3.new(0.6, 0, slide * 1.4))
			end
		end
	end
	-- Os nomes das pecas das rodas ficam depois de os pais mudarem de nome.
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Roda" and d:FindFirstAncestor("Roda") then
			d.Name = "Jante"
		end
	end

	local proxies = Instance.new("Folder")
	proxies.Name = "Colisao"
	proxies.Parent = model
	local function proxy(name: string, size: Vector3, cf: CFrame): Part
		local p = part(name, size, cf, GREY, proxies)
		p.Transparency = 1
		return p
	end
	local L = MESH.length - 1.5
	local wallH = MESH.roof - MESH.floor
	local wallY = MESH.floor + wallH / 2
	proxy("Piso", Vector3.new(MESH.side * 2, 0.6, L), CFrame.new(0, MESH.floor - 0.3, 0))
	proxy("Tecto", Vector3.new(MESH.side * 2, 0.4, L), CFrame.new(0, MESH.roof + 0.2, 0))
	proxy("Frente", Vector3.new(MESH.side * 2, wallH, 0.4), CFrame.new(0, wallY, -L / 2))
	proxy("Tras", Vector3.new(MESH.side * 2, wallH, 0.4), CFrame.new(0, wallY, L / 2))
	proxy("Lado", Vector3.new(0.3, wallH, L), CFrame.new(-MESH.side, wallY, 0))
	-- O lado das portas, partido nas portas; nas portas, uma tampa que abre.
	local edges = { -L / 2 }
	for _, d in MESH.doors do
		table.insert(edges, d.from)
		table.insert(edges, d.to)
	end
	table.insert(edges, L / 2)
	for i = 1, #edges, 2 do
		local a, b = edges[i], edges[i + 1]
		proxy("Lado", Vector3.new(0.3, wallH, b - a), CFrame.new(MESH.side, wallY, (a + b) / 2))
	end
	for index, d in MESH.doors do
		local width = d.to - d.from
		local block = proxy("Porta", Vector3.new(0.3, wallH, width), CFrame.new(MESH.side, wallY, (d.from + d.to) / 2))
		block:SetAttribute("Door", index)
		block:SetAttribute("Blocker", true)
		block:SetAttribute("OpenOffset", Vector3.zero)
		-- O degrau, por fora, a meia altura do chao do autocarro.
		proxy("Degrau", Vector3.new(1.6, 0.4, width - 0.3), CFrame.new(MESH.side + 0.9, MESH.floor / 2, (d.from + d.to) / 2))
		local entry = proxy("Entrada", Vector3.new(2, 1, width), CFrame.new(MESH.side - 1, MESH.floor + 1, (d.from + d.to) / 2))
		entry.CanCollide = false
		entry:SetAttribute("Door", index)
	end

	-- O motorista, sentado ao volante.
	if driverAt then
		local skin = Color3.fromRGB(214, 170, 130)
		local shirt = Color3.fromRGB(60, 80, 110)
		local seat = driverAt * CFrame.new(0, 1, 0)
		part("Motorista", Vector3.new(1.8, 2, 1), seat * CFrame.new(0, 0.6, 0.2), shirt, model).CanCollide = false
		part("MotoristaCabeca", Vector3.new(1.1, 1.1, 1.1), seat * CFrame.new(0, 2.2, 0.2), skin, model).CanCollide = false
		part("MotoristaPernas", Vector3.new(1.6, 0.9, 2), seat * CFrame.new(0, -0.6, -0.8), Color3.fromRGB(30, 32, 40), model).CanCollide = false
	end

	-- O letreiro da linha a frente e atras, e o numero na cor da linha.
	local front = part("Letreiro", Vector3.new(6.2, 1, 0.2), CFrame.new(0, 11.1, -MESH.length / 2 - 0.05), DARK, model)
	front.CanCollide = false
	sign(front, Enum.NormalId.Front, livery.line .. "  " .. livery.destination)
	local box = part("NumeroLinha", Vector3.new(1.6, 1, 0.2), CFrame.new(-3.9, 11.1, -MESH.length / 2 - 0.05), livery.colour, model, Enum.Material.Neon)
	box.CanCollide = false
	local back = part("LetreiroTras", Vector3.new(2.4, 1, 0.2), CFrame.new(0, 11.1, MESH.length / 2 + 0.05), DARK, model)
	back.CanCollide = false
	sign(back, Enum.NormalId.Back, livery.line)

	-- O chassis: a peca a que tudo se prende e que o Transit puxa.
	local chassis = part("Chassis", Vector3.new(1, 1, 1), CFrame.new(0, 2, 0), GREY, model)
	chassis.Transparency = 1
	chassis.CanCollide = false
	model.PrimaryPart = chassis
	chassis.PivotOffset = chassis.CFrame:Inverse()
	model:PivotTo(at)
	model.Parent = parent
	return model
end

function Builder.build(livery: Livery, at: CFrame, parent: Instance): Model
	local source = template()
	if source then
		return buildMesh(source, livery, at, parent)
	end
	local model = Instance.new("Model")
	model.Name = "Autocarro"
	model:SetAttribute("Line", livery.line)

	-- Tudo se desenha com a origem no (0,0,0) e no fim move-se para `at`.
	local chassis = part("Chassis", Vector3.new(1, 1, 1), CFrame.new(0, FLOOR - 0.5, 0), GREY, model)
	chassis.Transparency = 1
	chassis.CanCollide = false
	model.PrimaryPart = chassis

	-- Piso, tecto e a caixa por baixo do piso (entre as rodas).
	part("Piso", Vector3.new(WIDTH - 0.6, 0.5, LENGTH - 1), CFrame.new(0, FLOOR - 0.25, 0), Color3.fromRGB(70, 72, 78), model, Enum.Material.DiamondPlate)
	part("Fundo", Vector3.new(WIDTH - 1.4, 1.2, LENGTH - 6), CFrame.new(0, FLOOR - 1.1, 0), DARK, model)
	part("Tecto", Vector3.new(WIDTH, 0.6, LENGTH), CFrame.new(0, ROOF, 0), WHITE, model)
	part("TectoAr", Vector3.new(WIDTH - 3, 0.9, 9), CFrame.new(0, ROOF + 0.7, 6), Color3.fromRGB(210, 212, 214), model) -- o ar condicionado

	-- Os lados: saia na cor da linha, faixa de vidro, e o friso branco por cima.
	for _, side in { -1, 1 } do
		local x = side * (WIDTH / 2 - 0.15)
		local doors = side > 0
		part("Saia", Vector3.new(0.35, 1.3, LENGTH), CFrame.new(x, FLOOR - 0.35, 0), livery.colour, model)
		sidePanels("Lado", x, doors, FLOOR + 0.3, FLOOR + 3.4, livery.colour, model)
		sidePanels("Vidro", x, doors, FLOOR + 3.4, ROOF - 1.3, GLASS, model, Enum.Material.Glass, 0.25, 0.2)
		sidePanels("Friso", x, doors, ROOF - 1.3, ROOF - 0.3, WHITE, model)
		-- Montantes entre as janelas.
		for i = -4, 4 do
			local z = i * 4.3
			local inDoor = false
			if doors then
				for _, d in DOORS do
					if math.abs(z - d.z) < d.width / 2 + 0.4 then
						inDoor = true
					end
				end
			end
			if not inDoor then
				part("Montante", Vector3.new(0.35, ROOF - 1.3 - FLOOR - 3.4, 0.35), CFrame.new(x, (FLOOR + 3.4 + ROOF - 1.3) / 2, z), DARK, model)
			end
		end
	end

	-- A frente: para-brisas grande, painel, farois, letreiro por cima.
	local front = -LENGTH / 2
	part("ParaBrisas", Vector3.new(WIDTH - 0.4, ROOF - 1.6 - FLOOR - 3, 0.25), CFrame.new(0, (FLOOR + 3 + ROOF - 1.6) / 2, front + 0.2) * CFrame.Angles(math.rad(-5), 0, 0), GLASS, model, Enum.Material.Glass, 0.3)
	part("Frente", Vector3.new(WIDTH, 3.4, 0.4), CFrame.new(0, FLOOR + 1.3, front + 0.2), livery.colour, model)
	part("ParaChoques", Vector3.new(WIDTH, 1.2, 0.6), CFrame.new(0, FLOOR - 0.6, front + 0.1), DARK, model)
	for _, s in { -1, 1 } do
		local lamp = part("Farol", Vector3.new(1.4, 0.7, 0.2), CFrame.new(s * (WIDTH / 2 - 1.3), FLOOR + 0.6, front - 0.05), Color3.fromRGB(255, 248, 226), model, Enum.Material.Neon)
		lamp.CastShadow = false
		part("Espelho", Vector3.new(0.25, 1.4, 0.8), CFrame.new(s * (WIDTH / 2 + 0.5), ROOF - 2.6, front + 1.2), DARK, model)
		part("BracoEspelho", Vector3.new(0.9, 0.15, 0.15), CFrame.new(s * (WIDTH / 2 + 0.1), ROOF - 1.9, front + 1.2), DARK, model)
	end
	local frontSign = part("Letreiro", Vector3.new(WIDTH - 1.2, 1.1, 0.2), CFrame.new(0, ROOF - 1.0, front + 0.15), DARK, model)
	sign(frontSign, Enum.NormalId.Front, livery.line .. "  " .. livery.destination)

	-- Atras: painel, farolins, letreiro com o numero.
	local back = LENGTH / 2
	part("Traseira", Vector3.new(WIDTH, ROOF - FLOOR, 0.4), CFrame.new(0, (FLOOR + ROOF) / 2, back - 0.2), livery.colour, model)
	part("VidroTras", Vector3.new(WIDTH - 2, 2.6, 0.2), CFrame.new(0, ROOF - 2.8, back), GLASS, model, Enum.Material.Glass, 0.3)
	part("ParaChoquesTras", Vector3.new(WIDTH, 1.2, 0.6), CFrame.new(0, FLOOR - 0.6, back - 0.1), DARK, model)
	for _, s in { -1, 1 } do
		local lamp = part("Farolim", Vector3.new(0.8, 1.6, 0.2), CFrame.new(s * (WIDTH / 2 - 0.8), FLOOR + 1.4, back + 0.05), Color3.fromRGB(200, 20, 20), model, Enum.Material.Neon)
		lamp.CastShadow = false
	end
	local backSign = part("LetreiroTras", Vector3.new(2.4, 1.1, 0.2), CFrame.new(0, ROOF - 1.0, back + 0.05), DARK, model)
	sign(backSign, Enum.NormalId.Back, livery.line)
	-- O nome da linha nos lados, por baixo das janelas.
	for _, s in { -1, 1 } do
		local band = part("Faixa", Vector3.new(0.1, 1, 12), CFrame.new(s * (WIDTH / 2 + 0.02), FLOOR + 2.4, -6.5), WHITE, model)
		local gui = Instance.new("SurfaceGui")
		gui.Face = if s > 0 then Enum.NormalId.Right else Enum.NormalId.Left
		gui.CanvasSize = Vector2.new(720, 60)
		gui.Parent = band
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = livery.colour
		label.Text = "LINHA " .. livery.line .. " · " .. livery.destination
		label.Parent = gui
	end

	-- As portas: duas folhas de vidro por porta, que correm para os lados.
	for index, d in DOORS do
		for _, s in { -1, 1 } do
			local leaf = part("Porta", Vector3.new(0.2, ROOF - 1.3 - FLOOR - 0.2, d.width / 2 - 0.05), CFrame.new(WIDTH / 2 - 0.15, (FLOOR + 0.1 + ROOF - 1.3) / 2, d.z + s * d.width / 4), GLASS, model, Enum.Material.Glass, 0.35)
			leaf:SetAttribute("Door", index)
			leaf:SetAttribute("Slide", s)
		end
		-- Os varoes amarelos a entrada.
		part("Varao", Vector3.new(0.25, ROOF - FLOOR - 0.6, 0.25), CFrame.new(WIDTH / 2 - 1.6, (FLOOR + ROOF) / 2, d.z - d.width / 2 - 0.4), POLE, model, Enum.Material.Metal)
	end
	part("VaraoMeio", Vector3.new(0.25, ROOF - FLOOR - 0.6, 0.25), CFrame.new(0, (FLOOR + ROOF) / 2, -6), POLE, model, Enum.Material.Metal)
	part("VaraoMeio", Vector3.new(0.25, ROOF - FLOOR - 0.6, 0.25), CFrame.new(0, (FLOOR + ROOF) / 2, 10), POLE, model, Enum.Material.Metal)
	for _, s in { -1, 1 } do
		part("Corrimao", Vector3.new(0.2, 0.2, LENGTH - 8), CFrame.new(s * 2.2, ROOF - 1.2, 2), POLE, model, Enum.Material.Metal)
	end

	-- O lugar do motorista e o volante.
	part("Cabine", Vector3.new(3.4, 3.2, 0.2), CFrame.new(-WIDTH / 2 + 2, FLOOR + 1.6, front + 4.4), DARK, model)
	part("Volante", Vector3.new(1.4, 0.2, 1.4), CFrame.new(-WIDTH / 2 + 2.3, FLOOR + 2.8, front + 2.2) * CFrame.Angles(math.rad(-40), 0, 0), DARK, model)

	-- Os bancos: dois de cada lado por fila, virados para a frente; fora das portas.
	local rows = { -10.5, -7.5, -2, 6.5, 9.5, 12.5, 15.5 }
	for _, z in rows do
		for _, x in { -3.4, -1.6, 1.6, 3.4 } do
			local nearDoor = false
			for _, d in DOORS do
				if x > 0 and math.abs(z - d.z) < d.width / 2 + 1.5 then
					nearDoor = true
				end
			end
			if not nearDoor then
				local seat = Instance.new("Seat")
				seat.Name = "Banco"
				seat.Size = Vector3.new(1.6, 0.4, 1.6)
				seat.CFrame = CFrame.new(x, FLOOR + 1.3, z)
				seat.Color = SEAT
				seat.Material = Enum.Material.Fabric
				seat.Anchored = true
				seat.TopSurface = Enum.SurfaceType.Smooth
				seat.Parent = model
				part("Encosto", Vector3.new(1.6, 2.2, 0.3), CFrame.new(x, FLOOR + 2.4, z + 0.8), SEAT, model, Enum.Material.Fabric)
				part("PeBanco", Vector3.new(1.2, 1.1, 1.2), CFrame.new(x, FLOOR + 0.55, z), GREY, model)
			end
		end
	end

	-- As rodas: pneu, jante e cubo; em arcos pretos na carrocaria.
	for _, z in { -12.5, 12 } do
		for _, s in { -1, 1 } do
			local x = s * (WIDTH / 2 - 0.9)
			local wheel = part("Roda", Vector3.new(1.3, WHEEL_R * 2, WHEEL_R * 2), CFrame.new(x, WHEEL_R, z), DARK, model)
			wheel.Shape = Enum.PartType.Cylinder
			local rim = part("Jante", Vector3.new(1.35, WHEEL_R * 1.2, WHEEL_R * 1.2), CFrame.new(x + s * 0.02, WHEEL_R, z), Color3.fromRGB(190, 192, 196), model, Enum.Material.Metal)
			rim.Shape = Enum.PartType.Cylinder
			rim:SetAttribute("Wheel", wheel.Name)
			rim.Name = "Jante"
			part("Arco", Vector3.new(0.4, 0.6, WHEEL_R * 2 + 1.2), CFrame.new(s * (WIDTH / 2), WHEEL_R * 2 + 0.3, z), DARK, model)
		end
	end

	-- O pivo e o meio ao nivel da estrada (onde a origem do desenho estava).
	chassis.PivotOffset = chassis.CFrame:Inverse()
	model:PivotTo(at)
	model.Parent = parent
	return model
end

Builder.LENGTH = LENGTH
Builder.WIDTH = WIDTH
Builder.FLOOR = FLOOR
Builder.WHEEL_R = WHEEL_R
Builder.DOORS = DOORS

return Builder
