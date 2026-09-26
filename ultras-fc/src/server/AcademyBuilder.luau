--!strict
--[[
	Constroi a academia em Workspace.Academia (no quarteirao a norte do
	estadio), para ficar no mapa e ver-se no Studio sem Play:

	- o relvado de treino, com linhas e duas balizas como as do estadio;
	- a vedacao a volta, aberta a meio do lado da rua;
	- uma bancada pequena a norte;
	- o edificio da academia, a poente, com o nome;
	- cones de treino;
	- os lugares dos bonecos que ficam a ver ("Lugar"), o guarda-redes de
	  treino ("GuardaRedes", parado na baliza nascente) e onde aparece quem
	  joga ("Chegada").

	As medidas vem do Config.Academy. Corre-se uma vez no Studio; refazer apaga
	o que la estiver.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Builder = {}

local A = Config.Academy

local GRASS_A = Color3.fromRGB(64, 122, 62)
local GRASS_B = Color3.fromRGB(76, 138, 72)
local LINE = Color3.fromRGB(236, 240, 236)
local WHITE = Color3.fromRGB(238, 238, 234)
local STEEL = Color3.fromRGB(80, 84, 90)
local GLASS = Color3.fromRGB(150, 180, 200)

type Opts = { material: Enum.Material?, transparency: number?, collide: boolean? }

local function part(name: string, size: Vector3, cf: CFrame, colour: Color3, parent: Instance, opts: Opts?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = (opts and opts.material) or Enum.Material.SmoothPlastic
	p.Transparency = (opts and opts.transparency) or 0
	if opts and opts.collide == false then
		p.CanCollide = false
	end
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function span(name: string, from: Vector3, to: Vector3, thick: number, colour: Color3, parent: Instance, opts: Opts?): Part
	return part(name, Vector3.new(thick, thick, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), colour, parent, opts)
end

local function folderIn(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function label(on: BasePart, face: Enum.NormalId, text: string, colour: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	local sideways = face == Enum.NormalId.Left or face == Enum.NormalId.Right
	gui.CanvasSize = Vector2.new((sideways and on.Size.Z or on.Size.X) * 30, on.Size.Y * 30)
	gui.Parent = on
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(0.96, 0.84)
	t.Position = UDim2.fromScale(0.02, 0.08)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = colour
	t.Text = text
	t.Parent = gui
end

-- Um boneco de pecas (para o guarda-redes de treino no mapa).
local function dummy(name: string, at: CFrame, shirt: Color3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	local skin = Color3.fromRGB(214, 170, 130)
	local torso = part("Tronco", Vector3.new(2, 2, 1), at * CFrame.new(0, 3, 0), shirt, model)
	model.PrimaryPart = torso
	part("Cabeca", Vector3.new(1.2, 1.2, 1.2), at * CFrame.new(0, 4.6, 0), skin, model)
	for _, s in { -1, 1 } do
		part("Braco", Vector3.new(1, 2, 1), at * CFrame.new(s * 1.5, 3, 0), shirt, model)
		part("Perna", Vector3.new(1, 2, 1), at * CFrame.new(s * 0.5, 1, 0), Color3.fromRGB(30, 30, 34), model)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	model.Parent = parent
	return model
end

--------------------------------------------------------------------------------

local function buildPitch(root: Instance)
	local folder = folderIn(root, "Relvado")
	local c = A.centre
	local y = A.groundY
	local L, W = A.pitchLength, A.pitchWidth

	-- A relva, com faixas, um pouco maior do que as linhas.
	local stripes = 10
	for i = 1, stripes do
		local x = c.X - (L + 12) / 2 + (i - 0.5) * (L + 12) / stripes
		part("Faixa", Vector3.new((L + 12) / stripes, 0.4, W + 12), CFrame.new(x, y + 0.2, c.Z), if i % 2 == 0 then GRASS_B else GRASS_A, folder, { material = Enum.Material.Grass })
	end

	local ly = y + 0.42
	local function line(size: Vector3, cf: CFrame)
		part("Linha", size, cf, LINE, folder, { collide = false })
	end
	line(Vector3.new(L, 0.05, 0.5), CFrame.new(c.X, ly, c.Z - W / 2))
	line(Vector3.new(L, 0.05, 0.5), CFrame.new(c.X, ly, c.Z + W / 2))
	line(Vector3.new(0.5, 0.05, W), CFrame.new(c.X - L / 2, ly, c.Z))
	line(Vector3.new(0.5, 0.05, W), CFrame.new(c.X + L / 2, ly, c.Z))
	line(Vector3.new(0.5, 0.05, W), CFrame.new(c.X, ly, c.Z))
	local radius = 9
	for i = 1, 24 do
		local a = i / 24 * math.pi * 2
		line(Vector3.new(0.5, 0.05, math.pi * 2 * radius / 24 + 0.2), CFrame.new(c.X + math.cos(a) * radius, ly, c.Z + math.sin(a) * radius) * CFrame.Angles(0, -a, 0))
	end
	for _, sign in { -1, 1 } do
		local gl = c.X + sign * L / 2
		local boxD, boxW = 16, 34
		line(Vector3.new(0.5, 0.05, boxW), CFrame.new(gl - sign * boxD, ly, c.Z))
		line(Vector3.new(boxD, 0.05, 0.5), CFrame.new(gl - sign * boxD / 2, ly, c.Z - boxW / 2))
		line(Vector3.new(boxD, 0.05, 0.5), CFrame.new(gl - sign * boxD / 2, ly, c.Z + boxW / 2))
		line(Vector3.new(0.9, 0.06, 0.9), CFrame.new(gl - sign * 11, ly, c.Z))

		-- A baliza: armacao branca e rede em quadricula (como as do estadio).
		local goal = folderIn(folder, if sign > 0 then "BalizaNascente" else "BalizaPoente")
		local w, h, d = A.goalHalfWidth, A.goalHeight, A.goalDepth
		local gx = gl + sign * 0.35
		local bx = gl + sign * d
		part("PosteE", Vector3.new(0.6, h, 0.6), CFrame.new(gx, y + h / 2, c.Z - w - 0.3), LINE, goal)
		part("PosteD", Vector3.new(0.6, h, 0.6), CFrame.new(gx, y + h / 2, c.Z + w + 0.3), LINE, goal)
		part("Trave", Vector3.new(0.6, 0.6, w * 2 + 1.2), CFrame.new(gx, y + h + 0.3, c.Z), LINE, goal)
		for _, s in { -1, 1 } do
			local z = c.Z + s * (w + 0.3)
			span("PosteTras", Vector3.new(bx, y, z), Vector3.new(bx, y + h + 0.3, z), 0.3, LINE, goal)
			span("BarraLado", Vector3.new(gx, y + h + 0.3, z), Vector3.new(bx, y + h + 0.3, z), 0.25, LINE, goal)
			span("BarraChao", Vector3.new(gx, y + 0.15, z), Vector3.new(bx, y + 0.15, z), 0.25, LINE, goal)
		end
		span("BarraTras", Vector3.new(bx, y + h + 0.3, c.Z - w - 0.3), Vector3.new(bx, y + h + 0.3, c.Z + w + 0.3), 0.3, LINE, goal)
		local function net(name: string, size: Vector3, cf: CFrame, faces: { Enum.NormalId })
			local panel = part(name, size, cf, LINE, goal, { transparency = 1 })
			for _, face in faces do
				local across = if face == Enum.NormalId.Left or face == Enum.NormalId.Right then size.Z elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then size.X else size.X
				local up = if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then size.Z else size.Y
				local gui = Instance.new("SurfaceGui")
				gui.Face = face
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 20
				gui.Parent = panel
				for i = 0, math.floor(across / 0.9) do
					local f = Instance.new("Frame")
					f.BorderSizePixel = 0
					f.BackgroundColor3 = LINE
					f.Size = UDim2.new(0, 2, 1, 0)
					f.Position = UDim2.fromOffset(math.floor(i * 18), 0)
					f.Parent = gui
				end
				for i = 0, math.floor(up / 0.9) do
					local f = Instance.new("Frame")
					f.BorderSizePixel = 0
					f.BackgroundColor3 = LINE
					f.Size = UDim2.new(1, 0, 0, 2)
					f.Position = UDim2.fromOffset(0, math.floor(i * 18))
					f.Parent = gui
				end
			end
		end
		net("RedeFundo", Vector3.new(0.15, h, w * 2 + 0.6), CFrame.new(bx + sign * 0.1, y + h / 2, c.Z), { Enum.NormalId.Left, Enum.NormalId.Right })
		net("RedeTopo", Vector3.new(d - 0.3, 0.15, w * 2 + 0.6), CFrame.new((gx + bx) / 2, y + h + 0.3, c.Z), { Enum.NormalId.Top, Enum.NormalId.Bottom })
		for _, s in { -1, 1 } do
			net("RedeLado", Vector3.new(d - 0.3, h, 0.15), CFrame.new((gx + bx) / 2, y + h / 2, c.Z + s * (w + 0.4)), { Enum.NormalId.Front, Enum.NormalId.Back })
		end
	end
end

--[[
	A vedacao a volta do relvado: postes e malha, aberta a meio do lado sul
	(o da rua e da paragem). Por cima, uma parede invisivel so para a bola de
	treino nao ir parar a rua.
]]
local function buildFence(root: Instance)
	local folder = folderIn(root, "Vedacao")
	local c = A.centre
	local y = A.groundY
	local hx = A.pitchLength / 2 + 10
	local hz = A.pitchWidth / 2 + 8
	local H = 6
	local gate = 10 -- meia largura da entrada
	local sides = {
		{ Vector3.new(c.X - hx, y, c.Z + hz), Vector3.new(c.X + hx, y, c.Z + hz) },
		{ Vector3.new(c.X - hx, y, c.Z - hz), Vector3.new(c.X - gate, y, c.Z - hz) },
		{ Vector3.new(c.X + gate, y, c.Z - hz), Vector3.new(c.X + hx, y, c.Z - hz) },
		{ Vector3.new(c.X - hx, y, c.Z - hz), Vector3.new(c.X - hx, y, c.Z + hz) },
		{ Vector3.new(c.X + hx, y, c.Z - hz), Vector3.new(c.X + hx, y, c.Z + hz) },
	}
	for _, s in sides do
		local a, b = s[1], s[2]
		local length = (b - a).Magnitude
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b)
		part("Malha", Vector3.new(0.12, H, length), cf * CFrame.new(0, H / 2, 0), Color3.fromRGB(60, 110, 70), folder, { material = Enum.Material.DiamondPlate, transparency = 0.55 })
		part("Barra", Vector3.new(0.3, 0.3, length), cf * CFrame.new(0, H, 0), STEEL, folder, { material = Enum.Material.Metal })
		local posts = math.floor(length / 8)
		for i = 0, posts do
			local p = a:Lerp(b, i / posts)
			part("Poste", Vector3.new(0.35, H + 0.3, 0.35), CFrame.new(p.X, y + (H + 0.3) / 2, p.Z), STEEL, folder, { material = Enum.Material.Metal })
		end
		-- A parede so da bola de treino (grupo BallWall; ninguem mais a sente).
		local wall = part("ParedeBola", Vector3.new(0.5, 30, length), cf * CFrame.new(0, 15, 0), STEEL, folder, { transparency = 1 })
		wall.CanQuery = false
		wall.CanTouch = false
		pcall(function()
			wall.CollisionGroup = "BallWall"
		end)
	end
	-- A entrada tambem tem a parede da bola, por cima da altura de uma pessoa.
	local door = part("ParedeBola", Vector3.new(gate * 2, 24, 0.5), CFrame.new(c.X, y + 18, c.Z - hz), STEEL, folder, { transparency = 1 })
	door.CanQuery = false
	door.CanTouch = false
	pcall(function()
		door.CollisionGroup = "BallWall"
	end)
	local arch = part("Portico", Vector3.new(gate * 2 + 1, 1.4, 0.6), CFrame.new(c.X, y + 8.5, c.Z - hz), Color3.fromRGB(30, 34, 40), folder)
	label(arch, Enum.NormalId.Front, "ACADEMIA · CAMPO DE TREINO", Color3.fromRGB(240, 240, 240))
	for _, s in { -1, 1 } do
		part("PorticoPoste", Vector3.new(0.6, 9, 0.6), CFrame.new(c.X + s * gate, y + 4.5, c.Z - hz), STEEL, folder, { material = Enum.Material.Metal })
	end
end

-- A bancada pequena, a norte, virada para o relvado.
local function buildStand(root: Instance)
	local folder = folderIn(root, "Bancada")
	local c = A.centre
	local y = A.groundY
	local z0 = c.Z + A.pitchWidth / 2 + 10
	local length = 60
	for row = 1, 4 do
		local top = y + row * 1.4
		local z = z0 + (row - 0.5) * 2.4
		part("Degrau", Vector3.new(length, top - y, 2.4), CFrame.new(c.X, (top + y) / 2, z), Color3.fromRGB(186, 186, 184), folder, { material = Enum.Material.Concrete })
		part("Cadeiras", Vector3.new(length - 1, 0.4, 1.6), CFrame.new(c.X, top + 0.2, z), if row % 2 == 0 then Color3.fromRGB(58, 56, 92) else Color3.fromRGB(48, 46, 80), folder)
	end
	part("Cobertura", Vector3.new(length + 2, 0.6, 12), CFrame.new(c.X, y + 13, z0 + 5), WHITE, folder)
	for _, s in { -1, 1 } do
		part("Pilar", Vector3.new(0.6, 13, 0.6), CFrame.new(c.X + s * (length / 2), y + 6.5, z0 + 10), STEEL, folder, { material = Enum.Material.Metal })
	end
end

-- O edificio da academia, a poente do relvado.
local function buildHouse(root: Instance)
	local folder = folderIn(root, "Edificio")
	local c = A.centre
	local y = A.groundY
	local centre = Vector3.new(c.X - A.pitchLength / 2 - 60, y, c.Z)
	local sx, sz, h = 64, 76, 20
	-- Chao, paredes (com a entrada de vidro virada para o relvado), tecto.
	part("Chao", Vector3.new(sx, 0.4, sz), CFrame.new(centre.X, y + 0.2, centre.Z), Color3.fromRGB(200, 198, 194), folder)
	part("Tecto", Vector3.new(sx + 2, 1, sz + 2), CFrame.new(centre.X, y + h + 0.5, centre.Z), WHITE, folder)
	part("ParedeOeste", Vector3.new(1, h, sz), CFrame.new(centre.X - sx / 2, y + h / 2, centre.Z), WHITE, folder)
	part("ParedeNorte", Vector3.new(sx, h, 1), CFrame.new(centre.X, y + h / 2, centre.Z + sz / 2), WHITE, folder)
	part("ParedeSul", Vector3.new(sx, h, 1), CFrame.new(centre.X, y + h / 2, centre.Z - sz / 2), WHITE, folder)
	-- A fachada do relvado: vidro em baixo e em cima, com a porta a meio.
	local ex = centre.X + sx / 2
	for _, s in { -1, 1 } do
		part("Vidro", Vector3.new(0.4, 7, sz / 2 - 4), CFrame.new(ex, y + 3.5, centre.Z + s * (sz / 4 + 2)), GLASS, folder, { material = Enum.Material.Glass, transparency = 0.35 })
	end
	part("VidroCima", Vector3.new(0.4, h - 9, sz), CFrame.new(ex, y + 9 + (h - 9) / 2, centre.Z), GLASS, folder, { material = Enum.Material.Glass, transparency = 0.35 })
	part("Friso", Vector3.new(0.8, 2, sz), CFrame.new(ex, y + 8, centre.Z), WHITE, folder)
	part("Pala", Vector3.new(6, 0.6, 16), CFrame.new(ex + 3, y + 7.4, centre.Z), WHITE, folder)
	-- O piso de cima, por dentro.
	part("Piso1", Vector3.new(sx - 2, 0.6, sz - 2), CFrame.new(centre.X, y + 10, centre.Z), Color3.fromRGB(200, 198, 194), folder)
	-- O nome, na fachada da rua e na do relvado.
	local sign = part("Nome", Vector3.new(44, 4, 0.4), CFrame.new(centre.X, y + h - 3.5, centre.Z - sz / 2 - 0.7), Color3.fromRGB(30, 34, 40), folder)
	label(sign, Enum.NormalId.Front, "ACADEMIA ULTRAS FC", Color3.fromRGB(236, 200, 110))
	local sign2 = part("NomeRelvado", Vector3.new(0.4, 3, 40), CFrame.new(ex + 0.7, y + h - 3, centre.Z), Color3.fromRGB(30, 34, 40), folder)
	label(sign2, Enum.NormalId.Right, "ACADEMIA", Color3.fromRGB(236, 200, 110))
	-- A rececao e bancos, por dentro.
	part("Balcao", Vector3.new(3, 3.5, 14), CFrame.new(centre.X + 10, y + 1.75, centre.Z), Color3.fromRGB(150, 110, 70), folder, { material = Enum.Material.Wood })
	for _, s in { -1, 1 } do
		part("Banco", Vector3.new(12, 1.4, 2), CFrame.new(centre.X - 12, y + 0.7, centre.Z + s * 22), Color3.fromRGB(150, 110, 70), folder, { material = Enum.Material.Wood })
	end
end

-- Cones e o resto do treino, e os lugares de quem fica a ver.
local function buildExtras(root: Instance)
	local folder = folderIn(root, "Treino")
	local c = A.centre
	local y = A.groundY
	for i = 0, 9 do
		local x = c.X - 30 + i * 6
		local z = c.Z - A.pitchWidth / 2 - 4 + (if i % 2 == 0 then 0 else 1.5)
		local cone = part("Cone", Vector3.new(0.9, 1.2, 0.9), CFrame.new(x, y + 0.6, z), Color3.fromRGB(245, 120, 30), folder)
		cone.CanCollide = false
	end

	-- Onde aparece quem joga: ao meio-campo, do lado da entrada.
	local arrival = part("Chegada", Vector3.new(6, 0.2, 6), CFrame.new(c.X, y + 0.5, c.Z - A.pitchWidth / 2 + 6), Color3.fromRGB(240, 200, 40), root, { transparency = 0.5, collide = false })
	arrival:SetAttribute("Info", "Onde aparece quem joga, antes do jogo")

	-- Os lugares dos bonecos a ver: fora das linhas, no lado sul e na bancada.
	local spots = folderIn(root, "Lugares")
	for i = 0, 9 do
		local at = Vector3.new(c.X - 40 + i * 9, y + 0.5, c.Z - A.pitchWidth / 2 - 5)
		local p = part("Lugar", Vector3.new(1.5, 0.2, 1.5), CFrame.new(at), Color3.fromRGB(120, 160, 230), spots, { transparency = 0.5, collide = false })
		p:SetAttribute("Info", "Um boneco fica aqui a ver o treino")
	end

	-- O guarda-redes de treino, na baliza nascente.
	local gx = c.X + A.pitchLength / 2 - 1.8
	dummy("GuardaRedes", CFrame.lookAt(Vector3.new(gx, y, c.Z), Vector3.new(c.X, y, c.Z)), Color3.fromRGB(46, 160, 82), root)
end

function Builder.build(parent: Instance): Folder
	local old = parent:FindFirstChild("Academia")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Academia"
	buildPitch(root)
	buildFence(root)
	buildStand(root)
	buildHouse(root)
	buildExtras(root)
	root.Parent = parent
	return root
end

return Builder
