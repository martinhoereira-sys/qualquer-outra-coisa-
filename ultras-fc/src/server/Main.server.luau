--!strict
--[[
	Arranque do servidor: liga os modulos e trata dos jogadores.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TXT = Config.Text.main
local Remotes = require(Shared:WaitForChild("Remotes"))

local Teams = require(script.Parent:WaitForChild("Teams"))
local Stadium = require(script.Parent:WaitForChild("Stadium"))
local Gear = require(script.Parent:WaitForChild("Gear"))
local Lider = require(script.Parent:WaitForChild("Lider"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Uniform = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Uniform"))
local Derby = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Derby"))
local Faixas = require(script.Parent:WaitForChild("Faixas"))
local Ancora = require(script.Parent:WaitForChild("Ancora"))
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
local DayNight = require(script.Parent:WaitForChild("DayNight"))
local Money = require(script.Parent:WaitForChild("Money"))
local Competition = require(script.Parent:WaitForChild("Competition"))
local Trophy = require(script.Parent:WaitForChild("Trophy"))
local Calendar = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Calendar"))
local Schedule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Schedule"))
local Friendly = require(script.Parent:WaitForChild("Friendly"))
local Bikes = require(script.Parent:WaitForChild("Bikes"))
local Shops = require(script.Parent:WaitForChild("Shops"))
local Academy = require(script.Parent:WaitForChild("Academy"))
local Transit = require(script.Parent:WaitForChild("Transit"))
local TransitBuilder = require(script.Parent:WaitForChild("TransitBuilder"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Bank = require(script.Parent:WaitForChild("Bank"))
local StadiumPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StadiumPlan"))

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
	-- Quem vai de bicicleta desce antes: ela fica onde estava, nao vem junto.
	Bikes.dismount(player)
	if Squad.unseat(character) then
		task.wait(Squad.UNSEAT_WAIT)
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
	if Squad.unseat(character) then
		task.wait(Squad.UNSEAT_WAIT)
	end
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
--[[
	Where a supporter is put. ALWAYS AT HOME (the club's ground), whatever the
	phase. While a match is on one can go straight to the stadium (`toStadium`:
	the STADIUM button, or GO TO THE MATCH); having gone, one stays there until
	that match ends: coming back to life is at the stadium, and there is no way
	back home.
]]
local atStadium: { [Player]: number } = {} -- the slot in which each one went to the stadium
local function slotNow(): number
	return Schedule.at(Schedule.gameTime()).slot
end
local function sendToClaque(player: Player, teamId: string, toStadium: boolean?)
	if toStadium then
		atStadium[player] = slotNow()
		player:SetAttribute("NoEstadio", atStadium[player])
	end
	local there = atStadium[player] == slotNow()
	local point = if there then Stadium.spawnPoint(teamId) else City.spawnPoint(teamId) or Stadium.spawnPoint(teamId)
	if point then
		placeAt(player, point, Vector3.new(0, point.Y - 8, 0))
	end
end

-- Um som para toda a gente, pelo nome do Config.Sounds; com posicao, ouve-se dali.
local function sound(name: string, at: Vector3?)
	Remotes.Sound:FireAllClients(name, at)
end

-- How many match days this server has seen (each one is the other derby).
local matchDays = 0

local offerInvasion: (string) -> ()
local placeTeamBuses: () -> ()

local function isAdmin(player: Player): boolean
	return table.find(Config.Admins, player.UserId) ~= nil
end

-- Dentro do estadio: as bancadas, a explanada a volta e o relvado.
local function insideGround(position: Vector3): boolean
	return StadiumPlan.insideGround(position)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Na curva da sua claque (StadiumPlan).
local function inOwnStand(position: Vector3, teamId: string): boolean
	return StadiumPlan.inClaque(teamId, position) ~= nil
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

--[[
	Trocar de papel tem espera: depois de escolher (claque, jogador, baliza ou
	apito), so se volta a trocar passado Config.Match.switchCooldown segundos.
	Sem isto, saltava-se de papel a meio de um lance para o que dava jeito.
]]
local switchedAt: { [Player]: number } = {}

local function canSwitch(player: Player): boolean
	local last = switchedAt[player]
	return last == nil or os.clock() - last >= Config.Match.switchCooldown
end

local function markSwitch(player: Player)
	switchedAt[player] = os.clock()
	player:SetAttribute("SwitchReadyAt", workspace:GetServerTimeNow() + Config.Match.switchCooldown)
end

Players.PlayerRemoving:Connect(function(player)
	switchedAt[player] = nil
end)

local function pickTeam(player: Player, teamId: any)
	if type(teamId) ~= "string" or not canSwitch(player) then
		return
	end

	-- O apito e um papel como os outros, escolhido a entrada.
	if teamId == "arbitro" then
		-- Nobody referees a match with any of their clubs in it (ultra, player or referee).
		local mine, second = Money.clubOf(player)
		local third = Money.refereeOf(player)
		local other = Money.second2Of(player)
		for _, slot in Config.TeamOrder do
			local playing = Config.Teams[slot].club
			if playing == mine or playing == second or playing == third or playing == other then
				return
			end
		end
		if Referee.take(player) then
			markSwitch(player)
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
			markSwitch(player)
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
	markSwitch(player)
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
end

--[[
	The two derbies are played on the same day, one after the other. A club
	can be chosen at any time: if its match is the one on now, the player goes
	in right away; if it is the following one, the choice is kept (attribute
	"UpNext") and the player goes in when that match starts. When the derby
	changes, those whose club has just played wait for its next match instead
	of being handed the other club.
]]
local wish: { [Player]: { club: string, role: string } } = {}

local function clubPlace(clubId: string): string?
	local match = Config.Derbies[Derby.current()]
	return if match.home == clubId then "home" elseif match.away == clubId then "away" else nil
end

local function toWait(player: Player, clubId: string, role: string)
	wish[player] = { club = clubId, role = role }
	Squad.leave(player)
	Referee.release(player)
	Teams.forget(player)
	player:SetAttribute("Team", nil)
	player:SetAttribute("UpNext", clubId)
end

--[[
	MY CLUB AND THE SECOND CLUB (kept in the profile: Money).
	- One club is mine: chosen the first time, kept between sessions. Everything
	  of the claque comes from it. Changing it is deliberate ("mudar:<club>",
	  after the screen asked "do you really want to leave X?").
	- A second club can be followed ("seguir:<club>"): no claque, no curva, no
	  gear. It can be played for, as a starter, in the places its own people
	  left free.

	WHO GETS A PLACE IN THE TEAM, in this order:
	  1st  the players of the club itself (they go in as they ask, before kick-off);
	  2nd  the people who have it as their SECOND club: at kick-off (the
	       entrance), in the places still free;
	  3rd  bots, only in what is left after that.
	A bot never keeps a place a real person could have. But nobody walks into
	a match that is being played: whoever asks then goes in at the next match
	of that club, in the place of a bot.
]]
local seating = false -- the entrance: the second-club people are being given their places
--[[
	CHANGING ROLE PUTS ME AT THAT ROLE'S HOME: the ground of the club I am
	that for, not where I happened to be. (An ultra goes to his club's
	clubhouse; a player waiting for a place, to the ground of the club he
	plays for.)
]]
local lastRole: { [Player]: string } = {}
local function sendToClubHome(player: Player, clubId: string)
	local slot = nil
	for _, teamId in Config.TeamOrder do
		if Config.Teams[teamId].club == clubId then
			slot = teamId
		end
	end
	local point = if slot then City.spawnPoint(slot) else nil
	local site = (Config.Clubs :: any)[clubId].site
	if not point and site then
		point = Vector3.new(site.x, 8, site.z)
	end
	if point then
		placeAt(player, point, Vector3.new(0, point.Y - 8, 0))
	end
end

local function pickClub(player: Player, clubId: string, role: string)
	if not (Config.Clubs :: any)[clubId] or not canSwitch(player) then
		return
	end
	local kind = if role == "baliza" then "jogador" else role
	local changed = lastRole[player] ~= kind .. ":" .. clubId
	lastRole[player] = kind .. ":" .. clubId
	if changed then
		-- (Wherever I had gone as what I was before does not hold any more.)
		atStadium[player] = nil
		player:SetAttribute("NoEstadio", nil)
	end
	--[[
		A CLUB FOR EACH ROLE. The ultras' club (`mine`) and the club one plays
		for (`second`) are chosen apart, and may be the same. The first time a
		role is asked for, its club is the one asked with it; after that the
		ultras' club only changes at the other clubhouse, and the player's
		club in the profile ("papel:jogador:<club>"). A rival of one of my
		clubs is never another of them.
	]]
	local mine, second = Money.clubOf(player)
	local onPitch = role == "jogador" or role == "baliza"
	if onPitch then
		if not second then
			Money.setSecond(player, clubId)
			second = select(2, Money.clubOf(player))
		end
		-- One plays for two clubs at most: the first, and a second one.
		if clubId ~= second and clubId ~= Money.second2Of(player) then
			return
		end
	else
		if not mine then
			if Config.isRival(clubId, second) or Config.isRival(clubId, Money.refereeOf(player)) then
				return
			end
			Money.setClub(player, clubId)
			mine = clubId
		end
		if clubId ~= mine then
			return
		end
	end
	local slot = clubPlace(clubId)
	if not slot then
		-- Not playing now: the choice is kept for the club's next match.
		toWait(player, clubId, role)
		if changed then
			task.spawn(sendToClubHome, player, clubId)
		end
		return
	end
	if role == "jogador" or role == "baliza" then
		local f = Squad.byPlayer(player)
		local already = f ~= nil and f.teamId == slot
		local phase = MatchLoop.phase()
		local running = phase == "first" or phase == "halftime" or phase == "second" or phase == "fulltime"
		-- ("Its own": whoever has it as the FIRST club they play for. Whoever has
		-- it as the second gets a place at kick-off, in what is still free.)
		local own = clubId == second
		if not already and (running or (not own and not seating)) then
			wish[player] = { club = clubId, role = role }
			player:SetAttribute("UpNext", clubId)
			Remotes.Npc:FireClient(player, {
				title = (Config.Clubs :: any)[clubId].name,
				lines = { if running then Config.Text.hud.pitchNextMatch else Config.Text.hud.pitchAtKickOff },
			})
			if changed then
				task.spawn(sendToClubHome, player, clubId)
			end
			return
		end
	end
	wish[player] = { club = clubId, role = role }
	player:SetAttribute("UpNext", nil)
	pickTeam(player, if role == "jogador" then "jogador:" .. slot elseif role == "baliza" then "baliza:" .. slot else slot)
end

Remotes.PickTeam.OnServerEvent:Connect(function(player, what)
	if type(what) ~= "string" then
		return
	end
	-- Change club (the screen asked first), or follow a second one ("seguir:" alone stops following).
	local newClub = string.match(what, "^mudar:(%w+)$")
	if newClub and (Config.Clubs :: any)[newClub] then
		-- Only at that club's clubhouse, in person.
		local site = (Config.Clubs :: any)[newClub].site
		local root = rootOf(player)
		if not site or not root or (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(site.x, 0, site.z)).Magnitude > Config.SedeReach then
			Remotes.Npc:FireClient(player, { title = (Config.Clubs :: any)[newClub].name, lines = { Config.Text.sede.tooFar } })
			return
		end
		local old = Money.clubOf(player)
		Money.setClub(player, newClub)
		if old and Config.isRival(old, newClub) then
			-- To the rival: a traitor, and the new claque is told who he is.
			Money.markTraitor(player, old)
			local line = string.format(Config.Text.hud.traitorJoined, player.DisplayName, (Config.Clubs :: any)[old].name)
			for _, other in Players:GetPlayers() do
				if other ~= player and Money.clubOf(other) == newClub then
					Remotes.Npc:FireClient(other, { title = Config.Text.hud.traitor, lines = { line } })
				end
			end
		end
		pickClub(player, newClub, "adepto")
		return
	end
	-- From the profile: the second club one plays for is taken away ("tirar:jogador2").
	if what == "tirar:jogador2" then
		Money.setSecond2(player, nil)
		return
	end
	-- From the profile: "papel:<adepto|jogador|arbitro>:<club>" gives a role its club.
	local which, forClub = string.match(what, "^papel:(%w+):(%w+)$")
	if which and (Config.Clubs :: any)[forClub] then
		if which == "jogador" then
			-- The club one plays for changes here, whenever one wants.
			Money.setSecond(player, forClub)
		elseif which == "jogador2" then
			Money.setSecond2(player, forClub)
		elseif which == "adepto" and Money.clubOf(player) == nil then
			-- The ultras' club: only the first time here (after that, at the other clubhouse).
			local _, plays = Money.clubOf(player)
			if not Config.isRival(forClub, plays) and not Config.isRival(forClub, Money.refereeOf(player)) then
				Money.setClub(player, forClub)
			end
		end
		return
	end
	-- From the menu: "clube:<club>:<adepto|jogador|baliza>".
	local clubId, role = string.match(what, "^clube:(%w+):(%w+)$")
	if clubId and role then
		pickClub(player, clubId, role)
		return
	end
	if what == "arbitro" then
		wish[player] = nil
		player:SetAttribute("UpNext", nil)
	end
	pickTeam(player, what)
end)

-- At every clubhouse: the place where one joins that club (the screen asks first).
task.defer(function()
	local folder = Instance.new("Folder")
	folder.Name = "SedesInscricao"
	folder.Parent = workspace
	for _, clubId in Config.ClubOrder do
		local club = (Config.Clubs :: any)[clubId]
		local site = club.site
		if site then
			local spot = Instance.new("Part")
			spot.Name = "Inscricao_" .. clubId
			spot.Anchored = true
			spot.CanCollide = false
			spot.CanQuery = false
			spot.Transparency = 1
			spot.Size = Vector3.new(2, 2, 2)
			local at = Vector3.new(site.x, 4, site.z)
			if site.marker then
				local marker = workspace:FindFirstChild(site.marker, true)
				if marker and marker:IsA("Model") then
					local p = marker:GetPivot().Position
					at = Vector3.new(p.X, 4, p.Z)
				end
			else
				local ground = workspace:FindFirstChild("Recintos") and workspace.Recintos:FindFirstChild("Recinto_" .. clubId)
				local total = (ground and ground:GetAttribute("Total")) or 86
				at = Vector3.new(site.x, 4, site.z - total / 2 + 45)
			end
			spot.Position = at
			spot.Parent = folder
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = Config.Text.sede.join
			prompt.ObjectText = club.name
			prompt.AutoLocalize = true
			prompt.MaxActivationDistance = 14
			prompt.HoldDuration = 0.5
			prompt.RequiresLineOfSight = false
			prompt.Parent = spot
			prompt.Triggered:Connect(function(player)
				if Money.clubOf(player) ~= clubId then
					Remotes.PickTeam:FireClient(player, "confirmar", clubId)
				end
			end)
		end
	end
end)

-- Coming back: straight in with my club, as a supporter (no menu to go through).
local greeted: { [Player]: boolean } = {}
local function welcomeBack(player: Player)
	local mine = Money.clubOf(player)
	if mine and not greeted[player] and not Teams.get(player) and not Squad.byPlayer(player) and Referee.current() ~= player and not player:GetAttribute("UpNext") then
		greeted[player] = true
		pickClub(player, mine, "adepto")
	end
end
Players.PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("Clube"):Connect(function()
		welcomeBack(player)
	end)
end)
Players.PlayerRemoving:Connect(function(player)
	greeted[player] = nil
end)

-- Joining at the clubhouse desk also counts as choosing that club.
Teams.onChanged(function(player)
	local slot = Teams.get(player)
	if slot then
		local clubId = Config.Teams[slot].club
		if not Money.clubOf(player) then
			Money.setClub(player, clubId)
		end
		greeted[player] = true
		local w = wish[player]
		if not w or w.club ~= clubId then
			wish[player] = { club = clubId, role = "adepto" }
		end
		player:SetAttribute("UpNext", nil)
	end
end)

-- The derby changed: who was waiting for this match goes in, who has just
-- played waits for the next one.
local function derbyTurn()
	for _, player in Players:GetPlayers() do
		local w = wish[player]
		if w then
			local place = clubPlace(w.club)
			if place then
				-- In again if they were waiting, and also if the club changed places
				-- (home in one match, away in the next): never left in the other claque's stand.
				local f = Squad.byPlayer(player)
				local now = Teams.get(player) or (if f then f.teamId else nil)
				if player:GetAttribute("UpNext") or (now ~= nil and now ~= place) then
					switchedAt[player] = nil
					task.spawn(pickClub, player, w.club, w.role)
				end
			elseif Teams.get(player) or Squad.byPlayer(player) then
				toWait(player, w.club, w.role)
			end
		end
	end
end

--[[
	Whoever is waiting for a place on the pitch gets it now: the club's own
	players when the day starts (`second` false), the second-club people at
	the entrance (`second` true), in what is still free.
]]
local function seatWaiting(second: boolean)
	seating = second
	for _, player in Players:GetPlayers() do
		local w = wish[player]
		if w and player:GetAttribute("UpNext") and (w.role == "jogador" or w.role == "baliza") and clubPlace(w.club) then
			local mine = Money.clubOf(player)
			local _, firstClub = Money.clubOf(player)
			local own = firstClub == w.club
			if own ~= second then
				switchedAt[player] = nil
				pickClub(player, w.club, w.role)
			end
		end
	end
	seating = false
end

Gear.onDrumHit(function(player)
	Progress.markActive(player)
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
	wish[player] = nil
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

-- Tentou acender sem stock: diz-se onde arranjar mais.
Gear.onEmpty(function(player, kind)
	local name = kind
	for _, item in Config.Shop do
		if item.kind == kind then
			name = item.label
		end
	end
	Remotes.Npc:FireClient(player, {
		title = TXT.outOf .. name,
		lines = {
			TXT.theUltrasGiveOneRation,
			TXT.buyMoreFromADealer,
		},
	})
end)

Gear.onCountChanged(function(player, counts)
	Remotes.GearCount:FireClient(player, counts)
end)

--[[
	THE MATCH OF THE SLOT. The server asks Competition which match it plays
	(by who is inside), and puts its two clubs in the two places.
]]
local derbyOf: { [string]: number } = {}
for n, match in Config.Derbies do
	derbyOf[match.home .. ":" .. match.away] = n
end

local function chooseMatch(slot: number, late: boolean)
	local people: { [string]: number } = {}
	for _, player in Players:GetPlayers() do
		-- (A person counts for the club they are an ultra of, and for the one they play for.)
		local mine, plays = Money.clubOf(player)
		if mine then
			people[mine] = (people[mine] or 0) + 1
		end
		if plays and plays ~= mine then
			people[plays] = (people[plays] or 0) + 1
		end
		local also = Money.second2Of(player)
		if also and also ~= mine and also ~= plays then
			people[also] = (people[also] or 0) + 1
		end
	end
	local match = Competition.pick(slot, people, late)
	local n = derbyOf[match.fixture.home .. ":" .. match.fixture.away]
	if n then
		Derby.set(n)
	end
	print(string.format("[Ultras FC] slot %s: %s %s v %s%s", Schedule.clock(Schedule.slotStart(slot)), match.fixture.kind, match.fixture.home, match.fixture.away, if match.noFans then " (no fans)" else ""))
end

--[[
	The trophy ceremony: the trophy on the pitch, the captain of the winners
	lifting it, confetti in their colours. `kind` is "liga", "taca" or
	"supertaca"; `clubId` is who won it.
]]
local function ceremony(kind: string, clubId: string)
	local club = (Config.Clubs :: any)[clubId]
	if not club then
		return
	end
	Remotes.Npc:FireAllClients({ title = (Config.Text.trophy :: any)[kind], lines = { club.name } })
	-- The captain: of that club, if it is on this pitch (the armband, or the first one).
	local captain: any = nil
	for _, teamId in Config.TeamOrder do
		if Config.Teams[teamId].club == clubId then
			for _, f in Squad.team(teamId) do
				if f.model and (captain == nil or f.model:FindFirstChild("Bracadeira", true)) then
					captain = f
				end
			end
		end
	end
	task.spawn(Trophy.present, kind, club, if captain then captain.model else nil, function(at: Vector3, facing: Vector3)
		Squad.place(captain, at, facing)
	end, function(up: boolean)
		if captain then
			Squad.openArms(captain, up)
		end
	end)
end

-- A knockout match that ends level: penalties, kicked here on the server. Returns who goes through.
local function shootOut(): string
	local home, away = Config.Teams.home, Config.Teams.away
	local goals = { 0, 0 }
	local lines = {}
	local kick = 0
	while true do
		kick += 1
		for side = 1, 2 do
			local club = if side == 1 then home else away
			local scored = math.random() < Config.Competitions.penalty
			if scored then
				goals[side] += 1
			end
			table.insert(lines, string.format(if scored then Config.Text.comp.penaltyScored else Config.Text.comp.penaltyMissed, club.short, goals[1], goals[2]))
		end
		if kick >= 5 and goals[1] ~= goals[2] then
			break
		end
		if kick >= 12 then
			goals[if math.random() < 0.5 then 1 else 2] += 1
			break
		end
	end
	local winner = if goals[1] > goals[2] then home else away
	table.insert(lines, string.format(Config.Text.comp.goesThrough, winner.name))
	-- Only the last kicks fit on the screen.
	local shown = {}
	for i = math.max(1, #lines - 6), #lines do
		table.insert(shown, lines[i])
	end
	Remotes.Npc:FireAllClients({ title = Config.Text.comp.penalties, lines = shown })
	return winner.club
end

local pickedSlot = -1
local lastPhase = ""
local lastKey = "" -- phase, slot and night: a new one is a phase that has just started
local lastGoalStamp = 0

MatchLoop.onChange(function(snapshot)
	Progress.phaseChanged(snapshot.phase)
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

	-- The match of this slot, chosen once, whenever the slot comes (also when this
	-- server opens with it already going: then it joins it as a friendly).
	if not snapshot.night and snapshot.slot ~= pickedSlot then
		pickedSlot = snapshot.slot
		task.spawn(chooseMatch, snapshot.slot, snapshot.phase ~= "clubhouse" and snapshot.phase ~= "corteo")
	end
	local key = snapshot.phase .. ":" .. tostring(snapshot.slot) .. ":" .. tostring(snapshot.night)
	local entered = key ~= lastKey
	lastKey = key

	-- Fora das partes nao ha faltas a apitar.
	if entered and snapshot.phase ~= "first" and snapshot.phase ~= "second" then
		Whistle.cancel()
	end

	-- A sede: dia de jogo novo. Tabela limpa, tochas novas, e toda a gente de
	-- volta a sua sede. Guardar as tochas do jogo anterior nao faria sentido:
	-- sao para o momento, nao para acumular.
	if entered and snapshot.phase == "clubhouse" then
		matchDays += 1
		-- Dia de jogo novo: quem joga volta a academia, a treinar.
		Academy.setOpen(nil, true)
		for _, f in Squad.humans() do
			local spot = Academy.spotFor(f.teamId, f.slot)
			if spot then
				Squad.place(f, spot)
			end
		end
		Gear.refill()
		Tifo.refill()
		Lider.newMatch()
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
		-- Quem joga esta na academia do seu clube: vai no autocarro do clube,
		-- que abre as portas agora e arranca a tempo de chegar uns 30 s antes do
		-- fim do corteo (a claque tem o corteo inteiro).
		Entrance.prepare(Academy.anyOpen())
		for _, teamId in Config.TeamOrder do
			if Academy.isOpen(teamId) then
				local wait = math.max(Config.Academy.boardingTime, Config.Match.corteoLength - Transit.teamTripTime(teamId) - 30)
				Transit.boardTeamBus(teamId, wait)
				for _, f in Squad.humans() do
					local who = f.player
					if who and f.teamId == teamId then
						Remotes.Npc:FireClient(who, {
							title = TXT.theClubBusIsHere,
							lines = {
								TXT.itIsAtTheAcademy,
								TXT.itLeavesForTheStadium .. math.floor(wait) .. TXT.seconds,
							},
						})
					end
				end
			end
		end
		-- Quem nao tem academia (nao esta no mapa) vai logo para o balneario.
		for _, f in Squad.humans() do
			if not Academy.isOpen(f.teamId) then
				Squad.place(f, Stadium.lockerSpot(f.teamId, f.slot), Vector3.new(0, 0, -Stadium.mainSide()))
			end
		end
	end

	-- Acabou a caminhada: espera-se que as bancadas estejam nos seus lugares.
	if entered and snapshot.phase == "espera" then
		March.stop()
	end
	-- Friendlies are for the breaks and the night: they end by themselves a
	-- minute before an official match, and are off while it is on.
	do
		local allowed = snapshot.night
			or snapshot.phase == "clubhouse"
			or (snapshot.phase == "corteo" and snapshot.clock > Config.Friendly.stopBefore)
		if allowed ~= Friendly.allowed() then
			Friendly.setAllowed(allowed)
		end
	end
	if entered then
		-- The clubs' buses are only in the city around the match.
		Transit.showTeamBuses(snapshot.phase == "corteo" or snapshot.phase == "espera" or snapshot.phase == "entrada")
	end

	--[[
		A entrada em campo. Quem ainda esta na rua fica na rua: o jogo acontece
		com ou sem ele, e o botao "SEDE" ou as pernas levam-no quando quiser.
	]]
	if entered and snapshot.phase == "clubhouse" then
		task.defer(seatWaiting, false)
	end
	if entered and snapshot.phase == "entrada" then
		seatWaiting(true)
		March.stop()
		-- O autocarro ainda nao chegou (ou a fase foi saltada): ja ninguem espera.
		if Academy.anyOpen() then
			Academy.setOpen(nil, false)
			Squad.sendAllToLocker()
		end
		Entrance.start()
	end

	-- Com o jogo a decorrer a academia esta fechada (tambem quando se salta
	-- fases: o salto do corteo vai direto a 1a parte, sem entrada em campo).
	if entered and (snapshot.phase == "first" or snapshot.phase == "halftime" or snapshot.phase == "second" or snapshot.phase == "fulltime") then
		Academy.setOpen(nil, false)
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

		-- O que a claque ganha pelo jogo e pelo corteo paga-se agora no fim do
		-- jogo, como salario (Progress), conforme o nivel.
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
		-- The referee is told how many calls were right (counted on the server).
		local ref = Referee.current()
		if ref then
			local right, total = Referee.tallyOf(ref)
			if total > 0 then
				Remotes.Npc:FireClient(ref, { title = string.format(TXT.youGotOutOf, right, total), lines = { TXT.rightCallsEarnXp } })
			end
		end
		Referee.endMatch()
		-- The result goes to the tables (everything played counts; a friendly does not).
		do
			local now = Competition.playing()
			if now and now.counts then
				local penalties: string? = nil
				if Competition.knockout() and snapshot.score.home == snapshot.score.away then
					penalties = shootOut()
				end
				local fixture = now.fixture
				Competition.record(snapshot.score.home, snapshot.score.away, penalties)
				-- The cup final and the supercup end with a trophy.
				if fixture.id == "F" or fixture.id == "S" then
					local winner = Calendar.winner(fixture, { h = snapshot.score.home, a = snapshot.score.away, p = penalties })
					if winner then
						ceremony(if fixture.id == "F" then "taca" else "supertaca", winner)
					end
				end
			end
		end
		--[[
			SATURDAY NIGHT: the last official match of the week has just ended.
			The league closes there, in every server at the same moment, and
			there is a CHAMPION: the trophy on the pitch, the captain lifting it,
			confetti, and the champion's claque may invade the pitch if its capo
			wants. (In "tudoConta" nothing has to be "all played": whoever is in
			front at this moment wins.)
		]]
		-- One match less for the traitors who played it.
		for _, player in Players:GetPlayers() do
			-- (Only the matches played ON THE PITCH count: being in the claque does not.)
			if player:GetAttribute("Traidor") ~= nil and Squad.byPlayer(player) then
				Money.traitorTick(player)
			end
		end
		if Calendar.closesLeague(snapshot.slot) then
			local last = Competition.playing()
			local wait = if last and last.fixture.id == "F" then Config.Trophy.seconds else Config.Competitions.closeWait
			task.delay(wait, function()
				local champion = Competition.closeLeague()
				if champion then
					ceremony("liga", champion)
					for _, teamId in Config.TeamOrder do
						if Config.Teams[teamId].club == champion then
							offerInvasion(teamId)
						end
					end
				end
			end)
		end
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

-- O cenario todo preso ao chao (o que vem da Toolbox vem solto: um autocarro
-- deitava uma sede abaixo). Tambem o que se acrescentar ao mapa depois.
print(string.format("[Ultras FC] Cenario preso ao chao: %d pecas soltas prendidas.", Ancora.run()))

Stadium.build()
-- A academia e os transportes estao no mapa; se faltarem, fazem-se agora.
if not workspace:FindFirstChild("Transportes") then
	TransitBuilder.build(workspace)
end
Academy.start()
Transit.start()
-- Antes do jogo, quem joga aparece na academia.
Squad.setStartOverride(function(f)
	if f.player and Academy.isOpen(f.teamId) then
		return Academy.spotFor(f.teamId, f.slot)
	end
	return nil
end)
-- Each club's bus goes from its own ground (the place's club changes with the match).
function placeTeamBuses()
	local stops = workspace:FindFirstChild("Transportes") and workspace.Transportes:FindFirstChild("Paragens")
	for _, teamId in Config.TeamOrder do
		local line = if teamId == "home" then "EN" else "ES"
		local stop: Vector3? = nil
		for _, m in (if stops then stops:GetChildren() else {}) do
			local name = m:GetAttribute("Nome")
			if m:IsA("Model") and m:GetAttribute("Linhas") == line and type(name) == "string" and name:find("Estadio") then
				stop = m:GetPivot().Position
			end
		end
		if stop then
			local nodes, wait = City.busLoop(teamId, stop)
			if wait then
				Transit.setTeamRoute(teamId, nodes, wait, stop)
			end
		end
	end
end
placeTeamBuses()
-- O autocarro de um clube chegou ao estadio: a gente dele para o balneario.
-- Quando ja nao ha nenhum a caminho, 30 s depois entra-se em campo.
Transit.onTeamArrived(function(teamId)
	if not Academy.isOpen(teamId) then
		return
	end
	Academy.setOpen(teamId, false)
	for _, f in Squad.humans() do
		if f.teamId == teamId then
			Squad.place(f, Stadium.lockerSpot(f.teamId, f.slot), Vector3.new(0, 0, -Stadium.mainSide()))
			local who = f.player
			if who then
				Remotes.Npc:FireClient(who, { title = TXT.youAreAtTheStadium, lines = { TXT.dressingRoomYouWalkOut } })
			end
		end
	end
	if not Academy.anyOpen() then
		MatchLoop.entranceIn(30)
	end
end)
-- Os bonecos a ver o treino: um por cada lugar ainda sem pessoa.
task.spawn(function()
	while true do
		Academy.setWatchers(Squad.botSlots())
		task.wait(2)
	end
end)
-- As horas a andar, com o estadio e a cidade ja de pe (para achar as luzes).
DayNight.start()
Squad.build(workspace:WaitForChild("Stadium"))
Budget.run("Jogo", Football.build, workspace:WaitForChild("Stadium"))
Budget.run("Adeptos", Crowd.build, workspace:WaitForChild("Stadium"))
Tifo.build(workspace:WaitForChild("Stadium"))

-- O lider dispara o tifo; cada um levanta a sua cartolina.
Remotes.Tifo.OnServerEvent:Connect(function(player, action, designId)
	Progress.markActive(player)
	if action == "launch" and type(designId) == "string" then
		Tifo.launch(player, designId)
	elseif action == "lift" then
		Tifo.lift(player)
	end
end)

--[[
	THE PITCH IS FOR THE MATCH. Nobody from the stands gets onto the grass: a
	supporter found there is put back in their stand. One exception, rare on
	purpose: the PITCH INVASION.
	  It can only happen (a) after a winning goal in the last minutes, for the
	  club that scored, or (b) when the club wins the championship (it is top
	  of the table at full time on the last day of the season).
	  Then, and only then, the CAPO of that claque gets a button. If the capo
	  presses it, that claque may run on (each one decides: a button), for
	  about thirty seconds, with stewards running after them; then everyone is
	  back in the stand. If the capo does not press it, there is no invasion.
	  The other claque never can.
]]
local invasionOffer: { [string]: number } = {} -- claque -> until when its capo may call it
local invasionOpen: { [string]: number } = {} -- claque -> until when it is on
local stewards: Folder? = nil

local function onGrass(position: Vector3): boolean
	return math.abs(position.X) < Config.Stadium.pitchLength / 2 + 2
		and math.abs(position.Z) < Config.Stadium.pitchWidth / 2 + 2
		and position.Y < 9
end

offerInvasion = function(teamId: string)
	local leader = Teams.leader(teamId)
	if not leader or invasionOpen[teamId] then
		return
	end
	local untilAt = workspace:GetServerTimeNow() + Config.Invasion.offerSeconds
	invasionOffer[teamId] = untilAt
	leader:SetAttribute("InvasaoOferta", untilAt)
end

local function endInvasion(teamId: string)
	invasionOpen[teamId] = nil
	workspace:SetAttribute("Invasao_" .. teamId, nil)
	if stewards then
		stewards:Destroy()
		stewards = nil
	end
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if Teams.get(player) == teamId and root and onGrass(root.Position) then
			task.spawn(sendToClaque, player, teamId)
		end
	end
end

-- A steward: a simple figure in a yellow vest, that runs after whoever is on the grass.
local function makeSteward(at: Vector3, parent: Instance): Part
	local body = Instance.new("Part")
	body.Name = "Seguranca"
	body.Anchored = true
	body.CanCollide = false
	body.Size = Vector3.new(2, 2.4, 1.1)
	body.Color = Color3.fromRGB(236, 220, 40)
	body.Material = Enum.Material.Fabric
	body.CFrame = CFrame.new(at)
	local function piece(size: Vector3, offset: CFrame, colour: Color3)
		local p = Instance.new("Part")
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		p.Size = size
		p.Color = colour
		p.CFrame = body.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
		p.Parent = body
	end
	piece(Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 1.8, 0), Color3.fromRGB(224, 180, 140))
	piece(Vector3.new(1.9, 2.2, 1), CFrame.new(0, -2.3, 0), Color3.fromRGB(28, 30, 36))
	piece(Vector3.new(2.04, 0.3, 1.14), CFrame.new(0, 0.2, 0), Color3.fromRGB(200, 200, 200))
	body.Parent = parent
	return body
end

local function startInvasion(teamId: string)
	invasionOffer[teamId] = nil
	local untilAt = workspace:GetServerTimeNow() + Config.Invasion.seconds
	invasionOpen[teamId] = untilAt
	workspace:SetAttribute("Invasao_" .. teamId, untilAt)
	local folder = Instance.new("Folder")
	folder.Name = "Segurancas"
	folder.Parent = workspace
	stewards = folder
	local side = Config.Teams[teamId].side
	for i = 1, Config.Invasion.stewards do
		makeSteward(Vector3.new(-side * 30, 4.2, (i - (Config.Invasion.stewards + 1) / 2) * 16), folder)
	end
	task.delay(Config.Invasion.seconds, function()
		if invasionOpen[teamId] == untilAt then
			endInvasion(teamId)
		end
	end)
end

-- "invasao": the capo calls it. "entrar": a supporter of that claque runs on.
local function invasionRequest(player: Player, what: string)
	local teamId = Teams.get(player)
	if not teamId then
		return
	end
	local now = workspace:GetServerTimeNow()
	if what == "invasao" then
		local offer = invasionOffer[teamId]
		if offer and now <= offer and Teams.leader(teamId) == player then
			player:SetAttribute("InvasaoOferta", nil)
			startInvasion(teamId)
		end
	elseif what == "entrar" then
		local open = invasionOpen[teamId]
		local spot = Stadium.spawnPoint(teamId)
		if open and now < open and spot then
			-- Onto the grass in front of their own stand.
			local to = Vector3.new(spot.X * 0.5, 4, spot.Z * 0.4)
			placeAt(player, to, Vector3.new(0, 4, 0))
		end
	end
end

task.spawn(function()
	while true do
		task.wait(0.5)
		local now = workspace:GetServerTimeNow()
		for teamId, untilAt in invasionOffer do
			if now > untilAt then
				invasionOffer[teamId] = nil
				local leader = Teams.leader(teamId)
				if leader then
					leader:SetAttribute("InvasaoOferta", nil)
				end
			end
		end
		-- Supporters off the grass, unless their claque's invasion is on.
		local invaders: { Vector3 } = {}
		for _, player in Players:GetPlayers() do
			local teamId = Teams.get(player)
			local root = rootOf(player)
			if teamId and root and onGrass(root.Position) and insideGround(root.Position) then
				if invasionOpen[teamId] then
					table.insert(invaders, root.Position)
				else
					task.spawn(sendToClaque, player, teamId)
				end
			end
		end
		-- The stewards run after whoever is nearest.
		local folder = stewards
		if folder then
			for _, steward in folder:GetChildren() do
				if steward:IsA("BasePart") then
					local best, distance = nil :: Vector3?, math.huge
					for _, at in invaders do
						local d = (at - steward.Position).Magnitude
						if d < distance then
							best, distance = at, d
						end
					end
					if best and distance > 4 then
						local flat = Vector3.new(best.X, steward.Position.Y, best.Z)
						local step = (flat - steward.Position).Unit * math.min(distance - 3, Config.Invasion.stewardSpeed * 0.5)
						game:GetService("TweenService"):Create(steward, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(steward.Position + step, flat) }):Play()
					end
				end
			end
		end
	end
end)

--[[
	Um golo. Entra no marcador; o fora de jogo, quando houver, e o arbitro que
	o ve.
]]
Football.onGoal(function(teamId, scorer)
	local scorerPlayer = if scorer and scorer.player and scorer.teamId == teamId then scorer.player else nil
	local assist = if scorer and scorerPlayer then Football.assistFor(scorer) else nil
	Progress.goal(teamId, scorerPlayer, if assist and assist.teamId == teamId then assist.player else nil)
	-- O festejo desbloqueado pelo nivel de jogador (so aspeto): maos no ar, depois saltos.
	if scorerPlayer then
		local level = Progress.level(scorerPlayer, "jogador")
		local steps = Config.Progress.perks.celebrationAt
		--[[
			Os festejos animados (Config.Animations): nivel 12 desliza de
			joelhos; a partir do 20, ao calhas, esse ou o do Mbappe. Toca uma
			vez, a correr para a claque (Animacoes.client).
		]]
		local unlocked = {}
		if level >= steps[1] then
			table.insert(unlocked, "joelho")
		end
		if level >= steps[2] then
			table.insert(unlocked, "mbappe")
		end
		local pick = if #unlocked > 0 then unlocked[math.random(1, #unlocked)] else nil
		if pick and (Config.Animations :: any)[pick] ~= "" then
			scorerPlayer:SetAttribute("FestejoGolo", pick)
			task.delay(5, function()
				if scorerPlayer.Parent and scorerPlayer:GetAttribute("FestejoGolo") == pick then
					scorerPlayer:SetAttribute("FestejoGolo", nil)
				end
			end)
		end
		local emote = if pick then nil elseif level >= steps[2] then "saltar" elseif level >= steps[1] then "maos" else nil
		if emote then
			scorerPlayer:SetAttribute("Emote", emote)
			task.delay(6, function()
				if scorerPlayer.Parent and scorerPlayer:GetAttribute("Emote") == emote then
					scorerPlayer:SetAttribute("Emote", nil)
				end
			end)
		end
	end
	-- Uma entrada ainda em aberto ja nao se apita: o golo conta.
	Whistle.cancel()
	MatchLoop.scoreGoal(teamId)
	-- A winning goal in the last minutes: the capo of that claque may call a pitch invasion.
	do
		local now = MatchLoop.snapshot()
		local mine = now.score[teamId]
		local theirs = if teamId == "home" then now.score.away else now.score.home
		if now.phase == "second" and now.clock <= Config.Invasion.lastSeconds and mine == theirs + 1 then
			offerInvasion(teamId)
		end
	end

	-- Cada golo da equipa vale umas moedas a sua claque.
	for _, player in Players:GetPlayers() do
		if Teams.get(player) == teamId then
			Money.add(player, Config.Money.perGoal)
		end
	end

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
MatchLoop.pauseWhile(Football.clockStopped)

--[[
	A espera pelas bancadas acaba quando todas as pessoas de claque estao no
	seu topo — e logo, se nao houver nenhuma. Nunca fica a espera sem fim: o
	MatchLoop corta-a ao fim de Config.Match.waitLength.
]]
MatchLoop.readyWhen(function()
	local ready, total = standsCount()
	return ready >= total
end)

-- Os bonecos da bancada dao lugar as pessoas de cada claque.
task.spawn(function()
	while true do
		local members: { [string]: number } = {}
		for _, teamId in Config.TeamOrder do
			members[teamId] = Teams.count(teamId)
		end
		Crowd.makeRoom(members)
		task.wait(1)
	end
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
	local text = TXT.whistleFoulBy .. Squad.label(foul.fouler)
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
	Progress.markActive(player)
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
			-- Na academia, e a bola de treino.
			if Academy.kick(player, power, curve, height) then
				return
			end
			--[[
				Para onde e de onde: o ecra de quem chuta ve-se a si proprio sem
				atraso, o servidor nao. Aceita-se o que o ecra diz, mas so dentro
				do razoavel (direcao horizontal, e de perto de onde o servidor o ve).
			]]
			local dir: Vector3? = nil
			if typeof(value.dir) == "Vector3" then
				local flatDir = Vector3.new(value.dir.X, 0, value.dir.Z)
				if flatDir.Magnitude > 0.5 then
					dir = flatDir.Unit
				end
			end
			local from: Vector3? = nil
			local root = f.root
			if typeof(value.at) == "Vector3" and root and (value.at - root.Position).Magnitude < 8 then
				from = value.at
			end
			Football.kick(f, power, curve, height, dir, from)
		end
	end
end)

--[[
	Saltar de fase, para testes e para mostrar o jogo sem esperar. Quem pode e
	a lista Config.Admins, e e aqui, no servidor, que se confirma: o botao no
	ecra so aparece aos admins, mas um cliente consegue mandar o pedido na
	mesma, e por isso nao e o botao que decide.
]]
--[[
	The admin bar (client/Admin): only for Config.Admins, and it is checked
	here, on the server. Nothing in it is a shortcut for playing: it is for
	looking at the four clubs without waiting for the right match day.
	  team   <club>   I support this club (the derby changes if it is not today's)
	  kit    <club>   wear this club's kit ("" takes it off)
	  farda  <club>   wear this claque's farda ("" takes it off)
	  kitName <home|away|"">  main or alternate kit ("" = what the match decided)
	  derby  <n>      the match on now is this one
]]
local function slotOf(clubId: string): (number?, string?)
	for n, derby in Config.Derbies do
		if derby.home == clubId then
			return n, "home"
		elseif derby.away == clubId then
			return n, "away"
		end
	end
	return nil, nil
end

local function adminBar(player: Player, action: any, value: any)
	local club = if type(value) == "string" then (Config.Clubs :: any)[value] else nil
	if action == "reset" then
		-- Start the season again: results, points, goals and tables go; people's clubs, levels and gear stay.
		Competition.reset()
		Remotes.Npc:FireClient(player, { title = Config.Text.admin.resetDone, lines = {} })
	elseif action == "wipe" then
		-- RESET MY PROFILE: the admin's own account, as if it had never joined.
		if Money.wipe(player) then
			Squad.leave(player)
			Referee.release(player)
			Teams.forget(player)
			wish[player] = nil
			switchedAt[player] = nil
			atStadium[player] = nil
			player:SetAttribute("Team", nil)
			player:SetAttribute("UpNext", nil)
			player:SetAttribute("NoEstadio", nil)
			Remotes.PickTeam:FireClient(player, "novo")
			Remotes.Npc:FireClient(player, { title = Config.Text.admin.wipeDone, lines = {} })
		end
	elseif action == "derby" then
		if type(value) == "number" and Config.Derbies[value] then
			Derby.set(value)
		end
	elseif action == "team" and club then
		-- (The admin's own club too: "I support this one". No traitor's banner for this.)
		Money.setClub(player, value)
		local n, slot = slotOf(value)
		if n and slot then
			Derby.set(n)
			pickTeam(player, slot)
		end
	elseif action == "kit" or action == "kitName" then
		local character = player.Character
		if not character then
			return
		end
		if action == "kit" then
			character:SetAttribute("KitClub", if club then value else nil)
		else
			character:SetAttribute("KitName", if value == "home" or value == "away" then value else nil)
		end
		local f = Squad.byPlayer(player)
		local worn = (Config.Clubs :: any)[character:GetAttribute("KitClub") or ""]
		if f then
			Squad.redress(f)
		elseif worn then
			for _, child in character:GetChildren() do
				if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
					child:Destroy()
				end
			end
			local number = player:GetAttribute("Number")
			local kitName = character:GetAttribute("KitName")
			Uniform.wear(character, worn.kits[if type(kitName) == "string" then kitName else "home"] or worn.kits.home, {
				number = if type(number) == "number" then number else 10,
				name = player.DisplayName,
				club = worn,
			})
		elseif action == "kit" then
			-- Back to my own clothes.
			task.spawn(Kit.apply, player)
		end
	elseif action == "farda" then
		Lider.undress(player)
		if club then
			Lider.dress(player, club)
		end
	end
	print(string.format("[Ultras FC] admin %s: %s %s", player.Name, tostring(action), tostring(value)))
end

local lastSkip = 0
Remotes.Admin.OnServerEvent:Connect(function(player, action, value)
	if not isAdmin(player) then
		return
	end
	if action ~= "skip" then
		adminBar(player, action, value)
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
	Progress.markActive(player)
	if type(id) ~= "string" or player:GetAttribute("Riding") then
		return
	end
	player:SetAttribute("Emote", if EMOTE_IDS[id] then id else nil)
end)

--[[
	Comprar a um dealer: so quem e de claque, so ao pe de um dealer, e so com
	moedas que cheguem. O preco e o do Config.Shop, nunca o que o cliente diz.
]]
Remotes.Shop.OnServerEvent:Connect(function(player, action, kind, choice)
	if type(kind) ~= "string" or type(choice) ~= "number" or not Teams.get(player) then
		return
	end
	local root = rootOf(player)
	if not root or not Clubhouse.nearDealer(root.Position) then
		return
	end
	local item
	for _, entry in Config.Shop do
		if entry.kind == kind then
			item = entry
		end
	end
	if not item then
		return
	end
	if action == "cor" then
		-- A cor fica a valer para esse material (Gear le o atributo ao acender).
		local colour = Config.PyroColours[choice] :: any
		if colour and colour.exclusive and not Progress.exclusiveColours(player) then
			return
		end
		if colour then
			player:SetAttribute("Cor_" .. kind, colour.color)
		end
	elseif action == "buy" then
		local pack = Config.ShopPacks[choice]
		if pack and Money.spend(player, item.price * pack.pay) then
			Gear.give(player, kind, pack.amount)
		end
	end
end)

-- O botao "SEDE": volta-se quando se quer, nunca a forca.
local lastHome: { [Player]: number } = {}
Remotes.Home.OnServerEvent:Connect(function(player, where)
	local now = os.clock()
	if (lastHome[player] or 0) + 3 > now then
		return
	end
	if where == "invasao" or where == "entrar" then
		invasionRequest(player, where)
		return
	end
	lastHome[player] = now
	-- "jogo": the match of my club is about to start: to the corteo if it is on
	-- its way, or to my stand.
	if where == "jogo" then
		local mine = Teams.get(player)
		if mine then
			local banner = March.bannerPosition(mine)
			if MatchLoop.phase() == "corteo" and banner then
				placeAt(player, banner + Vector3.new(0, 1, 6), banner)
			else
				task.spawn(sendToClaque, player, mine, true)
			end
		end
		return
	end
	-- "estadio": straight to my stand, when the match has already started
	-- (nobody is stuck in a corteo that left late).
	local teamId = Teams.get(player)
	local phase = MatchLoop.phase()
	local matchOn = phase ~= "clubhouse" and phase ~= "corteo" and not MatchLoop.snapshot().night
	if where == "estadio" then
		if teamId and matchOn then
			task.spawn(sendToClaque, player, teamId, true)
		elseif matchOn and not Squad.byPlayer(player) and Referee.current() ~= player then
			-- Not of either club: any match can be watched, from the side stand, as a neutral.
			local S = Config.Stadium
			local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StadiumPlan"))
			local row = 5
			task.spawn(placeAt, player, Vector3.new(0, row * S.rowHeight + 3.5, Plan.innerZ + row * S.rowDepth), Vector3.new(0, 0, 0))
		else
			Remotes.Npc:FireClient(player, { title = Config.Text.hud.stadium, lines = { Config.Text.hud.noMatchOn } })
		end
		return
	end
	-- Whoever went to the stadium stays for the match.
	if matchOn and atStadium[player] == slotNow() then
		Remotes.Npc:FireClient(player, { title = Config.Text.hud.atStadium, lines = { Config.Text.hud.noWayHome } })
		return
	end
	task.spawn(sendHome, player)
end)
Players.PlayerRemoving:Connect(function(player)
	lastHome[player] = nil
	atStadium[player] = nil
	lastRole[player] = nil
end)

--[[
	THE TRAITOR'S BANNER: over the head of whoever left a club for its rival,
	for everyone to see, while it lasts (the attribute "Traidor": matches left).
]]
do
	local function banner(player: Player)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not head then
			return
		end
		local old = head:FindFirstChild("Traidor")
		if player:GetAttribute("Traidor") == nil then
			if old then
				old:Destroy()
			end
			return
		end
		if old then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "Traidor"
		gui.Size = UDim2.fromScale(Config.Labels.width, Config.Labels.height)
		gui.StudsOffset = Vector3.new(0, 4.6, 0)
		gui.MaxDistance = Config.Traitor.labelDistance
		gui.LightInfluence = 0
		local words = Instance.new("TextLabel")
		words.Size = UDim2.fromScale(1, 1)
		words.BackgroundColor3 = Config.UI.bad
		words.BorderSizePixel = 0
		words.Font = Enum.Font.GothamBlack
		words.TextScaled = true
		words.TextColor3 = Config.UI.text
		words.Text = Config.Text.hud.traitor
		words.Parent = gui
		gui.Parent = head
	end
	local function watch(player: Player)
		player:GetAttributeChangedSignal("Traidor"):Connect(function()
			banner(player)
		end)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			task.wait(0.5)
			banner(player)
		end)
		banner(player)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

Gear.start()
-- O lider: o letreiro, as ordens (a claque decide sempre) e o material que da.
Lider.start({
	level = function(player: Player): number
		return Progress.level(player, "adepto")
	end,
	phase = MatchLoop.phase,
})
-- A roupa muda com o papel: ultra, jogador ou arbitro.
Kit.start()

Money.start()
Competition.start()
-- Players' own name tags follow the rule of every floating label (Config.Labels).
game:GetService("StarterPlayer").NameDisplayDistance = Config.Labels.distance
game:GetService("StarterPlayer").HealthDisplayDistance = 0
local function nameTagRule(player: Player)
	local function apply(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.NameDisplayDistance = Config.Labels.distance
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
	end
	player.CharacterAdded:Connect(apply)
	if player.Character then
		task.spawn(apply, player.Character)
	end
end
Players.PlayerAdded:Connect(nameTagRule)
for _, player in Players:GetPlayers() do
	nameTagRule(player)
end
Friendly.onXP(function(player, amount)
	Money.addXP(player, "jogador", amount)
end)
Friendly.start()

--[[
	Os niveis (Progress): o que cada sistema lhes diz, e o que eles dao. Tudo
	no servidor; o jogador so ve.
]]
Progress.link({
	bannerPosition = March.bannerPosition,
	footballerOf = function(player)
		local f = Squad.byPlayer(player)
		return if f then { teamId = f.teamId, keeper = f.keeper } else nil
	end,
	referee = Referee.current,
	atmosphere = Atmosphere.fraction,
	winner = MatchLoop.winner,
	corteoCredit = March.creditFor,
})
Football.onEvent(function(kind, f)
	local who = f.player
	if who then
		Progress.footballEvent(kind, who)
	end
end)
Referee.onDecision(Progress.refDecision)
-- Too many wrong calls: the whistle is taken away, and the match goes on with the automatic referee.
Referee.onDismissed(function(player)
	local right, total = Referee.tallyOf(player)
	Remotes.Npc:FireClient(player, { title = TXT.youLostTheWhistle, lines = { string.format(TXT.youGotOutOf, right, total), string.format(TXT.noRefereeingFor, Config.Referee.banMatches) } })
	task.spawn(sendToSquare, player)
end)
Gear.setBonus(Progress.gearBonus)
Gear.setPerks(Progress.gearPerks)
Gear.setDrumRule(Progress.drumWithoutLeader)
Gear.onIgnite(Progress.ignite)
March.setHoldRule(Progress.canHoldBanner)
Squad.setPositionHook(Progress.preferredPosition)

-- O aspeto de cada jogador (numero, botas, nome, bracadeira): so aspeto.
local function takenNumbers(teamId: string, me: Player): { [number]: boolean }
	local taken: { [number]: boolean } = {}
	for _, other in Squad.team(teamId) do
		local who = other.player
		if who ~= me then
			-- O numero do lugar de um boneco, ou o que uma pessoa ja tem vestido.
			local n = if who then who:GetAttribute("Number") else other.number
			if type(n) == "number" then
				taken[n] = true
			end
		end
	end
	return taken
end
Squad.setLookHook(function(f)
	local who = f.player
	if not who then
		return nil
	end
	local look = Progress.lookFor(who, f.teamId, takenNumbers(f.teamId, who))
	return look
end)
local function lookKey(f: any): string
	local who = f.player
	if not who then
		return ""
	end
	local look = Progress.lookFor(who, f.teamId, takenNumbers(f.teamId, who))
	return tostring(look.number) .. "|" .. tostring(look.boots) .. "|" .. tostring(look.name) .. "|" .. tostring(look.captain)
end
local function refreshLook(player: Player)
	local f = Squad.byPlayer(player)
	if f and f.model then
		player:SetAttribute("LookKey", lookKey(f))
		Squad.redress(f)
	end
end
Progress.onLookChanged(refreshLook)
Progress.start()
Bank.start()

--[[
	The derby. Everything built so far has the clubs of Derby 1: remember it,
	so a derby change can repaint the world (Derby). Things with their own
	design are rebuilt: the fence faixas, the kits, the claque material.
]]
Derby.track(workspace)
workspace:SetAttribute("Derby", Derby.current())
Derby.onChanged(function(n)
	local home, away = Derby.clubs()
	print(string.format("[Ultras FC] %s: %s vs %s", Config.Derbies[n].name, home.name, away.name))
	local estadio = workspace:FindFirstChild("Estadio")
	if estadio then
		for _, teamId in Config.TeamOrder do
			local old = estadio:FindFirstChild("Faixas_" .. teamId)
			if old then
				old:Destroy()
			end
		end
		Faixas.build(estadio)
	end
	for _, f in Squad.active() do
		Squad.redress(f)
	end
	Gear.rebuildAll()
	-- Each place moves to the ground of the club that has it now.
	for _, teamId in Config.TeamOrder do
		City.place(teamId)
	end
	placeTeamBuses()
	-- Only now the people: they go to where their club's place is today.
	derbyTurn()
end)

-- The map still carries names from before the clubs were renamed: write
-- today's over them right away.
Derby.refresh()

-- Studio only: setting the workspace attribute "TestDerby" to 1 or 2 changes
-- the derby (for tests run from Studio tools; the live game has no such hook).
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("TestDerby"):Connect(function()
		local n = workspace:GetAttribute("TestDerby")
		if type(n) == "number" then
			Derby.set(n)
		end
	end)
end
-- Studio only: the workspace attribute "TestInvasion" offers the home capo a pitch invasion (for tests).
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("TestInvasion"):Connect(function()
		offerInvasion("home")
	end)
end
-- Studio only: the workspace attribute "TestJoin" ("<club>" or "<club>:<role>") puts the first player in that club (for tests).
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("TestJoin"):Connect(function()
		local value = workspace:GetAttribute("TestJoin")
		local player = Players:GetPlayers()[1]
		if type(value) == "string" and player then
			local clubId, role = string.match(value, "^(%w+):?(%w*)$")
			if clubId then
				switchedAt[player] = nil
				if not Money.clubOf(player) then
					Money.setClub(player, clubId)
				end
				pickClub(player, clubId, if role == "" then "adepto" else role)
			end
		end
	end)
end
-- Studio only: the workspace attribute "TestTrophy" ("liga", "taca" or "supertaca") runs the ceremony for the home club (for tests).
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("TestTrophy"):Connect(function()
		local kind = workspace:GetAttribute("TestTrophy")
		if type(kind) == "string" and (Config.Text.trophy :: any)[kind] then
			ceremony(kind, Config.Teams.home.club)
		end
	end)
end
-- Studio only: the workspace attribute "TestLeader" makes the first player in a claque its capo (for tests).
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("TestLeader"):Connect(function()
		for _, player in Players:GetPlayers() do
			if Teams.get(player) then
				Teams.claimLeader(player)
				break
			end
		end
	end)
end
-- Studio only: the workspace attribute "TestParade" lines up one dummy per
-- club and per outfit (main kit, alternate kit, ultra) on the pitch, to look
-- at all of them at once. Setting it to false takes them away.
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("TestParade"):Connect(function()
		local old = workspace:FindFirstChild("TestParade")
		if old then
			old:Destroy()
		end
		if not workspace:GetAttribute("TestParade") then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "TestParade"
		folder.Parent = workspace
		for i, clubId in Config.ClubOrder do
			local club = (Config.Clubs :: any)[clubId]
			for j, outfit in { "home", "away", "ultra" } do
				local dummy = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
				dummy.Name = club.short .. " " .. outfit
				local root = dummy:FindFirstChild("HumanoidRootPart") :: BasePart
				root.Anchored = true
				dummy:PivotTo(CFrame.new((i - (#Config.ClubOrder + 1) / 2) * 5, 3.2, (j - 2) * 7) * CFrame.Angles(0, math.pi, 0))
				dummy.Parent = folder
				if outfit == "ultra" then
					Uniform.ultra(dummy, club)
				else
					Uniform.wear(dummy, club.kits[outfit], { number = 10, name = club.short, club = club })
				end
			end
		end
	end)
end
-- De 5 em 5 s: a bracadeira passa de um para outro, o tambor muda de dono sem lider.
task.spawn(function()
	while true do
		task.wait(5)
		for _, f in Squad.humans() do
			local who = f.player
			if who and f.model and who:GetAttribute("LookKey") ~= lookKey(f) then
				refreshLook(who)
			end
		end
		for _, player in Players:GetPlayers() do
			if Teams.get(player) then
				Gear.sync(player)
			end
		end
	end
end)
Bikes.start()
Shops.start()

-- Descer da bicicleta (botao DESCER, ou F).
Remotes.Bike.OnServerEvent:Connect(function(player, action)
	if action == "descer" then
		Bikes.dismount(player)
	end
end)
MatchLoop.start()

print("[Ultras FC] Servidor a postos.")

-- Quantas pecas criou cada parte. Os bonecos nascem aos poucos, dai a espera.
task.delay(5, Budget.report)
