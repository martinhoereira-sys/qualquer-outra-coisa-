--!strict
--[[
	O arbitro.

	E o motor do drama deste jogo. Um golo mal anulado poe uma bancada inteira a
	insultar a mesma pessoa ao mesmo tempo, e isso e social, e engracado, e da
	razao de ser a um papel que ninguem quereria.

	O jogo nunca para a espera dele. Quando ha uma entrada que pode ser falta,
	abre-se uma janela de dois segundos: quem apita ve-a, e apita ou nao apita.
	Nao apitar e deixar seguir — a lei da vantagem sai daqui sozinha, porque se
	a equipa que sofreu continua bem, simplesmente nao se apita. So depois do
	apito, com a bola ja parada, se escolhe o cartao, sem pressa.

	A regra que mantem isto vivo: corromper-se e ARRISCADO, nunca comprado. O
	arbitro cede a quem mais pressiona, ganha com isso, e cada cedencia enche a
	barra de suspeicao — apitar para quem grita "falta!", ou calar-se para quem
	grita "deixa jogar!". Cheia, e apanhado — a decisao passa a ser a do
	arbitro automatico, e fica suspenso. Se fosse a venda, quem pagasse ganhava
	sempre e o jogo durava dois dias; assim vira jogo do gato e do rato, e esse
	nao acaba.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Teams = require(script.Parent:WaitForChild("Teams"))

local Referee = {}

local R = Config.Referee

-- Uma escolha do painel, e a equipa a quem ela aproveita.
export type Option = {
	id: string,
	label: string,
	favours: string,
}

--[[
	Uma escolha feita com a bola parada, depois do apito: o cartao, ou, na
	duvida da linha da area, se foi penalti ou livre.
]]
export type Incident = {
	id: number,
	kind: string, -- "cartao" | "lugar"
	title: string, -- o que aconteceu
	detail: string, -- quem, e onde
	options: { Option },
	fair: string, -- o que o arbitro automatico decidiria
	default: string, -- o que sai se ninguem decidir
	expires: number,
}

--[[
	A janela de uma entrada: dois segundos em que se pode apitar. `fair` diz,
	no fim, se o arbitro automatico apitaria — pergunta-se so no fim, porque a
	vantagem so se ve depois.
]]
export type Window = {
	id: number,
	title: string,
	detail: string,
	favours: string, -- a quem aproveita apitar: quem sofreu a entrada
	against: string, -- a quem aproveita nao apitar: quem a fez
	fair: () -> boolean,
	expires: number,
}

local whistle: Player? = nil
local suspicion = 0
local bans: { [Player]: number } = {}
local pending: Incident? = nil
local window: Window? = nil
local nextId = 0

-- Pedidos das bancadas, com validade: um grito de ha um minuto ja nao conta.
local pressure: { [string]: { number } } = {}

local onResolved: ((Incident, string, boolean) -> ())? = nil
local onWindowClosed: ((Window, boolean, boolean) -> ())? = nil

-- Definido mais abaixo, com os lances; o `release` ja precisa dele.
local resolve: (choice: string, byReferee: boolean) -> ()
local onState: (() -> ())? = nil

function Referee.onResolved(fn: (Incident, string, boolean) -> ())
	onResolved = fn
end

-- Fechou-se a janela de uma entrada: se houve apito, e se o arbitro foi apanhado.
function Referee.onWindowClosed(fn: (Window, boolean, boolean) -> ())
	onWindowClosed = fn
end

function Referee.onState(fn: () -> ())
	onState = fn
end

local function announce()
	if onState then
		onState()
	end
end

function Referee.state()
	return {
		name = whistle and whistle.DisplayName or nil,
		suspicion = math.floor(suspicion),
		max = R.caughtAt,
	}
end

function Referee.current(): Player?
	return whistle
end

local function hasHuman(): boolean
	return whistle ~= nil and whistle.Parent ~= nil
end

function Referee.isBanned(player: Player): boolean
	return (bans[player] or 0) > 0
end

--[[
	Ficar com o apito. So um de cada vez, e nao quem esteja suspenso — a
	suspensao tem de custar alguma coisa ou apanhar nao significava nada.
]]
function Referee.take(player: Player): boolean
	if hasHuman() then
		return false
	end
	if Referee.isBanned(player) then
		return false
	end

	whistle = player
	suspicion = 0
	Teams.forget(player)
	player:SetAttribute("Team", "arbitro")
	announce()
	return true
end

function Referee.release(player: Player)
	if whistle == player then
		whistle = nil
		-- Um cartao por escolher nao pode ficar a espera de quem saiu: a bola
		-- esta parada a espera dele. A janela aberta, essa, fecha sozinha e
		-- decide o arbitro automatico.
		local incident = pending
		if incident then
			resolve(incident.fair, false)
		end
		announce()
	end
	bans[player] = nil
end

--------------------------------------------------------------------------------
-- Pressao das bancadas
--------------------------------------------------------------------------------

--[[
	Um adepto pede ao arbitro. Nao e dinheiro: e a bancada a gritar, e conta
	pelo numero de vozes e por serem recentes. Grita-se durante a janela da
	entrada, com o jogo a correr, e outra vez pelo cartao.
]]
function Referee.addPressure(player: Player)
	local teamId = Teams.get(player)
	if not teamId or not (pending or window) then
		return
	end
	pressure[teamId] = pressure[teamId] or {}
	table.insert(pressure[teamId], os.clock())
	announce()
end

local function pressureFor(teamId: string): number
	local list = pressure[teamId]
	if not list then
		return 0
	end
	local cutoff = os.clock() - R.pressureWindow
	local count = 0
	for _, at in list do
		if at >= cutoff then
			count += 1
		end
	end
	return count
end

function Referee.pressureSnapshot(): { [string]: number }
	local out = {}
	for _, teamId in Config.TeamOrder do
		out[teamId] = pressureFor(teamId)
	end
	return out
end

--[[
	Ceder a quem mais grita e o que levanta suspeitas — nao decidir mal,
	decidir sempre para o lado de quem pressiona. A barra so sobe quando houve
	mesmo pressao, e so quando a decisao aproveita a quem gritou mais. Devolve
	se o arbitro foi apanhado agora.
]]
local function judge(favoured: string): boolean
	local mine = pressureFor(favoured)
	local rivals = 0
	for _, teamId in Config.TeamOrder do
		if teamId ~= favoured then
			rivals += pressureFor(teamId)
		end
	end

	if mine > rivals and mine >= 2 then
		suspicion += R.suspicionPerCall
	end

	if suspicion < R.caughtAt then
		return false
	end

	local ref = whistle
	if ref then
		bans[ref] = R.banMatches
		ref:SetAttribute("Team", nil)
	end
	whistle = nil
	suspicion = 0
	return true
end

--------------------------------------------------------------------------------
-- A janela da entrada
--------------------------------------------------------------------------------

function Referee.window(): Window?
	return window
end

-- O que os ecras precisam da janela: o que aconteceu e quanto tempo falta.
function Referee.windowForClient()
	local w = window
	if not w then
		return nil
	end
	return {
		id = w.id,
		title = w.title,
		detail = w.detail,
		endsAt = workspace:GetServerTimeNow() + math.max(w.expires - os.clock(), 0),
		seconds = R.whistleWindow,
	}
end

--[[
	Fecha a janela. `whistled` e se houve apito; `byReferee` e se foi uma
	pessoa a decidir, que e o unico caso em que ha suspeitas.
]]
local function closeWindow(whistled: boolean, byReferee: boolean)
	local w = window
	if not w then
		return
	end
	window = nil

	local caught = false
	if byReferee then
		caught = judge(if whistled then w.favours else w.against)
		if caught then
			-- Apanhado: vale o que o arbitro automatico teria feito.
			whistled = w.fair()
		end
	end

	pressure = {}
	if onWindowClosed then
		onWindowClosed(w, whistled, caught)
	end
	announce()
end

--[[
	Uma entrada que pode ser falta. O jogo continua; durante dois segundos
	pode-se apitar. Sem ninguem com o apito, decide o arbitro automatico no fim
	da janela, com o que entretanto se viu — se a equipa que sofreu ficou bem,
	ha vantagem e nao se apita.
]]
function Referee.openWindow(spec: {
	title: string,
	detail: string,
	favours: string,
	against: string,
	fair: () -> boolean,
}): number
	-- Uma entrada nova com outra ainda aberta: a antiga fecha-se sem apito.
	if window then
		window = nil
	end

	nextId += 1
	window = {
		id = nextId,
		title = spec.title,
		detail = spec.detail,
		favours = spec.favours,
		against = spec.against,
		fair = spec.fair,
		expires = os.clock() + R.whistleWindow,
	}
	pressure = {}
	announce()
	return nextId
end

-- Fecha a janela sem apito e sem suspeitas (um golo, o fim da parte).
function Referee.cancelWindow()
	if window then
		window = nil
		announce()
	end
end

--------------------------------------------------------------------------------
-- Escolhas com a bola parada
--------------------------------------------------------------------------------

function Referee.pending(): Incident?
	return pending
end

-- O que o painel de quem apita precisa, sem a resposta justa la dentro.
function Referee.pendingForClient()
	local incident = pending
	if not incident then
		return nil
	end
	local options = {}
	for _, option in incident.options do
		table.insert(options, { id = option.id, label = option.label })
	end
	return {
		id = incident.id,
		kind = incident.kind,
		title = incident.title,
		detail = incident.detail,
		options = options,
		seconds = math.max(incident.expires - os.clock(), 0),
	}
end

local function optionById(incident: Incident, id: string): Option?
	for _, option in incident.options do
		if option.id == id then
			return option
		end
	end
	return nil
end

--[[
	A escolha sai. Apanhado, a escolha dele e trocada pela do arbitro
	automatico — a justa.
]]
resolve = function(choice: string, byReferee: boolean)
	local incident = pending
	if not incident then
		return
	end
	pending = nil

	local caught = false
	local option = optionById(incident, choice)
	if byReferee and option then
		caught = judge(option.favours)
		if caught then
			choice = incident.fair
		end
	end

	pressure = {}
	if onResolved then
		onResolved(incident, choice, caught)
	end
	announce()
end

--[[
	Abre uma escolha com a bola parada. Com uma pessoa com o apito, fica a
	espera dela, sem pressa; sem ninguem, decide logo o arbitro automatico, com
	justica — a corrupcao so existe quando ha alguem para ser corrompido.

	Devolve o id.
]]
function Referee.raise(spec: {
	kind: string,
	title: string,
	detail: string,
	options: { Option },
	fair: string,
	default: string,
}): number
	-- Uma escolha nova com outra por fazer: a antiga sai com a natural.
	if pending then
		resolve(pending.default, false)
	end

	nextId += 1
	local incident: Incident = {
		id = nextId,
		kind = spec.kind,
		title = spec.title,
		detail = spec.detail,
		options = spec.options,
		fair = spec.fair,
		default = spec.default,
		expires = os.clock() + R.cardSeconds,
	}
	pending = incident
	pressure = {}

	if not hasHuman() then
		task.defer(function()
			if pending == incident then
				resolve(incident.fair, false)
			end
		end)
		return incident.id
	end

	announce()
	return incident.id
end

--[[
	O que quem apita manda: "apitar" durante a janela de uma entrada, ou uma
	das opcoes do painel com a bola parada.
]]
function Referee.decide(player: Player, choice: string)
	if player ~= whistle then
		return
	end
	if choice == "apitar" then
		if window then
			closeWindow(true, true)
		end
		return
	end
	local incident = pending
	if not incident or not optionById(incident, choice) then
		return
	end
	resolve(choice, true)
end

function Referee.step(dt: number)
	local w = window
	if w and os.clock() >= w.expires then
		if hasHuman() then
			-- Nao apitar e deixar seguir: e uma decisao, e tambem pode ser cedencia.
			closeWindow(false, true)
		else
			closeWindow(w.fair(), false)
		end
	end

	local incident = pending
	if incident and os.clock() >= incident.expires then
		-- Sem escolha a tempo, sai a natural, sem suspeitas.
		resolve(incident.default, false)
		return
	end

	if suspicion > 0 then
		suspicion = math.max(suspicion - R.suspicionDecay * dt, 0)
	end
end

-- Fim de jogo: desconta uma partida a quem esta suspenso.
function Referee.endMatch()
	window = nil
	for player, left in bans do
		bans[player] = math.max(left - 1, 0)
	end
	suspicion = 0
	announce()
end

return Referee
