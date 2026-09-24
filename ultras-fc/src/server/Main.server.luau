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
local Entrance = require(script.Parent:WaitForChild("Entrance"))

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
	-- Antes da entrada em campo, o arbitro espera no balneario, como os jogadores.
	local locker = Entrance.refereeSpot()
	local at = if locker then locker + Vector3.new(0, 3.2, 0) else Vector3.new(0, 3.2, -Config.Stadium.pitchWidth / 2 + 6)
	root.CFrame = CFrame.lookAt(at, Vector3.new(0, at.Y, 0))
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Footballers"
		end
	end
end

--[[
	Onde fica um adepto da claque agora. Antes do jogo, a porta da sede: e de
	la que sai o corteo. Com o jogo ja comecado, direto para a bancada da sua
	claque — quem chega tarde nao fica de fora.
]]
local function sendToClaque(player: Player, teamId: string)
	local phase = MatchLoop.phase()
	local beforeMatch = phase == "clubhouse" or phase == "corteo"
	local point = if beforeMatch then City.spawnPoint(teamId) or Stadium.spawnPoint(teamId) else Stadium.spawnPoint(teamId)
	if point then
		placeAt(player, point, Vector3.new(0, point.Y - 8, 0))
	end
end

-- Um som para toda a gente, pelo nome do Config.Sounds; com posicao, ouve-se dali.
local function sound(name: string, at: Vector3?)
	Remotes.Sound:FireAllClients(name, at)
end

local function isAdmin(player: Player): boolean
	return table.find(Config.Admins, player.UserId) ~= nil
end

-- Dentro da muralha do estadio: a bancada, a explanada e o relvado.
local function insideGround(position: Vector3): boolean
	local S = Config.Stadium
	local depth = S.rows * S.rowDepth
	local outX = S.pitchLength / 2 + S.standGap + depth + 26
	local outZ = S.pitchWidth / 2 + S.standGap + depth + 26
	return math.abs(position.X) <= outX and math.abs(position.Z) <= outZ
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- No topo da sua claque: nos degraus atras da baliza que ela ataca.
local function inOwnStand(position: Vector3, teamId: string): boolean
	local S = Config.Stadium
	local inner = S.pitchLength / 2 + S.standGap
	local across = position.X * Config.Teams[teamId].side
	return across >= inner - 3 and across <= inner + S.rows * S.rowDepth + 3 and math.abs(position.Z) <= S.pitchWidth / 2 + 4
end

--[[
	Quantas pessoas de claque ja estao no seu topo, e quantas ha. So contam
	pessoas: os bonecos ja la estao e nao decidem quando o jogo comeca.
]]
local function standsCount(): (number, number)
	local ready, total = 0, 0
	for _, player in Players:GetPlayers() do
		local teamId = Teams.get(player)
		if teamId then
			total += 1
			local root = rootOf(player)
			if root and inOwnStand(root.Position, teamId) then
				ready += 1
			end
		end
	end
	return ready, total
end

--[[
	Voltar a sede, a pedido (o botao "SEDE" no ecra). Os adeptos e os
	jogadores a da sua equipa; o arbitro, e quem nao e de ninguem, a praca.

	Ninguem e mandado para casa a forca: o dia de jogo recomeca na sede, mas
	quem quiser ficar na rua ou no estadio fica.
]]
local function sendHome(player: Player)
	local teamId = Teams.get(player)
	local f = Squad.byPlayer(player)
	local home = teamId or (f and f.teamId)
	local point = if home and Referee.current() ~= player then City.spawnPoint(home) else City.arrivalPoint()
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
			-- Quem apita nao e de nenhuma claque, nem leva material.
			Teams.forget(player)
			task.spawn(sendToPitch, player)
		end
		return
	end

	-- Jogar: "jogador:<equipa>". Quem entra em campo deixa a bancada e o apito.
	-- Na baliza: "baliza:<equipa>", o lugar do guarda-redes.
	local goalTeam = string.match(teamId, "^baliza:(%w+)$")
	local pitchTeam = goalTeam or string.match(teamId, "^jogador:(%w+)$")
	if pitchTeam then
		if Teams.isValid(pitchTeam) and Squad.join(player, pitchTeam, goalTeam ~= nil) then
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
	-- Quem vai para a bancada larga o apito: senao o jogo continuava a
	-- esperar pelas decisoes de quem ja nao esta a apitar.
	Referee.release(player)
	Teams.assign(player, teamId)

	task.spawn(sendToClaque, player, teamId)

	if first then
		player.CharacterAdded:Connect(function(character)
			local current = Teams.get(player)
			if not current then
				return
			end
			-- Deixa o Roblox acabar de montar o personagem antes de o mover.
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.2)
			sendToClaque(player, current)
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

	local root = rootOf(player)
	sound("tambor", root and root.Position)
