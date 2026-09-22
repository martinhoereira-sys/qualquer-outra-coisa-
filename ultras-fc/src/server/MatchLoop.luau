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
local Atmosphere = require(script.Parent:WaitForChild("Atmosphere"))

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

-- So ha lances com a bola a rolar.
local function isPlaying(): boolean
	return state.phase == "first" or state.phase == "second"
end

--[[
	Um lance. Cada equipa tem a sua hipotese, empurrada para cima pelo ambiente
	da propria bancada. Cantar nao garante o golo — inclina a moeda.
]]
local function attemptChance()
	local candidates = {}
	for _, teamId in Config.TeamOrder do
		local boost = 1 + Atmosphere.fraction(teamId) * Config.Match.atmosphereSwing
		table.insert(candidates, { id = teamId, chance = Config.Match.baseGoalChance * boost })
	end

	-- Ordem baralhada para nao favorecer sempre a mesma equipa no desempate.
	if math.random() < 0.5 then
		candidates[1], candidates[2] = candidates[2], candidates[1]
	end

	for _, entry in candidates do
		if math.random() < entry.chance then
			state.score[entry.id] += 1
			state.lastGoal = entry.id
			state.goalStamp = workspace:GetServerTimeNow()
			broadcast()
			return
		end
	end
end

function MatchLoop.start()
	enterPhase("warmup")

	task.spawn(function()
		local sinceChance = 0

		while true do
			local dt = task.wait(0.25)
			state.clock -= dt

			if isPlaying() then
				sinceChance += dt
				if sinceChance >= Config.Match.chanceInterval then
					sinceChance = 0
					attemptChance()
				end
			end

			if state.clock <= 0 then
				sinceChance = 0
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
