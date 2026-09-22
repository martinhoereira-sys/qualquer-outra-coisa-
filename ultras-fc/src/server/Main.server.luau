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
local Flares = require(script.Parent:WaitForChild("Flares"))
local Pitch = require(script.Parent:WaitForChild("Pitch"))
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
	Poe o jogador na bancada da equipa dele.

	Espera pelo corpo em vez de desistir se ele ainda nao existir: escolher
	equipa antes do personagem carregar e o caso normal, nao a excepcao, e
	desistir ai deixava a pessoa largada no chao la fora — que e exactamente o
	que acontecia.
]]
local function sendToStand(player: Player, teamId: string)
	local point = Stadium.spawnPoint(teamId)
	if not point then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end

	-- Virado para o relvado, que e para onde se olha.
	root.CFrame = CFrame.lookAt(point, Vector3.new(0, point.Y - 8, 0))
end

Remotes.PickTeam.OnServerEvent:Connect(function(player, teamId)
	if type(teamId) ~= "string" or not Teams.isValid(teamId) then
		return
	end

	-- Uma vez so: se a pessoa carregar no botao duas vezes, nao fica com duas
	-- ligacoes a atirarem-na para a bancada a cada respawn.
	local first = Teams.get(player) == nil
	Teams.assign(player, teamId)

	task.spawn(sendToStand, player, teamId)

	if first then
		player.CharacterAdded:Connect(function(character)
			local current = Teams.get(player)
			if not current then
				return
			end
			-- Deixa o Roblox acabar de montar o personagem antes de o mover.
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.2)
			sendToStand(player, current)
		end)
	end
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

Flares.onCountChanged(function(player, count)
	Remotes.FlareCount:FireClient(player, count)
end)

local function sendFlareCount(player: Player)
	Remotes.FlareCount:FireClient(player, Flares.remaining(player))
end

-- O cliente pede uma tocha; ela aparece na mochila e acende-se ao usa-la.
Remotes.Flare.OnServerEvent:Connect(function(player)
	Flares.issue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	Teams.forget(player)
	Flares.forget(player)
	lastBeatUsed[player] = nil
end)

local playing = false

-- A barra desce continuamente; e isso que obriga a manter o cantico.
RunService.Heartbeat:Connect(function(dt)
	Atmosphere.step(dt)
	Pitch.step(dt, playing)
end)

-- Dez vezes por segundo chega para a barra parecer viva sem encher a rede.
task.spawn(function()
	while true do
		task.wait(0.1)
		Remotes.Atmosphere:FireAllClients(Atmosphere.all())
	end
end)

local lastPhase = ""
local lastGoalStamp = 0

MatchLoop.onChange(function(snapshot)
	Remotes.MatchState:FireAllClients(snapshot)

	-- Jogo novo, tochas novas. Guardar as do jogo anterior nao faria sentido:
	-- sao para o momento, nao para acumular.
	playing = snapshot.phase == "first" or snapshot.phase == "second"

	if snapshot.phase == "warmup" and lastPhase ~= "warmup" then
		Flares.refill()
		for _, player in Players:GetPlayers() do
			sendFlareCount(player)
		end
	end

	-- Bola ao centro em cada recomeco.
	if snapshot.phase ~= lastPhase and playing then
		Pitch.kickOff()
	end

	lastPhase = snapshot.phase
end)

-- Quem chega a meio de um jogo tem de ver o estado atual, nao esperar pela
-- proxima mudanca de fase.
Players.PlayerAdded:Connect(function(player)
	Remotes.MatchState:FireClient(player, MatchLoop.snapshot())
	sendFlareCount(player)
end)

Stadium.build()
Pitch.build(workspace:WaitForChild("Stadium"))

-- A bola entrar na baliza e que marca. O ambiente da bancada ja entrou na
-- pontaria do remate, la no campo.
Pitch.onGoal(function(teamId)
	MatchLoop.scoreGoal(teamId)
end)

Flares.start()
MatchLoop.start()

print("[Ultras FC] Servidor a postos.")
