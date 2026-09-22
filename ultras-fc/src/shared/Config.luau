--!strict
--[[
	Numeros de afinacao do jogo.

	Mexe AQUI primeiro. Quase tudo o que "sente mal" a jogar — a barra sobe
	depressa demais, os golos sao poucos, o compasso e apertado — resolve-se
	nestes valores, sem tocar na logica.
]]

local Config = {}

--[[
	As duas equipas da Fase 1. Cada claque tem o seu topo, atras de uma baliza,
	como num estadio a serio — as laterais sao do publico.

	`side` e o topo, ao longo do eixo X: -1 o poente, 1 o nascente. Cada claque
	fica do lado da sua sede, para os dois corteos chegarem sem se cruzarem.
]]
Config.Teams = {
	home = {
		id = "home",
		name = "Aguias do Norte",
		short = "AGN",
		color = Color3.fromRGB(196, 58, 48),
		side = -1, -- topo poente
	},
	away = {
		id = "away",
		name = "Leoes do Sul",
		short = "LES",
		color = Color3.fromRGB(46, 98, 178),
		side = 1, -- topo nascente
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
	perStand = 40,
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

	--[[
		O campo, em studs. Cerca de 70 x 45 m: menos do que um relvado oficial,
		mas o suficiente para jogadores a serio (5 studs de altura, 16 por segundo
		a correr) terem espaco. Tudo o resto — bancadas, muralha, cidade, corteo —
		mede-se a partir daqui, menos o bloco da claque, que tem medida propria.
	]]
	pitchLength = 210, -- ao longo do eixo X
	pitchWidth = 136, -- ao longo do eixo Z

	--[[
		Medidas de um recinto a serio, convertidas para studs (1 m ~ 3 studs).

		Degrau de 0,8 m de profundidade e inclinacao de 34 graus, que e o maximo
		que se usa numa bancada; da 1,6 studs de subida, e por baixo dos 2 studs
		que o Roblox deixa subir a andar. Doze filas chegam: isto e um estadio
		pequeno de proposito, e um pequeno cheio vale mais do que um grande vazio.
	]]
	rows = 12,
	rowDepth = 2.4,
	rowHeight = 1.6,
	standGap = 8, -- da linha lateral a primeira fila

	--[[
		Blocos. E a divisao que faz uma bancada parecer arrumada em vez de uma
		rampa unica.

		Nos topos, o bloco do meio e da claque, mesmo atras da baliza, e uma
		claque quer-se junta: nenhuma escada o corta ao meio, so tem as duas dos
		lados, e sao essas as suas entradas. Tem largura fixa — nao cresce com o
		campo — porque e sobre ele que assenta a grelha do tifo, e uma claque
		espalhada deixa de o ser. Os outros blocos dividem o resto. `blocksEnd`
		tem de ser impar, para haver bloco do meio.
	]]
	blocksLong = 5, -- nas bancadas laterais, do publico
	blocksEnd = 3, -- nas bancadas de topo, das claques
	claqueBlockWidth = 28, -- o bloco do meio dos topos
	gangwayWidth = 5, -- tambem a largura do tunel de cada vomitorio

	--[[
		Os vomitorios. Entra-se pelas costas da bancada ao nivel da rua, sobe-se
		uma rampa por baixo dos degraus e sai-se a meio da bancada, nesta fila.
		A meio e de proposito: sair ca em baixo obrigava a subir a bancada toda,
		sair la em cima obrigava a desce-la.
	]]
	vomitoryRow = 6,

	-- A muralha a volta do recinto. Cada claque entra pela porta do seu topo;
	-- o publico pelas das laterais.
	wallHeight = 10,
	claqueGateWidth = 24,
	publicGateWidth = 16,
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
	-- Zero: o relvado fica livre para jogadores a serio. Bonecos a correr atras
	-- da bola liam-se como enchimento, e o jogo nao e sobre eles.
	perSide = 0,
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
	readyNeeded = 3, -- quantos tem de estar na sede para o lider poder sair
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
--[[
	O arbitro.

	E o motor do drama, e por isso corromper-se tem de ser ARRISCADO e nunca
	comprado. Um arbitro que se comprasse com Robux fazia quem paga ganhar
	sempre — toda a gente percebia em dois dias e o jogo morria. Assim vira jogo
	do gato e do rato, e esse dura.

	Cada decisao a favor de quem mais pressionou enche a barra de suspeicao.
	Cheia, e apanhado: a ultima decisao e revertida e fica suspenso.
]]
Config.Referee = {
	decisionSeconds = 12, -- tempo para decidir antes de sair sozinha
	contestedGoalChance = 0.4, -- golos que ficam por confirmar
	shoutInterval = 50, -- de quantos em quantos segundos ha um lance na area
	suspicionPerCall = 26, -- quanto sobe ao ceder a quem pressiona
	suspicionDecay = 1.4, -- por segundo, quando se porta bem
	caughtAt = 100,
	banMatches = 2,
	pressureWindow = 20, -- segundos que um pedido da bancada continua a contar
}

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

--[[
	Os tifos: um mosaico de cartolinas por cima do bloco da claque.

	O lider escolhe o desenho e dispara; cada um no bloco recebe a cartolina da
	cor do seu lugar e levanta-a. O lugar de quem nao levanta fica um buraco no
	desenho — ve-se de longe quem nao esteve.

	Vale pelo MOMENTO. Um tifo e para o apito inicial ou para o golo, nao para
	meio da segunda parte: nessas janelas da o dobro, fora delas da metade.
	E isso que torna disparar uma decisao do lider e nao um botao a toa.
]]
Config.Tifo = {
	perMatch = 2, -- por claque, e renova-se no aquecimento
	countdown = 3, -- segundos de aviso antes de subir
	duration = 12, -- quanto tempo fica no ar
	gainPerSecond = 3, -- ambiente por segundo enquanto esta no ar
	momentWindow = 20, -- segundos depois do apito inicial ou de um golo nosso
	momentMultiplier = 2, -- na janela certa
	offMomentMultiplier = 0.5, -- fora dela
	crowdShare = 0.5, -- a parte do efeito que a bancada ja da sozinha; o resto e de quem levanta

	-- A grelha, sobre o bloco do meio da bancada: colunas ao longo dela, filas
	-- a partir desta, para cima.
	columns = 14,
	rows = 8,
	firstRow = 2,
	liftHeight = 6.6, -- a que altura acima do degrau fica a cartolina

	--[[
		Os desenhos. Cada linha e uma fila de cartolinas vista do relvado, de cima
		para baixo e da esquerda para a direita:

			E  cor da equipa
			B  branco
			P  preto

		Com `initials`, o desenho e gerado a partir da sigla da equipa.
	]]
	designs = {
		{
			id = "riscas",
			name = "Riscas",
			rows = {
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
			},
		},
		{
			id = "iniciais",
			name = "Iniciais",
			initials = true,
		},
		{
			id = "estrela",
			name = "Estrela",
			rows = {
				"EEEEEEBBEEEEEE",
				"EEEEEBBBBEEEEE",
				"BBBBBBBBBBBBBB",
				"EBBBBBBBBBBBBE",
				"EEBBBBBBBBBBEE",
				"EEEBBBBBBBBEEE",
				"EEBBBBEEBBBBEE",
				"EBBBEEEEEEBBBE",
			},
		},
	},
}

return Config
