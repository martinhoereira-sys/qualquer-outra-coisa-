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
local Squad = require(script.Parent:WaitForChild("Squad"))
local Football = require(script.Parent:WaitForChild("Football"))
local Bots = require(script.Parent:WaitForChild("Bots"))
local Whistle = require(script.Parent:WaitForChild("Whistle"))
local City = require(script.Parent:WaitForChild("City"))
local Crowd = require(script.Parent:WaitForChild("Crowd"))
local Referee = require(script.Parent:WaitForChild("Referee"))
local Clubhouse = require(script.Parent:WaitForChild("Clubhouse"))
local March = require(script.Parent:WaitForChild("March"))
local Atmosphere = require(script.Parent:WaitForChild("Atmosphere"))
local MatchLoop = require(script.Parent:WaitForChild("MatchLoop"))
local Tifo = require(script.Parent:WaitForChild("Tifo"))
local Budget = require(script.Parent:WaitForChild("Budget"))

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

--[[
	Quem apita fica no relvado, junto ao meio-campo: tem de ver o jogo para o
	decidir. A bola e os jogadores passam por ele — um arbitro que desviasse a
	bola era mais um jogador.
]]
local function sendToPitch(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	local at = Vector3.new(0, 3.2, -Config.Stadium.pitchWidth / 2 + 6)
	root.CFrame = CFrame.lookAt(at, Vector3.new(0, at.Y, 0))
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Footballers"
		end
	end
end

local function sendToStand(player: Player, teamId: string)
	local point = City.spawnPoint(teamId) or Stadium.spawnPoint(teamId)
	if point then
		placeAt(player, point, Vector3.new(0, point.Y - 8, 0))
	end
end

Remotes.PickTeam.OnServerEvent:Connect(function(player, teamId)
	if type(teamId) ~= "string" then
		return
	end

	-- O apito e um papel como os outros, escolhido a entrada.
	if teamId == "arbitro" then
		if Referee.take(player) then
			Squad.leave(player)
			task.spawn(sendToPitch, player)
		end
		return
	end

	-- Jogar: "jogador:<equipa>". Quem entra em campo deixa a bancada e o apito.
	local pitchTeam = string.match(teamId, "^jogador:(%w+)$")
	if pitchTeam then
		if Teams.isValid(pitchTeam) and Squad.join(player, pitchTeam) then
			Teams.forget(player)
			Referee.release(player)
		end
		return
	end

	if not Teams.isValid(teamId) then
		return
	end

	-- Uma vez so: se a pessoa carregar no botao duas vezes, nao fica com duas
	-- ligacoes a atirarem-na para a bancada a cada respawn.
	local first = Teams.get(player) == nil
	Squad.leave(player)
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
	Tifo.forget(player)
	Referee.release(player)
	Squad.leave(player)
	lastHit[player] = nil
end)

local playing = false

-- A barra desce continuamente; e isso que obriga a manter o cantico.
RunService.Heartbeat:Connect(function(dt)
	Atmosphere.step(dt)
	Squad.step(dt, os.clock())
	Football.step(dt)
	Bots.step(dt)
	March.step(dt)
	Referee.step(dt)

	for teamId, value in intensity do
		intensity[teamId] = math.max(value - Config.Drum.intensityDecay * dt, 0)
	end
	Crowd.step(dt, intensity)
end)

-- Dez vezes por segundo chega para a barra parecer viva sem encher a rede.
task.spawn(function()
	while true do
		task.wait(0.1)
		Remotes.Atmosphere:FireAllClients(Atmosphere.all())
	end
end)

-- O que resta a cada um na mochila, para o rodape do ecra.
local function sendGearCount(player: Player)
	Remotes.GearCount:FireClient(player, {
		tocha = Gear.remaining(player, "tocha"),
		fumo = Gear.remaining(player, "fumo"),
		tambor = Gear.remaining(player, "tambor"),
	})
end

Gear.onCountChanged(function(player, counts)
	Remotes.GearCount:FireClient(player, counts)
end)

local lastPhase = ""
local lastGoalStamp = 0

MatchLoop.onChange(function(snapshot)
	Remotes.MatchState:FireAllClients(snapshot)

	local wasPlaying = playing
	playing = snapshot.phase == "first" or snapshot.phase == "second"
	Tifo.setPlaying(playing)

	-- Os dois momentos do tifo: o apito inicial e o golo.
	if snapshot.phase == "first" and lastPhase ~= "first" then
		Tifo.markKickoff()
	end
	if snapshot.lastGoal and snapshot.goalStamp > lastGoalStamp then
		lastGoalStamp = snapshot.goalStamp
		Tifo.markGoal(snapshot.lastGoal)
	end

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
		Tifo.refill()
		for _, player in Players:GetPlayers() do
			sendGearCount(player)
		end
	end

	if snapshot.phase == "fulltime" and lastPhase ~= "fulltime" then
		Referee.endMatch()
	end

	-- Pontape de saida no inicio de cada parte: a primeira sai a casa, a
	-- segunda os visitantes. Depois de cada golo sai quem o sofreu (Football).
	if snapshot.phase ~= lastPhase then
		Football.setPhase(snapshot.phase)
		if snapshot.phase == "warmup" then
			Football.resetClock()
			Squad.resetMatch()
		end
		if snapshot.phase == "first" then
			Football.kickOff(Config.TeamOrder[1])
		elseif snapshot.phase == "second" then
			Football.kickOff(Config.TeamOrder[2])
		end
	end

	lastPhase = snapshot.phase
end)

-- Quem chega a meio de um jogo tem de ver o estado atual, nao esperar pela
-- proxima mudanca de fase.
Players.PlayerAdded:Connect(function(player)
	Remotes.MatchState:FireClient(player, MatchLoop.snapshot())
	sendGearCount(player)
	Tifo.sync(player)

	task.spawn(sendToSquare, player)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		if Referee.current() == player then
			sendToPitch(player)
		elseif not Teams.get(player) and not Squad.byPlayer(player) then
			sendToSquare(player)
		end
	end)
end)

