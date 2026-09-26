--!strict
--[[
	As academias a funcionar, uma por clube (no mapa: Workspace.Academia_home e
	Workspace.Academia_away, do AcademyBuilder).

	Antes do jogo (sede e corteo) quem joga aparece na academia do seu clube, a
	treinar, em vez de no estadio. Cada academia tem uma bola de treino que se
	joga como a do jogo (colada aos pes, roubos, a mesma barra de chuto), golos
	com "GOLO" no ecra de quem esta la, e um guarda-redes de treino numa das
	balizas.

	Os bonecos do plantel nao jogam aqui: ficam fora das linhas a ver, um por
	cada lugar do clube que ainda nao tem pessoa.

	No corteo o autocarro de cada clube leva a sua gente ao estadio (Transit);
	quando chega, a academia desse clube fecha ate ao proximo jogo.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Academy = {}

local A = Config.Academy
local F = Config.Football
local BALL_SIZE = 2.2
local R = BALL_SIZE / 2
local GROUP = "BolaTreino"

type Site = {
	teamId: string,
	folder: Instance,
	centre: Vector3,
	entrySide: number, -- de que lado (em z) fica a entrada: e ai que se aparece
	keeperSide: number, -- em que baliza (em x) esta o guarda-redes
	open: boolean,
	ball: BasePart?,
	carrier: Player?,
	carriedSince: number,
	flightUntil: number,
	noClaim: { [Player]: number },
	curve: number,
	curveUntil: number,
	lastKicker: Player?,
	scoredAt: number,
	keeper: Model?,
	keeperHolding: number,
	spots: { Vector3 },
	watchers: { Model },
}

local sites: { [string]: Site } = {}

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.xAxis
end

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function groundY(): number
	return A.groundY + 0.4 + R
end

-- A academia de um clube esta aberta (antes do jogo, ate o autocarro chegar)?
function Academy.isOpen(teamId: string): boolean
	local site = sites[teamId]
	return site ~= nil and site.open
end

-- Alguma academia aberta?
function Academy.anyOpen(): boolean
	for _, site in sites do
		if site.open then
			return true
		end
	end
	return false
end

function Academy.setOpen(teamId: string?, on: boolean)
	for id, site in sites do
		if teamId == nil or id == teamId then
			site.open = on
			if not on then
				site.carrier = nil
			end
		end
	end
end

--[[
	Onde aparece quem joga: perto da entrada do relvado da academia do seu
	clube, cada um no seu sitio (pelo numero do lugar).
]]
function Academy.spotFor(teamId: string, slot: number): Vector3?
	local site = sites[teamId]
	if not site then
		return nil
	end
	local c = site.centre
	local column = (slot - 1) % 5
	local line = (slot - 1) // 5
	return Vector3.new(c.X - 14 + column * 7, A.groundY + 3.2, c.Z + site.entrySide * (A.pitchWidth / 2 - 8 - line * 6))
end

--------------------------------------------------------------------------------
-- A bola de treino (as mesmas regras do Football)
--------------------------------------------------------------------------------

local function resetBall(site: Site)
	local b = site.ball
	if not b then
		return
	end
	site.carrier = nil
	b.AssemblyLinearVelocity = Vector3.zero
	b.AssemblyAngularVelocity = Vector3.zero
	b.CFrame = CFrame.new(site.centre.X, groundY() + 0.5, site.centre.Z)
end

local function makeBall(site: Site)
	local b = Instance.new("Part")
	b.Name = "BolaTreino"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(BALL_SIZE, BALL_SIZE, BALL_SIZE)
	b.Color = Color3.fromRGB(248, 248, 248)
	b.Material = Enum.Material.SmoothPlastic
	b.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.4, 0.45, 1, 1)
	b.CollisionGroup = GROUP
	b.Parent = site.folder
	site.ball = b
	resetBall(site)
	pcall(function()
		b:SetNetworkOwner(nil)
	end)
end

-- As pessoas que jogam por este clube e estao vivas.
local function players(site: Site): { { player: Player, root: BasePart } }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Team") == "jogador" and player:GetAttribute("PitchTeam") == site.teamId then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = rootOf(player)
			if root and humanoid and humanoid.Health > 0 then
				table.insert(list, { player = player, root = root })
			end
		end
	end
	return list
end

--[[
	Um chuto, como no jogo: `power` 0 a 1, `curveIn` -1 a 1 (efeito), `height`
	-1 a 1 (rasteira, normal, chapeu). Com a bola nos pes, ou de primeira numa
	bola solta ao alcance. Devolve se o chuto era da academia (senao e do
	Football).
]]
function Academy.kick(player: Player, power: number, curveIn: number, height: number): boolean
	local teamId = player:GetAttribute("PitchTeam")
	local site = if type(teamId) == "string" then sites[teamId] else nil
	local root = rootOf(player)
	if not site or not site.open or not root then
		return false
	end
	local b = site.ball
	if not b then
		return false
	end
	local now = os.clock()
	local mine = site.carrier == player
	if not mine then
		local reach = horizontal(b.Position, root.Position)
		local tooHigh = b.Position.Y - (root.Position.Y - 3) > F.claimHeight + 1
		if site.carrier ~= nil or reach > F.claimRange + 2.4 or tooHigh or (site.noClaim[player] or 0) > now then
			-- Longe da bola: se esta na academia, o chuto fica por aqui.
			return horizontal(root.Position, site.centre) < A.pitchLength
		end
	end
	local p = math.clamp(power, 0, 1)
	local h = math.clamp(height, -1, 1)
	local dir = flat(root.CFrame.LookVector)
	local speed = F.kickSpeedMin + (F.kickSpeedMax - F.kickSpeedMin) * p
	local liftFraction = if h < 0 then F.liftNeutral * (1 + h) else F.liftNeutral + (F.liftMax - F.liftNeutral) * h
	if mine then
		b.CFrame = CFrame.new(root.Position.X + dir.X * F.dribbleDistance, groundY(), root.Position.Z + dir.Z * F.dribbleDistance)
	end
	site.carrier = nil
	site.flightUntil = now + F.kickFlight
	site.noClaim[player] = now + F.kickLockout
	b.AssemblyAngularVelocity = Vector3.zero
	b.AssemblyLinearVelocity = dir * speed + Vector3.new(0, speed * liftFraction, 0)
	site.curve = math.clamp(curveIn, -1, 1) * F.curveAccel
	site.curveUntil = now + F.curveTime
	site.lastKicker = player
	return true
end

-- A bola a cada instante: nos pes de quem a tem, ou solta a rolar.
local function stepBall(site: Site, dt: number, now: number)
	local b = site.ball
	if not b or now < site.keeperHolding then
		return
	end
	local list = players(site)

	local owner = site.carrier
	if owner then
		local root = rootOf(owner)
		if not root or horizontal(root.Position, site.centre) > A.pitchLength then
			site.carrier = nil
		else
			-- Roubo: quem encosta fica com ela (menos logo a seguir a ganha-la).
			if now - site.carriedSince > F.tackleImmunity then
				for _, other in list do
					if other.player ~= owner and horizontal(other.root.Position, b.Position) < F.tackleRange and (site.noClaim[other.player] or 0) <= now then
						site.carrier = other.player
						site.carriedSince = now
						root = other.root
						break
					end
				end
			end
			local look = flat(root.CFrame.LookVector)
			local at = root.Position + look * F.dribbleDistance
			local v = root.AssemblyLinearVelocity
			b.CFrame = CFrame.new(at.X, groundY(), at.Z)
			b.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
			b.AssemblyAngularVelocity = Vector3.new(v.Z, 0, -v.X) / R
			return
		end
	end

	-- Solta: trava forte no chao, pouco no ar; o efeito desvia-a de lado.
	local v = b.AssemblyLinearVelocity
	local onGround = b.Position.Y < groundY() + 0.4
	local keep = math.exp(-(if onGround then F.rollDrag else F.airDrag) * dt)
	local hv = Vector3.new(v.X * keep, 0, v.Z * keep)
	if site.curve ~= 0 and now < site.curveUntil and hv.Magnitude > 4 then
		hv += hv.Unit:Cross(Vector3.yAxis) * site.curve * dt
	end
	b.AssemblyLinearVelocity = hv + Vector3.new(0, v.Y, 0)

	-- Quem chega a ela fica com ela.
	if now >= site.flightUntil then
		local best: Player? = nil
		local bestD = F.claimRange
		for _, other in list do
			local d = horizontal(other.root.Position, b.Position)
			if d < bestD and b.Position.Y - (other.root.Position.Y - 3) < F.claimHeight and (site.noClaim[other.player] or 0) <= now then
				best, bestD = other.player, d
			end
		end
		if best then
			site.carrier = best
			site.carriedSince = now
			site.lastKicker = best
		end
	end
end

-- A bola entrou numa das balizas? Ou saiu de vez?
local function checkGoal(site: Site, now: number)
	local b = site.ball
	if not b or now - site.scoredAt < 3 then
		return
	end
	local c = site.centre
	local p = b.Position
	local depth = math.abs(p.X - c.X) - A.pitchLength / 2
	if depth > R + 0.8 and depth < A.goalDepth + 1 and math.abs(p.Z - c.Z) < A.goalHalfWidth and p.Y < A.groundY + A.goalHeight then
		site.scoredAt = now
		local who = site.lastKicker
		Remotes.Academia:FireAllClients({ kind = "golo", name = if who then who.DisplayName else nil, at = c })
		task.delay(2.5, resetBall, site)
	end
	if math.abs(p.X - c.X) > A.pitchLength / 2 + 30 or math.abs(p.Z - c.Z) > A.pitchWidth / 2 + 30 or p.Y < A.groundY - 20 then
		resetBall(site)
	end
end

--------------------------------------------------------------------------------
-- O guarda-redes de treino
--------------------------------------------------------------------------------

local function stepKeeper(site: Site, dt: number, now: number)
	local k = site.keeper
	local b = site.ball
	if not k or not b or not k.PrimaryPart then
		return
	end
	local c = site.centre
	local side = site.keeperSide
	local goalX = c.X + side * (A.pitchLength / 2 - 1.8)
	local here = k:GetPivot().Position
	local bp = b.Position

	-- Com a bola nas maos: fica com ela um pouco e depois repoe para o meio.
	if now < site.keeperHolding then
		b.AssemblyLinearVelocity = Vector3.zero
		b.CFrame = CFrame.new(here + Vector3.new(-side * 1.6, 0, 0)) -- a frente do peito
		return
	elseif site.keeperHolding > 0 then
		site.keeperHolding = 0
		b.AssemblyLinearVelocity = Vector3.new(-side * 48, 22, (math.random() - 0.5) * 20)
	end

	-- Acompanha a bola ao longo da linha, sem sair da baliza.
	local targetZ = c.Z
	if (bp.X - c.X) * side > 0 then
		targetZ = math.clamp(bp.Z, c.Z - A.goalHalfWidth + 1.2, c.Z + A.goalHalfWidth - 1.2)
	end
	local z = here.Z + math.clamp(targetZ - here.Z, -A.keeperSpeed * dt, A.keeperSpeed * dt)
	-- O pivo do boneco e o tronco, 3 studs acima do chao.
	local at = Vector3.new(goalX, A.groundY, z)
	k:PivotTo(CFrame.lookAt(at + Vector3.new(0, 3, 0), Vector3.new(c.X, A.groundY + 3, z)))

	-- Defende: se a bola vem ao alcance das maos, agarra-a (nem sempre).
	local toBall = bp - (at + Vector3.new(0, 3, 0))
	local incoming = b.AssemblyLinearVelocity.X * side > 4
	if incoming and Vector3.new(toBall.X, 0, toBall.Z).Magnitude < 3.2 and toBall.Y < 4.5 then
		local fast = b.AssemblyLinearVelocity.Magnitude > 55
		if not fast or math.random() < 0.5 then
			site.keeperHolding = now + 1.4
			site.carrier = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Os bonecos que ficam a ver
--------------------------------------------------------------------------------

local function watcher(site: Site, number: number, at: Vector3): Model
	local team = Config.Teams[site.teamId]
	local model = Instance.new("Model")
	model.Name = "AVer"
	local facing = CFrame.lookAt(at, Vector3.new(site.centre.X, at.Y, site.centre.Z))
	local function p(name: string, size: Vector3, offset: Vector3, colour: Color3)
		local x = Instance.new("Part")
		x.Name = name
		x.Size = size
		x.CFrame = facing * CFrame.new(offset)
		x.Color = colour
		x.Anchored = true
		x.CanCollide = false
		x.Material = Enum.Material.SmoothPlastic
		x.Parent = model
		return x
	end
	local torso = p("Tronco", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), team.color)
	model.PrimaryPart = torso
	p("Cabeca", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), Color3.fromRGB(214, 170, 130))
	for _, s in { -1, 1 } do
		p("Braco", Vector3.new(1, 2, 1), Vector3.new(s * 1.5, 3, 0), team.color)
		p("Perna", Vector3.new(1, 2, 1), Vector3.new(s * 0.5, 1, 0), Color3.fromRGB(240, 240, 240))
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(100, 100)
	gui.Parent = torso
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Text = tostring(number)
	label.Parent = gui
	model.Parent = site.folder
	return model
