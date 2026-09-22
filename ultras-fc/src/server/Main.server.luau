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
local Crowd = require(script.Parent:WaitForChild("Crowd"))
local Referee = require(script.Parent:WaitForChild("Referee"))
local Clubhouse = require(script.Parent:WaitForChild("Clubhouse"))
local March = require(script.Parent:WaitForChild("March"))
local Atmosphere = require(script.Parent:WaitForChild("Atmosphere"))
local MatchLoop = require(script.Parent:WaitForChild("MatchLoop"))

--[[
	A forca do tambor de cada bancada, de 0 a 1.

	Sobe a cada pancada e desce sozinha. E ela que manda na claque: com o tambor
	parado a bancada mexe-se devagar, a bater salta a serio.
]]
local intensity: { [string]: number } = {}
local lastHit: { [Player]: number } = {}

--[[
	Onde cada papel aparece.

	Os adeptos a porta da sede da sua claque; quem apita, na praca, que fica
	fora das duas — nao se entra num estadio por magia, e o caminho ate la e a
	melhor parte.

	Ambas esperam pelo corpo em vez de desistir se ele ainda nao existir:
	escolher o papel antes do personagem carregar e o caso normal, nao a
	excepcao, e desistir ai deixava a pessoa largada onde nasceu.
]]
local function placeAt(player: Player, point: Vector3, lookAt: Vector3?)
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	root.CFrame = lookAt and CFrame.lookAt(point, lookAt) or CFrame.new(point)
end

local function sendToSquare(player: Player)
	local point = City.arrivalPoint()
	if point then
		placeAt(player, point)
	end
end

local function sendToStand(player: Player, teamId: string)
	local point = City.spawnPoint(teamId) or Stadium.spawnPoint(teamId)
	if point then
		placeAt(player, point, Vector3.new(point.X, point.Y - 8, point.Z - 40))
	end
end

Remotes.PickTeam.OnServerEvent:Connect(function(player, teamId)
	if type(teamId) ~= "string" then
		return
	end

	-- O apito e um papel como os outros, escolhido a entrada.
	if teamId == "arbitro" then
		if Referee.take(player) then
			task.spawn(sendToSquare, player)
		end
		return
	end

	if not Teams.isValid(teamId) then
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

Gear.onDrumHit(function(player)
	local teamId = Teams.get(player)
	if not teamId then
		return
	end

	-- Uma pancada de cada vez: martelar o botao nao vale mais do que bater.
	local now = os.clock()
	if (lastHit[player] or 0) + Config.Drum.minInterval > now then
		return
	end
	lastHit[player] = now

	intensity[teamId] = math.min((intensity[teamId] or 0) + Config.Drum.intensityPerHit, 1)
	Atmosphere.registerDrum(teamId)
end)

Players.PlayerRemoving:Connect(function(player)
	Teams.forget(player)
	Gear.forget(player)
	March.forget(player)
	Referee.release(player)
	lastHit[player] = nil
end)

local playing = false

-- A barra desce continuamente; e isso que obriga a manter o cantico.
RunService.Heartbeat:Connect(function(dt)
	Atmosphere.step(dt)
	Pitch.step(dt, playing)
	March.step(dt)
	Referee.step(dt)

	for teamId, value in intensity do
		intensity[teamId] = math.max(value - Config.Drum.intensityDecay * dt, 0)
	end
	Crowd.step(os.clock(), intensity)
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
		March.arm(workspace:WaitForChild("Stadium"))
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

	if snapshot.phase == "fulltime" and lastPhase ~= "fulltime" then
		Referee.endMatch()
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

	task.spawn(sendToSquare, player)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		if not Teams.get(player) then
			sendToSquare(player)
		end
	end)
end)

Clubhouse.onStartMarch(function(teamId)
	March.launch(teamId)
end)

Stadium.build()
Pitch.build(workspace:WaitForChild("Stadium"))
Crowd.build(workspace:WaitForChild("Stadium"))

-- A bola entrar na baliza e que marca. O ambiente da bancada ja entrou na
-- pontaria do remate, la no campo.
--[[
	Um golo. Parte deles fica por confirmar: e o arbitro que decide se conta.

	Sem arbitro em campo, `raise` devolve falso e o golo sobe direto — um jogo
	nao pode parar a espera de uma pessoa que nao esta la.
]]
Pitch.onGoal(function(teamId)
	if math.random() < Config.Referee.contestedGoalChance and Referee.raise("golo", teamId) then
		return
	end
	MatchLoop.scoreGoal(teamId)
end)

Referee.onResolved(function(incident, choice, caught)
	if incident.kind == "golo" and choice == "validar" then
		MatchLoop.scoreGoal(incident.teamId)
	elseif incident.kind == "penalti" and choice == "marcar" then
		MatchLoop.scoreGoal(incident.teamId)
	end

	Remotes.RefState:FireAllClients({
		state = Referee.state(),
		resolved = { kind = incident.kind, team = incident.teamId, choice = choice, caught = caught },
	})
end)

Referee.onState(function()
	Remotes.RefState:FireAllClients({
		state = Referee.state(),
		pending = Referee.pending(),
		pressure = Referee.pressureSnapshot(),
	})

	local ref = Referee.current()
	if ref then
		Remotes.Incident:FireClient(ref, Referee.pending(), Referee.pressureSnapshot())
	end
end)

Remotes.Decide.OnServerEvent:Connect(function(player, choice)
	if type(choice) == "string" then
		Referee.decide(player, choice)
	end
end)

Remotes.Pressure.OnServerEvent:Connect(function(player)
	Referee.addPressure(player)
end)

-- Um lance na area de vez em quando, para o arbitro ter o que decidir mesmo
-- quando nao ha golos.
task.spawn(function()
	while true do
		task.wait(Config.Referee.shoutInterval)
		if playing then
			local teamId = Config.TeamOrder[math.random(1, #Config.TeamOrder)]
			Referee.raise("penalti", teamId)
		end
	end
end)

Gear.start()
MatchLoop.start()

print("[Ultras FC] Servidor a postos.")
