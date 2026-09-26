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
	-- Larga como a rua cheia de gente atras dela.
	banner.Size = Vector3.new(26, 5, 0.6)
	banner.CFrame = CFrame.new(at)
	banner.Color = team.color
	banner.Material = Enum.Material.Fabric
	banner.Anchored = true
	banner.CanCollide = false
	banner:SetAttribute("Team", teamId)
	banner:SetAttribute("Moving", false)
	banner:SetAttribute("Arrived", false)
	banner.Parent = parent

	-- O pano (com o nome da claque) cada ecra o faz e o pendura desta peca
	-- (Corteo.client, Pano): aqui a peca so marca o sitio e brilha.
	banner.Transparency = 1

	-- Brilha, para se ver de longe qual e o ponto de encontro.
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 45
	light.Color = team.color
	light.Parent = banner

	return banner
end

--[[
	A fase do corteo comecou: as faixas aparecem a porta de cada sede, paradas,
	a espera da ordem de sair.
]]
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
			banners[teamId].model:SetAttribute("Stage", "espera")
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
function March.form(teamId: string): boolean
	local banner = banners[teamId]
	if not (active and banner) or banner.stage ~= "espera" then
		return false
	end
	local here = banner.model.Position
	local ahead = banner.waypoints[2] or here + Vector3.new(0, 0, -1)
	local look = Vector3.new(ahead.X - here.X, 0, ahead.Z - here.Z)
	if look.Magnitude > 0.1 then
		banner.model.CFrame = CFrame.lookAt(here, here + look.Unit)
	end
	banner.formedAt = os.clock()
	setStage(banner, "formatura")
	return true
end

-- O corteo arranca: a faixa anda, e quem for atras dela ganha credito.
local function start(banner: Banner)
	local teamId = banner.teamId
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

function March.stop()
	active = false
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
	for teamId, banner in banners do
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
				local at = hrp.Position
				local movedBy = Vector3.new(at.X - banner.lastLeaderAt.X, 0, at.Z - banner.lastLeaderAt.Z)
				if movedBy.Magnitude > 0.2 then
					banner.heading = banner.heading:Lerp(movedBy.Unit, 0.25).Unit
				end
				banner.lastLeaderAt = at

				local here = banner.model.Position
				local want = Vector3.new(at.X, 3, at.Z) + banner.heading * M.leadDistance
				local delta = want - here
				local stepLength = math.min(delta.Magnitude, (M.leaderSpeed + 6) * dt)
				local nextAt = if delta.Magnitude > 0.05 then here + delta.Unit * stepLength else here
				banner.model.CFrame = CFrame.lookAt(nextAt, nextAt + banner.heading)

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
