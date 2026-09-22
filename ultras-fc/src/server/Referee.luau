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

export type Incident = {
	id: number,
	kind: string, -- "golo" | "penalti"
	teamId: string, -- a equipa a quem o lance aproveita
	options: { string },
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
		pending = nil
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

--[[
	Abre um lance para decisao. Sem arbitro em campo resolve-se sozinho e a favor
	de ninguem: um jogo nao pode parar a espera de uma pessoa que nao esta.
]]
function Referee.raise(kind: string, teamId: string): boolean
	if pending then
		return false
	end
	if not (whistle and whistle.Parent) then
		return false
	end

	nextId += 1
	pending = {
		id = nextId,
		kind = kind,
		teamId = teamId,
		options = kind == "golo" and { "validar", "anular" } or { "marcar", "nada" },
		expires = os.clock() + R.decisionSeconds,
	}
	pressure = {}
	announce()
	return true
end

--[[
	A decisao sai. `favoured` diz se ela beneficiou a equipa do lance.

	Ceder a quem mais grita e o que levanta suspeitas — nao decidir mal, decidir
	sempre para o mesmo lado de quem pressiona. E por isso que a barra so sobe
	quando houve mesmo pressao.
]]
local function resolve(choice: string, byReferee: boolean)
	local incident = pending
	if not incident then
		return
	end
	pending = nil

	local favoured = choice == incident.options[1]
	local caught = false

	if byReferee then
		local mine = pressureFor(incident.teamId)
		local rivals = 0
		for _, teamId in Config.TeamOrder do
			if teamId ~= incident.teamId then
				rivals += pressureFor(teamId)
			end
		end

		local leaned = (favoured and mine > rivals) or (not favoured and rivals > mine)
		if leaned and math.max(mine, rivals) >= 2 then
			suspicion += R.suspicionPerCall
		end

		if suspicion >= R.caughtAt then
			caught = true
			favoured = not favoured -- a decisao e revertida
			local ref = whistle
			if ref then
				bans[ref] = R.banMatches
			end
			whistle = nil
			suspicion = 0
		end
	end

	pressure = {}
	if onResolved then
		onResolved(incident, favoured and incident.options[1] or incident.options[2], caught)
	end
	announce()
end

function Referee.decide(player: Player, choice: string)
	if player ~= whistle or not pending then
		return
	end
	if choice ~= pending.options[1] and choice ~= pending.options[2] then
		return
	end
	resolve(choice, true)
end

function Referee.step(dt: number)
	if pending and os.clock() >= pending.expires then
		-- Nao decidir e decidir: sai a favor do lance, sem suspeitas.
		resolve(pending.options[1], false)
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