end)

Players.PlayerRemoving:Connect(function(player)
	Teams.forget(player)
	Gear.forget(player)
	March.forget(player)
	Tifo.forget(player)
	Referee.forget(player)
	Squad.leave(player)
	lastHit[player] = nil
end)

local playing = false

-- A barra desce continuamente; e isso que obriga a manter o cantico.
RunService.Heartbeat:Connect(function(dt)
	Atmosphere.step(dt)
	Squad.step(dt, os.clock())
	Entrance.step()
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
	Remotes.GearCount:FireClient(player, Gear.counts(player))
end

Gear.onCountChanged(function(player, counts)
	Remotes.GearCount:FireClient(player, counts)
end)

local lastPhase = ""
local lastGoalStamp = 0

MatchLoop.onChange(function(snapshot)
	Remotes.MatchState:FireAllClients(snapshot)

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

	local entered = snapshot.phase ~= lastPhase

	-- Fora das partes nao ha faltas a apitar.
	if entered and snapshot.phase ~= "first" and snapshot.phase ~= "second" then
		Whistle.cancel()
	end

	-- A sede: dia de jogo novo. Tabela limpa, tochas novas, e toda a gente de
	-- volta a sua sede. Guardar as tochas do jogo anterior nao faria sentido:
	-- sao para o momento, nao para acumular.
	if entered and snapshot.phase == "clubhouse" then
		Gear.refill()
		Tifo.refill()
		Football.resetClock()
		Squad.resetMatch()
		for _, teamId in Config.TeamOrder do
			Crowd.setMood(teamId, nil)
		end
		for _, player in Players:GetPlayers() do
			sendGearCount(player)
		end
	end

	-- Se a entrada foi saltada, ou o dia voltou ao principio, arruma-se.
	if entered and (snapshot.phase == "clubhouse" or snapshot.phase == "first") then
		Entrance.finish()
	end

	-- O corteo: as faixas aparecem a porta das sedes, e quem joga vai para o
	-- balneario esperar pela entrada em campo.
	if entered and snapshot.phase == "corteo" then
		March.arm(workspace:WaitForChild("Stadium"))
		Entrance.prepare()
	end

	-- Acabou a caminhada: espera-se que as bancadas estejam nos seus lugares.
	if entered and snapshot.phase == "espera" then
		March.stop()
	end

	--[[
		A entrada em campo. Quem ainda esta na rua fica na rua: o jogo acontece
		com ou sem ele, e o botao "SEDE" ou as pernas levam-no quando quiser.
	]]
	if entered and snapshot.phase == "entrada" then
		March.stop()
		Entrance.start()
	end

	if entered and snapshot.phase == "first" then
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

	-- Intervalo e fim: o apito comprido.
	if entered and (snapshot.phase == "halftime" or snapshot.phase == "fulltime") then
		sound("apito_fim")
	end

	--[[
		Apito final: quem ganhou fica em festa na bancada, quem perdeu senta-se
		calado. Empate, ninguem.
	]]
	if entered and snapshot.phase == "fulltime" then
		Referee.endMatch()
		local winner = MatchLoop.winner()
		for _, teamId in Config.TeamOrder do
			Crowd.setMood(teamId, if winner == nil then nil elseif teamId == winner then "festa" else "calada")
		end
		workspace:SetAttribute("LastWinner", winner or "")
	end

	-- Pontape de saida no inicio de cada parte: a primeira sai a casa, a
	-- segunda os visitantes. Depois de cada golo sai quem o sofreu (Football).
	if entered then
		Football.setPhase(snapshot.phase)
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
Football.onGoal(function(teamId, scorer)
	-- Uma entrada ainda em aberto ja nao se apita: o golo conta.
	Whistle.cancel()
	MatchLoop.scoreGoal(teamId)

	-- A bancada de quem marcou vai ao ar; a de quem sofreu senta-se e cala-se.
	for _, id in Config.TeamOrder do
		Crowd.setMood(id, if id == teamId then "festa" else "calada")
	end

	-- Uma pessoa que marca corre sozinha para a sua claque (Football.client).
	local party = Football.celebration()
	if scorer and scorer.player and party then
		Remotes.Celebrate:FireClient(scorer.player, party.spot)
	end
end)

-- Acabou a festa: a bancada volta ao tambor, e ha pontape de saida.
Football.onCelebrationEnd(function()
	for _, id in Config.TeamOrder do
		Crowd.setMood(id, nil)
	end
end)

-- Enquanto se festeja, a parte nao acaba: o intervalo espera pelo fim da festa.
MatchLoop.holdWhile(Football.celebrating)

--[[
	A espera pelas bancadas acaba quando todas as pessoas de claque estao no
	seu topo — e logo, se nao houver nenhuma. Nunca fica a espera sem fim: o
	MatchLoop corta-a ao fim de Config.Match.waitLength.
]]
MatchLoop.readyWhen(function()
	local ready, total = standsCount()
	return ready >= total
end)

-- Quantos ja estao na bancada, para o ecra da espera.
task.spawn(function()
	while true do
		task.wait(0.5)
		if MatchLoop.phase() == "espera" then
			local ready, total = standsCount()
			workspace:SetAttribute("StandsReady", ready)
			workspace:SetAttribute("StandsTotal", total)
		end
	end
end)

Football.onKick(function(at)
	sound("pontape", at)
end)

Football.onKickoffWhistle(function()
	sound("apito_inicio")
end)

--[[
	Uma entrada que pode ser falta: o jogo segue, e o arbitro (pessoa ou
	automatico) tem dois segundos para apitar.
]]
Football.onFoul(function(foul)
	Whistle.foul(foul)
end)

-- Apitou: o jogo parou no sitio da entrada, e toda a gente ouve e ve porque.
Whistle.onWhistled(function(foul, caught)
	sound("apito_falta", foul.at)
	-- Apanhado, o ecra junta "ARBITRO APANHADO" a frente.
	local text = "APITO  ·  falta de " .. Squad.label(foul.fouler)
	Remotes.RefState:FireAllClients({
		state = Referee.state(),
		resolved = { kind = "apito", choice = "apitar", caught = caught, text = text },
	})
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
		window = Referee.windowForClient(),
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
	elseif action == "dive" then
		Football.dive(f)
	elseif action == "kick" and type(value) == "table" then
		local power, curve, height = value.power, value.curve, value.height
		if type(power) == "number" and type(curve) == "number" and type(height) == "number" then
			Football.kick(f, power, curve, height)
		end
	end
end)

--[[
	Saltar de fase, para testes e para mostrar o jogo sem esperar. Quem pode e
	a lista Config.Admins, e e aqui, no servidor, que se confirma: o botao no
	ecra so aparece aos admins, mas um cliente consegue mandar o pedido na
	mesma, e por isso nao e o botao que decide.
]]
local lastSkip = 0
Remotes.Admin.OnServerEvent:Connect(function(player, action)
	if action ~= "skip" or not isAdmin(player) then
		return
	end
	-- Um salto de cada vez: dois cliques seguidos nao saltam duas fases.
	if os.clock() - lastSkip < 1 then
		return
	end
	lastSkip = os.clock()
	print(string.format("[Ultras FC] %s saltou a fase %s", player.Name, MatchLoop.phase()))
	MatchLoop.skip()

	-- Saltar a fase e ficar para tras nao serve de nada: cada um vai para onde
	-- devia estar agora. Quem joga, o campo ja o pos no lugar (balneario ou
	-- pontape de saida).
	for _, other in Players:GetPlayers() do
		local teamId = Teams.get(other)
		if Referee.current() == other then
			task.spawn(sendToPitch, other)
		elseif teamId then
			task.spawn(sendToClaque, other, teamId)
		end
	end
end)

-- O menu de animacoes: o servidor so guarda qual e, e cada ecra anima-a.
local EMOTE_IDS: { [string]: boolean } = {}
for _, emote in Config.Emotes do
	EMOTE_IDS[emote.id] = true
end
Remotes.Emote.OnServerEvent:Connect(function(player, id)
	if type(id) ~= "string" then
		return
	end
	player:SetAttribute("Emote", if EMOTE_IDS[id] then id else nil)
end)

-- O botao "SEDE": volta-se quando se quer, nunca a forca.
local lastHome: { [Player]: number } = {}
Remotes.Home.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if (lastHome[player] or 0) + 3 > now then
		return
	end
	lastHome[player] = now
	task.spawn(sendHome, player)
end)
Players.PlayerRemoving:Connect(function(player)
	lastHome[player] = nil
end)

Gear.start()
MatchLoop.start()

print("[Ultras FC] Servidor a postos.")

-- Quantas pecas criou cada parte. Os bonecos nascem aos poucos, dai a espera.
task.delay(5, Budget.report)
