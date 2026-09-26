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
		keeperColor = Color3.fromRGB(46, 160, 82), -- a camisola do guarda-redes, diferente da equipa
		sedeName = "sede vermelha", -- o nome da sede no mapa (ver City)
	},
	away = {
		id = "away",
		name = "Leoes do Sul",
		short = "LES",
		color = Color3.fromRGB(46, 98, 178),
		side = 1, -- topo nascente
		keeperColor = Color3.fromRGB(236, 176, 40),
		sedeName = "sede azul",
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
	partyHeight = 1.8, -- no golo, quantas vezes mais alto do que o salto normal
	sitDrop = 1.1, -- quanto descem os que se sentam, calados
	botsPerPlayer = 2, -- bonecos que saem da bancada por cada pessoa na claque
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
	O dia de jogo, em ciclo, sem nunca parar:

		sede -> corteo -> espera -> entrada -> 1a parte -> intervalo
		-> 2a parte -> fim -> sede

	Em segundos reais. Ao intervalo ninguem troca de campo: cada equipa ataca
	sempre a baliza a frente da sua claque.
]]
Config.Match = {
	clubhouseLength = 180, -- na sede: material, lider, e esperar pelos outros
	corteoLength = 180, -- a caminhada ate ao estadio: ~900 studs a passo de marcha, mais a espera pela ordem
	waitLength = 60, -- no maximo, a espera de que as bancadas estejam nos seus lugares
	entranceLength = 40, -- do tunel ao apito: saida, fila e cada um ao seu lugar
	halfLength = 450, -- cada parte: 7 min e meio
	halfTimeLength = 30,
	fullTimeLength = 120, -- no relvado ou na bancada, antes de voltar a sede
	celebrationLength = 15, -- do golo ao pontape de saida
	switchCooldown = 60, -- depois de escolher um papel, segundos ate poder trocar outra vez
}

--[[
	As horas do dia. Um dia inteiro (24 horas de jogo) dura `dayMinutes`
	minutos reais, e o servidor arranca a `startHour`. De noite acendem-se os
	candeeiros e os holofotes; so um candeeiro em cada `lampLightEvery`
	ilumina a serio, os outros so brilham.
]]
Config.DayNight = {
	dayMinutes = 30,
	startHour = 15,
	lampLightEvery = 3,
	windowsLit = 0.2, -- das faixas de janelas, quantas se acendem a noite
}

--[[
	Quem pode saltar de fase, pelo numero da conta Roblox. E o servidor que
	confirma: o botao so aparece a estes, mas quem decide e a lista.
]]
Config.Admins = {
	10733750829,
}

--[[
	Os sons. O codigo chama-os pelo nome, nunca pelo numero: para trocar um som,
	muda-se o numero aqui e mais nada.

	`volume` e o volume de base. A multidao de fundo sobe e desce com o ambiente
	entre `volume` e `volumeMax`, e fica sempre abaixo dos outros para nao os
	abafar.

	Todos da biblioteca de sons que o Roblox deixa usar em qualquer jogo
	(ProSoundEffects e APM). Audio privado de outra conta nao toca e nao da
	erro: fica mudo.
]]
export type SoundSpec = { id: number, volume: number, volumeMax: number?, looped: boolean?, cut: number? }

Config.Sounds = {
	multidao = { id = 9119562234, volume = 0.15, volumeMax = 0.4, looped = true },
	golo = { id = 9120975204, volume = 0.9 },
	lamento = { id = 9120974911, volume = 0.6 },
	tambor = { id = 9113343286, volume = 0.8, cut = 0.55 }, -- o ficheiro tem varias pancadas: toca-se so a primeira
	apito_inicio = { id = 9118113825, volume = 0.8 },
	apito_falta = { id = 9117261163, volume = 0.8 },
	apito_fim = { id = 9117259635, volume = 0.9 },
	pontape = { id = 9119326824, volume = 0.6 },
	corteo = { id = 9112779476, volume = 0.45, looped = true },
	festa_fim = { id = 1839963987, volume = 0.6 },
} :: { [string]: SoundSpec }

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

	--[[
		O estadio novo (2026-09): uma taca branca continua, com as bancadas a
		darem a volta pelos cantos em curva. As claques ficam em duas curvas
		opostas, na diagonal; a bancada principal tem dois andares, com os
		camarotes e a tribuna presidencial entre eles.
	]]
	endGap = 20, -- da linha de golo a primeira fila dos topos (a baliza precisa de espaco atras)
	cornerRadius = 20, -- raio da frente das curvas (a primeira fila)
	curveSegments = 7, -- pedacos de cada fila de uma curva (mais = mais redondo, mais pecas)
	boxDepth = 8, -- os camarotes, atras do primeiro andar da principal
	boxHeight = 7,
	upperRows = 8, -- o segundo andar da principal
	upperRowHeight = 1.9,
}


