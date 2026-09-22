--!strict
--[[
	O jogo: aquecimento, duas partes, intervalo, rescaldo, e volta ao inicio.

	Ninguem joga futebol aqui — os lances acontecem sozinhos, de tantos em
	tantos segundos, e a bancada e que inclina a hipotese de golo. E de
	proposito: o futebol so precisa de ser suficiente para haver algo a que
	reagir, e e a bancada que decide.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MatchLoop = {}

export type Phase = "warmup" | "first" | "halftime" | "second" | "fulltime"

local state = {
	phase = "warmup" :: Phase,
	clock = 0, -- segundos restantes da fase atual
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
		clock = math.floor(state.clock),
		score = { home = state.score.home, away = state.score.away },
		lastGoal = state.lastGoal,
		goalStamp = state.goalStamp,
	}
end

local function broadcast()
	local snap = MatchLoop.snapshot()
	for _, fn in listeners do
		fn(snap)
	end
end

local PHASE_LENGTH: { [string]: number } = {
	warmup = Config.Match.warmupLength,
	first = Config.Match.halfLength,
	halftime = Config.Match.halfTimeLength,
	second = Config.Match.halfLength,
	fulltime = Config.Match.fullTimeLength,
}

local NEXT_PHASE: { [string]: Phase } = {
	warmup = "first",
	first = "halftime",
	halftime = "second",
	second = "fulltime",
	fulltime = "warmup",
}

local function enterPhase(phase: Phase)
	state.phase = phase
	state.clock = PHASE_LENGTH[phase]

	-- Apito final: limpa a tabela para o jogo seguinte.
	if phase == "warmup" then
		state.score.home = 0
		state.score.away = 0
		state.lastGoal = nil
	end

	broadcast()
end

--[[
	Marcar um golo. Quem decide que houve golo e o campo, nao este modulo: a bola
	entrar na baliza e que conta. O ambiente da bancada ja entrou mais atras, na
	pontaria do remate.
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

function MatchLoop.start()
	enterPhase("warmup")

	task.spawn(function()
		while true do
			local dt = task.wait(0.25)
			state.clock -= dt

			if state.clock <= 0 then
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
