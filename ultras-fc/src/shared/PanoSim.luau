--!strict
--[[
	O pano simulado: tecido a serio em vez de placas animadas a mao.

	Pecas rigidas animadas junta a junta parecem sempre papel dobrado. Aqui o
	pano e uma rede de pontos com peso (verlet), presa ao mastro pela beira do
	lado dele: a gravidade puxa-o para baixo, o vento empurra-o e o ar trava-o.
	Quando o mastro se mexe (pela animacao de quem o agita, ou pelo jogo), o
	pano vai atras sozinho: chicoteia nas mudancas de lado, cai com o peso e
	ondula sempre de maneira diferente, como tecido.

	No fim, cada bocado do rig (PanoRig) e posto entre os seus quatro pontos,
	mexendo as juntas: o mesmo rig, os mesmos nomes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PanoRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PanoRig"))

local PanoSim = {}

export type Sim = {
	rig: PanoRig.Rig,
	cols: number,
	rows: number,
	w: number,
	h: number,
	pos: { Vector3 },
	prev: { Vector3 },
	links: { { number } }, -- { a, b }
	lengths: { number },
	stiff: { number },
	leftover: number,
	seed: number,
}

-- A fisica do tecido (em studs e segundos).
local GRAVITY = Vector3.new(0, -42, 0)
local AIR = 1.6 -- o ar trava o pano (e o que o faz ir atras do mastro)
local KEEP = 0.99 -- o pano perde um pouco de balanco a cada passo
local ITERATIONS = 6
local STEP = 1 / 90
-- O vento: sempre do mesmo lado em todo o mapa, com rajadas.
local WIND = Vector3.new(1, 0, 0.35).Unit

local function index(sim: Sim, i: number, j: number): number
	return j * (sim.cols + 1) + i + 1
end

local function link(sim: Sim, a: number, b: number, stiffness: number)
	table.insert(sim.links, { a, b })
	table.insert(sim.lengths, (sim.pos[a] - sim.pos[b]).Magnitude)
	table.insert(sim.stiff, stiffness)
end

--[[
	Um pano novo, estendido a partir do canto de cima do lado preso (`corner`:
	X ao comprido do pano, Y para cima).
]]
function PanoSim.new(rig: PanoRig.Rig, corner: CFrame): Sim
	local sim: Sim = {
		rig = rig,
		cols = rig.columns,
		rows = rig.rows,
		w = rig.w,
		h = rig.h,
		pos = {},
		prev = {},
		links = {},
		lengths = {},
		stiff = {},
		leftover = 0,
		seed = math.random() * 100,
	}
	for j = 0, sim.rows do
		for i = 0, sim.cols do
			local p = (corner * CFrame.new(i * sim.w, -j * sim.h, 0)).Position
			sim.pos[index(sim, i, j)] = p
			sim.prev[index(sim, i, j)] = p
		end
	end
	for j = 0, sim.rows do
		for i = 0, sim.cols do
			local a = index(sim, i, j)
			if i < sim.cols then
				link(sim, a, index(sim, i + 1, j), 1) -- a trama
			end
			if j < sim.rows then
				link(sim, a, index(sim, i, j + 1), 1)
			end
			if i < sim.cols and j < sim.rows then
				link(sim, a, index(sim, i + 1, j + 1), 0.6) -- nao deixa o pano torcer
				link(sim, index(sim, i + 1, j), index(sim, i, j + 1), 0.6)
			end
			if i + 2 <= sim.cols then
				link(sim, a, index(sim, i + 2, j), 0.25) -- o tecido resiste um pouco a dobrar
			end
			if j + 2 <= sim.rows then
				link(sim, a, index(sim, i, j + 2), 0.25)
			end
		end
	end
	return sim
end

--[[
	Um passo: a beira do lado do mastro vai para onde o mastro esta (`corner`),
	o resto segue pela fisica. `wind` de 0 (parado) a 1 (ventania).

	`opts`:
	- `shape`: quanto o pano volta a forma de bandeira esticada (0 = nada, so
	  fisica; 1 = uma bandeira de pano firme, como no Animation Editor);
	- `gravity`: o peso (a bandeirinha e mais leve);
	- `avoid`: esferas { centro, raio } de onde o pano sai (cabeca, tronco de
	  quem a segura): nunca passa por dentro da personagem.

	O vento sopra sempre PARA FORA do mastro, para o lado do pano: a bandeira
	fica esticada, como se o vento viesse de tras de quem a agita.
]]
export type StepOptions = {
	shape: number?,
	gravity: number?,
	avoid: { { any } }?,
}

function PanoSim.step(sim: Sim, dt: number, corner: CFrame, wind: number, t: number, opts: StepOptions?)
	local o: StepOptions = opts or {}
	local shape = o.shape or 0
	local gravity = Vector3.new(0, -(o.gravity or -GRAVITY.Y), 0)
	local avoid = o.avoid
	sim.leftover = math.min(sim.leftover + dt, 0.1)
	local pos, prev = sim.pos, sim.prev
	local cols, rows = sim.cols, sim.rows
	-- Para fora do mastro (o comprido do pano), e um pouco do vento do mapa.
	local out = corner.XVector
	local blow = (out * 0.8 + WIND * 0.2).Unit
	while sim.leftover >= STEP do
		sim.leftover -= STEP
		-- A beira presa ao mastro.
		for j = 0, rows do
			local k = index(sim, 0, j)
			local p = (corner * CFrame.new(0, -j * sim.h, 0)).Position
			prev[k] = p
			pos[k] = p
		end
		-- As rajadas: fortes e fracas, e um pouco diferentes em cada sitio do pano.
		local gust = 22 + 18 * wind + 8 * math.sin(t * 0.9 + sim.seed) + 5 * math.sin(t * 2.3 + sim.seed * 2)
		for j = 0, rows do
			for i = 1, cols do
				local k = index(sim, i, j)
				local p = pos[k]
				local v = (p - prev[k]) / STEP
				local flutter = math.sin(t * 7.1 + i * 0.9 + j * 1.3 + sim.seed) * 6
				local force = gravity + blow * (gust + flutter) + corner.ZVector * (flutter * 0.8) - v * AIR
				if shape > 0 then
					-- A forma de bandeira esticada: puxa devagar para la.
					local rest = (corner * CFrame.new(i * sim.w, -j * sim.h, 0)).Position
					force += (rest - p) * (shape * 60)
				end
				prev[k] = p
				pos[k] = p + v * STEP * KEEP + force * STEP * STEP
			end
		end
		-- As ligacoes do tecido.
		for _ = 1, ITERATIONS do
			for n, pair in sim.links do
				local a, b = pair[1], pair[2]
				local delta = pos[b] - pos[a]
				local d = delta.Magnitude
				if d > 1e-6 then
					local diff = (d - sim.lengths[n]) / d * sim.stiff[n]
					local aPinned = (a - 1) % (cols + 1) == 0
					local bPinned = (b - 1) % (cols + 1) == 0
					if aPinned and not bPinned then
						pos[b] -= delta * diff
					elseif bPinned and not aPinned then
						pos[a] += delta * diff
					elseif not aPinned then
						pos[a] += delta * (diff * 0.5)
						pos[b] -= delta * (diff * 0.5)
					end
				end
			end
		end
		-- Fora da personagem: o pano bate na cabeca e no tronco e escorrega.
		if avoid then
			for k = 1, #pos do
				if (k - 1) % (cols + 1) ~= 0 then
					for _, sphere in avoid do
						local centre: Vector3, radius: number = sphere[1], sphere[2]
						local away = pos[k] - centre
						local d = away.Magnitude
						if d < radius and d > 1e-4 then
							pos[k] = centre + away / d * radius
						end
					end
				end
			end
		end
	end
end

--[[
	Poe cada bocado do rig entre os seus quatro pontos, mexendo as juntas.
	`root` e onde o rig esta preso agora (o mastro), `attach` o C0 da primeira
	junta (o canto do pano no mastro).
]]
function PanoSim.apply(sim: Sim, root: CFrame)
	local rig = sim.rig
	local pos = sim.pos
	local placed: { { CFrame } } = {}
	for c = 1, sim.cols do
		placed[c] = {}
		for r = 1, sim.rows do
			local tl = pos[index(sim, c - 1, r - 1)]
			local tr = pos[index(sim, c, r - 1)]
			local bl = pos[index(sim, c - 1, r)]
			local br = pos[index(sim, c, r)]
			local across = (tr - tl) + (br - bl)
			local up = (tl - bl) + (tr - br)
			local x = if across.Magnitude > 1e-4 then across.Unit else Vector3.xAxis
			local y = up - x * up:Dot(x)
			y = if y.Magnitude > 1e-4 then y.Unit else Vector3.yAxis
			local cf = CFrame.fromMatrix((tl + tr + bl + br) / 4, x, y)
			placed[c][r] = cf
			local joint = rig.joints[c][r]
			local parent = if r > 1 then placed[c][r - 1] elseif c > 1 then placed[c - 1][1] else root
			-- Part0 * C0 * Transform = Part1 * C1
			joint.Transform = (parent * joint.C0):Inverse() * cf * joint.C1
		end
	end
end

return PanoSim
