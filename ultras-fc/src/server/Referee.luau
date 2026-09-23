--!strict
--[[
	O arbitro.

	E o motor do drama deste jogo. Um golo mal anulado poe uma bancada inteira a
	insultar a mesma pessoa ao mesmo tempo, e isso e social, e engracado, e da
	razao de ser a um papel que ninguem quereria.

	A regra que mantem isto vivo: corromper-se e ARRISCADO, nunca comprado. O
	arbitro cede a quem mais pressiona, ganha com isso, e cada cedencia enche a
	barra de suspeicao. Cheia, e apanhado — a decisao e revertida e fica
	suspenso. Se fosse a venda, quem pagasse ganhava sempre e o jogo durava dois
	dias; assim vira jogo do gato e do rato, e esse nao acaba.
]]

local Players = game:GetService("Players")
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

export type Incident = {
	id: number,
	kind: string, -- "falta" | "golo"
	title: string, -- o que aconteceu
	detail: string, -- quem, e onde
	options: { Option },
	fair: string, -- o que o arbitro automatico decidiria
	default: string, -- o que sai se ninguem decidir
	expires: number,
}

local whistle: Player? = nil
local suspicion = 0
local bans: { [Player]: number } = {}
local pending: Incident? = nil
local nextId = 0

-- Pedidos das bancadas, com validade: um grito de ha um minuto ja nao conta.
local pressure: { [string]: { number } } = {}

local onResolved: ((Incident, string, boolean) -> ())? = nil

-- Definido mais abaixo, com os lances; o `release` ja precisa dele.
local resolve: (choice: string, byReferee: boolean) -> ()
local onState: (() -> ())? = nil

function Referee.onResolved(fn: (Incident, string, boolean) -> ())
	onResolved = fn
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

function Referee.isBanned(player: Player): boolean
	return (bans[player] or 0) > 0
end

--[[
	Ficar com o apito. So um de cada vez, e nao quem esteja suspenso — a
	suspensao tem de custar alguma coisa ou apanhar nao significava nada.
]]
function Referee.take(player: Player): boolean
	if whistle and whistle.Parent then
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
		-- Um lance aberto nao pode ficar a espera de quem saiu: o jogo esta
		-- parado a espera dele.
		local incident = pending
		if incident then
			resolve(incident.default, false)
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
	pelo numero de vozes e por serem recentes.
]]
function Referee.addPressure(player: Player)
	local teamId = Teams.get(player)
	if not teamId or not pending then
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

--------------------------------------------------------------------------------
-- Lances
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
	A decisao sai.

	Ceder a quem mais grita e o que levanta suspeitas — nao decidir mal, decidir
	sempre para o lado de quem pressiona. E por isso que a barra so sobe quando
	houve mesmo pressao, e so quando a escolha aproveita a quem gritou mais.

	Apanhado, a decisao dele e trocada pela do arbitro automatico — a justa — e
	nao simplesmente virada: com quatro botoes, "ao contrario" nao quer dizer
	nada.
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
		local favoured = option.favours
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

		if suspicion >= R.caughtAt then
			caught = true
			choice = incident.fair
			local ref = whistle
			if ref then
				bans[ref] = R.banMatches
				ref:SetAttribute("Team", nil)
			end
			whistle = nil
			suspicion = 0
		end
	end

	pressure = {}
	if onResolved then
		onResolved(incident, choice, caught)
	end
	announce()
end

--[[
	Abre um lance. Com uma pessoa com o apito, fica a espera dela uns segundos;
	sem ninguem, decide o arbitro automatico, logo e sempre com justica — a
	corrupcao so existe quando ha alguem para ser corrompido.

	Devolve o id do lance.
]]
function Referee.raise(spec: {
	kind: string,
	title: string,
	detail: string,
	options: { Option },
	fair: string,
	default: string,
}): number
	-- Um lance novo com outro por decidir: o antigo sai com a decisao natural.
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
		expires = os.clock() + R.decisionSeconds,
	}
	pending = incident
	pressure = {}

	if not (whistle and whistle.Parent) then
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

function Referee.decide(player: Player, choice: string)
	local incident = pending
	if player ~= whistle or not incident then
		return
	end
	if not optionById(incident, choice) then
		return
	end
	resolve(choice, true)
end

function Referee.step(dt: number)
	local incident = pending
	if incident and os.clock() >= incident.expires then
		-- Nao decidir e decidir: sai a decisao natural, sem suspeitas.
		resolve(incident.default, false)
		return
	end

	if suspicion > 0 then
		suspicion = math.max(suspicion - R.suspicionDecay * dt, 0)
	end
end

-- Fim de jogo: desconta uma partida a quem esta suspenso.
function Referee.endMatch()
	for player, left in bans do
		bans[player] = math.max(left - 1, 0)
	end
	suspicion = 0
	announce()
end

return Referee
