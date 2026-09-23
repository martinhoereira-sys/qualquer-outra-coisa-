--!strict
--[[
	A ponte entre o relvado e o arbitro.

	O Football ve o que aconteceu (uma falta, onde, como); o Referee decide, com
	uma pessoa ou sozinho. Aqui transforma-se uma coisa na outra: que botoes o
	painel mostra, a quem aproveita cada um, qual seria a decisao justa — e,
	decidido, o que isso faz ao jogo (livre, penalti, cartao, expulsao).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Squad = require(script.Parent:WaitForChild("Squad"))
local Football = require(script.Parent:WaitForChild("Football"))
local Referee = require(script.Parent:WaitForChild("Referee"))

type Foul = Football.Foul

local Whistle = {}

local fouls: { [number]: Foul } = {}

local CARD_LABEL = { amarelo = "amarelo", vermelho = "vermelho" }

--[[
	Uma falta. Os cartoes vao dentro do botao da falta — um clique, nao dois
	paineis seguidos, que paravam o jogo o dobro. Na duvida da linha da area, o
	painel e so onde foi: penalti ou livre fora da area.
]]
function Whistle.foul(foul: Foul)
	local fouledTeam = foul.fouled.teamId
	local foulerTeam = foul.fouler.teamId
	local options: { Referee.Option } = {
		{ id = "segue", label = "Segue", favours = foulerTeam },
	}
	local fair: string

	if foul.nearLine then
		table.insert(options, { id = "livre", label = "Livre fora da area", favours = fouledTeam })
		table.insert(options, { id = "penalti", label = "Penalti", favours = fouledTeam })
		fair = if foul.inBox then "penalti" else "livre"
	else
		local base = if foul.inBox then "penalti" else "livre"
		local name = if foul.inBox then "Penalti" else "Livre"
		table.insert(options, { id = base, label = name, favours = fouledTeam })
		table.insert(options, { id = base .. "+amarelo", label = name .. " + amarelo", favours = fouledTeam })
		table.insert(options, { id = base .. "+vermelho", label = name .. " + vermelho", favours = fouledTeam })
		fair = if foul.card == "nada" then base else base .. "+" .. foul.card
	end

	local where = if foul.inBox then "dentro da area" elseif foul.nearLine then "em cima da linha da area" else "no meio-campo"
	local id = Referee.raise({
		kind = "falta",
		title = "Falta de " .. Squad.label(foul.fouler) .. " sobre " .. Squad.label(foul.fouled),
		detail = where .. (if foul.fromBehind then "  ·  por tras" else "  ·  de frente"),
		options = options,
		fair = fair,
		default = "segue",
	})
	fouls[id] = foul
end

--[[
	O arbitro decidiu. Aplica-se ao jogo e devolve o texto que toda a gente ve.
]]
function Whistle.resolved(incident: Referee.Incident, choice: string): string?
	if incident.kind ~= "falta" then
		return nil
	end
	local foul = fouls[incident.id]
	fouls[incident.id] = nil
	if not foul then
		return nil
	end

	local action, card = string.match(choice, "^(%a+)%+?(%a*)$")
	action = action or "segue"

	local lines = {}
	if action == "segue" then
		table.insert(lines, "SEGUE")
	else
		local team = Config.Teams[foul.fouled.teamId].short
		table.insert(lines, (if action == "penalti" then "PENALTI" else "LIVRE") .. "  " .. team)
	end

	if card and CARD_LABEL[card] then
		local who = Squad.label(foul.fouler)
		local out = Squad.book(foul.fouler, card)
		if card == "vermelho" then
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

return Whistle
