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
		side = 1, -- bancada norte
	},
	away = {
		id = "away",
		name = "Leoes do Sul",
		short = "LES",
		color = Color3.fromRGB(46, 98, 178),
		side = -1, -- bancada sul
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

--[[
	O estadio. E propositadamente simples: partes soltas, sem modelos nem texturas.
	Serve para haver um sitio, e para se perceber de que lado se esta. Quando
	quiseres um estadio a serio, constroi-o a mao no Studio e poe
	Config.Stadium.build a false para este nao te apagar o trabalho.
]]
Config.Stadium = {
	build = true,

	pitchLength = 110, -- ao longo do eixo X
	pitchWidth = 70, -- ao longo do eixo Z

	standRows = 12,
	rowHeight = 2.6,
	rowDepth = 3.6,
	standGap = 7, -- distancia da linha lateral a primeira fila
}

--[[
	Tochas.

	E a imagem da coisa toda: uma bancada as escuras e um ponto de luz vermelha a
	arder no meio dela. Por isso sao poucas e duram pouco — se cada um pudesse ter
	sempre uma acesa, deixava de ser um momento e passava a ser o fundo do ecra.
]]
Config.Flares = {
	perMatch = 3, -- quantas cada adepto recebe por jogo
	duration = 14, -- segundos acesa
	cooldown = 6, -- espera entre tochas
	gainPerSecond = 2.4, -- quanto acrescenta ao ambiente enquanto arde
}

return Config