end

--[[
	Um boneco a ver por cada lugar do clube ainda sem pessoa. `bots` e a lista
	desses lugares (equipa e numero), que o Main tira do Squad.
]]
function Academy.setWatchers(bots: { { teamId: string, number: number } })
	for teamId, site in sites do
		local mine = {}
		for _, b in bots do
			if b.teamId == teamId then
				table.insert(mine, b)
			end
		end
		local wanted = if site.open then math.min(#mine, #site.spots) else 0
		local same = #site.watchers == wanted
		if same then
			for i, m in site.watchers do
				local b = mine[i]
				if not b or m:GetAttribute("Key") ~= b.number then
					same = false
				end
			end
		end
		if not same then
			for _, m in site.watchers do
				m:Destroy()
			end
			table.clear(site.watchers)
			for i = 1, wanted do
				local m = watcher(site, mine[i].number, site.spots[i])
				m:SetAttribute("Key", mine[i].number)
				table.insert(site.watchers, m)
			end
		end
	end
end

--------------------------------------------------------------------------------

local function setupSite(teamId: string, folder: Instance)
	local config = Config.Academies[teamId]
	local centre = if config then config.centre else Vector3.zero
	local site: Site = {
		teamId = teamId,
		folder = folder,
		centre = Vector3.new(centre.X, 0, centre.Z),
		entrySide = -1,
		keeperSide = 1,
		open = true,
		ball = nil,
		carrier = nil,
		carriedSince = 0,
		flightUntil = 0,
		noClaim = {},
		curve = 0,
		curveUntil = 0,
		lastKicker = nil,
		scoredAt = 0,
		keeper = nil,
		keeperHolding = 0,
		spots = {},
		watchers = {},
	}
	-- De que lado ficam a entrada e o guarda-redes: le-se do mapa (a academia
	-- pode estar virada ao contrario).
	local arrival = folder:FindFirstChild("Chegada")
	if arrival and arrival:IsA("BasePart") then
		site.entrySide = if arrival.Position.Z < site.centre.Z then -1 else 1
		arrival.Transparency = 1
	end
	local places = folder:FindFirstChild("Lugares")
	for _, p in (if places then places:GetChildren() else {}) do
		if p:IsA("BasePart") then
			table.insert(site.spots, Vector3.new(p.Position.X, A.groundY, p.Position.Z))
			p.Transparency = 1
		end
	end
	local keeper = folder:FindFirstChild("GuardaRedes")
	if keeper and keeper:IsA("Model") then
		site.keeper = keeper
		site.keeperSide = if keeper:GetPivot().Position.X > site.centre.X then 1 else -1
	end
	sites[teamId] = site
	makeBall(site)
end

function Academy.start()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
	end)
	-- A bola de treino bate nas paredes invisiveis da vedacao (BallWall), e
	-- como a do jogo, quem joga nao a empurra com o corpo.
	PhysicsService:CollisionGroupSetCollidable(GROUP, "BallWall", true)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(GROUP, "Footballers", false)
	end)

	for _, teamId in Config.TeamOrder do
		local folder = workspace:FindFirstChild("Academia_" .. teamId)
		if folder then
			setupSite(teamId, folder)
		else
			warn("[Ultras FC] Sem Workspace.Academia_" .. teamId .. ": esse clube aparece no estadio.")
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, site in sites do
			if site.open then
				stepBall(site, dt, now)
				checkGoal(site, now)
				stepKeeper(site, dt, now)
			end
		end
	end)
end

return Academy
