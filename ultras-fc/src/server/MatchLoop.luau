--!strict
--[[
	O relogio do dia de jogo. Anda sempre em ciclo, sem nunca parar:

		sede -> corteo -> 1a parte -> intervalo -> 2a parte -> fim -> sede

	Quem entra a meio entra na fase que esta a decorrer: nada aqui espera por
	ninguem. Um servidor que ficasse parado a espera de uma pessoa ficava parado
	para toda a gente.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MatchLoop = {}

export type Phase = "clubhouse" | "corteo" | "first" | "halftime" | "second" | "fulltime"

local M = Config.Match

local state = {
	phase = "clubhouse" :: Phase,
	clock = 0, -- segundos restantes da fase atual
	length = 0, -- quanto dura a fase atual, para saber quanto ja passou
	score = { home = 0, away = 0 },
	lastGoal = nil :: string?, -- equipa que marcou o ultimo golo, para a UI festejar
	goalStamp = 0,
}

-- Quem ouve mudancas (o Main liga-se aqui para avisar os clientes).
local listeners: { (typeof(state)) -> () } = {}

function MatchLoop.onChange(fn: (typeof(state)) -> ())
	table.insert(listeners, fn)
end

function MatchLoop.snapshot()
	return {
		phase = state.phase,
		clock = math.max(math.ceil(state.clock), 0),
		length = state.length,
		score = { home = state.score.home, away = state.score.away },
		lastGoal = state.lastGoal,
		goalStamp = state.goalStamp,
	}
end

function MatchLoop.phase(): Phase
	return state.phase
end

-- Segundos desde que a fase atual comecou.
function MatchLoop.elapsed(): number
	return state.length - state.clock
end

local function broadcast()
	local snap = MatchLoop.snapshot()
	for _, fn in listeners do
		fn(snap)
	end
end

local PHASE_LENGTH: { [string]: number } = {
	clubhouse = M.clubhouseLength,
	corteo = M.corteoLength,
	first = M.halfLength,
	halftime = M.halfTimeLength,
	second = M.halfLength,
	fulltime = M.fullTimeLength,
}

local NEXT_PHASE: { [string]: Phase } = {
	clubhouse = "corteo",
	corteo = "first",
	first = "halftime",
	halftime = "second",
	second = "fulltime",
	fulltime = "clubhouse",
}

local function enterPhase(phase: Phase)
	state.phase = phase
	state.length = PHASE_LENGTH[phase]
	state.clock = state.length

	-- Dia de jogo novo: tabela limpa.
	if phase == "clubhouse" then
		state.score.home = 0
		state.score.away = 0
		state.lastGoal = nil
	end

	broadcast()
end

--[[
	Enquanto isto for verdade, a parte nao acaba: um golo aos 7:25 festeja-se na
	mesma ate ao fim, e so depois se apita para o intervalo.
]]
local holdWhile: (() -> boolean)? = nil

function MatchLoop.holdWhile(fn: () -> boolean)
	holdWhile = fn
end

--[[
	Marcar um golo. Quem decide que houve golo e o campo, nao este modulo: a bola
	entrar na baliza e que conta.
]]
function MatchLoop.scoreGoal(teamId: string)
	if state.phase ~= "first" and state.phase ~= "second" then
		return
	end
	if state.score[teamId] == nil then
		return
	end

	state.score[teamId] += 1
	state.lastGoal = teamId
	state.goalStamp = workspace:GetServerTimeNow()
	broadcast()
end

-- Quem ganhou, ou nil se empataram.
function MatchLoop.winner(): string?
	local home, away = state.score.home, state.score.away
	if home == away then
		return nil
	end
	return if home > away then "home" else "away"
end

-- Salta ja para a fase seguinte. So para testes: quem pode chamar isto e o Main
-- decide, pela lista de admins.
function MatchLoop.skip()
	enterPhase(NEXT_PHASE[state.phase])
end

function MatchLoop.start()
	enterPhase("clubhouse")

	task.spawn(function()
		while true do
			local dt = task.wait(0.25)
			state.clock -= dt

			local halfEnding = state.phase == "first" or state.phase == "second"
			local held = halfEnding and holdWhile ~= nil and holdWhile()
			if state.clock <= 0 and not held then
				enterPhase(NEXT_PHASE[state.phase])
			end
		end
	end)

	-- O relogio na UI so precisa de um acerto por segundo.
	task.spawn(function()
		while true do
			task.wait(1)
			broadcast()
		end
	end)
end

return MatchLoop
