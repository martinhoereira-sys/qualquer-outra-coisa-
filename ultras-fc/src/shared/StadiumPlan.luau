--!strict
--[[
	A planta do estadio: onde fica cada coisa, em numeros, sem construir nada.

	O estadio e uma taca: quatro bancadas rectas e, a juntar cada duas, uma
	curva. A frente das bancadas e um rectangulo de cantos redondos a volta do
	relvado. As claques ficam em duas curvas opostas, na diagonal: cada uma na
	curva do lado da baliza que a sua equipa ataca (x = side) e do lado de fora
	desse (z = -side), para as duas ficarem o mais longe possivel.

	Quem constroi (StadiumBuilder) e quem usa (adeptos, tifo, contagem da
	bancada, corteo) le daqui, para ninguem ter a sua versao das contas.

	Numa curva, `t` vai de 0 (a ponta que encosta ao topo, virada para x) a 1
	(a ponta que encosta a lateral, virada para z).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local S = Config.Stadium

local Plan = {}

Plan.rows = S.rows
Plan.rowDepth = S.rowDepth
Plan.rowHeight = S.rowHeight
Plan.standDepth = S.rows * S.rowDepth
Plan.topY = S.rows * S.rowHeight
Plan.innerX = S.pitchLength / 2 + S.endGap -- frente dos topos (mais longe: ha a baliza)
Plan.innerZ = S.pitchWidth / 2 + S.standGap -- frente das laterais
Plan.cornerRadius = S.cornerRadius
-- As rectas acabam onde comecam as curvas.
Plan.endRun = (Plan.innerZ - S.cornerRadius) * 2 -- comprimento dos topos
Plan.sideRun = (Plan.innerX - S.cornerRadius) * 2 -- comprimento das laterais
Plan.mainSide = -1 -- a principal (tunel, camarotes) e a lateral de z negativo

-- O vomitorio de cada bancada sai nesta fila; a boca vai ate `mouthTop`.
Plan.exitRow = S.vomitoryRow
Plan.mouthTop = math.min(S.vomitoryRow + 4, S.rows - 1)

-- A principal: camarotes atras do primeiro andar, e o segundo andar por cima.
Plan.boxFront = Plan.innerZ + Plan.standDepth
Plan.boxBack = Plan.boxFront + S.boxDepth
Plan.upperBase = Plan.topY + S.boxHeight + 1 -- o chao do segundo andar
Plan.upperFront = Plan.boxFront - 2 -- avanca um pouco por cima da ultima fila
Plan.upperDepth = S.upperRows * S.rowDepth
Plan.upperTop = Plan.upperBase + S.upperRows * S.upperRowHeight
Plan.mainBack = Plan.upperFront + Plan.upperDepth + 1 -- a fachada da principal

-- A fachada das outras bancadas (as costas delas).
Plan.backAt = Plan.standDepth + 1
Plan.backHeight = Plan.topY + 10

-- O centro da curva do canto (cx, cz): sinais de x e de z.
function Plan.corner(cx: number, cz: number): Vector3
	return Vector3.new(cx * (Plan.innerX - S.cornerRadius), 0, cz * (Plan.innerZ - S.cornerRadius))
end

-- Para fora da curva, no ponto t.
function Plan.dir(cx: number, cz: number, t: number): Vector3
	local a = t * math.pi / 2
	return Vector3.new(cx * math.cos(a), 0, cz * math.sin(a))
end

-- Um ponto da curva, a distancia `radius` do centro e a altura `y`.
function Plan.curvePoint(cx: number, cz: number, t: number, radius: number, y: number): Vector3
	return Plan.corner(cx, cz) + Plan.dir(cx, cz, t) * radius + Vector3.new(0, y, 0)
end

-- O meio de uma fila da curva, medido do centro dela.
function Plan.rowRadius(row: number): number
	return S.cornerRadius + (row - 0.5) * S.rowDepth
end

-- Metade da largura do vomitorio, em t, a esta distancia do centro.
function Plan.vomitoryHalfT(radius: number): number
	return (S.gangwayWidth / 2) / radius / (math.pi / 2)
end

-- Em que curva esta a claque desta equipa.
function Plan.claqueCorner(teamId: string): (number, number)
	local side = Config.Teams[teamId].side
	return side, -side
end

-- Em cima do degrau da fila `row`, no ponto t da curva da claque.
function Plan.claqueSeat(teamId: string, row: number, t: number): Vector3
	local cx, cz = Plan.claqueCorner(teamId)
	return Plan.curvePoint(cx, cz, t, Plan.rowRadius(row), row * S.rowHeight)
end

--[[
	Se esta posicao esta na curva da claque: devolve a fila e o t (senao nil).
	Com uma folga de uns studs, para contar quem esta na escada ou encostado.
]]
function Plan.inClaque(teamId: string, position: Vector3): (number?, number?)
	local cx, cz = Plan.claqueCorner(teamId)
	local rel = position - Plan.corner(cx, cz)
	local ax, az = rel.X * cx, rel.Z * cz
	if ax < -2 or az < -2 then
		return nil, nil
	end
	local distance = Vector3.new(rel.X, 0, rel.Z).Magnitude
	local row = math.ceil((distance - S.cornerRadius) / S.rowDepth)
	if row < 0 or row > S.rows + 1 then
		return nil, nil
	end
	local t = math.clamp(math.atan2(math.max(az, 0), math.max(ax, 0)) / (math.pi / 2), 0, 1)
	return math.clamp(row, 1, S.rows), t
end

-- A porta da claque, na rua, atras da curva: onde o corteo chega.
function Plan.claqueGate(teamId: string): Vector3
	local cx, cz = Plan.claqueCorner(teamId)
	return Plan.curvePoint(cx, cz, 0.5, S.cornerRadius + Plan.backAt + 14, 3)
end

-- A explanada a volta do estadio: meia largura em x, e o z de cada lado.
function Plan.grounds(): (number, number, number)
	local halfX = Plan.innerX + Plan.backAt + 34
	local zNear = Plan.innerZ + Plan.backAt + 34 -- a lateral do publico (z positivo)
	local zMain = Plan.mainBack + 30 -- a principal (z negativo)
	return halfX, zNear, zMain
end

-- Dentro da explanada do estadio (relvado, bancadas e a volta).
function Plan.insideGround(position: Vector3): boolean
	local halfX, zNear, zMain = Plan.grounds()
	return math.abs(position.X) <= halfX and position.Z <= zNear and position.Z >= -zMain
end

return Plan
