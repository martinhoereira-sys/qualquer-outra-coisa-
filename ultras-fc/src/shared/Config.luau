--!strict
--[[
	Numeros de afinacao do jogo.

	Mexe AQUI primeiro. Quase tudo o que "sente mal" a jogar — a barra sobe
	depressa demais, os golos sao poucos, o compasso e apertado — resolve-se
	nestes valores, sem tocar na logica.
]]

local Config = {}

-- As duas equipas da Fase 1. Uma bancada cada.
Config.Teams = {
	home = {
		id = "home",
		name = "Aguias do Norte",
		short = "AGN",
		color = Color3.fromRGB(196, 58, 48),
	},
	away = {
		id = "away",
		name = "Leoes do Sul",
		short = "LES",
		color = Color3.fromRGB(46, 98, 178),
	},
}

-- Ordem fixa, para a UI nao andar a saltar.
Config.TeamOrder = { "home", "away" }

--[[
	O compasso dos canticos.

	O servidor nao envia cada batida pela rede: servidor e clientes leem o mesmo
	relogio (workspace:GetServerTimeNow) e calculam a batida sozinhos. Menos
	trafego e fica tudo sincronizado.
]]
Config.Beat = {
	interval = 1.0, -- segundos entre batidas
	window = 0.30, -- acerto conta se cair a menos disto da batida
	perfectWindow = 0.12, -- dentro disto e perfeito
}

-- A barra de ambiente de cada bancada, de 0 a max.
Config.Atmosphere = {
	max = 100,
	gainPerHit = 3.2, -- quanto sobe por acerto bom
	perfectMultiplier = 1.8, -- quanto vale um acerto perfeito
	decayPerSecond = 4.5, -- quanto desce sozinha por segundo
	minorityCap = 2.0, -- teto do bonus de quem esta em minoria
}

--[[
	O jogo. Na Fase 1 quem joga sao NPCs — o que decide o resultado e a bancada.
	E de proposito: o futebol so precisa de ser suficiente para haver algo a que
	reagir.
]]
Config.Match = {
	warmupLength = 25, -- antes do apito inicial
	halfLength = 120, -- cada parte, em segundos reais
	halfTimeLength = 20,
	fullTimeLength = 25, -- rescaldo antes de recomecar

	chanceInterval = 5, -- de quantos em quantos segundos se tenta um lance
	baseGoalChance = 0.10, -- hipotese base de golo por lance
	atmosphereSwing = 1.6, -- bancada cheia multiplica a hipotese por (1 + isto)
}

return Config
