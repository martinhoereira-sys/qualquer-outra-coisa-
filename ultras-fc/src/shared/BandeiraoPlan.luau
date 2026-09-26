--!strict
--[[
	Onde fica o bandeirao de cada claque, em numeros.

	O pano cobre a curva da claque de ponta a ponta (t0 a t1) e da fila de
	cima a de baixo, `headroom` studs acima de cada degrau: passa por cima das
	cabecas. Esta partido em `columns` x `rows` bocados; as colunas contam-se
	da esquerda para a direita de quem olha do campo, as filas de cima (o fundo
	da bancada) para baixo.

	Usado pelo servidor (o rolo no mapa) e pelos ecras (o pano a desenrolar).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StadiumPlan"))

local S = Config.Stadium
local B = Config.Lider.bandeirao

local BP = {}

-- Em filas da bancada: de onde a onde vai o pano.
BP.sTop = S.rows + 0.3
BP.sBottom = 0.6
BP.columns = B.columns
BP.rows = B.rows

-- Um ponto do pano: `t` ao longo da curva, `s` em filas (0.5 = a primeira).
function BP.point(teamId: string, t: number, s: number): Vector3
	local cx, cz = Plan.claqueCorner(teamId)
	return Plan.curvePoint(cx, cz, t, S.cornerRadius + (s - 0.5) * S.rowDepth, s * S.rowHeight + B.headroom)
end

-- O t da beira `c` (0 a columns). Vista do campo, t cresce da direita para a esquerda.
function BP.tAt(c: number): number
	return B.t1 - c / B.columns * (B.t1 - B.t0)
end

-- O s da beira `j` (0 = em cima, rows = em baixo).
function BP.sAt(j: number): number
	return BP.sTop - j / B.rows * (BP.sTop - BP.sBottom)
end

--[[
	O rolo ao longo da curva, a altura da fila `s`: `n` bocados de cilindro,
	cada um com o seu CFrame (o eixo do cilindro e o X) e comprimento.
]]
function BP.roll(teamId: string, s: number, n: number): { { cf: CFrame, length: number } }
	local out = {}
	for i = 0, n - 1 do
		local a = BP.point(teamId, B.t0 + (B.t1 - B.t0) * i / n, s)
		local b = BP.point(teamId, B.t0 + (B.t1 - B.t0) * (i + 1) / n, s)
		local mid = (a + b) / 2
		local along = (b - a)
		local x = if along.Magnitude > 1e-3 then along.Unit else Vector3.xAxis
		local z = x:Cross(Vector3.yAxis)
		z = if z.Magnitude > 1e-3 then z.Unit else Vector3.zAxis
		table.insert(out, { cf = CFrame.fromMatrix(mid, x, z:Cross(x)), length = along.Magnitude * 1.04 })
	end
	return out
end

BP.ROLL_PIECES = 10
BP.ROLL_THICK = 2.2

return BP