--[[
	Tochas.

	E a imagem da coisa toda: uma bancada as escuras e um ponto de luz vermelha a
	arder no meio dela. Por isso sao poucas e duram pouco — se cada um pudesse ter
	sempre uma acesa, deixava de ser um momento e passava a ser o fundo do ecra.
]]
--[[
	O futebol. Cinco contra cinco, jogado por pessoas; os lugares que ficam
	vazios levam um boneco, e o boneco sai quando chega alguem.

	A bola e fisica normal do Roblox, nao simulacao: e para ser previsivel e
	agradavel de chutar, nao realista. Quase tudo o que "sente mal" a jogar
	resolve-se aqui.
]]
Config.Football = {
	-- A formacao: quatro no campo e um na baliza, como no futsal. `x` e a
	-- fracao de meio campo a partir do centro, para tras; `z` e a fracao da
	-- largura do relvado. A ordem e a de quem entra: uma pessoa fica com o
	-- primeiro lugar livre de campo, de frente para tras. A baliza so a quem
	-- a escolhe.
	formation = {
		{ number = 9, x = 0.12, z = 0 },
		{ number = 7, x = 0.42, z = 0.27 },
		{ number = 11, x = 0.42, z = -0.27 },
		{ number = 4, x = 0.68, z = 0 },
		{ number = 1, x = 0.95, z = 0, keeper = true },
	},

	--[[
		O guarda-redes. Dentro da sua area agarra a bola que lhe passa perto,
		sozinho; fora dela e um jogador como os outros. Com a bola nas maos
		ninguem lha tira, e tem uns segundos para a por em jogo.

		O boneco fica na linha, a acompanhar a bola, e defende so uma parte dos
		remates fortes — quer-se golos.
	]]
	keeperReach = 5, -- a esta distancia agarra sozinho, na sua area
	keeperHeight = 8, -- e ate esta altura: apanha a bola no ar
	keeperDiveReach = 11, -- a atirar-se chega mais longe
	keeperDiveSpeed = 42, -- studs/s do mergulho
	keeperDiveTime = 1, -- quanto dura o voo; falhou, fica no chao (fallTime)
	keeperDiveCooldown = 1.5,
	keeperHoldTime = 5, -- segundos com a bola nas maos; depois perde-a
	botKeeperSave = 0.45, -- remates fortes que o boneco agarra
	botKeeperDelay = 1.2, -- o boneco com a bola nas maos espera isto antes de a por em jogo
	fastShot = 38, -- acima desta velocidade e um remate a serio, nao uma bola a rolar

	-- Correr
	walkSpeed = 16,
	sprintSpeed = 24,
	botSpeed = 15, -- os bonecos a posicionar-se
	botSprintSpeed = 20, -- a ir a bola; abaixo do sprint de uma pessoa, para se lhes poder fugir
	botDribbleSpeed = 22, -- com bola, um pouco mais do que quem aperta: foge-se por tras, nao pela frente
	staminaMax = 100,
	staminaDrain = 24, -- por segundo, a correr em sprint
	staminaRegen = 13, -- por segundo, sem sprint
	staminaRecover = 30, -- esgotado, so volta ao sprint a partir daqui

	-- A bola
	ballSize = 2,
	claimRange = 3.6, -- a que distancia dos pes se fica com ela
	claimHeight = 3.8, -- acima disto passa por cima: nao ha cabecear
	dribbleDistance = 2.6, -- a que distancia a frente dos pes vai com a posse
	kickLockout = 0.4, -- quem chutou nao a volta a apanhar logo
	kickFlight = 0.15, -- ninguem lhe toca logo a saida do pe
	rollDrag = 0.85, -- travao no chao, por segundo
	airDrag = 0.12, -- travao no ar

	--[[
		Chutar: um botao para tudo. Segurar carrega a forca, largar chuta; um
		toque curto e um passe, carregado a fundo e um remate. Enquanto se
		segura, mexer o rato da o efeito (para os lados) e a altura (para cima,
		chapeu; para baixo, rasteira).
	]]
	chargeTime = 0.9, -- segundos ate a forca maxima
	kickSpeedMin = 24, -- um toque
	kickSpeedMax = 112, -- tudo
	aimPixels = 120, -- quanto se mexe o rato para chegar ao maximo de efeito ou altura
	liftNeutral = 0.08, -- fracao da velocidade que vai para cima, com o rato parado
	liftMax = 0.8, -- rato todo para cima: chapeu, que passa por cima de quem esta a frente
	curveAccel = 70, -- studs/s2 de desvio para o lado, com o efeito todo
	curveTime = 1.2, -- quanto tempo o efeito dura no ar

	-- Chutos fracos para a frente de um colega vao na direcao dele, com a
	-- forca que se escolheu. Sem isto, passar so pela direcao do boneco era
	-- quase impossivel.
	passAssistPower = 0.4, -- ate esta forca ha ajuda
	passCone = 25, -- graus; um colega dentro deste cone recebe-a
	passRange = 70,

	-- Os passes dos bonecos
	passSpeedMin = 30,
	passSpeedMax = 66,

	-- Roubar
	tackleRange = 2.8, -- encostar
	tackleImmunity = 1.5, -- quem ganhou a bola nao a perde logo a seguir
	claimImmunity = 0.5, -- o mesmo, mais curto, a quem apanha uma bola solta
	fallTime = 1, -- quem a perdeu fica no chao

	-- Recomecos
	kickoffFreeze = 2, -- toda a gente parada antes do apito
	restartPriority = 1.5, -- segundos em que so a equipa certa pode tocar
	goalPause = 2.5, -- a bola na rede antes do pontape de saida

	-- A baliza
	goalHalfWidth = 10.5, -- maiores do que eram (8 x 8): 21 de largo
	goalHeight = 9.6,
	goalDepth = 8, -- funda: a rede fica bem atras da linha, como as de verdade

	-- Os bonecos
	botThink = 0.35, -- de quanto em quanto tempo quem tem a bola decide
	botShootRange = 40,
	botPressure = 9, -- um adversario a esta distancia aperta
}

