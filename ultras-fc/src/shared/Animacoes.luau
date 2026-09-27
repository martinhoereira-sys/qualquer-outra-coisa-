--!strict
--[[
	As animacoes, pelo nome (Config.Animations). O codigo nunca usa numeros.

	Com o numero vazio, `has` diz que nao ha e quem chama faz a pose de
	sempre; `track` devolve nil sem erro.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Animacoes = {}

-- O id de uma animacao (rbxassetid://...), ou nil se ainda nao ha.
function Animacoes.id(name: string): string?
	local value = (Config.Animations :: any)[name]
	if type(value) == "number" and value > 0 then
		return "rbxassetid://" .. math.floor(value)
	end
	if type(value) == "string" then
		local digits = string.match(value, "%d+")
		if digits and #digits > 0 then
			return "rbxassetid://" .. digits
		end
	end
	return nil
end

function Animacoes.has(name: string): boolean
	return Animacoes.id(name) ~= nil
end

-- As faixas ja carregadas, por animador.
local loaded: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

-- A faixa de animacao `name` neste animador (carrega uma vez), ou nil.
function Animacoes.track(animator: Animator, name: string): AnimationTrack?
	local id = Animacoes.id(name)
	if not id then
		return nil
	end
	local mine = loaded[animator]
	if not mine then
		mine = {}
		loaded[animator] = mine
	end
	local existing = mine[name]
	if existing then
		return existing
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		warn("[Ultras FC] A animacao '" .. name .. "' (" .. id .. ") nao carregou: " .. tostring(track))
		return nil
	end
	mine[name] = track
	return track
end

return Animacoes
