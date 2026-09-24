--!strict
--[[
	Quem apoia quem, e quantos sao de cada lado.

	A contagem importa: e dela que sai o bonus de minoria, sem o qual a claque
	maior ganhava sempre e o jogo passaria a ser decidido pela assistencia.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Teams = {}

-- player -> teamId
local membership: { [Player]: string } = {}

-- Quem quer saber quando alguem entra, sai ou passa a lider (o material).
local listeners: { (Player) -> () } = {}

function Teams.onChanged(fn: (Player) -> ())
	table.insert(listeners, fn)
end

local function changed(player: Player)
	for _, fn in listeners do
		task.spawn(fn, player)
	end
end

function Teams.isValid(teamId: string): boolean
	return Config.Teams[teamId] ~= nil
end

function Teams.assign(player: Player, teamId: string)
	if not Teams.isValid(teamId) then
		return
	end
	membership[player] = teamId
	-- Atributo so para se ver de relance no Explorer durante os testes.
	player:SetAttribute("Team", teamId)
	changed(player)
end

function Teams.get(player: Player): string?
	return membership[player]
end

--[[
	O lider da claque. Um por claque, e e ele que leva o tambor e que da a ordem
	de sair. Se toda a gente pudesse ter tambor nao havia lider nenhum, havia
	barulho — o tambor so manda porque so ha um.
]]
local leaders: { [string]: Player } = {}

function Teams.leader(teamId: string): Player?
	local leader = leaders[teamId]
	if leader and leader.Parent then
		return leader
	end
	leaders[teamId] = nil
	return nil
end

function Teams.claimLeader(player: Player): boolean
	local teamId = membership[player]
	if not teamId or Teams.leader(teamId) then
		return false
	end
	leaders[teamId] = player
	player:SetAttribute("Leader", true)
	changed(player)
	return true
end

function Teams.isLeader(player: Player): boolean
	local teamId = membership[player]
	return teamId ~= nil and leaders[teamId] == player
end

function Teams.forget(player: Player)
	local teamId = membership[player]
	if teamId and leaders[teamId] == player then
		leaders[teamId] = nil
	end
	membership[player] = nil
	player:SetAttribute("Leader", nil)
	changed(player)
end

function Teams.count(teamId: string): number
	local total = 0
	for _, id in membership do
		if id == teamId then
			total += 1
		end
	end
	return total
end

--[[
	Quanto vale cada adepto desta bancada.

	Vinte que se deslocaram valem mais por cabeca do que cem em casa — e assim
	na vida real, e aqui impede que o jogo seja so uma contagem de cabecas.
]]
function Teams.minorityBonus(teamId: string): number
	local mine = Teams.count(teamId)
	if mine == 0 then
		return 1
	end

	local others = 0
	for otherId in Config.Teams do
		if otherId ~= teamId then
			others += Teams.count(otherId)
		end
	end
	if others == 0 then
		return 1
	end

	return math.clamp(others / mine, 1, Config.Atmosphere.minorityCap)
end

return Teams
