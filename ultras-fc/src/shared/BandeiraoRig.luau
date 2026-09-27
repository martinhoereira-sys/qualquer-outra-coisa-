--!strict
--[[
	O bandeirao como rig com juntas (para se animar no Animation Editor).

	O pano cobre a curva da claque (BandeiraoPlan). Esta partido numa grelha
	de 14 tiras ao alto x 4 bocados (Rigs.BANDEIRAO), com as mesmas juntas do
	PanoRig: a raiz (no cimo da curva) segura a primeira tira; ao longo da
	beira de cima cada tira segura a seguinte; em cada tira cada bocado segura
	o de baixo. Como a bancada e curva e inclinada, cada junta guarda a sua
	posicao de repouso (o pano aberto por cima das cabecas).

	O desenho (o emblema da claque, 28 x 16 quadrados de pano) vai soldado aos
	bocados: mexer uma junta mexe o desenho com ela. Dobrar os bocados de cima
	para baixo e desenrolar; e o que o jogo faz quando nao ha animacao feita.

	Nomes: raiz "Bandeirao_Raiz", bocados e juntas "Bandeirao_C<tira>L<bocado>".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BP = require(Shared:WaitForChild("BandeiraoPlan"))
local TifoDesigns = require(Shared:WaitForChild("TifoDesigns"))
local Rigs = require(Shared:WaitForChild("Rigs"))

local BandeiraoRig = {}

export type Rig = {
	model: Model,
	root: BasePart,
	columns: number,
	rows: number,
	joints: { { Motor6D } },
	-- Os quadrados de pano de cada bocado (para os esconder enquanto enrolado).
	cloth: { { { BasePart } } },
}

local NAME = Rigs.BANDEIRAO.name
local COLUMNS = Rigs.BANDEIRAO.columns
local ROWS = Rigs.BANDEIRAO.rows

local function part(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.Fabric
	p.Parent = parent
	return p
end

-- Um quadrilatero da grelha do pano: centro e orientacao (X ao comprido, Y para cima da bancada).
local function quad(teamId: string, t0: number, t1: number, s0: number, s1: number): (CFrame, Vector3, Vector3, Vector3)
	local tl = BP.point(teamId, t0, s0)
	local tr = BP.point(teamId, t1, s0)
	local bl = BP.point(teamId, t0, s1)
	local br = BP.point(teamId, t1, s1)
	local topMid = (tl + tr) / 2
	local botMid = (bl + br) / 2
	local across = tr - tl
	local x = across.Unit
	local y = (topMid - botMid).Unit
	local cf = CFrame.fromMatrix((tl + tr + bl + br) / 4, x, y)
	return cf, Vector3.new(across.Magnitude, (topMid - botMid).Magnitude, 0.1), tl, topMid
end

--[[
	Constroi o bandeirao aberto dentro de `model` (um Model novo). A raiz fica
	ancorada; o resto segue-a pelas juntas.
]]
function BandeiraoRig.build(model: Model, teamId: string): Rig
	local lines = TifoDesigns.rows({ emblem = true }, teamId)
	local pixelColumns = BP.columns -- 28
	local pixelRows = BP.rows -- 16
	local perColumn = pixelColumns // COLUMNS
	local perRow = pixelRows // ROWS

	-- A raiz: no cimo da curva, ao meio.
	local rootCF = CFrame.new(BP.point(teamId, (BP.tAt(0) + BP.tAt(pixelColumns)) / 2, BP.sAt(0)))
	local root = part(NAME .. "_Raiz", Vector3.new(1, 1, 1), rootCF, model)
	root.Anchored = true
	root.Transparency = 1
	model.PrimaryPart = root

	local joints: { { Motor6D } } = {}
	local pieces: { { BasePart } } = {}
	local cloth: { { { BasePart } } } = {}
	for c = 1, COLUMNS do
		joints[c] = {}
		pieces[c] = {}
		cloth[c] = {}
		for r = 1, ROWS do
			local c0, c1 = (c - 1) * perColumn, c * perColumn
			local r0, r1 = (r - 1) * perRow, r * perRow
			local cf, size, topLeft, topMid = quad(teamId, BP.tAt(c0), BP.tAt(c1), BP.sAt(r0), BP.sAt(r1))
			local key = NAME .. "_C" .. c .. "L" .. r
			local p = part(key, size, cf, model)
			p.Transparency = 1

			-- A junta: na beira de cima (e no canto, ao longo da primeira fila).
			local joint = Instance.new("Motor6D")
			joint.Name = key
			local parent: BasePart
			local hinge: CFrame
			if r == 1 then
				parent = if c == 1 then root else pieces[c - 1][1]
				hinge = CFrame.fromMatrix(topLeft, cf.XVector, cf.YVector)
			else
				parent = pieces[c][r - 1]
				hinge = CFrame.fromMatrix(topMid, cf.XVector, cf.YVector)
			end
			joint.Part0 = parent
			joint.Part1 = p
			joint.C0 = parent.CFrame:Inverse() * hinge
			joint.C1 = cf:Inverse() * hinge
			joint.Parent = p
			joints[c][r] = joint
			pieces[c][r] = p

			-- Os quadrados do emblema deste bocado, soldados a ele.
			local squares: { BasePart } = {}
			for j = r0 + 1, r1 do
				for i = c0 + 1, c1 do
					local qcf, qsize = quad(teamId, BP.tAt(i - 1), BP.tAt(i), BP.sAt(j - 1), BP.sAt(j))
					local q = part("Pano", Vector3.new(qsize.X * 1.08, qsize.Y * 1.1, 0.1), qcf, model)
					q.Color = TifoDesigns.colour(TifoDesigns.sample(lines, j, i, pixelRows, pixelColumns), teamId)
					-- Um pouco translucido: a luz das tochas por baixo passa.
					q.Transparency = 0.14
					local weld = Instance.new("Weld")
					weld.Part0 = p
					weld.Part1 = q
					weld.C0 = cf:Inverse() * qcf
					weld.Parent = q
					table.insert(squares, q)
				end
			end
			cloth[c][r] = squares
		end
	end

	local controller = Instance.new("AnimationController")
	controller.Parent = model
	Instance.new("Animator").Parent = controller

	return { model = model, root = root, columns = COLUMNS, rows = ROWS, joints = joints, cloth = cloth }
end

--[[
	O jogo, sem animacao feita: `front` de 0 (enrolado) a ROWS (todo aberto).
	Cada fila de bocados desdobra-se a partir da de cima quando a frente passa
	por ela; aberto, ondula um pouco (a claque a empurrar por baixo).
]]
function BandeiraoRig.pose(rig: Rig, front: number, t: number)
	for c = 1, rig.columns do
		for r = 1, rig.rows do
			local k = math.clamp(front - (r - 1), 0, 1)
			local fold = (1 - k) * 2.9
			local wave = k * 0.06 * math.sin(t * 2.1 + c * 0.45 + r * 0.9)
			rig.joints[c][r].Transform = CFrame.Angles(fold + wave, 0, 0)
			local hide = if k <= 0.02 then 1 else 0
			for _, q in rig.cloth[c][r] do
				q.LocalTransparencyModifier = hide
			end
		end
	end
end

return BandeiraoRig