--[[
	O corteo. Sai no aquecimento e tem de chegar antes do apito — por isso o
	aquecimento e mais longo do que seria preciso: e o tempo da caminhada.
]]
Config.March = {
	readyNeeded = 3, -- quantos tem de estar na sede para o lider poder sair (ou todos, se forem menos)
	autoStartAfter = 30, -- sem lider a dar a ordem, a faixa sai sozinha, com folga para chegar
	bots = 36, -- bonecos que marcham atras de cada faixa, fora os dois que a seguram
	columns = 10, -- quantos lado a lado, da largura da faixa: a rua cheia de parede a parede
	leaderSpeed = 11, -- o lider a guiar anda a este passo, para o grupo o acompanhar
	leadDistance = 8, -- a faixa vai estes studs a frente do lider
	takeRadius = 20, -- o lider a esta distancia da faixa passa a guia-la
	arriveRadius = 30, -- a esta distancia da porta da claque, o corteo chegou
	speed = 9, -- passo da faixa, em studs por segundo: o de uma marcha, devagar e em grupo
	radius = 45, -- a que distancia da faixa ainda se conta como ir no corteo
	atmosphereBonus = 55, -- ambiente de partida para uma claque que fez o caminho
}

--[[
	A entrada em campo. Sai o arbitro, as duas equipas atras dele em fila, e
	param lado a lado a frente do circulo central, virados para a bancada
	principal. E o momento mais alto do dia: as duas claques no maximo.
]]
Config.Entrance = {
	lineAt = 14, -- segundos depois de abrir o tunel em que a fila fica presa
	lineSeconds = 20, -- quanto tempo fica parada
	lineZ = 22, -- a que distancia do centro, para o lado da bancada principal
	spacing = 2.6, -- entre dois jogadores lado a lado
	stagger = 0.9, -- segundos entre um jogador e o seguinte a sair do balneario
	flares = 4, -- bonecos de cada claque que acendem tocha na fila (so no ecra)
	flareLights = 1, -- desses, quantos tem luz propria, por claque
}

