--!strict
--[[
	Os niveis: adepto, jogador e arbitro, tres caminhos que nao se misturam.

	Tudo e contado AQUI, no servidor: o ecra de cada um so mostra (Remotes.Perfil)
	e so pode pedir escolhas (numero, posicao, botas), que sao validadas contra
	o nivel. Nenhum XP nem dinheiro chega do cliente.

	Parado nao se ganha: o XP de estar (bancada, minutos jogados, corteo) so
	conta a quem se mexeu ou fez alguma coisa nos ultimos
	Config.Progress.activeWindow segundos.

	No fim de cada jogo paga-se o salario de cada papel, conforme o nivel, a
	quem participou, e mostra-se um resumo. A recompensa diaria da-se quando o
	perfil carrega.

	As medidas estao todas em Config.Progress.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local StadiumPlan = require(Shared:WaitForChild("StadiumPlan"))
local Money = require(script.Parent:WaitForChild("Money"))
local Teams = require(script.Parent:WaitForChild("Teams"))

local Progress = {}

local P = Config.Progress
local PATHS = { "adepto", "jogador", "arbitro" }

--------------------------------------------------------------------------------
-- Niveis
--------------------------------------------------------------------------------

-- O nivel de um total de XP, o XP ja feito dentro dele e o que falta para o seguinte.
function Progress.levelOf(xp: number): (number, number, number)
	local level = 1
	local need = P.xpBase
	while xp >= need and level < P.maxLevel do
		xp -= need
		level += 1
		need = P.xpBase + P.xpStep * (level - 1)
	end
	return level, xp, need
end

function Progress.level(player: Player, path: string): number
	local profile = Money.profile(player)
	if not profile then
		return 1
	end
	local level = Progress.levelOf((profile.xp :: any)[path] or 0)
	return level
end

--------------------------------------------------------------------------------
-- Ativo ou parado
--------------------------------------------------------------------------------

local lastActive: { [Player]: number } = {}
local anchor: { [Player]: Vector3 } = {}

-- Fez alguma coisa (tambor, tocha, chuto, emote...): conta como ativo.
function Progress.markActive(player: Player)
	lastActive[player] = os.clock()
end

local function isActive(player: Player): boolean
	return os.clock() - (lastActive[player] or -math.huge) <= P.activeWindow
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- De segundo a segundo: quem se afastou uns studs de onde estava, mexeu-se.
local function watchMovement()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			local here = root.Position
			local was = anchor[player]
			if not was or (here - was).Magnitude >= P.activeDistance then
				anchor[player] = here
				if was then
					lastActive[player] = os.clock()
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- O jogo de cada um (o que ganhou neste jogo)
--------------------------------------------------------------------------------

type MatchStats = {
	adepto: number,
	jogador: number,
	arbitro: number,
	corteo: number,
	stand: number,
	pyro: number,
	kickoff: boolean,
	corteoCredit: number, -- a parte do corteo que fez (0 a 1), para o salario
	claque: string?, -- de que claque foi, neste jogo
	minutes: number,
	pitchTeam: string?,
	goals: number,
	steals: number,
	saves: number,
	refMinutes: number,
	caught: boolean,
}

local match: { [Player]: MatchStats } = {}

local function statsFor(player: Player): MatchStats
	local s = match[player]
	if not s then
		s = {
			adepto = 0,
			jogador = 0,
			arbitro = 0,
			corteo = 0,
			stand = 0,
			pyro = 0,
			kickoff = false,
			corteoCredit = 0,
			claque = nil,
			minutes = 0,
			pitchTeam = nil,
			goals = 0,
			steals = 0,
			saves = 0,
			refMinutes = 0,
			caught = false,
		}
		match[player] = s
	end
	return s :: MatchStats
end

local function notify(player: Player, payload: { [string]: any })
	Remotes.Perfil:FireClient(player, payload)
end

-- Da XP num caminho (e soma-o ao deste jogo). Avisa se subiu de nivel.
local function gain(player: Player, path: string, amount: number)
	if amount <= 0 or not player.Parent then
		return
	end
	local before = Progress.level(player, path)
	Money.addXP(player, path, amount)
	local s = statsFor(player) :: any
	s[path] += amount
	local after = Progress.level(player, path)
	if after > before then
		notify(player, { kind = "nivel", path = path, level = after })
	end
end

--------------------------------------------------------------------------------
-- Os ganhos
--------------------------------------------------------------------------------

local phase = "clubhouse"
local lastGoal: { [string]: number } = {}
local atmosphereSum: { [string]: number } = {}
local atmosphereSamples = 0
local claqueOf: (Player) -> string? = function(player)
	return Teams.get(player)
end

-- Ligacoes que o Main da (para nao haver voltas de requires).
type Links = {
	bannerPosition: (string) -> Vector3?,
	footballerOf: (Player) -> { teamId: string, keeper: boolean }?,
	referee: () -> Player?,
	atmosphere: (string) -> number,
	winner: () -> string?,
	corteoCredit: (Player) -> number,
}
local links: Links? = nil

function Progress.link(l: Links)
	links = l
end

-- A cada 10 s do corteo: quem anda perto da faixa da sua claque.
local function corteoTick()
	local L = links
	if not L then
		return
	end
	local A = P.adepto
	for _, player in Players:GetPlayers() do
		local teamId = claqueOf(player)
		local root = rootOf(player)
		local banner = if teamId then L.bannerPosition(teamId) else nil
		if teamId and root and banner and isActive(player) then
			local s = statsFor(player)
			local d = (root.Position - banner).Magnitude
			local xp = if d <= A.corteoNear then A.corteoNearXP elseif d <= A.corteoFar then A.corteoFarXP else 0
			xp = math.min(xp, A.corteoCap - s.corteo)
			if xp > 0 then
				s.corteo += xp
				gain(player, "adepto", xp)
			end
		end
	end
end

-- A cada 30 s de jogo: quem esta na sua curva, ativo.
local function standTick()
	local A = P.adepto
	for _, player in Players:GetPlayers() do
		local teamId = claqueOf(player)
		local root = rootOf(player)
		if teamId and root and isActive(player) and StadiumPlan.inClaque(teamId, root.Position) then
			local s = statsFor(player)
			s.claque = teamId
			local xp = math.min(A.standXP, A.standCap - s.stand)
			if xp > 0 then
				s.stand += xp
				gain(player, "adepto", xp)
			end
		end
	end
end

-- A cada minuto de jogo: minutos jogados (ativos) e minutos de apito.
local function minuteTick()
	local L = links
	if not L then
		return
	end
	for _, player in Players:GetPlayers() do
		local f = L.footballerOf(player)
		if f and isActive(player) then
			local s = statsFor(player)
			s.minutes += 1
			s.pitchTeam = f.teamId
			gain(player, "jogador", P.jogador.minuteXP)
		end
	end
	local ref = L.referee()
	if ref then
		statsFor(ref).refMinutes += 1
	end
end

-- O ambiente das claques ao longo do jogo (para o bonus de claque alta).
local function atmosphereTick()
	local L = links
	if not L then
		return
	end
	atmosphereSamples += 1
	for _, teamId in Config.TeamOrder do
		atmosphereSum[teamId] = (atmosphereSum[teamId] or 0) + L.atmosphere(teamId)
	end
end

-- Um golo: XP a quem marcou e a quem assistiu; abre o momento da pirotecnia.
function Progress.goal(teamId: string, scorer: Player?, assist: Player?)
	lastGoal[teamId] = os.clock()
	local J = P.jogador
	if scorer then
		statsFor(scorer).goals += 1
		gain(scorer, "jogador", J.goalXP)
	end
	if assist and assist ~= scorer then
		gain(assist, "jogador", J.assistXP)
	end
end

-- Roubou a bola / defendeu (Football.onEvent), com maximos por jogo.
function Progress.footballEvent(kind: string, player: Player)
	local J = P.jogador
	local s = statsFor(player)
	if kind == "steal" and s.steals < J.stealCap then
		s.steals += 1
		gain(player, "jogador", J.stealXP)
	elseif kind == "save" and s.saves < J.saveCap then
		s.saves += 1
		gain(player, "jogador", J.saveXP)
	end
end

-- Acendeu alguma coisa: tocha ou fumo no momento certo da XP (ate 3 por jogo).
function Progress.ignite(player: Player, kind: string)
	Progress.markActive(player)
	if kind ~= "tocha" and kind ~= "fumo" then
		return
	end
	local teamId = claqueOf(player)
	if not teamId then
		return
	end
	local A = P.adepto
	local moment = phase == "entrada" or os.clock() - (lastGoal[teamId] or -math.huge) <= A.pyroMoment
	local s = statsFor(player)
	if moment and s.pyro < A.pyroCap then
		s.pyro += 1
		gain(player, "adepto", A.pyroXP)
	end
end

-- Uma decisao do arbitro: certa (igual a do automatico) da XP; apanhado, perde o bonus.
function Progress.refDecision(player: Player, correct: boolean, caught: boolean)
	local s = statsFor(player)
	if caught then
		s.caught = true
		return
	end
	if correct then
		gain(player, "arbitro", P.arbitro.rightCallXP)
	end
end

--------------------------------------------------------------------------------
-- O fim do jogo: bonus e salario
--------------------------------------------------------------------------------

local function money(amount: number): string
	return tostring(math.floor(amount)) .. "$"
end

local function endOfMatch()
	local L = links
	if not L then
		return
	end
	local A, J, R, S = P.adepto, P.jogador, P.arbitro, P.salary
	local halfMatch = Config.Match.halfLength / 60 -- minutos de uma parte
	local winner = L.winner()

	for player, s in match do
		if not player.Parent then
			continue
		end
		local lines = {}
		local pay = 0

		-- Adepto: claque alta, e o salario a quem participou.
		if s.claque then
			local avg = if atmosphereSamples > 0 then (atmosphereSum[s.claque] or 0) / atmosphereSamples else 0
			if s.adepto >= S.adepto.minXP then
				local bonus = if avg >= A.louderAt then A.louderXP elseif avg >= A.loudAt then A.loudXP else 0
				if bonus > 0 then
					gain(player, "adepto", bonus)
					table.insert(lines, "Claque alta: +" .. bonus .. " XP")
				end
			end
		end
		if s.adepto >= S.adepto.minXP then
			local level = Progress.level(player, "adepto")
			local salary = S.adepto.base + S.adepto.perLevel * level + Config.Money.perCorteo * s.corteoCredit
			pay += salary
			table.insert(lines, "Adepto: +" .. s.adepto .. " XP, salario " .. money(salary))
		end

		-- Jogador: resultado e salario.
		if s.minutes >= S.jogador.minMinutes and s.pitchTeam then
			if winner == s.pitchTeam then
				gain(player, "jogador", J.winXP)
			elseif winner == nil then
				gain(player, "jogador", J.drawXP)
			end
			local level = Progress.level(player, "jogador")
			local salary = S.jogador.base + S.jogador.perLevel * level + S.jogador.perGoal * s.goals
			pay += salary
			table.insert(lines, "Jogador: +" .. s.jogador .. " XP, salario " .. money(salary))
		end

		-- Arbitro: o jogo apitado (com pelo menos metade) e nao ser apanhado.
		if s.refMinutes >= halfMatch then
			if not s.caught then
				local share = math.min(1, s.refMinutes / (halfMatch * 2))
				gain(player, "arbitro", math.floor(R.fullMatchXP * share))
				gain(player, "arbitro", R.cleanXP)
				local level = Progress.level(player, "arbitro")
				local salary = S.arbitro.base + S.arbitro.perLevel * level
				pay += salary
				table.insert(lines, "Arbitro: +" .. s.arbitro .. " XP, salario " .. money(salary))
			else
				table.insert(lines, "Arbitro: apanhado, sem salario neste jogo")
			end
		end

		if pay > 0 then
			Money.add(player, pay)
		end
		if #lines > 0 then
			notify(player, { kind = "resumo", lines = lines, pay = math.floor(pay) })
		end
	end
end

-- Uma fase nova do dia de jogo.
function Progress.phaseChanged(newPhase: string)
	-- O relogio avisa todos os segundos: so conta a mudanca de fase.
	if newPhase == phase then
		return
	end
	phase = newPhase
	local L = links
	if newPhase == "clubhouse" then
		table.clear(match)
		table.clear(atmosphereSum)
		table.clear(lastGoal)
		atmosphereSamples = 0
	elseif newPhase == "first" and L then
		-- O apito inicial: quem esta na sua curva, e o que fez do corteo.
		for _, player in Players:GetPlayers() do
			local teamId = claqueOf(player)
			local root = rootOf(player)
			if teamId then
				local s = statsFor(player)
				s.claque = teamId
				s.corteoCredit = L.corteoCredit(player)
				if root and not s.kickoff and StadiumPlan.inClaque(teamId, root.Position) then
					s.kickoff = true
					gain(player, "adepto", P.adepto.kickoffXP)
				end
			end
		end
	elseif newPhase == "fulltime" then
		endOfMatch()
	end
end

--------------------------------------------------------------------------------
-- O que os niveis dao
--------------------------------------------------------------------------------

local K = P.perks

local function countReached(list: { number }, level: number): number
	local n = 0
	for _, at in list do
		if level >= at then
			n += 1
		end
	end
	return n
end

-- Material a mais por jogo (adepto).
function Progress.gearBonus(player: Player, kind: string): number
	local level = Progress.level(player, "adepto")
	if kind == "tocha" then
		return countReached(K.tochaAt, level)
	elseif kind == "fumo" then
		return countReached(K.fumoAt, level)
	elseif kind == "vela" then
		return countReached(K.velaAt, level)
	end
	return 0
end

function Progress.gearPerks(player: Player): { bigFlare: boolean, candleShots: number }
	local level = Progress.level(player, "adepto")
	return {
		bigFlare = level >= K.bigFlareAt,
		candleShots = if level >= K.longCandleAt then K.longCandleShots else 10,
	}
end

function Progress.canHoldBanner(player: Player): boolean
	return Progress.level(player, "adepto") >= K.bannerAt
end

function Progress.exclusiveColours(player: Player): boolean
	return Progress.level(player, "adepto") >= K.exclusiveColoursAt
end

-- Sem lider, o tambor e do adepto de nivel mais alto da claque.
function Progress.drumWithoutLeader(player: Player): boolean
	local teamId = Teams.get(player)
	if not teamId or Teams.leader(teamId) then
		return false
	end
	local mine = Progress.level(player, "adepto")
	for _, other in Players:GetPlayers() do
		if other ~= player and Teams.get(other) == teamId then
			local theirs = Progress.level(other, "adepto")
			if theirs > mine or (theirs == mine and other.UserId < player.UserId) then
				return false
			end
		end
	end
	return true
end

-- Jogador: a posicao que quer (nivel 5), se ja pode escolher.
function Progress.preferredPosition(player: Player): string?
	local profile = Money.profile(player)
	if not profile or Progress.level(player, "jogador") < K.positionAt then
		return nil
	end
	return profile.prefs.position
end

--[[
	O aspeto de um jogador (so aspeto): o numero escolhido (se ninguem da
	equipa ja o tiver), as botas, o nome nas costas e a bracadeira (o de
	nivel mais alto da equipa, a partir do nivel 10).
]]
function Progress.lookFor(player: Player, teamId: string, taken: { [number]: boolean }): { number: number?, boots: Color3?, name: string?, captain: boolean? }
	local profile = Money.profile(player)
	local level = Progress.level(player, "jogador")
	local look: { number: number?, boots: Color3?, name: string?, captain: boolean? } = {}
	if not profile then
		return look
	end
	local wanted = profile.prefs.number
	if level >= K.numberAt and wanted and not taken[wanted] then
		look.number = wanted
	end
	if level >= K.goldBootsAt then
		look.boots = Color3.fromRGB(230, 180, 50)
	elseif level >= K.bootsAt and profile.prefs.boots then
		local choice = Config.BootColours[profile.prefs.boots]
		look.boots = if choice then choice.color else nil
	end
	if level >= K.nameAt then
		look.name = player.DisplayName
	end
	if level >= K.captainAt then
		look.captain = true
		for _, other in Players:GetPlayers() do
			if other ~= player and other:GetAttribute("PitchTeam") == teamId and other:GetAttribute("Team") == "jogador" then
				local theirs = Progress.level(other, "jogador")
				if theirs > level or (theirs == level and other.UserId < player.UserId) then
					look.captain = nil
				end
			end
		end
	end
	return look
end

--------------------------------------------------------------------------------
-- O perfil no ecra, as escolhas e a recompensa diaria
--------------------------------------------------------------------------------

local function nextReward(path: string, level: number): string
	local list: { { at: number, text: string } } = {}
	if path == "adepto" then
		for _, at in K.tochaAt do
			table.insert(list, { at = at, text = "mais uma tocha por jogo" })
		end
		for _, at in K.fumoAt do
			table.insert(list, { at = at, text = "mais um fumo por jogo" })
		end
		for _, at in K.velaAt do
			table.insert(list, { at = at, text = "mais uma vela romana por jogo" })
		end
		table.insert(list, { at = K.bannerAt, text = "segurar a faixa do corteo" })
		table.insert(list, { at = K.bigFlareAt, text = "tocha grande" })
		table.insert(list, { at = K.longCandleAt, text = "vela romana com " .. K.longCandleShots .. " tiros" })
		table.insert(list, { at = K.exclusiveColoursAt, text = "cores douradas e prateadas" })
	elseif path == "jogador" then
		table.insert(list, { at = K.numberAt, text = "escolher o numero" })
		table.insert(list, { at = K.positionAt, text = "escolher a posicao" })
		table.insert(list, { at = K.bootsAt, text = "cor das botas" })
		table.insert(list, { at = K.captainAt, text = "bracadeira de capitao" })
		for _, at in K.celebrationAt do
			table.insert(list, { at = at, text = "festejo novo" })
		end
		table.insert(list, { at = K.nameAt, text = "nome nas costas" })
		table.insert(list, { at = K.goldBootsAt, text = "botas douradas" })
	else
		return "salario maior a cada nivel"
	end
	local best: { at: number, text: string }? = nil
	for _, r in list do
		if r.at > level and (best == nil or r.at < best.at) then
			best = r
		end
	end
	return if best then "Nivel " .. best.at .. ": " .. best.text else "Tudo desbloqueado"
end

local function snapshot(player: Player): { [string]: any }?
	local profile = Money.profile(player)
	if not profile then
		return nil
	end
	local paths = {}
	for _, path in PATHS do
		local total = (profile.xp :: any)[path] or 0
		local level, into, need = Progress.levelOf(total)
		paths[path] = { level = level, xp = into, need = need, total = total, nextReward = nextReward(path, level) }
		player:SetAttribute("Nivel_" .. path, level)
	end
	return {
		kind = "perfil",
		escudos = profile.escudos,
		saved = Money.isLoaded(player),
		paths = paths,
		prefs = { number = profile.prefs.number, position = profile.prefs.position, boots = profile.prefs.boots },
		streak = profile.daily.streak,
	}
end

local pendingSend: { [Player]: boolean } = {}
local function sendProfile(player: Player)
	if pendingSend[player] then
		return
	end
	pendingSend[player] = true
	task.delay(0.4, function()
		pendingSend[player] = nil
		local snap = snapshot(player)
		if snap and player.Parent then
			notify(player, snap)
		end
	end)
end

-- A recompensa diaria: um dia seguido a mais da mais (volta ao 1 depois do 7).
local function daily(player: Player)
	local profile = Money.profile(player)
	if not profile then
		return
	end
	local today = math.floor(os.time() / 86400)
	if profile.daily.day == today then
		return
	end
	local streak = if profile.daily.day == today - 1 then (profile.daily.streak % #P.daily) + 1 else 1
	local reward = P.daily[streak]
	Money.setDaily(player, today, streak)
	Money.add(player, reward)
	notify(player, { kind = "diaria", day = streak, reward = reward })
end

--[[
	As escolhas que o ecra pode pedir, validadas aqui contra o nivel: o numero
	(1 a 99), a posicao ("ataque", "meio", "defesa") e a cor das botas.
]]
local onLookChanged: ((Player) -> ())? = nil
function Progress.onLookChanged(fn: (Player) -> ())
	onLookChanged = fn
end

local function choose(player: Player, action: any, value: any)
	local level = Progress.level(player, "jogador")
	if action == "numero" and type(value) == "number" and level >= K.numberAt then
		local n = math.floor(value)
		if n >= 1 and n <= 99 then
			Money.setPref(player, "number", n)
		end
	elseif action == "posicao" and level >= K.positionAt and (value == "ataque" or value == "meio" or value == "defesa" or value == nil) then
		Money.setPref(player, "position", value)
	elseif action == "botas" and type(value) == "number" and level >= K.bootsAt and Config.BootColours[value] then
		Money.setPref(player, "boots", math.floor(value))
	else
		return
	end
	if onLookChanged then
		onLookChanged(player)
	end
end

function Progress.start()
	Money.onChanged(sendProfile)
	Money.onLoaded(function(player)
		daily(player)
		sendProfile(player)
	end)
	Remotes.Perfil.OnServerEvent:Connect(function(player, action, value)
		if action == "pedir" then
			sendProfile(player)
		else
			choose(player, action, value)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastActive[player] = nil
		anchor[player] = nil
		match[player] = nil
	end)

	-- Os relogios: movimento (1 s), corteo (10 s), bancada (30 s), minutos (60 s).
	task.spawn(function()
		local t = 0
		while true do
			task.wait(1)
			t += 1
			watchMovement()
			local playing = phase == "first" or phase == "second"
			if phase == "corteo" and t % P.adepto.corteoTick == 0 then
				corteoTick()
			end
			if playing and t % P.adepto.standTick == 0 then
				standTick()
			end
			if playing and t % 60 == 0 then
				minuteTick()
			end
			if playing and t % 10 == 0 then
				atmosphereTick()
			end
		end
	end)
end

return Progress
