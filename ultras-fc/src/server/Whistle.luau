--!strict
--[[
	A ponte entre o relvado e o arbitro.

	O Football ve o que aconteceu (uma entrada, onde, como); o Referee decide,
	com uma pessoa ou sozinho. Aqui transforma-se uma coisa na outra.

	Primeiro a janela: dois segundos para apitar, com o jogo a correr. Sem
	apito nao acontece nada. Com apito o jogo para ali, e so entao, com a bola
	parada, se escolhe — onde foi, se foi em cima da linha da area, e o cartao.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Squad = require(script.Parent:WaitForChild("Squad"))
local Football = require(script.Parent:WaitForChild("Football"))
local Referee = require(script.Parent:WaitForChild("Referee"))

type Foul = Football.Foul

local Whistle = {}

-- Entradas com a janela aberta, pelo id da janela.
local candidates: { [number]: Foul } = {}
-- Faltas apitadas a espera de escolha, pelo id da escolha; e o sitio escolhido.
local fouls: { [number]: Foul } = {}
local places: { [number]: string } = {}

local onWhistled: ((Foul, boolean) -> ())? = nil

-- Houve apito (e se foi por o arbitro ter sido apanhado a nao apitar).
function Whistle.onWhistled(fn: (Foul, boolean) -> ())
	onWhistled = fn
end

local function whereText(foul: Foul): string
	return if foul.inBox then "dentro da area" elseif foul.nearLine then "em cima da linha da area" else "no meio-campo"
end

-- Se foi dentro da area e penalti; na duvida da linha, conta onde foi mesmo.
local function fairPlace(foul: Foul): string
	return if foul.inBox then "penalti" else "livre"
end

--[[
	Uma entrada que pode ser falta. O jogo segue; abre-se a janela do apito. O
	arbitro automatico, se for ele, apita no fim — a nao ser que a equipa que
	sofreu tenha ficado com a bola, que e a vantagem.
]]
function Whistle.foul(foul: Foul)
	local fouledTeam = foul.fouled.teamId
	local id = Referee.openWindow({
		title = "Entrada de " .. Squad.label(foul.fouler) .. " sobre " .. Squad.label(foul.fouled),
		detail = whereText(foul) .. (if foul.fromBehind then "  ·  por tras" else "  ·  de frente"),
		favours = fouledTeam,
		against = foul.fouler.teamId,
		fair = function()
			local carrier = Football.carrier()
			return not (carrier and carrier.teamId == fouledTeam)
		end,
	})
	candidates[id] = foul
end

-- O cartao, com a bola ja parada. Sem pressa.
local function askCard(foul: Foul, place: string)
	local fouledTeam = foul.fouled.teamId
	local foulerTeam = foul.fouler.teamId
	local id = Referee.raise({
		kind = "cartao",
		title = "Cartao para " .. Squad.label(foul.fouler) .. "?",
		detail = (if place == "penalti" then "penalti" else "livre") .. "  ·  " .. whereText(foul),
		options = {
			{ id = "nada", label = "Nada", favours = foulerTeam },
			{ id = "amarelo", label = "Amarelo", favours = fouledTeam },
			{ id = "vermelho", label = "Vermelho", favours = fouledTeam },
		},
		fair = foul.card,
		default = "nada",
	})
	fouls[id] = foul
	places[id] = place
end

Referee.onWindowClosed(function(window, whistled, caught)
	local foul = candidates[window.id]
	candidates[window.id] = nil
	if not foul or not whistled then
		return
	end

	if not Football.whistleFoul(foul) then
		return
	end
	if onWhistled then
		onWhistled(foul, caught)
	end

	-- Em cima da linha da area, primeiro decide-se onde foi.
	if foul.nearLine then
		local id = Referee.raise({
			kind = "lugar",
			title = "Onde foi a falta de " .. Squad.label(foul.fouler) .. "?",
			detail = "em cima da linha da area",
			options = {
				{ id = "livre", label = "Livre fora da area", favours = foul.fouler.teamId },
				{ id = "penalti", label = "Penalti", favours = foul.fouled.teamId },
			},
			fair = fairPlace(foul),
			default = fairPlace(foul),
		})
		fouls[id] = foul
	else
		askCard(foul, fairPlace(foul))
	end
end)

--[[
	Uma escolha com a bola parada. Aplica-se ao jogo e devolve o texto que
	toda a gente ve (nada, enquanto ainda falta escolher o cartao).
]]
function Whistle.resolved(incident: Referee.Incident, choice: string): string?
	local foul = fouls[incident.id]
	fouls[incident.id] = nil
	local place = places[incident.id]
	places[incident.id] = nil
	if not foul then
		return nil
	end

	if incident.kind == "lugar" then
		askCard(foul, if choice == "penalti" then "penalti" else "livre")
		return nil
	end

	local action = place or fairPlace(foul)
	local lines = {
		(if action == "penalti" then "PENALTI" else "LIVRE") .. "  " .. Config.Teams[foul.fouled.teamId].short,
	}

	if choice == "amarelo" or choice == "vermelho" then
		local who = Squad.label(foul.fouler)
		local out = Squad.book(foul.fouler, choice)
		if choice == "vermelho" then
			table.insert(lines, "VERMELHO  " .. who)
		elseif out then
			table.insert(lines, "2.º AMARELO  " .. who .. "  ·  EXPULSO")
		else
			table.insert(lines, "AMARELO  " .. who)
		end
	end

	Football.resume(action, foul)
	return table.concat(lines, "   ·   ")
end

-- A janela aberta ja nao conta: houve golo, ou a parte acabou.
function Whistle.cancel()
	table.clear(candidates)
	Referee.cancelWindow()
end

return Whistle