--[[
	O material da claque.

	Tudo o que aqui esta empurra o ambiente para cima enquanto dura, e e por isso
	que quase tudo dura pouco: se pudesse estar sempre ligado, deixava de ser um
	momento e passava a ser o fundo do ecra. O tambor e a excepcao — esse nao da
	nada sozinho, so se acertar no compasso.
]]
--[[
	As regras: reposicoes, faltas, cartoes e fora de jogo.

	A regra que manda em todas: RAPIDEZ. Sao muitas formas de parar o jogo, e se
	cada uma demorar o jogo morre. Prefere-se um jogo rapido e um bocado tosco a
	um jogo correto e parado — a bola tem de estar viva pelo menos dois tercos do
	tempo.

	Distancias em studs (1 m ~ 3 studs). As zonas proibidas so valem para os
	bonecos: as pessoas ficam onde quiserem, e se alguem se puser em cima da
	bola o tempo da reposicao trata disso.
]]
Config.Rules = {
	outDelay = 0.5, -- a bola fora ve-se sair antes de ser reposta
	restartTime = 3, -- quanto se espera por quem repoe; depois a bola fica viva ali
	humanRestartTime = 6, -- uma pessoa a bater tem mais tempo: apontar e dosear demora
	freeKickTime = 15, -- um livre (ou penalti) marcado por uma pessoa; o relogio do jogo para ate ser batido
	restartEdge = 0.5, -- acabado o tempo, a equipa que repunha ainda tem este avanco
	botTakerDelay = 0.6, -- um boneco na bola bate ao fim disto

	throwInGap = 9, -- lancamento: adversarios a 3 m
	cornerGap = 15, -- canto: a 5 m
	freeKickGap = 15, -- livre: a 5 m
	penaltyTime = 4, -- o penalti espera mais: apontar leva tempo

	--[[
		As faltas. A maior parte do contacto e so contacto: decide-se no momento
		do roubo, e por tras e mais provavel do que de frente, mas mesmo por
		tras a maioria nao e falta. Nao ha relogio: e sorte a cada entrada, e
		por isso em 30 segundos tanto pode nao haver nenhuma como haver duas ou
		tres. Em media da perto de duas por minuto; o Output diz a cada minuto
		quantas houve. `foulGap` so impede duas faltas no mesmo lance.
		O arbitro automatico marca o que aqui sai; uma pessoa com o apito pode
		marcar outra coisa.
	]]
	foulBehind = 0.2, -- roubos por tras que sao falta
	foulFront = 0.05, -- roubos de frente que sao falta
	foulGap = 3, -- segundos depois de uma falta em que nenhuma entrada o e: so o mesmo lance
	behindDot = -0.2, -- abaixo disto (olhar de quem leva a bola vs. de onde vem quem rouba) e por tras
	boxLineMargin = 3, -- a esta distancia da linha da area, fica em duvida: penalti ou livre

	-- Cartoes que o arbitro automatico mostra, por falta
	yellowBehind = 0.2,
	redBehind = 0.03,
	yellowFront = 0.05,
}

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
	whistleWindow = 2, -- segundos para apitar uma entrada; sem apito, o jogo seguiu
	cardSeconds = 10, -- com a bola parada, para escolher o cartao; sem escolha, nao ha cartao
	suspicionPerCall = 26, -- quanto sobe ao ceder a quem pressiona
	suspicionDecay = 1.4, -- por segundo, quando se porta bem
	caughtAt = 100,
	banMatches = 2,
	pressureWindow = 20, -- segundos que um pedido da bancada continua a contar
}

--[[
	Maquinas fracas.

	A maior parte de quem joga isto esta no telemovel. Estes tetos sao o que
	impede o jogo de pesar mais do que um telemovel aguenta.
]]
Config.Performance = {
	--[[
		Tochas e fumos acesos com luz propria, no estadio inteiro. Cada luz custa
		em todos os ecras; a partir daqui, as que se acendem dao chama e fumo na
		mesma, mas sem luz.
	]]
	maxLights = 6,

	--[[
		Bombas de fumo acesas a fundo ao mesmo tempo, no estadio inteiro. Uma
		nuvem sao umas centenas de particulas grandes; a partir daqui as que se
		acendem deitam metade, e continuam a ver-se.
	]]
	maxSmokes = 8,

	--[[
		O maximo de pecas de cada parte. Passar daqui e engano num ciclo, nao
		crescimento normal: a construcao para e escreve no Output. Estao um pouco
		acima do que cada parte cria hoje.
	]]
	maxParts = {
		Estadio = 1400,
		Cidade = 800,
		Adeptos = 600,
		Jogadores = 400, -- vivos ao mesmo tempo; os bonecos saem e entram
		Tifo = 300, -- cartolinas no ar, as duas claques
		Jogo = 20, -- a bola e as paredes que so ela sente
		default = 200,
	},
}

