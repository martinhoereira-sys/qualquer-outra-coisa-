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
	warmupLength = 90, -- da tempo ao corteo de chegar
	halfLength = 120, -- cada parte, em segundos reais
	halfTimeLength = 20,
	fullTimeLength = 25, -- rescaldo antes de recomecar

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

	standRows = 14,
	rowHeight = 2.4,
	rowDepth = 3.2,
	standGap = 9, -- distancia da linha lateral a primeira fila

	cornerSegments = 7, -- quantos blocos fazem cada canto curvo
	tunnelWidth = 14, -- vao das entradas por baixo da bancada
}

--[[
	Tochas.

	E a imagem da coisa toda: uma bancada as escuras e um ponto de luz vermelha a
	arder no meio dela. Por isso sao poucas e duram pouco — se cada um pudesse ter
	sempre uma acesa, deixava de ser um momento e passava a ser o fundo do ecra.
]]
--[[
	Os jogadores em campo. Nao sao pessoas — sao NPCs, e sao de proposito: o
	futebol so precisa de ser suficiente para a bancada ter algo a que reagir.
]]
Config.Pitch = {
	perSide = 6,
	speed = 17, -- studs por segundo com bola nos pes
	chaseSpeed = 21, -- sem bola corre-se mais
	ballSpeed = 58, -- remate
	passSpeed = 40,
	controlRange = 4.5, -- a que distancia se ganha a bola
	shootRange = 34, -- daqui para dentro, remata-se
	goalHalfWidth = 8,
	goalHeight = 9,

	-- O ambiente da bancada entra aqui: com a bancada cheia o remate sai mais
	-- certeiro. E a ligacao entre cantar e marcar, e e o coracao do jogo.
	shotSpreadCold = 16, -- desvio com a bancada calada
	shotSpreadHot = 3, -- desvio com a bancada ao rubro
}

--[[
	O corteo. Sai no aquecimento e tem de chegar antes do apito — por isso o
	aquecimento e mais longo do que seria preciso: e o tempo da caminhada.
]]
Config.March = {
	speed = 17, -- passo da faixa, em studs por segundo
	radius = 45, -- a que distancia da faixa ainda se conta como ir no corteo
	legSeconds = 20, -- tempo de referencia por perna do percurso
	atmosphereBonus = 55, -- ambiente de partida para uma claque que fez o caminho
}

Config.Flares = {
	perMatch = 3, -- quantas cada adepto recebe por jogo
	duration = 14, -- segundos acesa
	cooldown = 6, -- espera entre tochas
	gainPerSecond = 2.4, -- quanto acrescenta ao ambiente enquanto arde
}

return Config
