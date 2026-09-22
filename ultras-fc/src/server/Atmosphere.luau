--!strict
--[[
	A barra de ambiente de cada bancada.

	E a peca central do jogo: cantar deixa de ser decoracao e passa a ser jogar.
	Sobe com acertos no compasso, desce sozinha — por isso nao chega martelar o
	botao uma vez, tem de ser mantida.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Teams = require(script.Parent:WaitForChild("Teams"))
local Gear = require(script.Parent:WaitForChild("Gear"))

local Atmosphere = {}

local levels: { [string]: number } = {}
for teamId in Config.Teams do
	levels[teamId] = 0
end

--[[
	Arranque de uma parte. O corteo entra aqui: uma claque que fez o caminho
	comeca com a bancada ja quente, uma que apareceu no fim comeca do zero.
	E o que paga a caminhada.
]]
function Atmosphere.kickOff(bonusByTeam: { [string]: number })
	for teamId in levels do
		levels[teamId] = math.clamp(bonusByTeam[teamId] or 0, 0, Config.Atmosphere.max)
	end
end

function Atmosphere.get(teamId: string): number
	return levels[teamId] or 0
end

-- 0 a 1, que e o que a UI e o jogo querem.
function Atmosphere.fraction(teamId: string): number
	return Atmosphere.get(teamId) / Config.Atmosphere.max
end

function Atmosphere.all(): { [string]: number }
	local copy = {}
	for teamId, value in levels do
		copy[teamId] = value
	end
	return copy
end

--[[
	Um adepto acertou no compasso.

	`offset` e a distancia (em segundos) a batida mais proxima: quanto menor,
	melhor o acerto.
]]
function Atmosphere.registerChant(teamId: string, offset: number, multiplier: number?)
	if levels[teamId] == nil then
		return
	end

	local gain = Config.Atmosphere.gainPerHit
	if offset <= Config.Beat.perfectWindow then
		gain *= Config.Atmosphere.perfectMultiplier
	end
	gain *= Teams.minorityBonus(teamId)
	gain *= multiplier or 1

	levels[teamId] = math.min(levels[teamId] + gain, Config.Atmosphere.max)
end

--[[
	Chamado todos os frames. A descida constante e o que obriga a manter o ritmo.

	O material aceso empurra na direcao contraria enquanto dura: acender uma
	tocha compra a bancada uns segundos de folga, o que e exactamente o que uma
	tocha faz numa bancada a serio.
]]
function Atmosphere.step(dt: number)
	local drop = Config.Atmosphere.decayPerSecond * dt

	for teamId, value in levels do
		local fromGear = Gear.heatFor(teamId) * dt
		levels[teamId] = math.clamp(value - drop + fromGear, 0, Config.Atmosphere.max)
	end
end

return Atmosphere