--[[
	As animacoes: os bracos com a tocha no ar, o cachecol esticado, e o menu
	de animacoes de adepto. Sao feitas em codigo, junta a junta, em todos os
	ecras (Poses.client) — assim toda a gente ve as de toda a gente, sem
	depender de animacoes carregadas de fora. So para avatares R15.

	`raisedArm` e o angulo do braco com a tocha acesa: 0 caido, 180 todo no
	ar. O Gear usa o mesmo para a tocha ficar de pe na mao.
]]
Config.Poses = {
	raisedArm = 150,
}

-- O menu de animacoes, pela ordem em que aparecem. Mexer-se para-as.
Config.Emotes = {
	{ id = "aplaudir", label = "Aplaudir" },
	{ id = "maos", label = "Maos no ar" },
	{ id = "saltar", label = "Saltar" },
	{ id = "balancar", label = "Balancar" },
	{ id = "agachado", label = "Agachado" },
}

--[[
	O material de claque. Esta sempre na barra de baixo de quem e de claque,
	desde que escolhe o lado; quem nao e de claque nao tem nada. Acender gasta
	um do stock, e o objecto fica na mao a espera do proximo.

	A sede da, a cada dia de jogo, `perMatch` de cada (a racao da claque); o
	resto compra-se aos dealers na rua, com o dinheiro do jogo (Config.Money).
	`GearStock.unlimited` = true poe tudo sem limite, para testes.
]]
Config.GearStock = {
	unlimited = false,
}

--[[
	O dinheiro do jogo (moedas). Ganha-se a jogar e gasta-se nos dealers da
	rua. Nao se compra com Robux.
]]
Config.Money = {
	start = 50, -- quem entra pela primeira vez
	perMatch = 20, -- cada pessoa de claque no apito inicial
	perCorteo = 30, -- a mais, por ter feito o corteo inteiro (proporcional)
	perGoal = 5, -- cada golo da propria equipa
}

--[[
	A academia: o campo de treino onde quem joga aparece antes do jogo, a norte
	do estadio. Dali o autocarro da equipa leva-os ao estadio no corteo.
	(O edificio vive no mapa, em Workspace.Academia: AcademyBuilder.)
]]
Config.Academy = {
	centre = Vector3.new(40, 0, 510), -- o meio do relvado de treino
	pitchLength = 110, -- ao longo de X
	pitchWidth = 64, -- ao longo de Z
	groundY = 0.3, -- o passeio do quarteirao
	goalHalfWidth = 8,
	goalHeight = 8.4,
	goalDepth = 6,
	kickSpeed = 70, -- a bola de treino, com a barra toda
	keeperSpeed = 13, -- o guarda-redes de treino, a acompanhar a bola
	boardingTime = 45, -- segundos com o autocarro da equipa de portas abertas
}

--[[
	Os autocarros. Andam sozinhos pelos percursos do mapa
	(Workspace.Transportes.Rotas, que se mexem no Studio) e param nas
	paragens que ficam ao lado deles. Conduz-se pela direita.
]]
Config.Transit = {
	cruise = 26, -- studs/s em recta
	turnSpeed = 9, -- nas curvas
	accel = 6, -- studs/s2 a arrancar
	brake = 10, -- a travar
	dwell = 9, -- segundos parado numa paragem, de portas abertas
	laneOffset = 6.5, -- do meio da rua ao meio da faixa
	cornerRadius = 11, -- o raio das curvas nos cruzamentos
	stopReach = 16, -- uma paragem a esta distancia da faixa serve o percurso
}

-- As bicicletas das sedes: a velocidade de quem pedala (a pe e 16).
Config.Bikes = {
	speed = 34,
}

