--!strict
--[[
	Um pano com juntas: para se poder ANIMAR no Animation Editor (e para o jogo
	o mexer do mesmo modo quando ainda nao ha animacao).

	O pano e uma grelha de `columns` tiras ao alto, cada uma partida em `rows`
	bocados. As juntas (Motor6D) ligam:
	- a raiz (o mastro, a barra da faixa, o rolo) ao primeiro bocado de cima;
	- ao longo da beira de cima, cada tira a anterior (a onda corre por aqui);
	- em cada tira, cada bocado ao de cima (o pano ondula de cima a baixo).

	Os nomes sao sempre os mesmos ("<nome>_C3L2" = tira 3, bocado 2), para uma
	animacao feita no modelo de copia (ServerStorage.Modelos) servir no jogo.

	O desenho (o emblema, as cores, o nome) e cortado aos bocados, dos dois
	lados, como no Pano.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pano = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pano"))

local PanoRig = {}

export type Options = {
	name: string, -- o prefixo das pecas e das juntas
	columns: number,
	rows: number,
	width: number,
	height: number,
	design: Pano.Design?, -- sem desenho: so a cor
	colour: Color3?,
	pixels: number?,
	maxDistance: number?,
	-- Onde fica o canto de cima (do lado preso) do pano, relativo a raiz:
	-- X ao comprido do pano, Y para cima, o pano cai para -Y.
	attach: CFrame,
}

export type Rig = {
	name: string,
	columns: number,
	rows: number,
	w: number, -- largura de cada tira
	h: number, -- altura de cada bocado
	-- joints[c][r]: a junta que segura o bocado (c, r)
	joints: { { Motor6D } },
	parts: { { BasePart } },
}

-- Um pouco maiores do que a grelha: sem buracos quando dobram.
local OVERLAP = 1.05

local function piece(name: string, size: Vector3, colour: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.Fabric
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = false
	p.Parent = parent
	return p
end

-- A fatia (c, r) do desenho, dos dois lados, a ler bem de ambos.
local function slice(p: BasePart, c: number, r: number, o: Options)
	local design = o.design
	if not design then
		return
	end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = o.pixels or 20
		gui.LightInfluence = 0.85
		if o.maxDistance then
			gui.MaxDistance = o.maxDistance
		end
		gui.Parent = p
		-- Vista de frente (face Front, -Z), o X corre da direita para a esquerda.
		local column = if face == Enum.NormalId.Front then o.columns - c else c - 1
		local window = Instance.new("Frame")
		window.Name = "Desenho"
		window.Size = UDim2.fromScale(o.columns / OVERLAP, o.rows / OVERLAP)
		window.Position = UDim2.fromScale(
			-column / OVERLAP + (OVERLAP - 1) / (2 * OVERLAP),
			-(r - 1) / OVERLAP + (OVERLAP - 1) / (2 * OVERLAP)
		)
		window.Parent = gui
		Pano.draw(window, design)
	end
end

--[[
	Constroi o pano dentro de `parent`, preso a `root` (que ja la esta). Devolve
	o rig com as juntas. As pecas nao estao ancoradas: seguem a raiz pelas juntas.
]]
function PanoRig.build(parent: Instance, root: BasePart, o: Options): Rig
	local w = o.width / o.columns
	local h = o.height / o.rows
	local colour = if o.design then o.design.colour else (o.colour or Color3.new(1, 1, 1))
	local joints: { { Motor6D } } = {}
	local parts: { { BasePart } } = {}
	local size = Vector3.new(w * OVERLAP, h * OVERLAP, 0.05)

	for c = 1, o.columns do
		joints[c] = {}
		parts[c] = {}
		for r = 1, o.rows do
			local p = piece(o.name .. "_C" .. c .. "L" .. r, size, colour, parent)
			slice(p, c, r, o)
			local joint = Instance.new("Motor6D")
			joint.Name = o.name .. "_C" .. c .. "L" .. r
			if r == 1 then
				if c == 1 then
					-- Da raiz ao canto de cima: a junta e no canto (o lado preso).
					joint.Part0 = root
					joint.C0 = o.attach
				else
					-- A tira anterior, pelo seu canto de cima do outro lado.
					joint.Part0 = parts[c - 1][1]
					joint.C0 = CFrame.new(w / 2, h / 2, 0)
				end
				joint.C1 = CFrame.new(-w / 2, h / 2, 0)
			else
				-- O bocado de cima, pela sua beira de baixo.
				joint.Part0 = parts[c][r - 1]
				joint.C0 = CFrame.new(0, -h / 2, 0)
				joint.C1 = CFrame.new(0, h / 2, 0)
			end
			joint.Part1 = p
			joint.Parent = p
			-- Posta ja no sitio (antes de a fisica a resolver), para nao saltar.
			p.CFrame = (joint.Part0 :: BasePart).CFrame * joint.C0 * joint.C1:Inverse()
			joints[c][r] = joint
			parts[c][r] = p
		end
	end
	return { name = o.name, columns = o.columns, rows = o.rows, w = w, h = h, joints = joints, parts = parts }
end

-- Encontra de novo um rig ja feito (pelo servidor), pelos nomes.
function PanoRig.find(container: Instance, name: string, columns: number, rows: number, width: number, height: number): Rig?
	local joints: { { Motor6D } } = {}
	local parts: { { BasePart } } = {}
	for c = 1, columns do
		joints[c] = {}
		parts[c] = {}
		for r = 1, rows do
			local key = name .. "_C" .. c .. "L" .. r
			local p = container:FindFirstChild(key)
			local joint = p and p:FindFirstChild(key)
			if not p or not p:IsA("BasePart") or not joint or not joint:IsA("Motor6D") then
				return nil
			end
			joints[c][r] = joint
			parts[c][r] = p
		end
	end
	return { name = name, columns = columns, rows = rows, w = width / columns, h = height / rows, joints = joints, parts = parts }
end

--[[
	Como o jogo mexe o pano quando nao ha animacao feita: a onda corre da raiz
	para a ponta (cada tira roda um pouco em relacao a anterior), a ponta solta
	chicoteia, sem vento o pano cai com o peso, e cada tira ondula de cima a
	baixo. `amp` 0 parado, 1 agitado com forca; `fly` roda o pano todo a volta
	da raiz (para onde voa, em radianos, no eixo Y da raiz).
]]
function PanoRig.wave(rig: Rig, t: number, amp: number, phase: number, fly: number?)
	local n = rig.columns
	local sagBase = 0.08 + 0.6 * math.clamp(1 - amp, 0, 1)
	local previousYaw = 0
	local previousSag = 0
	for c = 1, n do
		local u = (c - 0.5) / n
		local whip = amp * (0.3 + 0.9 * u)
		local yaw = whip * (0.6 * math.sin(t * 3.8 - u * 2.4 + phase) + 0.2 * math.sin(t * 6.4 - u * 3.6 + phase * 2))
		local sag = sagBase * u * (0.85 + 0.15 * math.sin(t * 2.2 - u * 1.5 + phase))
		local top = rig.joints[c][1]
		local turn = CFrame.Angles(0, yaw - previousYaw, 0) * CFrame.Angles(0, 0, -(sag - previousSag))
		if c == 1 and fly then
			turn = CFrame.Angles(0, fly, 0) * turn
		end
		top.Transform = turn
		previousYaw = yaw
		previousSag = sag
		-- De cima a baixo: cada bocado dobra um pouco em relacao ao de cima.
		for r = 2, rig.rows do
			local v = (r - 1) / math.max(rig.rows - 1, 1)
			local ripple = amp * 0.22 * u * math.sin(t * 2.7 - u * 2.0 - v * 1.6 + phase)
			rig.joints[c][r].Transform = CFrame.Angles(ripple, 0, 0)
		end
	end
end

--[[
	Pendurado pela beira de cima (a faixa): baloica devagar para a frente e
	para tras, cada tira com atraso da do lado, o meio mais solto.
]]
function PanoRig.hang(rig: Rig, t: number, amp: number, phase: number)
	for c = 1, rig.columns do
		local u = (c - 0.5) / rig.columns
		rig.joints[c][1].Transform = CFrame.Angles(amp * 0.18 * math.sin(t * 2.1 - u * 3 + phase), 0, 0)
		for r = 2, rig.rows do
			local v = (r - 1) / math.max(rig.rows - 1, 1)
			rig.joints[c][r].Transform = CFrame.Angles(amp * 0.12 * math.sin(t * 2.6 - u * 3 - v * 1.4 + phase), 0, 0)
		end
	end
end

function PanoRig.show(rig: Rig, on: boolean)
	for _, column in rig.parts do
		for _, p in column do
			p.LocalTransparencyModifier = if on then 0 else 1
		end
	end
end

return PanoRig
