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

	Os bonecos que marcham atras da faixa nao vivem aqui: cada ecra desenha-os a
	partir da posicao dela (Corteo.client). Nao pesam nada na rede.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Teams = require(script.Parent:WaitForChild("Teams"))
local City = require(script.Parent:WaitForChild("City"))

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
	heading: Vector3, -- para onde o lider vai, alisado
	lastLeaderAt: Vector3,
}

local banners: { [string]: Banner } = {}
local credit: { [Player]: number } = {} -- 0 a 1: quanto do percurso acompanhou
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
	O percurso: sai-se pela frente da sede, contorna-se o quarteirao por tras,
	desce-se a rua do meio ate a avenida, e segue-se por ela ate a porta do topo
	da claque. Cada sede fica do lado do seu topo, por isso os dois corteos
	descem a avenida cada um para o seu lado e nunca se cruzam.
]]
local function routeFor(teamId: string): { Vector3 }
	local start = City.spawnPoint(teamId)
	if not start then
		return {}
	end

	local S = Config.Stadium
	local standDepth = S.rows * S.rowDepth
	local outerZ = S.pitchWidth / 2 + S.standGap + standDepth + 26
	local outerX = S.pitchLength / 2 + S.standGap + standDepth + 26
	local roadZ = outerZ + 70

	local side = Config.Teams[teamId].side
	local behind = roadZ + 165 -- por tras dos quarteiroes, onde nao ha predios
	local street = side * 20 -- a rua do meio, cada claque do seu lado
	local flank = side * (outerX + 20) -- por fora da muralha, rente ao topo

	return {
		start,
		Vector3.new(start.X, 3, behind),
		Vector3.new(street, 3, behind),
		Vector3.new(street, 3, roadZ),
		Vector3.new(flank, 3, roadZ),
		Vector3.new(side * (outerX + 10), 3, 0), -- a porta da claque
	}
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

	-- O nome dos dois lados: le-se a frente de quem vem atras e de quem espera.
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sign = Instance.new("SurfaceGui")
		sign.Face = face
		sign.CanvasSize = Vector2.new(900, 200)
		sign.Parent = banner

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.Text = team.name
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(245, 245, 245)
		text.Parent = sign
	end

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
			}
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

function March.launch(teamId: string): boolean
	local banner = banners[teamId]
	if not (active and banner) or banner.moving then
		return false
	end
	banner.moving = true
	banner.model:SetAttribute("Moving", true)

	-- O lider, se estiver junto a faixa, passa a guia-la.
	local leader = Teams.leader(teamId)
	local humanoid, hrp = if leader then leaderRoot(leader) else nil, nil
	if leader and humanoid and hrp and (hrp.Position - banner.model.Position).Magnitude <= M.radius then
		banner.leader = leader
		banner.lastLeaderAt = hrp.Position
		banner.heading = Vector3.new(0, 0, 1)
		humanoid.WalkSpeed = M.leaderSpeed
		banner.model:SetAttribute("Led", true)
	end
	return true
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

	for teamId, banner in banners do
		if not banner.moving then
			continue
		end

		-- Guiada pelo lider: vai uns passos a frente dele, para onde ele vai.
		local leader = banner.leader
		if leader then
			local humanoid, hrp = leaderRoot(leader)
			if not humanoid or not hrp or not leader.Parent or Teams.leader(teamId) ~= leader then
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

				-- Chegou a porta da claque: entra.
				local gate = banner.waypoints[#banner.waypoints]
				if (Vector3.new(nextAt.X, gate.Y, nextAt.Z) - gate).Magnitude <= M.arriveRadius then
					banner.model:SetAttribute("Arrived", true)
					releaseLeader(banner)
					banner.leg = #banner.waypoints
				end
			end
		end

		-- Sem lider: o caminho de sempre, ponto a ponto.
		if not banner.leader then
			local target = banner.waypoints[banner.leg + 1]
			if not target then
				if not banner.model:GetAttribute("Arrived") then
					banner.model:SetAttribute("Arrived", true)
				end
				continue
			end

			local here = banner.model.Position
			local delta = target - here
			if delta.Magnitude <= M.speed * dt then
				banner.leg += 1
				banner.model.CFrame = CFrame.new(target) * banner.model.CFrame.Rotation
			else
				-- Atravessada na rua, virada para a frente: toda a gente vem atras dela.
				local step = delta.Unit * M.speed * dt
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
