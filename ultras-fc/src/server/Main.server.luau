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
local Gear = require(script.Parent:WaitForChild("Gear"))
local Pitch = require(script.Parent:WaitForChild("Pitch"))
local City = require(script.Parent:WaitForChild("City"))
local March = require(script.Parent:WaitForChild("March"))
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
	Poe o jogador a porta da sede da sua claque, na cidade.

	Nao na bancada: nao se entra num estadio por magia. Sai-se da sede, anda-se
	pela avenida e chega-se la — e no caminho que o corteo ha-de acontecer, e um
	jogo que te punha ja sentado perdia a melhor parte.

	Espera pelo corpo em vez de desistir se ele ainda nao existir: escolher
	equipa antes do personagem carregar e o caso normal, nao a excepcao.
]]
local function sendToStand(player: Player, teamId: string)
	local point = City.spawnPoint(teamId) or Stadium.spawnPoint(teamId)
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

--[[
	Um cantico. Vem da tecla E ou de uma pancada no tambor — o caminho e o mesmo,
	so muda quanto vale.
]]
local function registerChant(player: Player, multiplier: number)
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
	Atmosphere.registerChant(teamId, offset, multiplier)
end

Remotes.Chant.OnServerEvent:Connect(function(player)
	registerChant(player, Gear.drumMultiplier(player))
end)

Gear.onDrumHit(function(player)
	registerChant(player, Config.Gear.tambor.chantMultiplier)
end)

Gear.onCountChanged(function(player, counts)
	Remotes.GearCount:FireClient(player, counts)
end)

local function sendGearCount(player: Player)
	Remotes.GearCount:FireClient(player, {
		tocha = Gear.remaining(player, "tocha"),
		fumo = Gear.remaining(player, "fumo"),
		tambor = Gear.remaining(player, "tambor"),
	})
end

-- O cliente pede material; ele aparece na mochila e usa-se com a mao.
Remotes.Gear.OnServerEvent:Connect(function(player, kind)
	if type(kind) == "string" then
		Gear.issue(player, kind)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Teams.forget(player)
	Gear.forget(player)
	March.forget(player)
	lastBeatUsed[player] = nil
end)

local playing = false

-- A barra desce continuamente; e isso que obriga a manter o cantico.
RunService.Heartbeat:Connect(function(dt)
	Atmosphere.step(dt)
	Pitch.step(dt, playing)
	March.step(dt)
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

	local wasPlaying = playing
	playing = snapshot.phase == "first" or snapshot.phase == "second"

	-- O corteo sai no aquecimento e acaba ao apito.
	if snapshot.phase == "warmup" and lastPhase ~= "warmup" then
		March.start(workspace:WaitForChild("Stadium"))
	end

	if playing and not wasPlaying then
		-- Soma o que cada claque trouxe da rua e poe a bancada a arrancar dai.
		local bonus: { [string]: number } = {}
		for _, player in Players:GetPlayers() do
			local teamId = Teams.get(player)
			if teamId then
				bonus[teamId] = (bonus[teamId] or 0)
					+ March.creditFor(player) * Config.March.atmosphereBonus
			end
		end
		Atmosphere.kickOff(bonus)
		March.stop()
	end

	-- Jogo novo, tochas novas. Guardar as do jogo anterior nao faria sentido:
	-- sao para o momento, nao para acumular.
	if snapshot.phase == "warmup" and lastPhase ~= "warmup" then
		Gear.refill()
		for _, player in Players:GetPlayers() do
			sendGearCount(player)
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
	sendGearCount(player)
end)

Stadium.build()
Pitch.build(workspace:WaitForChild("Stadium"))

-- A bola entrar na baliza e que marca. O ambiente da bancada ja entrou na
-- pontaria do remate, la no campo.
Pitch.onGoal(function(teamId)
	MatchLoop.scoreGoal(teamId)
end)

Gear.start()
MatchLoop.start()

print("[Ultras FC] Servidor a postos.")
