--!strict
--[[
	Arranque do servidor: liga os modulos e trata dos jogadores.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Teams = require(script.Parent:WaitForChild("Teams"))
local Stadium = require(script.Parent:WaitForChild("Stadium"))
local Atmosphere = require(script.Parent:WaitForChild("Atmosphere"))
local MatchLoop = require(script.Parent:WaitForChild("MatchLoop"))

-- Uma so batida por jogador. Sem isto, martelar o botao valia mais do que
-- acertar no compasso, e o ritmo deixava de significar alguma coisa.
local lastBeatUsed: { [Player]: number } = {}

local function currentBeat(now: number): (number, number)
	local index = math.floor(now / Config.Beat.interval + 0.5)
	local offset = math.abs(now - index * Config.Beat.interval)
	return index, offset
end

--[[
	Poe o jogador na bancada da equipa dele. Sem isto, escolher equipa era so uma
	etiqueta — e o que faz a escolha significar alguma coisa e estar mesmo la.
]]
local function sendToStand(player: Player, teamId: string)
	local point = Stadium.spawnPoint(teamId)
	if not point then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	-- Virado para o relvado, que e para onde se olha.
	root.CFrame = CFrame.lookAt(point, Vector3.new(0, point.Y - 6, 0))
end

Remotes.PickTeam.OnServerEvent:Connect(function(player, teamId)
	if type(teamId) ~= "string" or not Teams.isValid(teamId) then
		return
	end

	Teams.assign(player, teamId)
	sendToStand(player, teamId)

	-- E depois de cada morte ou respawn, volta para o mesmo lado.
	player.CharacterAdded:Connect(function()
		task.wait(0.4)
		if Teams.get(player) == teamId then
			sendToStand(player, teamId)
		end
	end)
end)

Remotes.Chant.OnServerEvent:Connect(function(player)
	local teamId = Teams.get(player)
	if not teamId then
		return
	end

	--[[
		O offset e medido a chegada, por isso a latencia do jogador empurra-o
		para cima: quem joga com ping alto acerta "tarde" aos olhos do servidor.
		A janela e larga o suficiente para absorver o normal. Se der problemas,
		sobe Config.Beat.window antes de complicar com compensacao.
	]]
	local index, offset = currentBeat(workspace:GetServerTimeNow())
	if offset > Config.Beat.window then
		return
	end
	if lastBeatUsed[player] == index then
		return
	end

	lastBeatUsed[player] = index
	Atmosphere.registerChant(teamId, offset)
end)

Players.PlayerRemoving:Connect(function(player)
	Teams.forget(player)
	lastBeatUsed[player] = nil
end)

-- A barra desce continuamente; e isso que obriga a manter o cantico.
RunService.Heartbeat:Connect(function(dt)
	Atmosphere.step(dt)
end)

-- Dez vezes por segundo chega para a barra parecer viva sem encher a rede.
task.spawn(function()
	while true do
		task.wait(0.1)
		Remotes.Atmosphere:FireAllClients(Atmosphere.all())
	end
end)

MatchLoop.onChange(function(snapshot)
	Remotes.MatchState:FireAllClients(snapshot)
end)

-- Quem chega a meio de um jogo tem de ver o estado atual, nao esperar pela
-- proxima mudanca de fase.
Players.PlayerAdded:Connect(function(player)
	Remotes.MatchState:FireClient(player, MatchLoop.snapshot())
end)

Stadium.build()
MatchLoop.start()

print("[Ultras FC] Servidor a postos.")
