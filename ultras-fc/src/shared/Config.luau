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
	A claque.

	A bancada enche-se de gente. Nao e decoracao: e a massa que faz o ambiente, e
	o ambiente e que faz o remate entrar. Uma bancada vazia nao apoia ninguem por
	mais botoes que se carregue.

	Saltam em sincronia. E isso que se ve de uma claque a serio de longe — nao
	pessoas paradas, um bloco inteiro a mexer ao mesmo tempo.
]]
Config.Crowd = {
	perStand = 46,
	bounceHeight = 1.6,
	baseRate = 1.6, -- saltos por segundo em repouso
	drumRate = 3.4, -- ao ritmo do tambor
	flagEvery = 6, -- de quantos em quantos leva bandeira
}

--[[
	O tambor. E ele que manda na bancada: bate-se, a claque salta mais forte e o
	ambiente sobe. Para de se bater e cai.
]]
Config.Drum = {
	hitGain = 7, -- quanto sobe o ambiente por pancada
	intensityPerHit = 0.34, -- quanto acelera a claque
	intensityDecay = 0.5, -- por segundo
	minInterval = 0.22, -- entre pancadas que contam
}

-- A barra de ambiente de cada bancada, de 0 a max.
Config.Atmosphere = {
	max = 100,
	decayPerSecond = 3.2, -- quanto desce sozinha por segundo
	crowdFloor = 0.3, -- o ambiente nunca cai abaixo disto com a bancada cheia
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

	-- 1.9 nao e por acaso: acima de 2 studs o Roblox deixa de deixar subir um
	-- degrau a andar, e a bancada passava a ser uma parede. Como cada fila fica
	-- mais baixa, sao precisas mais para a taca ter altura.
	standRows = 18,
	rowHeight = 1.9,
	rowDepth = 3.0,
	standGap = 9, -- distancia da linha lateral a primeira fila

	cornerSegments = 7, -- quantos blocos fazem cada canto curvo
	tunnelWidth = 16, -- vao das entradas por baixo da bancada
	tunnelHeight = 11, -- altura livre da passagem
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

--[[
	O material da claque.

	Tudo o que aqui esta empurra o ambiente para cima enquanto dura, e e por isso
	que quase tudo dura pouco: se pudesse estar sempre ligado, deixava de ser um
	momento e passava a ser o fundo do ecra. O tambor e a excepcao — esse nao da
	nada sozinho, so se acertar no compasso.
]]
Config.Gear = {
	tocha = {
		perMatch = 3,
		duration = 14,
		cooldown = 6,
		gainPerSecond = 2.4,
	},
	fumo = {
		perMatch = 2,
		duration = 22, -- dura mais e ve-se melhor de longe, mas aquece menos
		cooldown = 10,
		gainPerSecond = 1.5,
	},
	tambor = {
		perMatch = 1, -- so um, e fica para o jogo todo
		duration = math.huge,
		cooldown = 0,
		gainPerSecond = 0, -- nao aquece sozinho: tem de se bater ao ritmo
		chantMultiplier = 2.2, -- e ai vale por dois
	},
}


return Config