Clubhouse.onStartMarch(function(teamId)
	March.launch(teamId)
end)

Stadium.build()
Squad.build(workspace:WaitForChild("Stadium"))
Budget.run("Jogo", Football.build, workspace:WaitForChild("Stadium"))
Budget.run("Adeptos", Crowd.build, workspace:WaitForChild("Stadium"))
Tifo.build(workspace:WaitForChild("Stadium"))

-- O lider dispara o tifo; cada um levanta a sua cartolina.
Remotes.Tifo.OnServerEvent:Connect(function(player, action, designId)
	if action == "launch" and type(designId) == "string" then
		Tifo.launch(player, designId)
	elseif action == "lift" then
		Tifo.lift(player)
	end
end)

--[[
	Um golo. Entra no marcador; o fora de jogo, quando houver, e o arbitro que
	o ve.
]]
Football.onGoal(function(teamId)
	MatchLoop.scoreGoal(teamId)
end)

-- Uma falta: o jogo ja parou, e o arbitro (pessoa ou automatico) decide.
Football.onFoul(function(foul)
	Whistle.foul(foul)
end)

Referee.onResolved(function(incident, choice, caught)
	local text = Whistle.resolved(incident, choice)

	Remotes.RefState:FireAllClients({
		state = Referee.state(),
		resolved = { kind = incident.kind, choice = choice, caught = caught, text = text },
	})
end)

-- Expulso: sai do relvado e volta a praca, como quem acabou de chegar.
Squad.onSentOff(function(player)
	task.spawn(sendToSquare, player)
end)

Referee.onState(function()
	local pending = Referee.pendingForClient()
	Remotes.RefState:FireAllClients({
		state = Referee.state(),
		pending = pending,
		pressure = Referee.pressureSnapshot(),
	})

	local ref = Referee.current()
	if ref then
		Remotes.Incident:FireClient(ref, pending, Referee.pressureSnapshot())
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

-- O que o jogador faz com a bola. O servidor e que sabe se ele a tem.
Remotes.Football.OnServerEvent:Connect(function(player, action, value)
	local f = Squad.byPlayer(player)
	if not f then
		return
	end
	if action == "sprint" then
		Squad.setSprint(player, value == true)
	elseif action == "kick" and type(value) == "table" then
		local power, curve, height = value.power, value.curve, value.height
		if type(power) == "number" and type(curve) == "number" and type(height) == "number" then
			Football.kick(f, power, curve, height)
		end
	end
end)

Gear.start()
MatchLoop.start()

print("[Ultras FC] Servidor a postos.")

-- Quantas pecas criou cada parte. Os bonecos nascem aos poucos, dai a espera.
task.delay(5, Budget.report)
