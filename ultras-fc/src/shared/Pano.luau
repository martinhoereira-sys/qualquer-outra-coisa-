--!strict
--[[
	Tudo o que e pano: faixas, bandeiras, bandeirinhas (e o bandeirao).

	A REGRA: nada e um retangulo liso. Um pano e feito de tiras ao alto, cada
	uma com o seu angulo, a baloicar com atraso em relacao a do lado; material
	de tecido; as pontas de baixo nao sao todas do mesmo comprimento. O desenho
	(cores, nome, emblema) e cortado as fatias, uma por tira, e ve-se dos dois
	lados sem ficar ao contrario.

	Tres maneiras de estar:
	- "flag"   : preso por um lado (o mastro); a ponta solta e que ondula mais.
	- "hang"   : pendurado pela beira de cima (faixas na vedacao, faixa do
	             corteo); baloica pouco, como pano pesado.
	- "pinned" : preso pelos dois cantos de cima (bandeira de duas hastes):
	             incha ao meio e ondula entre as hastes.

	O sitio do pano e um CFrame `base`: a origem e o canto de cima do lado
	preso, X ao comprido do pano, Y para cima, o pano cai para -Y.

	Quem constroi no servidor (faixas no estadio) chama `Pano.fix`: fica parado
	com uma forma natural (ve-se no preview do Studio), e o Pano.client de cada
	ecra poe-no a mexer. Os panos que andam com alguem (bandeiras na mao, a
	faixa do corteo) cada ecra cria-os e mexe-os com `Pano.pose`.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Pano = {}

Pano.TAG = "Pano"

export type Design = {
	kind: string, -- "faixa", "faixa_cor", "bandeira", "bandeirinha"
	colour: Color3,
	text: string?,
	short: string?,
}

export type Cloth = {
	model: Model,
	strips: { BasePart },
	lens: { number },
	n: number,
	width: number,
	height: number,
	mode: string,
	phase: number,
	shown: boolean,
}

local WHITE = Color3.fromRGB(246, 246, 246)
local DARK = Color3.fromRGB(18, 18, 22)

-- As tiras sobrepoem-se um bocadinho, para nao abrir buracos quando dobram.
local OVERLAP = 1.07

--------------------------------------------------------------------------------
-- Os desenhos (feitos em GUI, cortados as fatias)
--------------------------------------------------------------------------------

local function frame(parent: Instance, colour: Color3, size: UDim2, position: UDim2): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.Size = size
	f.Position = position
	f.Parent = parent
	return f
end

local function label(parent: Instance, text: string, colour: Color3, size: UDim2, position: UDim2)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = position
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = colour
	t.Text = text
	t.Parent = parent
end

-- Desenha `design` a ocupar `canvas` todo (o pano inteiro).
function Pano.draw(canvas: GuiObject, design: Design)
	local c = design.colour
	local kind = design.kind
	canvas.BackgroundTransparency = 0
	canvas.BorderSizePixel = 0
	if kind == "faixa" or kind == "faixa_cor" then
		-- Como as das claques: letras grossas brancas, barras de cor em cima e em baixo.
		local ground = if kind == "faixa" then DARK else c
		local band = if kind == "faixa" then c else DARK
		canvas.BackgroundColor3 = ground
		frame(canvas, band, UDim2.fromScale(1, 0.13), UDim2.fromScale(0, 0))
		frame(canvas, band, UDim2.fromScale(1, 0.13), UDim2.fromScale(0, 0.87))
		frame(canvas, WHITE, UDim2.fromScale(1, 0.025), UDim2.fromScale(0, 0.14))
		frame(canvas, WHITE, UDim2.fromScale(1, 0.025), UDim2.fromScale(0, 0.835))
		label(canvas, string.upper(design.text or ""), WHITE, UDim2.fromScale(0.94, 0.62), UDim2.fromScale(0.03, 0.19))
	elseif kind == "bandeira" then
		-- Tres bandas ao alto e o emblema redondo ao meio.
		canvas.BackgroundColor3 = WHITE
		frame(canvas, c, UDim2.fromScale(0.34, 1), UDim2.fromScale(0, 0))
		frame(canvas, c, UDim2.fromScale(0.34, 1), UDim2.fromScale(0.66, 0))
		local badge = frame(canvas, DARK, UDim2.fromScale(0.36, 0.62), UDim2.fromScale(0.32, 0.19))
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = badge
		local ring = Instance.new("UIStroke")
		ring.Color = c
		ring.Thickness = 5
		ring.Parent = badge
		label(badge, design.short or "", WHITE, UDim2.fromScale(0.8, 0.5), UDim2.fromScale(0.1, 0.25))
	else
		-- A bandeirinha: bandas deitadas, cor-branco-cor.
		canvas.BackgroundColor3 = c
		frame(canvas, WHITE, UDim2.fromScale(1, 0.34), UDim2.fromScale(0, 0.33))
		if design.short then
			label(canvas, design.short, c, UDim2.fromScale(0.8, 0.28), UDim2.fromScale(0.1, 0.36))
		end
	end
end

-- O desenho de cada coisa, de uma claque.
function Pano.designFor(kind: string, teamId: string, text: string?): Design
	local team = Config.Teams[teamId]
	return {
		kind = kind,
		colour = if team then team.color else WHITE,
		text = text or (if team then team.claque else ""),
		short = if team then team.short else nil,
	}
end

--------------------------------------------------------------------------------
-- Construir
--------------------------------------------------------------------------------

export type Options = {
	mode: string?,
	pixels: number?, -- pixeis por stud do desenho (menos = mais leve)
	maxDistance: number?, -- a partir daqui o desenho nao se ve (so a cor)
	name: string?,
	seed: number?,
}

function Pano.new(parent: Instance, width: number, height: number, n: number, design: Design, opts: Options?): Cloth
	local o: Options = opts or {}
	local rng = Random.new(o.seed or math.random(1, 1e6))
	local model = Instance.new("Model")
	model.Name = o.name or "Pano"
	model:SetAttribute("Width", width)
	model:SetAttribute("Height", height)
	model:SetAttribute("Mode", o.mode or "hang")

	local w = width / n
	local strips: { BasePart } = {}
	local lens: { number } = {}
	for i = 0, n - 1 do
		-- As pontas de baixo nunca ficam direitas.
		local len = height * (1 + rng:NextNumber(-0.06, 0.03))
		local p = Instance.new("Part")
		p.Name = "Tira"
		p.Size = Vector3.new(w * OVERLAP, len, 0.06)
		p.Color = design.colour
		p.Material = Enum.Material.Fabric
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p:SetAttribute("I", i)
		p.Parent = model

		--[[
			A fatia do desenho, dos dois lados. Visto de frente (face Front, -Z)
			o X do pano corre da direita para a esquerda; visto de tras, da
			esquerda para a direita. Cada face poe a sua janela no sitio certo
			para o desenho se ler bem dos dois lados.
		]]
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = o.pixels or 30
			gui.LightInfluence = 0.85
			if o.maxDistance then
				gui.MaxDistance = o.maxDistance
			end
			gui.Parent = p
			local column = if face == Enum.NormalId.Front then n - 1 - i else i
			local window = Instance.new("Frame")
			window.Name = "Desenho"
			-- A janela e o pano inteiro, puxado para mostrar so esta fatia.
			window.Size = UDim2.fromScale(n / OVERLAP, 1)
			window.Position = UDim2.fromScale(-column / OVERLAP + (OVERLAP - 1) / (2 * OVERLAP), 0)
			window.Parent = gui
			Pano.draw(window, design)
		end

		table.insert(strips, p)
		table.insert(lens, len)
	end
	model.Parent = parent

	return {
		model = model,
		strips = strips,
		lens = lens,
		n = n,
		width = width,
		height = height,
		mode = o.mode or "hang",
		phase = rng:NextNumber(0, math.pi * 2),
		shown = true,
	}
end

-- Um pano ja construido (o servidor fe-lo), para o por a mexer neste ecra.
function Pano.wrap(model: Model): Cloth?
	local width = model:GetAttribute("Width")
	local height = model:GetAttribute("Height")
	local mode = model:GetAttribute("Mode")
	if type(width) ~= "number" or type(height) ~= "number" or type(mode) ~= "string" then
		return nil
	end
	local strips: { BasePart } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and type(child:GetAttribute("I")) == "number" then
			table.insert(strips, child)
		end
	end
	if #strips == 0 then
		return nil
	end
	table.sort(strips, function(a, b)
		return (a:GetAttribute("I") :: number) < (b:GetAttribute("I") :: number)
	end)
	local lens = {}
	for _, s in strips do
		table.insert(lens, s.Size.Y)
	end
	return {
		model = model,
		strips = strips,
		lens = lens,
		n = #strips,
		width = width,
		height = height,
		mode = mode,
		phase = (#strips * 1.37 + width) % (math.pi * 2),
		shown = true,
	}
end

--------------------------------------------------------------------------------
-- Mexer
--------------------------------------------------------------------------------

--[[
	Poe cada tira no sitio, no instante `t`, com a forca `amp` (0 parado, 1
	vento forte). Se `outParts`/`outFrames` vierem, junta-lhes as tiras (para
	quem chama mexer tudo de uma vez); senao, mexe ja.
]]
function Pano.pose(cloth: Cloth, base: CFrame, t: number, amp: number, outParts: { BasePart }?, outFrames: { CFrame }?)
	local parts = outParts or {}
	local frames = outFrames or {}
	local n = cloth.n
	local w = cloth.width / n
	local ph = cloth.phase
	local mode = cloth.mode

	if mode == "flag" then
		-- Presa ao mastro: cada tira dobra um pouco em relacao a anterior, e a
		-- onda corre do mastro para a ponta, cada vez mais forte.
		local ex, ez = 0, 0
		for i = 1, n do
			local u = (i - 0.5) / n
			local k = i - 1
			local yaw = amp * (0.25 + 0.75 * u) * (0.55 * math.sin(t * 3.4 - k * 0.8 + ph) + 0.2 * math.sin(t * 5.3 - k * 1.4 + ph * 2))
			local tilt = 0.04 + amp * 0.22 * u * math.sin(t * 2.5 - k * 0.9 + ph)
			local len = cloth.lens[i]
			local cf = base
				* CFrame.new(ex, 0, ez)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.new(w / 2, 0, 0)
				* CFrame.Angles(tilt, 0, 0)
				* CFrame.new(0, -len / 2, 0)
			table.insert(parts, cloth.strips[i])
			table.insert(frames, cf)
			ex += w * math.cos(yaw)
			ez -= w * math.sin(yaw)
		end
	else
		-- Pendurado pela beira de cima: cada tira balanca para a frente e para
		-- tras com atraso da do lado. Entre duas hastes, o meio incha mais.
		local pinned = mode == "pinned"
		for i = 1, n do
			local u = (i - 0.5) / n
			local k = i - 1
			local swing = if pinned then 0.3 else 0.22
			local tilt = amp * swing * math.sin(t * 2.1 - k * 0.55 + ph) + amp * 0.06 * math.sin(t * 4.3 - k * 1.1)
			local bulge = if pinned
				then amp * 0.9 * math.sin(math.pi * u) * (0.65 + 0.35 * math.sin(t * 2.6 - k * 0.5 + ph))
				else amp * 0.25 * math.sin(t * 1.4 - k * 0.45 + ph)
			local yaw = amp * 0.1 * math.sin(t * 1.9 - k * 0.7 + ph)
			local len = cloth.lens[i]
			local cf = base
				* CFrame.new((i - 0.5) * w, 0, bulge)
				* CFrame.Angles(tilt, yaw, 0)
				* CFrame.new(0, -len / 2, 0)
			table.insert(parts, cloth.strips[i])
			table.insert(frames, cf)
		end
	end

	if not outParts then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- O pano muda de largura (a bandeira de duas hastes, com as maos a mexer).
function Pano.resize(cloth: Cloth, width: number)
	if math.abs(width - cloth.width) < 0.05 then
		return
	end
	cloth.width = width
	local w = width / cloth.n
	for i, strip in cloth.strips do
		strip.Size = Vector3.new(w * OVERLAP, cloth.lens[i], strip.Size.Z)
	end
end

-- O CFrame `base` de um pano preso pelos cantos `a` e `b` (a beira de cima).
function Pano.between(a: Vector3, b: Vector3, up: Vector3): CFrame
	local across = b - a
	if across.Magnitude < 1e-3 then
		return CFrame.new(a)
	end
	local x = across.Unit
	local y = (up - x * up:Dot(x))
	y = if y.Magnitude > 1e-3 then y.Unit else Vector3.yAxis
	return CFrame.fromMatrix(a, x, y)
end

function Pano.show(cloth: Cloth, on: boolean)
	if cloth.shown == on then
		return
	end
	cloth.shown = on
	for _, strip in cloth.strips do
		strip.Transparency = if on then 0 else 1
		for _, gui in strip:GetChildren() do
			if gui:IsA("SurfaceGui") then
				gui.Enabled = on
			end
		end
	end
end

--[[
	Um pano parado no mapa (servidor): fica com uma forma natural, ja com as
	tiras desencontradas, e cada ecra poe-no a mexer (Pano.client).
]]
function Pano.fix(cloth: Cloth, base: CFrame, amp: number)
	cloth.model:SetAttribute("Base", base)
	cloth.model:SetAttribute("Amp", amp)
	Pano.pose(cloth, base, cloth.phase * 3, amp)
	CollectionService:AddTag(cloth.model, Pano.TAG)
end

return Pano
