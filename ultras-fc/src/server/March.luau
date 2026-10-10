--!strict
--[[
	O corteo.

	A claque junta-se a porta da sede, sai em bloco e desce a avenida ate ao
	estadio, a cantar pelo caminho. E a ideia central do jogo inteiro: nao se
	entra num estadio por magia, e a caminhada e a melhor parte.

	Como funciona: quando a fase do corteo comeca, a faixa de cada claque
	aparece parada a porta da sede. O lider da a ordem na porta, e a partir dai
	e ELE que guia: a faixa vai uns passos a frente dele, para onde ele andar e
	ao passo dele — se para, o corteo para; se se perde, a claque perde-se com
	ele. O lider anda a passo de marcha enquanto guia. Sem lider (ou se ele
	sair), a faixa segue sozinha o caminho de sempre. Se ninguem der a ordem, a
	faixa sai sozinha a meio da fase — um servidor sem lider nao pode
	ficar preso. Quem vai perto dela enquanto anda leva a bancada ja quente para
	o apito inicial; quem la chega sozinho entra na mesma, so sem o bonus.

	TRES MOMENTOS (atributo "Stage" da faixa), como numa claque a serio:
	1. "formatura": a porta da sede, filas direitas, paradas, a faixa aberta a
	   frente. Uns segundos quietos: e o que faz aquilo parecer serio.
	2. "marcha": um bloco colado de parede a parede, devagar, ao passo do
	   tambor; tochas e fumo pelo caminho.
	3. "corrida": nos ultimos metros acaba a marcha e toda a gente desata a
	   correr para dentro. A mudanca de ritmo e o que faz isto funcionar.
	Antes disso a faixa esta em "espera"; no fim, "chegou".

	Os bonecos que marcham atras da faixa nao vivem aqui: cada ecra desenha-os a
	partir da posicao dela (Corteo.client). Nao pesam nada na rede.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Teams = require(script.Parent:WaitForChild("Teams"))
local City = require(script.Parent:WaitForChild("City"))
local Rigs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rigs"))
local StadiumPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StadiumPlan"))

local March = {}

local M = Config.March

type Banner = {
	model: Part,
	waypoints: { Vector3 },
	leg: number,
	teamId: string,
	moving: boolean,
	seconds: number, -- quanto demora o percurso todo, a passo da faixa
	leader: Player?, -- quem a guia; sem ninguem, segue os waypoints
	stage: string, -- espera, formatura, marcha, corrida, chegou
	formedAt: number, -- quando formou
	launchPending: boolean, -- ja tem ordem de sair: sai quando acabar a formatura
	heading: Vector3, -- para onde o lider vai, alisado
	lastLeaderAt: Vector3,
}

local banners: { [string]: Banner } = {}

--[[
	THE ROUTE IS THE ARROWS. The banner always goes along the route to the
	stadium (the arrows on the ground), whoever leads it. The leader sets the
	PACE, not the direction: the banner keeps a few steps ahead of the leader
	along the route and never turns round with them or leaves the street.
]]
local progress: { [string]: number } = {} -- how far along its route each banner is, in studs

-- The point `s` studs along the path, the direction there, and the leg it is on.
local function along(points: { Vector3 }, s: number): (Vector3, Vector3, number)
	local left = math.max(s, 0)
	local dir = Vector3.new(0, 0, -1)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local step = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		if step.Magnitude > 0.1 then
			dir = step.Unit
			if left <= step.Magnitude then
				return Vector3.new(a.X, 0, a.Z) + dir * left, dir, i
			end
			left -= step.Magnitude
		end
	end
	local last = points[#points]
	return Vector3.new(last.X, 0, last.Z), dir, math.max(#points - 1, 1)
end

-- How far along the path the point nearest to `p` is (looking only from `from` studs on).
local function project(points: { Vector3 }, p: Vector3, from: number): number
	local best, bestDistance = from, math.huge
	local walked = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local step = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = step.Magnitude
		if length > 0.1 then
			local t = math.clamp(Vector3.new(p.X - a.X, 0, p.Z - a.Z):Dot(step.Unit), 0, length)
			local s = walked + t
			if s >= from - 40 then
				local at = Vector3.new(a.X, 0, a.Z) + step.Unit * t
				local distance = (Vector3.new(p.X, 0, p.Z) - at).Magnitude
				if distance < bestDistance then
					best, bestDistance = s, distance
				end
			end
			walked += length
		end
	end
	return best
end

-- The route, for the arrows on each screen: "x,z;x,z;..."
local function publishRoute(banner: Banner)
	local list = {}
	for _, point in banner.waypoints do
		table.insert(list, string.format("%d,%d", point.X, point.Z))
	end
	banner.model:SetAttribute("Rota", table.concat(list, ";"))
end
local credit: { [Player]: number } = {} -- 0 a 1: quanto do percurso acompanhou
-- A quem o lider deu a faixa (DAR MATERIAL), neste corteo.
local granted: { [Player]: boolean } = {}
local active = false
local armedAt = 0
local root: Folder? = nil

function March.creditFor(player: Player): number
	return credit[player] or 0
end

function March.forget(player: Player)
	credit[player] = nil
end

--[[
	O percurso de sempre: da porta da sede pelos pontos do mapa (Cidade.Rotas,
	que se mexem no Studio), e no fim a porta da claque no estadio. E o que a
	faixa faz sozinha quando nao ha lider a guia-la; com lider, vai por onde
	ele for.
]]
local function routeFor(teamId: string): { Vector3 }
	local points = City.route(teamId)
	if #points == 0 then
		return {}
	end

	table.insert(points, StadiumPlan.claqueGate(teamId)) -- a porta da claque, atras da sua curva
	return points
end

local function buildBanner(teamId: string, at: Vector3, parent: Instance): Part
	local team = Config.Teams[teamId]

	local banner = Instance.new("Part")
	banner.Name = "Banner_" .. teamId
	-- Cloth carried by hand: three players wide, half a player tall (Config.March.banner).
	banner.Size = Vector3.new(M.banner.width, M.banner.height, 0.3)
	banner.CFrame = CFrame.new(at)
	banner.Color = team.color
	banner.Material = Enum.Material.Fabric
	banner.Anchored = true
	banner.CanCollide = false
	banner:SetAttribute("Team", teamId)
	banner:SetAttribute("Moving", false)
	banner:SetAttribute("Arrived", false)
	banner.Parent = parent

	-- O pano (com o nome da claque) e um rig com juntas pendurado desta peca
	-- (Rigs.faixa): cada ecra ondula-o, ou toca a animacao "faixapano". Aqui
	-- a peca so marca o sitio e brilha.
	local pano = Instance.new("Model")
	pano.Name = "FaixaPano_" .. teamId
	Rigs.faixa(pano, banner, teamId)
	pano.Parent = parent
	banner.Transparency = 1

	-- It is cloth: no light, no glow.

	return banner
end

--[[
	A fase do corteo comecou: as faixas aparecem a porta de cada sede, paradas,
	a espera da ordem de sair.
]]
local streetSpot: (any) -> (Vector3, Vector3)

function March.arm(parent: Instance)
	March.stop()

	local folder = Instance.new("Folder")
	folder.Name = "March"
	folder.Parent = parent
	root = folder

	table.clear(credit)
	active = true
	table.clear(granted)
	armedAt = os.clock()

	for _, teamId in Config.TeamOrder do
		local waypoints = routeFor(teamId)
		if #waypoints >= 2 then
			local length = 0
			for i = 2, #waypoints do
				length += (waypoints[i] - waypoints[i - 1]).Magnitude
			end
			banners[teamId] = {
				model = buildBanner(teamId, waypoints[1], folder),
				waypoints = waypoints,
				leg = 1,
				teamId = teamId,
				moving = false,
				seconds = length / M.speed,
				leader = nil,
				heading = Vector3.new(0, 0, 1),
				lastLeaderAt = Vector3.zero,
				stage = "espera",
				formedAt = 0,
				launchPending = false,
			}
			-- They wait in the street already (behind the door the rows would stand inside the sede).
			do
				local b = banners[teamId]
				local at, look = streetSpot(b)
				b.leg = 1
				b.model.CFrame = CFrame.lookAt(Vector3.new(at.X, b.model.Position.Y, at.Z), Vector3.new(at.X, b.model.Position.Y, at.Z) + look)
			end
			banners[teamId].model:SetAttribute("Stage", "espera")
			progress[teamId] = nil
			publishRoute(banners[teamId])
		end
	end
end

--[[
	A ordem de sair: do lider, na porta da sede, ou do relogio a meio da fase.
	A faixa comeca a andar; quem for atras dela ganha credito.
]]
local function leaderRoot(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- O lider deixa de guiar: volta a andar ao seu passo, e a faixa segue sozinha.
--[[
	Quem, alem do lider, pode segurar a faixa (Progress: nivel de adepto). O
	lider tem sempre prioridade: chegando, fica ele com ela.
]]
local holdRule: ((Player) -> boolean)? = nil
function March.setHoldRule(fn: (Player) -> boolean)
	holdRule = fn
end

function March.grantHold(player: Player)
	granted[player] = true
end

local function mayHold(player: Player, teamId: string): boolean
	if Teams.leader(teamId) == player then
		return true
	end
	if granted[player] and Teams.get(player) == teamId then
		return true
	end
	local rule = holdRule
	return Teams.get(player) == teamId and rule ~= nil and rule(player)
end

-- Alguem da claque que pode segurar a faixa e esta mesmo ao pe dela.
local function holderNear(teamId: string, at: Vector3): Player?
	local leader = Teams.leader(teamId)
	if leader then
		local _, hrp = leaderRoot(leader)
		if hrp and (hrp.Position - at).Magnitude <= M.takeRadius then
			return leader
		end
	end
	for _, player in Players:GetPlayers() do
		if player ~= leader and mayHold(player, teamId) then
			local _, hrp = leaderRoot(player)
			if hrp and (hrp.Position - at).Magnitude <= M.takeRadius then
				return player
			end
		end
	end
	return nil
end

local function releaseLeader(banner: Banner)
	local leader = banner.leader
	banner.leader = nil
	banner.model:SetAttribute("Led", false)
	if leader then
		local humanoid = leaderRoot(leader)
		if humanoid then
			humanoid.WalkSpeed = 16
		end
	end

	-- Retoma o caminho de sempre a partir do ponto mais perto de onde esta.
	local here = banner.model.Position
	local nearest, best = banner.leg, math.huge
	for i, point in banner.waypoints do
		local d = (point - here).Magnitude
		if d < best then
			best = d
			nearest = i
		end
	end
	banner.leg = math.min(nearest, #banner.waypoints - 1)
end

local function setStage(banner: Banner, stage: string)
	banner.stage = stage
	banner.model:SetAttribute("Stage", stage)
end

--[[
	FORMAR: a faixa vira-se para o caminho e a claque forma atras dela, em
	filas direitas (os bonecos; as pessoas so se quiserem). Nao sai sozinha:
	sai com a ordem de marchar, depois de estar formada uns segundos.
]]
-- Where the claque stands in the street, and which way it looks: out of the sede, never inside it.
function streetSpot(banner: Banner): (Vector3, Vector3)
	--[[
		A faixa avanca pela rua `formAhead` studs e vira-se para o caminho: as
		filas formam atras dela, na rua. (A porta da sede fica mesmo atras da
		faixa: formar ali metia as filas dentro do edificio.)
	]]
	-- IN THE ROAD, away from the door: out to the street, and then `formStreet`
	-- studs down it on the way to the stadium, so the whole block stands on the road.
	local points = banner.waypoints
	local left = M.formAhead
	if #points >= 3 then
		left = Vector3.new(points[2].X - points[1].X, 0, points[2].Z - points[1].Z).Magnitude + M.formStreet
	end
	local at, look = points[1], Vector3.new(0, 0, -1)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local segment = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		if segment.Magnitude < 0.1 then
			continue
		end
		look = segment.Unit
		banner.leg = i
		if segment.Magnitude >= left then
			at = a + look * left
			break
		end
		left -= segment.Magnitude
		at = b
	end
	-- They form up looking down the street, the way to the stadium: at a point
	-- well ahead on the route, not along the short first step out of the door
	-- (which points at the wall across the street).
	local ahead, walked = at, 0
	local from = at
	for i = banner.leg + 1, #points do
		local b = points[i]
		local step = Vector3.new(b.X - from.X, 0, b.Z - from.Z)
		if walked + step.Magnitude >= M.formLook then
			ahead = from + step.Unit * (M.formLook - walked)
			walked = M.formLook
			break
		end
		walked += step.Magnitude
		from = b
		ahead = b
	end
	local facing = Vector3.new(ahead.X - at.X, 0, ahead.Z - at.Z)
	if facing.Magnitude > 1 then
		look = facing.Unit
	end
	return at, look
end

function March.form(teamId: string): boolean
	local banner = banners[teamId]
	if not (active and banner) or banner.stage ~= "espera" then
		return false
	end
	local at, look = streetSpot(banner)
	banner.model.CFrame = CFrame.lookAt(Vector3.new(at.X, banner.model.Position.Y, at.Z), Vector3.new(at.X, banner.model.Position.Y, at.Z) + look)
	banner.formedAt = os.clock()
	setStage(banner, "formatura")
	return true
end

--[[
	STEWARDS AT THE CROSSINGS. At each corner of the route two stewards in
	yellow vests stand with a barrier across the side street while the corteo
	goes by, and leave once it has passed. (It is for the look of it: the
	barrier does not stop anything.)
]]
local crossings: { [string]: { { at: Vector3, model: Model } } } = {}

local function steward(at: CFrame, parent: Instance)
	local function piece(size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material?)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.Color = colour
		p.Material = material or Enum.Material.SmoothPlastic
		p.CFrame = at * offset
		p.Parent = parent
	end
	piece(Vector3.new(1.9, 2.2, 1), CFrame.new(0, 1.1, 0), Color3.fromRGB(28, 30, 36), Enum.Material.Fabric)
	piece(Vector3.new(2, 2.4, 1.1), CFrame.new(0, 3.4, 0), Color3.fromRGB(236, 220, 40), Enum.Material.Fabric)
	piece(Vector3.new(2.04, 0.3, 1.14), CFrame.new(0, 3.4, 0), Color3.fromRGB(200, 200, 200))
	piece(Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 5.2, 0), Color3.fromRGB(224, 180, 140))
	piece(Vector3.new(0.5, 2, 0.5), CFrame.new(-1.25, 3.5, 0), Color3.fromRGB(236, 220, 40), Enum.Material.Fabric)
	piece(Vector3.new(0.5, 2, 0.5), CFrame.new(1.25, 3.5, 0), Color3.fromRGB(236, 220, 40), Enum.Material.Fabric)
end

local function closeCrossings(banner: Banner)
	local list = {}
	local points = banner.waypoints
	for i = 2, #points - 1 do
		local before = Vector3.new(points[i].X - points[i - 1].X, 0, points[i].Z - points[i - 1].Z)
		local after = Vector3.new(points[i + 1].X - points[i].X, 0, points[i + 1].Z - points[i].Z)
		-- (Only real corners: a long stretch before and after, and a turn.)
		if before.Magnitude > 30 and after.Magnitude > 30 and before.Unit:Dot(after.Unit) < 0.8 then
			local model = Instance.new("Model")
			model.Name = "Cruzamento"
			-- Across the street the corteo does NOT take: straight on, past the corner.
			local on = before.Unit
			local centre = Vector3.new(points[i].X, 0.6, points[i].Z) + on * 16
			local frame = CFrame.lookAt(centre, centre - on)
			for _, side in { -1, 1 } do
				steward(frame * CFrame.new(side * 7, 0, 0), model)
			end
			for k = -2, 2 do
				local bar = Instance.new("Part")
				bar.Anchored = true
				bar.CanCollide = false
				bar.CanQuery = false
				bar.Size = Vector3.new(4.6, 0.7, 0.3)
				bar.Color = if k % 2 == 0 then Color3.fromRGB(214, 40, 40) else Color3.fromRGB(240, 240, 240)
				bar.CFrame = frame * CFrame.new(k * 4.6, 2.6, 2)
				bar.Parent = model
			end
			model.Parent = root
			table.insert(list, { at = points[i], model = model })
		end
	end
	crossings[banner.teamId] = list
end

-- The corteo has gone by: that crossing is open again.
local function reopenCrossings(banner: Banner)
	local list = crossings[banner.teamId]
	if not list then
		return
	end
	local here = banner.model.Position
	local ahead = banner.model.CFrame.LookVector
	for i = #list, 1, -1 do
		local to = list[i].at - here
		if Vector3.new(to.X, 0, to.Z):Dot(ahead) < -70 and Vector3.new(to.X, 0, to.Z).Magnitude > 70 then
			list[i].model:Destroy()
			table.remove(list, i)
		end
	end
end

-- O corteo arranca: a faixa anda, e quem for atras dela ganha credito.
local function start(banner: Banner)
	local teamId = banner.teamId
	closeCrossings(banner)
	banner.moving = true
	banner.launchPending = false
	setStage(banner, "marcha")
	banner.model:SetAttribute("Moving", true)

	-- O lider, se estiver junto a faixa, passa a guia-la.
	local leader = Teams.leader(teamId)
	-- Os dois valores: um "if" numa so linha ficava so com o primeiro.
	local humanoid, hrp
	if leader then
		humanoid, hrp = leaderRoot(leader)
	end
	if leader and humanoid and hrp and (hrp.Position - banner.model.Position).Magnitude <= M.radius then
		banner.leader = leader
		banner.lastLeaderAt = hrp.Position
		local look = banner.model.CFrame.LookVector
		banner.heading = Vector3.new(look.X, 0, look.Z).Unit
		humanoid.WalkSpeed = M.leaderSpeed
		banner.model:SetAttribute("Led", true)
	end
end

--[[
	MARCHAR: se ainda nao formou, forma primeiro; sai quando a formatura
	ja tiver durado `formSeconds`.
]]
function March.launch(teamId: string): boolean
	local banner = banners[teamId]
	if not (active and banner) or banner.moving or banner.launchPending then
		return false
	end
	if banner.stage == "espera" then
		March.form(teamId)
	end
	banner.launchPending = true
	return true
end

-- Em que momento esta o corteo desta claque.
function March.stage(teamId: string): string?
	local banner = banners[teamId]
	return banner and banner.stage or nil
end

--[[
	TWO CORTEI MEET IN THE STREET (Config.Gemellaggio). Never a fight.
	  gemellati  both stop, face each other and sing together a few seconds;
	  enemies    both stop face to face, a line of stewards between them,
	             flares lit, half a minute; the stewards open and on they go;
	  others     nothing.
	Once a corteo. The banners say it to every screen (attribute "Encontro":
	"amigos" or "inimigos"); `meetHook` tells the people (Main).
]]
local meeting: { untilAt: number, model: Model? }? = nil
local met = false
local meetHook: ((string, string, string) -> ())? = nil
function March.onMeet(fn: (kind: string, a: string, b: string) -> ())
	meetHook = fn
end

local function endMeeting()
	if meeting and meeting.model then
		meeting.model:Destroy()
	end
	meeting = nil
	for _, banner in banners do
		banner.model:SetAttribute("Encontro", nil)
	end
end

local function checkMeeting(now: number)
	if meeting then
		if now >= meeting.untilAt then
			endMeeting()
		end
		return
	end
	if met then
		return
	end
	local a, b = banners.home, banners.away
	if not a or not b or a.stage ~= "marcha" or b.stage ~= "marcha" then
		return
	end
	local G = Config.Gemellaggio
	local pa, pb = a.model.Position, b.model.Position
	local gap = Vector3.new(pb.X - pa.X, 0, pb.Z - pa.Z)
	if gap.Magnitude > G.meetDistance or gap.Magnitude < 1 then
		return
	end
	-- Only in the last part of the way, in the streets round the stadium: never in the middle of the city.
	if Vector3.new(pa.X, 0, pa.Z).Magnitude > G.nearStadium or Vector3.new(pb.X, 0, pb.Z).Magnitude > G.nearStadium then
		return
	end
	met = true
	local clubA, clubB = Config.Teams.home.club, Config.Teams.away.club
	local kind = if Config.isGemellati(clubA, clubB) then "amigos" elseif Config.isEnemy(clubA, clubB) then "inimigos" else nil
	if not kind then
		return
	end
	-- Face to face.
	a.model.CFrame = CFrame.lookAt(pa, pa + gap.Unit)
	b.model.CFrame = CFrame.lookAt(pb, pb - gap.Unit)
	local model: Model? = nil
	if kind == "inimigos" and root then
		-- The stewards: a line across, in the middle, one looking each way in turn.
		local line = Instance.new("Model")
		line.Name = "Encontro"
		local middle = Vector3.new((pa.X + pb.X) / 2, 0.6, (pa.Z + pb.Z) / 2)
		local across = gap.Unit:Cross(Vector3.yAxis)
		for i = 1, G.stewards do
			local at = middle + across * ((i - (G.stewards + 1) / 2) * 4)
			local toward = if i % 2 == 0 then gap.Unit else -gap.Unit
			steward(CFrame.lookAt(at, at + toward), line)
		end
		line.Parent = root
		model = line
	end
	meeting = { untilAt = now + (if kind == "amigos" then G.greetSeconds else G.standoffSeconds), model = model }
	a.model:SetAttribute("Encontro", kind)
	b.model:SetAttribute("Encontro", kind)
	if meetHook then
		task.spawn(meetHook, kind, clubA, clubB)
	end
end

function March.stop()
	active = false
	endMeeting()
	met = false
	for _, banner in banners do
		if banner.leader then
			releaseLeader(banner)
		end
	end
	table.clear(banners)
	if root then
		root:Destroy()
		root = nil
	end
end

function March.isActive(): boolean
	return active
end

-- Onde vai a faixa da equipa, para o cliente poder apontar o caminho.
function March.bannerPosition(teamId: string): Vector3?
	local banner = banners[teamId]
	return banner and banner.model.Position or nil
end

function March.step(dt: number)
	if not active then
		return
	end

	-- Sem ordem do lider, sai-se na mesma a meio da fase.
	if os.clock() - armedAt >= M.autoStartAfter then
		for teamId in banners do
			March.launch(teamId)
		end
	end

	local now = os.clock()
	checkMeeting(now)
	for teamId, banner in banners do
		-- (Stopped, face to face with the other corteo.)
		if meeting then
			continue
		end
		-- Formados e com ordem de sair: saem quando a formatura tiver durado o que deve.
		if banner.stage == "formatura" and banner.launchPending and now - banner.formedAt >= M.formSeconds then
			start(banner)
		end
		if not banner.moving then
			continue
		end
		local gate = banner.waypoints[#banner.waypoints]

		--[[
			O lider que chega a faixa passa a guia-la, a qualquer altura: se a
			faixa saiu sozinha, ou se ele se atrasou, basta ir ter com ela.
		]]
		-- (So em marcha: na corrida a faixa ja nao e de ninguem.)
		if not banner.leader and banner.stage == "marcha" then
			local candidate = holderNear(teamId, banner.model.Position)
			local humanoid, hrp
			if candidate then
				humanoid, hrp = leaderRoot(candidate)
			end
			if candidate and humanoid and hrp and (hrp.Position - banner.model.Position).Magnitude <= M.takeRadius then
				banner.leader = candidate
				banner.lastLeaderAt = hrp.Position
				local look = banner.model.CFrame.LookVector
				banner.heading = Vector3.new(look.X, 0, look.Z).Unit
				humanoid.WalkSpeed = M.leaderSpeed
				banner.model:SetAttribute("Led", true)
			end
		end

		-- Guiada pelo lider: vai uns passos a frente dele, para onde ele vai.
		local leader = banner.leader
		if leader then
			local humanoid, hrp = leaderRoot(leader)
			local newLeader = Teams.leader(teamId)
			if not humanoid or not hrp or not leader.Parent or not mayHold(leader, teamId) then
				releaseLeader(banner)
			elseif newLeader and newLeader ~= leader and holderNear(teamId, banner.model.Position) == newLeader then
				-- Chegou o lider: passa a ser ele.
				releaseLeader(banner)
			else
				-- Along the route, a few steps ahead of the leader: the leader sets the pace.
				local points = banner.waypoints
				local here = banner.model.Position
				local done = progress[teamId] or project(points, here, 0)
				local leaderAt = project(points, hrp.Position, done)
				local target = math.max(done, leaderAt + M.leadDistance)
				done += math.min(target - done, (M.leaderSpeed + 6) * dt)
				progress[teamId] = done
				local spot, dir, leg = along(points, done)
				banner.leg = leg
				banner.heading = dir
				banner.lastLeaderAt = hrp.Position
				local nextAt = Vector3.new(spot.X, here.Y, spot.Z)
				banner.model.CFrame = CFrame.lookAt(nextAt, nextAt + dir)

				-- Perto da porta da claque: acaba a marcha, corre-se para dentro. O
				-- lider larga a faixa (corre ao seu passo) e ela vai direita a porta.
				if (Vector3.new(nextAt.X, gate.Y, nextAt.Z) - gate).Magnitude <= M.runDistance then
					setStage(banner, "corrida")
					releaseLeader(banner)
				end
			end
		end

		-- Sem lider: o caminho de sempre, ponto a ponto.
		if not banner.leader then
			local here = banner.model.Position
			if banner.stage == "marcha" and (Vector3.new(here.X, gate.Y, here.Z) - gate).Magnitude <= M.runDistance then
				setStage(banner, "corrida")
			end
			local target = banner.waypoints[banner.leg + 1]
			if not target then
				if not banner.model:GetAttribute("Arrived") then
					banner.model:SetAttribute("Arrived", true)
					setStage(banner, "chegou")
				end
				continue
			end

			-- A passo de marcha; na corrida, a correr.
			local speed = if banner.stage == "corrida" then M.runSpeed else M.speed
			local delta = target - here
			if delta.Magnitude <= speed * dt then
				banner.leg += 1
				banner.model.CFrame = CFrame.new(target) * banner.model.CFrame.Rotation
			else
				-- Atravessada na rua, virada para a frente: toda a gente vem atras dela.
				local step = delta.Unit * speed * dt
				banner.model.CFrame = CFrame.lookAt(here + step, here + step + delta.Unit)
			end
		end

		reopenCrossings(banner)

		-- Quem vai junto a faixa ganha credito, proporcional ao tempo que a
		-- acompanha. Andar ao lado dela o caminho todo vale o credito todo.
		for _, player in Players:GetPlayers() do
			if Teams.get(player) == teamId then
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp and (hrp.Position - banner.model.Position).Magnitude <= M.radius then
					credit[player] = math.min((credit[player] or 0) + dt / banner.seconds, 1)
				end
			end
		end
	end
end

return March