-- Quantos dealers ha na rua, se o mapa nao tiver pecas "Dealer" a dizer onde.
Config.Dealers = {
	count = 6,
}

-- O que os dealers vendem, e quanto custa cada um.
Config.Shop = {
	{ kind = "tocha", label = "Tocha", price = 10, about = "Chama viva e fumo. Arde 16 segundos." },
	{ kind = "fumo", label = "Bomba de fumo", price = 15, about = "Nuvem grossa que se ve do outro lado." },
	{ kind = "estrobo", label = "Estrobo", price = 12, about = "Pisca-pisca branco, ofusca a bancada." },
	{ kind = "vela", label = "Vela romana", price = 25, about = "Dez bolas de fogo, uma por clique." },
}

-- Quantas de uma vez: o pack de 5 sai mais barato (paga-se 4).
Config.ShopPacks = {
	{ amount = 1, pay = 1 },
	{ amount = 5, pay = 4 },
}

--[[
	As cores a escolher no dealer. "Equipa" e a cor da claque; as outras
	ficam a valer para esse material ate se escolher outra.
]]
Config.PyroColours = {
	{ name = "Equipa", color = nil :: Color3? },
	{ name = "Vermelho", color = Color3.fromRGB(226, 36, 36) :: Color3? },
	{ name = "Laranja", color = Color3.fromRGB(255, 122, 20) :: Color3? },
	{ name = "Amarelo", color = Color3.fromRGB(255, 214, 40) :: Color3? },
	{ name = "Verde", color = Color3.fromRGB(40, 196, 80) :: Color3? },
	{ name = "Azul", color = Color3.fromRGB(40, 110, 240) :: Color3? },
	{ name = "Roxo", color = Color3.fromRGB(150, 60, 220) :: Color3? },
	{ name = "Rosa", color = Color3.fromRGB(255, 90, 170) :: Color3? },
	{ name = "Branco", color = Color3.fromRGB(245, 245, 245) :: Color3? },
}

Config.Gear = {
	tocha = {
		perMatch = 2,
		duration = 16, -- a arder na mao
		cooldown = 2, -- depois de apagar, ate se poder acender a seguinte
		gainPerSecond = 2.4,
	},
	fumo = {
		perMatch = 1,
		duration = 25, -- dura mais e ve-se melhor de longe, mas aquece menos
		cooldown = 3,
		gainPerSecond = 1.5,
	},
	vela = {
		perMatch = 1, -- a sede da uma; mais, so aos dealers
		duration = 40, -- acesa ate gastar os tiros (um por clique) ou ate isto
		cooldown = 3,
		gainPerSecond = 3,
	},
	estrobo = {
		perMatch = 1,
		duration = 15, -- pisca-pisca branco
		cooldown = 2,
		gainPerSecond = 1.8,
	},
	cachecol = {
		perMatch = 1, -- nao se gasta: levanta-se e baixa-se
		duration = math.huge,
		cooldown = 0,
		gainPerSecond = 0.3, -- enquanto roda no ar
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
	perMatch = 4, -- por claque, e renova-se no aquecimento
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

		Com `initials`, o desenho e gerado a partir da sigla da equipa. Com
		`message`, sai uma frase por cima (%TEAM% vira o nome da claque).
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
		{
			id = "emblema",
			name = "Emblema", -- a aguia (AGN) ou o leao (LES)
			emblem = true,
		},
		-- Frases: a cor da equipa, e a frase por cima em letras gigantes.
		{
			id = "frase_aqui",
			name = "Aqui mandamos nos",
			message = "AQUI MANDAMOS NÓS",
			rows = {
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
			},
		},
		{
			id = "frase_pesadelo",
			name = "O vosso pesadelo chegou",
			message = "O VOSSO PESADELO CHEGOU",
			rows = {
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
			},
		},
		{
			id = "frase_sempre",
			name = "Sempre contigo",
			message = "SEMPRE CONTIGO",
			rows = {
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
			},
		},
		{
			id = "frase_fim",
			name = "Ate ao fim",
			message = "ATÉ AO FIM",
			rows = {
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
			},
		},
		{
			id = "frase_equipa",
			name = "Nome da claque",
			message = "%TEAM%",
			rows = {
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
			},
		},
		{
			id = "frase_ultras",
			name = "Ultras",
			message = "ULTRAS",
			rows = {
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
			},
		},
	},
}

return Config
