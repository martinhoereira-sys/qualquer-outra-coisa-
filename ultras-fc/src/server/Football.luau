--!strict
--[[
	A bola e as regras.

	A bola e fisica normal do Roblox: chuta-se dando-lhe uma velocidade, e ela
	rola, salta e bate nos postes sozinha. So ha duas ajudas por cima disso — um
	travao leve, para rolar e parar sempre da mesma maneira, e, com a posse, a
	bola vai colada a frente dos pes. E o mais previsivel, e e o que se usa nos
	jogos de futebol do Roblox.

	Posse, roubo, golo, bola fora e pontape de saida vivem aqui. O servidor e
	que decide tudo: o cliente so diz "chutei com esta forca".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Budget = require(script.Parent:WaitForChild("Budget"))
local Squad = require(script.Parent:WaitForChild("Squad"))

type Footballer = Squad.Footballer

local Football = {}

local F = Config.Football
local S = Config.Stadium
local HALF = S.pitchLength / 2
local WIDTH2 = S.pitchWidth / 2
local R = F.ballSize / 2
local BOX_DEPTH = S.pitchLength * 16.5 / 105
local BOX_WIDTH = S.pitchWidth * 40.3 / 68

local ball: Part? = nil

--[[
	Uma reposicao: lancamento, canto, pontape de baliza, livre, penalti. Todas
	iguais por dentro — a bola num ponto, uma equipa a repor, uma zona onde os
	adversarios nao entram e um tempo maximo.
]]
export type SetPiece = {
	kind: string, -- "lancamento" | "canto" | "baliza" | "livre" | "penalti"
	team: string, -- quem repoe
	spot: Vector3,
	aim: Vector3, -- para onde quem bate fica virado
	deadline: number,
	taker: Footballer?,
	takenAt: number, -- quando quem bate chegou a bola
}

--[[
	A festa de um golo: quem marcou corre para a sua claque, os colegas vao
	atras, e so no fim ha pontape de saida.
]]
export type Celebration = {
	team: string,
	scorer: Footballer?,
	spot: Vector3, -- onde quem marcou vai festejar, a frente da sua claque
	endsAt: number,
}

local state = {
	carrier = nil :: Footballer?,
	lastTouch = nil :: string?, -- equipa do ultimo toque, para a bola fora
	lastToucher = nil :: Footballer?, -- quem lhe tocou por ultimo, para saber quem marcou
	celebration = nil :: Celebration?, -- os segundos de festa depois de um golo
	noClaim = {} :: { [Footballer]: number },
	priorityTeam = nil :: string?,
	priorityUntil = 0,
	live = false, -- os golos contam
	botsPlay = false,
	waitUntil = 0, -- bola na rede, ou fora, a espera de recomecar
	afterWait = nil :: (() -> ())?,
	releaseAt = 0, -- fim da espera do pontape de saida
	kickingTeam = nil :: string?,
	flightUntil = 0, -- acabada de chutar, ainda ninguem lhe pode tocar
	curve = 0, -- desvio lateral do efeito, em studs/s2 (positivo: para a direita de quem chutou)
	curveUntil = 0,
	halted = false, -- apito: tudo parado a espera do arbitro
	haltedAt = 0,
	haltedFoul = nil :: Foul?,
	piece = nil :: SetPiece?, -- a reposicao a espera de ser batida
	liveTime = 0, -- segundos de bola viva e parada nas partes, para medir o ritmo
	deadTime = 0,
	lastFoulAt = -math.huge, -- a ultima entrada que foi falta (os.clock)
	steals = 0, -- roubos e faltas nas partes, para o Output dizer o ritmo
	fouls = 0,
	reportedAt = 0, -- minuto de bola viva do ultimo relatorio
	heldBy = nil :: Footballer?, -- o guarda-redes com a bola nas maos
	heldUntil = 0, -- ate quando a pode segurar
}

local onGoal: ((string, Footballer?) -> ())? = nil

-- Um golo que conta: de que equipa, e quem o marcou (se se souber).
--[[
	O que se passou com a bola, para o XP (Progress): "steal" (roubou a bola
	a um adversario) e "save" (o guarda-redes agarrou um remate).
]]
local onEvent: ((string, Footballer) -> ())? = nil
function Football.onEvent(fn: (string, Footballer) -> ())
	onEvent = fn
end
local function emit(kind: string, f: Footballer)
	if onEvent then
		task.spawn(onEvent :: (string, Footballer) -> (), kind, f)
	end
end

-- O ultimo chuto (para as defesas e as assistencias) e o ultimo passe recebido.
local lastKick: { f: Footballer, at: number }? = nil
local passFrom: { from: Footballer, to: Footballer, at: number }? = nil

-- Quem fez a assistencia para o golo de `scorer`: o colega que lhe passou a
-- bola, se foi ha pouco (Config.Progress.jogador.assistWindow).
function Football.assistFor(scorer: Footballer): Footballer?
	local pass = passFrom
	if pass and pass.to == scorer and os.clock() - pass.at <= Config.Progress.jogador.assistWindow then
		return pass.from
	end
	return nil
end

function Football.onGoal(fn: (string, Footballer?) -> ())
	onGoal = fn
end

local onCelebrationEnd: ((string) -> ())? = nil

-- Acabou a festa do golo, e vai haver pontape de saida.
function Football.onCelebrationEnd(fn: (string) -> ())
	onCelebrationEnd = fn
end

local onKick: ((Vector3) -> ())? = nil

-- Alguem chutou a bola (para o som do pontape).
function Football.onKick(fn: (Vector3) -> ())
	onKick = fn
end

local onKickoffWhistle: (() -> ())? = nil

-- O apito do pontape de saida, no fim da espera.
function Football.onKickoffWhistle(fn: () -> ())
	onKickoffWhistle = fn
end

--[[
	Uma entrada que pode ser falta, como o servidor a viu. O jogo nao para: o
	arbitro apita ou nao apita (Whistle e Referee). Aqui so se sabe o que
	aconteceu, e onde.
]]
export type Foul = {
	fouled: Footballer, -- quem tinha a bola
	fouler: Footballer, -- quem entrou
	at: Vector3,
	fromBehind: boolean,
	inBox: boolean, -- na area que a equipa de quem sofreu ataca
	nearLine: boolean, -- tao perto da linha da area que fica em duvida
	card: string, -- "nada" | "amarelo" | "vermelho": o que o arbitro automatico mostra
}

local onFoul: ((Foul) -> ())? = nil

function Football.onFoul(fn: (Foul) -> ())
	onFoul = fn
end

--------------------------------------------------------------------------------
-- Construcao
--------------------------------------------------------------------------------

local function wall(name: string, size: Vector3, at: Vector3, parent: Instance)
	Budget.take("Jogo")
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(at)
	p.Anchored = true
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	p.CollisionGroup = "BallWall"
	p.Parent = parent
end

function Football.build(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Match"
	folder.Parent = parent

	-- A bola nunca vai parar a bancada: paredes que so ela sente, uns metros
	-- fora das linhas, e um tecto.
	local endX = HALF + F.goalDepth + 1.5
	local sideZ = WIDTH2 + 4
	for _, sign in { 1, -1 } do
		wall("BallWallX", Vector3.new(2, 80, sideZ * 2 + 4), Vector3.new(sign * (endX + 1), 40, 0), folder)
		wall("BallWallZ", Vector3.new(endX * 2 + 4, 80, 2), Vector3.new(0, 40, sign * (sideZ + 1)), folder)
	end
	wall("BallCeiling", Vector3.new(endX * 2 + 4, 2, sideZ * 2 + 4), Vector3.new(0, 70, 0), folder)

	Budget.take("Jogo")
	local b = Instance.new("Part")
	b.Name = "Ball"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(F.ballSize, F.ballSize, F.ballSize)
	b.Color = Color3.fromRGB(248, 248, 248)
	b.Material = Enum.Material.SmoothPlastic
	b.CustomPhysicalProperties = PhysicalProperties.new(0.35, 0.25, 0.5, 1, 1)
	b.CollisionGroup = "Ball"
	b.CFrame = CFrame.new(0, R + 0.05, 0)
	b.Parent = folder
	b:SetNetworkOwner(nil)
	ball = b
end

--------------------------------------------------------------------------------
-- Consultas (para os bonecos e para o ecra)
--------------------------------------------------------------------------------

function Football.ballPosition(): Vector3
	local b = ball
	return if b then b.Position else Vector3.zero
end

function Football.ballVelocity(): Vector3
	local b = ball
	return if b then b.AssemblyLinearVelocity else Vector3.zero
end

function Football.carrier(): Footballer?
	return state.carrier
end

function Football.botsPlay(): boolean
	return state.botsPlay
end

-- A baliza que esta equipa ataca.
function Football.goalFor(teamId: string): Vector3
	return Vector3.new(Squad.attackSign(teamId) * HALF, 0, 0)
end

--------------------------------------------------------------------------------
-- Chutar
--------------------------------------------------------------------------------

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.xAxis
end

local function release(f: Footballer, direction: Vector3, speed: number, lift: number, inPlace: boolean?)
	local b = ball
	local root = f.root
	if not b or not root then
		return
	end
	local dir = flat(direction)
	state.carrier = nil
	state.lastTouch = f.teamId
	state.lastToucher = f
	lastKick = { f = f, at = os.clock() }
	state.noClaim[f] = os.clock() + F.kickLockout
	-- Ninguem lhe toca no primeiro instante: sem isto, quem estava colado a
	-- quem chutou ficava com a bola antes de ela sair dos pes.
	state.flightUntil = os.clock() + F.kickFlight
	state.curve = 0
	-- Batida a reposicao, o jogo segue.
	if state.piece then
		state.piece = nil
		workspace:SetAttribute("Restart", nil)
	end

	-- De primeira, a bola sai de onde vinha; conduzida, sai dos pes.
	if not inPlace then
		local from = root.Position
		b.CFrame = CFrame.new(from.X + dir.X * F.dribbleDistance, R + 0.1, from.Z + dir.Z * F.dribbleDistance)
	end
	b.AssemblyAngularVelocity = Vector3.zero
	b.AssemblyLinearVelocity = dir * speed + Vector3.new(0, lift, 0)
	if onKick then
		onKick(b.Position)
	end
end

-- Um colega a frente, dentro do cone, para onde um chuto fraco se desvia.
local function mateInCone(f: Footballer, dir: Vector3): Footballer?
	local root = f.root :: BasePart
	local cosCone = math.cos(math.rad(F.passCone))
	local best: Footballer? = nil
	local bestScore = -math.huge
	for _, mate in Squad.team(f.teamId) do
		local other = mate.root
		if mate ~= f and other then
			local delta = Vector3.new(other.Position.X - root.Position.X, 0, other.Position.Z - root.Position.Z)
			local distance = delta.Magnitude
			if distance > 4 and distance <= F.passRange then
				local alignment = delta.Unit:Dot(dir)
				if alignment >= cosCone then
					-- Mais alinhado vale mais do que mais perto.
					local score = alignment * 2 - distance / F.passRange
					if score > bestScore then
						bestScore = score
						best = mate
					end
				end
			end
		end
	end
	return best
end

--[[
	Chutar. E o unico gesto com a bola: um toque e um passe, tudo e um remate.

	`power` e 0 a 1, a barra de forca. `curve` e -1 a 1, o efeito: a bola
	desvia-se para esse lado enquanto vai no ar. `height` e -1 a 1: para baixo
	sai rasteira, parada sai com um pouco de altura, para cima e um chapeu.
]]
--[[
	De primeira: sem a ter, chuta-se uma bola solta que passa ao alcance dos
	pes (um pouco mais longe do que para a agarrar, porque a perna estica).
	Nao durante uma reposicao, nem logo a seguir ao proprio chuto.
]]
local FIRST_TIME_REACH = 2.4
local function canStrikeLoose(f: Footballer, root: BasePart): boolean
	local b = ball
	local now = os.clock()
	if not b or state.carrier ~= nil or state.piece or state.halted or not state.live then
		return false
	end
	if Squad.isDown(f, now) or (state.noClaim[f] or 0) > now then
		return false
	end
	local feet = root.Position.Y - 3
	local flatDistance = Vector3.new(b.Position.X - root.Position.X, 0, b.Position.Z - root.Position.Z).Magnitude
	return flatDistance <= F.claimRange + FIRST_TIME_REACH and b.Position.Y - feet <= F.claimHeight + 1
end

function Football.kick(f: Footballer, power: number, curve: number, height: number, direction: Vector3?): boolean
	local root = f.root
	if not root then
		return false
	end
	local firstTime = false
	if state.carrier ~= f then
		if not canStrikeLoose(f, root) then
			return false
		end
		firstTime = true
	end
	local p = math.clamp(power, 0, 1)
	local c = math.clamp(curve, -1, 1)
	local h = math.clamp(height, -1, 1)
	local dir = flat(direction or root.CFrame.LookVector)

	if p <= F.passAssistPower then
		local mate = mateInCone(f, dir)
		if mate then
			local other = mate.root :: BasePart
			local aim = other.Position + Vector3.new(other.AssemblyLinearVelocity.X, 0, other.AssemblyLinearVelocity.Z) * 0.35
			dir = flat(aim - root.Position)
		end
	end

	local speed = F.kickSpeedMin + (F.kickSpeedMax - F.kickSpeedMin) * p
	local liftFraction = if h < 0 then F.liftNeutral * (1 + h) else F.liftNeutral + (F.liftMax - F.liftNeutral) * h
	release(f, dir, speed, speed * liftFraction, firstTime)
	state.curve = c * F.curveAccel
	state.curveUntil = os.clock() + F.curveTime
	return true
end

-- Os bonecos rematam sem efeito, com a altura de um remate normal.
function Football.shoot(f: Footballer, power: number, direction: Vector3?): boolean
	return Football.kick(f, power, 0, 0, direction)
end

local function passSpeed(distance: number): number
	return math.clamp(18 + distance * 0.75, F.passSpeedMin, F.passSpeedMax)
end

function Football.passTo(f: Footballer, target: Footballer): boolean
	local root = f.root
	local other = target.root
	if state.carrier ~= f or not root or not other then
		return false
	end
	-- Um pouco a frente de quem recebe, para nao lhe chegar aos calcanhares.
	local aim = other.Position + Vector3.new(other.AssemblyLinearVelocity.X, 0, other.AssemblyLinearVelocity.Z) * 0.35
	local delta = aim - root.Position
	release(f, delta, passSpeed(Vector3.new(delta.X, 0, delta.Z).Magnitude), 0)
	return true
end

--------------------------------------------------------------------------------
-- Recomecos
--------------------------------------------------------------------------------

-- Fim da festa do golo: bracos em baixo, e a bancada volta ao normal.
local function endCelebration()
	local party = state.celebration
	if not party then
		return
	end
	state.celebration = nil
	workspace:SetAttribute("Celebration", nil)
	for _, f in Squad.team(party.team) do
		Squad.openArms(f, false)
	end
	if onCelebrationEnd then
		onCelebrationEnd(party.team)
	end
end

local function placeBall(at: Vector3)
	local b = ball
	if not b then
		return
	end
	b.CFrame = CFrame.new(at.X, R + 0.1, at.Z)
	state.curve = 0
	b.AssemblyLinearVelocity = Vector3.zero
	b.AssemblyAngularVelocity = Vector3.zero
end

local function giveTo(teamId: string?, seconds: number)
	state.priorityTeam = teamId
	state.priorityUntil = os.clock() + seconds
end

local function otherTeam(teamId: string): string
	for _, id in Config.TeamOrder do
		if id ~= teamId then
			return id
		end
	end
	return teamId
end

--[[
	Pontape de saida: toda a gente ao seu lugar, bola ao centro, dois segundos
	parados e apito. Sai quem esta a comecar a parte, ou quem sofreu o golo.
]]
function Football.kickOff(teamId: string)
	state.carrier = nil
	state.piece = nil
	workspace:SetAttribute("Restart", nil)
	state.afterWait = nil
	state.waitUntil = 0
	table.clear(state.noClaim)
	placeBall(Vector3.zero)
	Squad.placeForKickoff(teamId)
	Squad.setFrozen(true)
	state.kickingTeam = teamId
	state.releaseAt = os.clock() + F.kickoffFreeze
	workspace:SetAttribute("KickoffAt", workspace:GetServerTimeNow() + F.kickoffFreeze)
	workspace:SetAttribute("KickoffTeam", teamId)
end

--[[
	A fase do jogo. So nas partes os golos contam; no aquecimento joga-se na
	mesma, que e o que se faz antes de um jogo; no intervalo e no fim os
	bonecos voltam ao lugar e a bola fica no centro.
]]
function Football.setPhase(phase: string)
	state.live = phase == "first" or phase == "second"
	local wasPlaying = state.botsPlay
	state.botsPlay = state.live or phase == "clubhouse" or phase == "corteo"
	if not state.botsPlay and wasPlaying then
		endCelebration()
		state.carrier = nil
		state.piece = nil
		state.halted = false
		Squad.setFrozen(false)
		workspace:SetAttribute("Halted", nil)
		state.waitUntil = 0
		state.afterWait = nil
		workspace:SetAttribute("Restart", nil)
		placeBall(Vector3.zero)
	end
end

local function hold(seconds: number, after: () -> ())
	state.waitUntil = os.clock() + seconds
	state.afterWait = after
end

function Football.celebration(): Celebration?
	return state.celebration
end

-- Enquanto houver festa, a parte nao acaba (o MatchLoop espera por isto).
function Football.celebrating(): boolean
	return state.celebration ~= nil
end

--[[
	Quem festeja: quem lhe tocou por ultimo, se for da equipa que marcou. Num
	autogolo, o da equipa que marcou que estiver mais perto da bola.
]]
local function scorerFor(teamId: string, at: Vector3): Footballer?
	local last = state.lastToucher
	if last and last.teamId == teamId and last.root and not last.sentOff then
		return last
	end
	local best: Footballer? = nil
	local bestDistance = math.huge
	for _, f in Squad.team(teamId) do
		local root = f.root
		if root then
			local d = (root.Position - at).Magnitude
			if d < bestDistance then
				best, bestDistance = f, d
			end
		end
	end
	return best
end

--[[
	Golo: a bola inteira passou a linha, entre os postes e por baixo da trave.
	Marca sempre quem ataca aquela baliza, seja quem for que lhe tocou por
	ultimo — um autogolo e golo na mesma.
]]
-- A bola tem de estar bem dentro da baliza, e nao so a passar a linha: o
-- servidor ve-a um pouco a frente do ecra de cada um, e o golo aparecia antes
-- de ela entrar a vista.
local GOAL_MARGIN = 1.6
local function checkGoal(p: Vector3): boolean
	if math.abs(p.X) < HALF + R + GOAL_MARGIN or math.abs(p.Z) > F.goalHalfWidth or p.Y > F.goalHeight then
		return false
	end
	local side = if p.X > 0 then 1 else -1
	local scorer = Config.TeamOrder[1]
	for _, teamId in Config.TeamOrder do
		if Squad.attackSign(teamId) == side then
			scorer = teamId
		end
	end

	state.carrier = nil
	if not state.live then
		-- Na sede e no corteo joga-se a brincar: a bola volta ao centro e pronto.
		hold(F.goalPause, function()
			placeBall(Vector3.zero)
		end)
		return true
	end

	--[[
		Golo a serio: quinze segundos de festa antes do pontape de saida. Quem
		marcou corre de bracos abertos para a sua claque, que fica atras da
		baliza onde marcou; os colegas vao atras.
	]]
	local who = scorerFor(scorer, p)
	local length = Config.Match.celebrationLength
	state.celebration = {
		team = scorer,
		scorer = who,
		spot = Vector3.new(side * (HALF - 4), 0, if p.Z >= 0 then 12 else -12),
		endsAt = os.clock() + length,
	}
	workspace:SetAttribute("Celebration", scorer)
	if who then
		Squad.openArms(who, true)
	end
	hold(length, function()
		endCelebration()
		Football.kickOff(otherTeam(scorer))
	end)
	if onGoal then
		onGoal(scorer, who)
	end
	return true
end

-- Ha alguma pessoa a jogar por esta equipa? Com pessoas e bonecos misturados,
-- as reposicoes sao das pessoas.
local function teamHasHuman(teamId: string): boolean
	for _, f in Squad.team(teamId) do
		if f.player and not f.sentOff then
			return true
		end
	end
	return false
end

-- O nome de quem bate, como aparece no ecra.
local function takerName(f: Footballer): string
	local player = f.player
	return if player then player.DisplayName else Squad.label(f)
end

--[[
	Uma reposicao comeca: bola no ponto, e quem vai bater ja atras dela,
	virado para onde vai jogar, sem ter de la ir a correr. E so esse que se
	mexe: os outros ficam onde estao, e a marca no chao mostra aos adversarios
	onde nao podem estar.

	Bate qualquer um da equipa que repoe. Com pessoas e bonecos misturados, so
	as pessoas batem — a mais perto, ou quem sofreu o penalti se for pessoa.
	Uma pessoa tem mais uns segundos, que apontar e dosear leva tempo.
]]
function Football.startSetPiece(kind: string, team: string, spot: Vector3, aim: Vector3, seconds: number, preferred: Footballer?)
	state.carrier = nil
	placeBall(spot)
	local piece: SetPiece = {
		kind = kind,
		team = team,
		spot = Vector3.new(spot.X, 0, spot.Z),
		aim = flat(aim),
		deadline = 0,
		taker = nil,
		takenAt = 0,
	}
	state.piece = piece

	local now = os.clock()
	local nearestHuman: Footballer? = nil
	local nearestBot: Footballer? = nil
	local humanDistance, botDistance = math.huge, math.huge
	for _, f in Squad.team(team) do
		local root = f.root
		if root and not f.sentOff and not Squad.isDown(f, now) then
			local d = Vector3.new(root.Position.X - spot.X, 0, root.Position.Z - spot.Z).Magnitude
			if f.player then
				if d < humanDistance then
					humanDistance = d
					nearestHuman = f
				end
			elseif d < botDistance then
				botDistance = d
				nearestBot = f
			end
		end
	end

	local chosen: Footballer? = nil
	local usable = preferred and preferred.root and not preferred.sentOff
	if usable and preferred and (preferred.player or not nearestHuman) then
		chosen = preferred
	elseif nearestHuman then
		chosen = nearestHuman
	else
		chosen = nearestBot
	end

	if chosen and chosen.player then
		local foul = kind == "livre" or kind == "penalti"
		seconds = math.max(seconds, if foul then Config.Rules.freeKickTime else Config.Rules.humanRestartTime)
	end
	piece.deadline = now + seconds
	workspace:SetAttribute("Restart", kind .. ":" .. team)
	workspace:SetAttribute("RestartUntil", workspace:GetServerTimeNow() + seconds)
	workspace:SetAttribute("RestartTaker", if chosen then takerName(chosen) else nil)

	if chosen then
		Squad.place(chosen, piece.spot - piece.aim * F.dribbleDistance, piece.aim)
		piece.taker = chosen
		piece.takenAt = now
		state.carrier = chosen
		state.lastTouch = team
	end
end

--[[
	O relogio do jogo esta parado? Desde o apito de uma falta ate o livre (ou
	o penalti) ser batido: quem ganha nao ganha nada a demorar.
]]
function Football.clockStopped(): boolean
	if state.halted then
		return true
	end
	local piece = state.piece
	return piece ~= nil and (piece.kind == "livre" or piece.kind == "penalti")
end

function Football.setPiece(): SetPiece?
	return state.piece
end

--[[
	Bola fora. Quem repoe decide-se sempre pelo ultimo a tocar:

	- pela linha lateral, lancamento para a outra equipa, no ponto onde saiu;
	- pela linha de fundo, se o ultimo toque foi de quem defende essa baliza,
	  canto para quem ataca; se foi de quem ataca, pontape de baliza.
]]
local SMALL_BOX_DEPTH = S.pitchLength * 5.5 / 105
local PENALTY_MARK = S.pitchLength * 11 / 105

local function checkOut(p: Vector3): boolean
	local last = state.lastTouch
	local kind, team, spot, aim

	if math.abs(p.Z) > WIDTH2 + R then
		kind = "lancamento"
		team = if last then otherTeam(last) else Config.TeamOrder[1]
		local side = math.sign(p.Z)
		spot = Vector3.new(math.clamp(p.X, -HALF + 3, HALF - 3), 0, side * (WIDTH2 - 1.2))
		aim = Vector3.new(0, 0, -side)
	elseif math.abs(p.X) > HALF + R then
		local side = if p.X > 0 then 1 else -1
		local attackers = Config.TeamOrder[1]
		for _, teamId in Config.TeamOrder do
			if Squad.attackSign(teamId) == side then
				attackers = teamId
			end
		end
		local defenders = otherTeam(attackers)
		if last == defenders then
			kind = "canto"
			team = attackers
			spot = Vector3.new(side * (HALF - 1.2), 0, math.sign(p.Z) * (WIDTH2 - 1.2))
			aim = Vector3.new(side * (HALF - 22), 0, 0) - spot
		else
			kind = "baliza"
			team = defenders
			spot = Vector3.new(side * (HALF - SMALL_BOX_DEPTH), 0, 0)
			aim = Vector3.new(-side, 0, 0)
		end
	else
		return false
	end

	state.carrier = nil
	hold(Config.Rules.outDelay, function()
		Football.startSetPiece(kind, team, spot, aim, Config.Rules.restartTime)
	end)
	return true
end

--------------------------------------------------------------------------------
-- Posse e roubo
--------------------------------------------------------------------------------

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function canPlay(f: Footballer, now: number): boolean
	if Squad.isDown(f, now) then
		return false
	end
	if (state.noClaim[f] or 0) > now then
		return false
	end
	if state.priorityTeam and now < state.priorityUntil and f.teamId ~= state.priorityTeam then
		return false
	end
	-- Numa reposicao so toca na bola quem repoe.
	local piece = state.piece
	if piece and f.teamId ~= piece.team then
		return false
	end
	-- Com pessoas na equipa, e uma delas que repoe: os bonecos nao lhe tiram a bola.
	if piece and not f.player and teamHasHuman(piece.team) then
		return false
	end
	-- Fora do aquecimento e das partes, os bonecos nao jogam.
	if not state.botsPlay and not f.player then
		return false
	end
	return true
end

-- Na area que este jogador defende: a do seu guarda-redes.
local function inOwnBox(f: Footballer, at: Vector3): boolean
	local side = -Squad.attackSign(f.teamId)
	return at.X * side > HALF - BOX_DEPTH and math.abs(at.Z) < BOX_WIDTH / 2
end

--[[
	Ate onde chega cada um. O guarda-redes, dentro da sua area, chega mais
	longe e mais alto — e a atirar-se, mais ainda. Fora dela e um jogador como
	os outros.
]]
local function reachFor(f: Footballer, at: Vector3, now: number): (number, number)
	if f.keeper and inOwnBox(f, at) then
		return if now < f.diveUntil then F.keeperDiveReach else F.keeperReach, F.keeperHeight
	end
	return F.claimRange, F.claimHeight
end

local function claim(b: BasePart, now: number)
	local best: Footballer? = nil
	local bestDistance = math.huge
	for _, f in Squad.active() do
		local root = f.root :: BasePart
		local reach, height = reachFor(f, b.Position, now)
		local d = horizontal(root.Position, b.Position)
		if d <= reach and d < bestDistance and b.Position.Y - R <= height and canPlay(f, now) then
			bestDistance = d
			best = f
		end
	end
	if not best then
		return
	end

	-- O guarda-redes na sua area agarra-a com as maos. O boneco so agarra
	-- parte dos remates fortes: os outros passam-lhe, e quer-se golos.
	local keeperCatch = best.keeper and inOwnBox(best, b.Position)
	if keeperCatch and not best.player and b.AssemblyLinearVelocity.Magnitude > F.fastShot then
		if math.random() >= F.botKeeperSave then
			state.noClaim[best] = now + 0.8
			return
		end
	end

	state.curve = 0
	-- Um instante para a dominar: sem isto, apanhar a bola ao lado de um
	-- adversario era perde-la no mesmo frame.
	best.immuneUntil = math.max(best.immuneUntil, now + F.claimImmunity)
	state.carrier = best
	state.lastTouch = best.teamId
	state.lastToucher = best
	-- Passe (de um colega) ou defesa (o guarda-redes agarra um remate do outro lado).
	local kick = lastKick
	lastKick = nil
	if kick and now - kick.at <= Config.Progress.jogador.assistWindow then
		if kick.f.teamId == best.teamId and kick.f ~= best then
			passFrom = { from = kick.f, to = best, at = now }
		elseif kick.f.teamId ~= best.teamId and keeperCatch and state.live and now - kick.at <= 2.5 then
			emit("save", best)
		end
	end
	if keeperCatch then
		state.heldBy = best
		state.heldUntil = now + F.keeperHoldTime
		best.diveUntil = 0
		workspace:SetAttribute("HeldUntil", workspace:GetServerTimeNow() + F.keeperHoldTime)
		workspace:SetAttribute("HeldTeam", best.teamId)
	end
	local piece = state.piece
	if piece and piece.taker ~= best then
		piece.taker = best
		piece.takenAt = now
		workspace:SetAttribute("RestartTaker", takerName(best))
	end
end

--[[
	O guarda-redes atira-se para o lado da bola. Chega mais longe durante o
	voo; se nao a apanhar, fica no chao um segundo. Numa pessoa o impulso e
	dado no proprio ecra (o corpo e dela); aqui so se regista o mergulho.
]]
function Football.dive(f: Footballer): boolean
	local root = f.root
	local now = os.clock()
	if not f.keeper or not root or Squad.isDown(f, now) or now < f.diveReadyAt then
		return false
	end
	if state.heldBy == f then
		return false
	end
	f.diveUntil = now + F.keeperDiveTime
	f.diveReadyAt = now + F.keeperDiveCooldown
	if not f.player then
		local toBall = flat(Football.ballPosition() - root.Position)
		root.AssemblyLinearVelocity = toBall * F.keeperDiveSpeed + Vector3.new(0, 10, 0)
	end
	local model = f.model
	if f.player then
		-- Numa pessoa, a queda de lado e o levantar ja os faz o ecra dela; aqui so
		-- fica no chao (sem chutar) ate se levantar. So depois do voo: durante
		-- ele ainda pode agarrar a bola.
		local AIR = 0.45
		-- Os bracos esticados, em todos os ecras (Poses.client).
		local who = f.player
		who:SetAttribute("Diving", true)
		task.delay(F.keeperDiveTime, function()
			if who.Parent then
				who:SetAttribute("Diving", nil)
			end
		end)
		task.delay(AIR, function()
			if f.model == model and state.carrier ~= f then
				f.downUntil = os.clock() + F.keeperDiveTime - AIR
			end
		end)
		return true
	end
	task.delay(F.keeperDiveTime, function()
		if f.model == model and state.carrier ~= f then
			Squad.fall(f, os.clock())
		end
	end)
	return true
end

local RULES = Config.Rules

-- Na area que esta equipa ataca, e se esta tao perto da linha que fica em duvida.
local function boxCheck(teamId: string, at: Vector3): (boolean, boolean)
	local side = Squad.attackSign(teamId)
	local depthInside = at.X * side - (HALF - BOX_DEPTH) -- positivo: para dentro da linha da area
	local widthInside = BOX_WIDTH / 2 - math.abs(at.Z)
	local inside = depthInside > 0 and widthInside > 0
	local toLine
	if inside then
		toLine = math.min(depthInside, widthInside)
	elseif depthInside > 0 then
		toLine = -widthInside
	elseif widthInside > 0 then
		toLine = -depthInside
	else
		toLine = math.huge
	end
	return inside, toLine <= RULES.boxLineMargin
end

--[[
	Foi falta? Decide-se no momento do roubo. Por tras e muito mais provavel do
	que de frente: e o que um arbitro ve de longe. Sendo, o jogo para ja — tudo
	quieto, bola no sitio — e quem decide o resto e o arbitro.
]]
local function checkFoul(fouled: Footballer, fouler: Footballer, at: Vector3, look: Vector3, from: Vector3)
	local toTackler = Vector3.new(from.X - at.X, 0, from.Z - at.Z)
	local facing = Vector3.new(look.X, 0, look.Z)
	local behind = toTackler.Magnitude > 0.1 and facing.Magnitude > 0.1
		and toTackler.Unit:Dot(facing.Unit) < RULES.behindDot
	state.steals += 1
	local chance = if behind then RULES.foulBehind else RULES.foulFront
	-- Depois de uma falta ha um intervalo sem nenhuma: o jogo tem de correr.
	if os.clock() - state.lastFoulAt < RULES.foulGap or math.random() >= chance then
		return
	end
	state.lastFoulAt = os.clock()
	state.fouls += 1

	local card = "nada"
	local roll = math.random()
	if behind then
		if roll < RULES.redBehind then
			card = "vermelho"
		elseif roll < RULES.redBehind + RULES.yellowBehind then
			card = "amarelo"
		end
	elseif roll < RULES.yellowFront then
		card = "amarelo"
	end

	local inBox, nearLine = boxCheck(fouled.teamId, at)
	local foul: Foul = {
		fouled = fouled,
		fouler = fouler,
		at = Vector3.new(at.X, 0, at.Z),
		fromBehind = behind,
		inBox = inBox,
		nearLine = nearLine,
		card = card,
	}
	-- O jogo segue. Quem decide se houve falta e o apito, nos proximos segundos.
	if onFoul then
		onFoul(foul)
	end
end

--[[
	Apito: o jogo para aqui, e a bola volta ao sitio da entrada, que e onde a
	falta se marca. Fica tudo parado ate o arbitro escolher o cartao.
]]
function Football.whistleFoul(foul: Foul): boolean
	-- Sem jogo a contar, ou com um golo a festejar, ja nao ha falta a marcar.
	if not state.live or state.celebration then
		return false
	end
	state.carrier = nil
	state.piece = nil
	workspace:SetAttribute("Restart", nil)
	state.waitUntil = 0
	state.afterWait = nil
	state.halted = true
	state.haltedAt = os.clock()
	state.haltedFoul = foul
	Squad.setFrozen(true)
	workspace:SetAttribute("Halted", true)
	placeBall(foul.at)
	return true
end

--[[
	Depois do apito, com o cartao escolhido: `action` e "livre" ou "penalti".

	Livre: no sitio da falta, para quem a sofreu. Penalti: na marca, e bate
	quem sofreu.
]]
function Football.resume(action: string, foul: Foul)
	if not state.halted then
		return
	end
	state.halted = false
	state.haltedFoul = nil
	Squad.setFrozen(false)
	workspace:SetAttribute("Halted", nil)

	local team = foul.fouled.teamId
	local goal = Football.goalFor(team)
	if action == "penalti" then
		local side = Squad.attackSign(team)
		local mark = Vector3.new(side * (HALF - PENALTY_MARK), 0, 0)
		Football.startSetPiece("penalti", team, mark, goal - mark, RULES.penaltyTime, foul.fouled)
	else
		-- Um livre na duvida da linha da area fica fora dela.
		local at = foul.at
		local inside, _ = boxCheck(team, at)
		if inside then
			local side = Squad.attackSign(team)
			at = Vector3.new(side * (HALF - BOX_DEPTH - 1.5), 0, at.Z)
		end
		Football.startSetPiece("livre", team, at, goal - at, RULES.restartTime)
	end
end

--[[
	O penalti que ninguem bateu a tempo sai sozinho: meia forca, para um canto
	ao calhas. Tambem pode falhar.
]]
local function autoPenalty(piece: SetPiece)
	local b = ball
	if not b then
		return
	end
	local goal = Football.goalFor(piece.team)
	local target = goal + Vector3.new(0, 0, (math.random() * 2 - 1) * (F.goalHalfWidth + 3))
	local dir = flat(target - piece.spot)
	local speed = F.kickSpeedMin + (F.kickSpeedMax - F.kickSpeedMin) * (0.5 + math.random() * 0.3)
	state.carrier = nil
	state.lastTouch = piece.team
	state.flightUntil = os.clock() + F.kickFlight
	state.curve = 0
	b.CFrame = CFrame.new(piece.spot.X, R + 0.1, piece.spot.Z)
	b.AssemblyLinearVelocity = dir * speed + Vector3.new(0, speed * F.liftNeutral, 0)
end

--[[
	Roubar: encostar a quem tem a bola chega. Quem a perdeu cai; quem a ganhou
	fica um segundo imune, senao a bola andava de pe em pe sem ninguem a jogar.
]]
local function tackle(carrier: Footballer, now: number): Footballer
	-- Com a bola nas maos do guarda-redes ninguem lha tira.
	if now < carrier.immuneUntil or state.heldBy == carrier then
		return carrier
	end
	local root = carrier.root :: BasePart
	for _, f in Squad.active() do
		if f.teamId ~= carrier.teamId and canPlay(f, now) then
			local other = (f.root :: BasePart).Position
			if horizontal(other, root.Position) <= F.tackleRange then
				Squad.fall(carrier, now)
				state.noClaim[carrier] = now + F.fallTime
				f.immuneUntil = now + F.tackleImmunity
				state.carrier = f
				state.lastTouch = f.teamId
				state.lastToucher = f
				lastKick = nil
				if state.live then
					emit("steal", f)
					checkFoul(carrier, f, root.Position, root.CFrame.LookVector, other)
				end
				return f
			end
		end
	end
	return carrier
end

--------------------------------------------------------------------------------

local function clearPiece()
	state.piece = nil
	workspace:SetAttribute("Restart", nil)
end

--[[
	O ritmo: quantos segundos a bola esteve viva e quantos esteve parada, nas
	partes. Parada e tudo o que nao e jogo — golo, bola fora, reposicao a
	espera, pontape de saida, lance no arbitro.
]]
local function measure(dt: number)
	if not state.live then
		return
	end
	local stopped = state.waitUntil > 0 or state.releaseAt > 0 or state.piece ~= nil or Squad.isFrozen()
	if stopped then
		state.deadTime += dt
	else
		state.liveTime += dt
	end
	workspace:SetAttribute("LiveTime", math.floor(state.liveTime))
	workspace:SetAttribute("DeadTime", math.floor(state.deadTime))

	-- A cada minuto de jogo, o ritmo no Output: para afinar as faltas a olho.
	local minutes = (state.liveTime + state.deadTime) / 60
	if minutes - state.reportedAt >= 1 then
		state.reportedAt = math.floor(minutes)
		print(string.format(
			"[Ultras FC] %d min: %.1f roubos/min, %.1f faltas/min, bola viva %d%%",
			state.reportedAt,
			state.steals / minutes,
			state.fouls / minutes,
			math.floor(100 * state.liveTime / math.max(state.liveTime + state.deadTime, 1))
		))
	end
end

function Football.resetClock()
	state.liveTime = 0
	state.deadTime = 0
	state.steals = 0
	state.fouls = 0
	state.reportedAt = 0
end

--[[
	A reposicao a vista de toda a gente, em dois segundos: a bola destacada
	atraves de quem estiver a frente, e no chao um circulo com a zona onde os
	adversarios nao podem estar. Os bonecos respeitam-no sozinhos; as pessoas
	veem-no.
]]
local RING_GAP: { [string]: number } = {
	lancamento = Config.Rules.throwInGap,
	canto = Config.Rules.cornerGap,
	livre = Config.Rules.freeKickGap,
	penalti = Config.Rules.freeKickGap,
}

local ring: Part? = nil
local glow: Highlight? = nil

local function syncMarks()
	local b = ball
	if not b then
		return
	end
	local piece = state.piece
	local gap = piece and RING_GAP[piece.kind]

	if not glow then
		local h = Instance.new("Highlight")
		h.Name = "Reposicao"
		h.FillColor = Color3.fromRGB(255, 214, 90)
		h.FillTransparency = 0.35
		h.OutlineColor = Color3.new(1, 1, 1)
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Enabled = false
		h.Parent = b
		glow = h
	end
	local h = glow :: Highlight
	h.Enabled = piece ~= nil

	if not ring then
		local p = Instance.new("Part")
		p.Name = "ZonaProibida"
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Transparency = 1
		p.Parent = b.Parent
		ring = p
	end
	local p = ring :: Part
	if piece and gap then
		-- Da cor de quem nao pode entrar: os adversarios de quem repoe.
		local other = if piece.team == Config.TeamOrder[1] then Config.TeamOrder[2] else Config.TeamOrder[1]
		p.Color = Config.Teams[other].color
		p.Size = Vector3.new(0.12, gap * 2, gap * 2)
		p.CFrame = CFrame.new(piece.spot.X, 0.08, piece.spot.Z) * CFrame.Angles(0, 0, math.rad(90))
		p.Transparency = 0.72
	elseif p.Transparency < 1 then
		p.Transparency = 1
	end
end

function Football.step(dt: number)
	syncMarks()
	local b = ball
	if not b then
		return
	end
	local now = os.clock()
	measure(dt)

	-- Apito: tudo parado, a bola onde estava, ate o arbitro decidir. Se a
	-- decisao nunca chegar (um erro algures), o jogo segue sozinho: parado
	-- para sempre e o pior que pode acontecer.
	if state.halted then
		b.AssemblyLinearVelocity = Vector3.zero
		local foul = state.haltedFoul
		-- Na duvida da linha ha duas escolhas seguidas: o sitio e o cartao.
		if foul and now - state.haltedAt > Config.Referee.cardSeconds * 2 + 4 then
			warn("[Football] o arbitro nao decidiu a falta; marca-se o livre")
			Football.resume(if foul.inBox then "penalti" else "livre", foul)
		end
		return
	end

	-- A espera do pontape de saida.
	if state.releaseAt > 0 then
		if now < state.releaseAt then
			return
		end
		state.releaseAt = 0
		Squad.setFrozen(false)
		giveTo(state.kickingTeam, F.restartPriority)
		if onKickoffWhistle then
			onKickoffWhistle()
		end
	end

	-- A bola caiu do mundo: volta ao centro.
	if b.Position.Y < -20 then
		placeBall(Vector3.zero)
	end

	if state.waitUntil > 0 then
		if now < state.waitUntil then
			return
		end
		state.waitUntil = 0
		local after = state.afterWait
		state.afterWait = nil
		if after then
			after()
		end
		return
	end

	--[[
		A reposicao a espera. Acabado o tempo sem ninguem bater, a bola fica
		viva ali mesmo: quem a tinha segue com ela, e se ninguem a tinha a
		equipa que repunha ainda leva meio segundo de avanco.
	]]
	local piece = state.piece
	if piece and now >= piece.deadline then
		local team = piece.team
		clearPiece()
		if piece.kind == "penalti" then
			autoPenalty(piece)
		elseif not state.carrier then
			giveTo(team, Config.Rules.restartEdge)
		end
		piece = nil
	end

	--[[
		A bola nas maos do guarda-redes. Sai das maos quando ele a joga, quando
		sai da area com ela (fora e um jogador normal, com a bola nos pes), ou
		quando passa o tempo: ai perde-a, a frente dele.
	]]
	local keeper = state.heldBy
	if keeper and (state.carrier ~= keeper or not keeper.root) then
		state.heldBy = nil
		workspace:SetAttribute("HeldUntil", nil)
	elseif keeper and keeper.root then
		local root = keeper.root :: BasePart
		if not inOwnBox(keeper, root.Position) then
			state.heldBy = nil
			workspace:SetAttribute("HeldUntil", nil)
		elseif now >= state.heldUntil then
			state.heldBy = nil
			workspace:SetAttribute("HeldUntil", nil)
			state.carrier = nil
			state.noClaim[keeper] = now + 1.2
			local look = flat(root.CFrame.LookVector)
			b.CFrame = CFrame.new(root.Position.X + look.X * 3, R + 0.1, root.Position.Z + look.Z * 3)
			b.AssemblyLinearVelocity = look * 6
		else
			-- Nas maos, a altura do peito.
			local look = flat(root.CFrame.LookVector)
			b.CFrame = CFrame.new(root.Position + look * 1.4 + Vector3.new(0, 0.6, 0))
			b.AssemblyLinearVelocity = Vector3.zero
			b.AssemblyAngularVelocity = Vector3.zero
		end
	end

	local carrier = state.carrier
	if state.heldBy ~= nil and carrier == state.heldBy then
		-- Ja tratado acima: a bola vai nas maos.
	elseif carrier then
		local root = carrier.root
		local humanoid = carrier.humanoid
		if not root or not humanoid or not humanoid.Parent or Squad.isDown(carrier, now) then
			state.carrier = nil
		elseif piece then
			-- Na reposicao a bola nao anda com os pes: fica no ponto ate ser
			-- batida. Quem se afasta dela larga-a.
			b.CFrame = CFrame.new(piece.spot.X, R + 0.05, piece.spot.Z)
			b.AssemblyLinearVelocity = Vector3.zero
			b.AssemblyAngularVelocity = Vector3.zero
			if horizontal(root.Position, piece.spot) > F.claimRange + 1.5 then
				state.carrier = nil
			end
		else
			carrier = tackle(carrier, now)
			local r = carrier.root :: BasePart
			local look = flat(r.CFrame.LookVector)
			local at = r.Position + look * F.dribbleDistance
			local v = r.AssemblyLinearVelocity
			b.CFrame = CFrame.new(at.X, R + 0.05, at.Z)
			b.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
			b.AssemblyAngularVelocity = Vector3.new(v.Z, 0, -v.X) / R
		end
	elseif piece then
		b.CFrame = CFrame.new(piece.spot.X, R + 0.05, piece.spot.Z)
		b.AssemblyLinearVelocity = Vector3.zero
	else
		-- O travao: forte no chao, fraco no ar.
		local v = b.AssemblyLinearVelocity
		local onGround = b.Position.Y < R + 0.4
		local keep = math.exp(-(if onGround then F.rollDrag else F.airDrag) * dt)
		local horizontalV = Vector3.new(v.X * keep, 0, v.Z * keep)

		-- O efeito: a bola vai-se desviando para o lado, sempre de lado em
		-- relacao ao caminho que leva, e o que a faz curvar em vez de derivar.
		if state.curve ~= 0 and now < state.curveUntil and horizontalV.Magnitude > 4 then
			local right = horizontalV.Unit:Cross(Vector3.yAxis)
			horizontalV += right * state.curve * dt
		end
		b.AssemblyLinearVelocity = horizontalV + Vector3.new(0, v.Y, 0)
	end

	local p = b.Position
	if not piece and (checkGoal(p) or checkOut(p)) then
		return
	end

	if not state.carrier and not Squad.isFrozen() and now >= state.flightUntil then
		claim(b, now)
	end

	-- Quem a tem, a vista de todos (ecra e testes).
	local holder = state.carrier
	local name = if holder and holder.model then holder.model.Name else nil
	if b:GetAttribute("Carrier") ~= name then
		b:SetAttribute("Carrier", name)
	end
end

return Football
