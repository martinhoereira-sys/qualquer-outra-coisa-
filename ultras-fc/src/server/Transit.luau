--!strict
--[[
	Os autocarros a andar.

	Os percursos, as paragens e os autocarros estao no mapa
	(Workspace.Transportes, do TransitBuilder). Aqui cada autocarro segue o seu
	percurso pela faixa da direita, com curvas redondas nos cruzamentos:
	acelera e trava aos poucos, abranda antes das curvas, para nas paragens da
	sua linha de portas abertas, e trava se tiver gente ou outro autocarro a
	frente.

	A fisica e a serio, para quem vai la dentro: o autocarro e solto e puxado
	por restricoes (AlignPosition/AlignOrientation) para o ponto do percurso.
	Quem vai de pe e levado pelo chao, quem vai sentado vai no banco, e as
	rodas giram a velocidade dele.

	O autocarro da equipa (linha E) so arranca quando o jogo manda: espera na
	academia de portas abertas, leva quem joga ao estadio e volta.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BusBuilder = require(script.Parent:WaitForChild("BusBuilder"))

local Transit = {}

local T = Config.Transit
local ROAD_Y = -0.6
local RIDE = BusBuilder.FLOOR - 0.5 -- a altura do chassis acima da estrada
local HALF_LENGTH = BusBuilder.LENGTH / 2

type Path = { points: { Vector3 }, lengths: { number }, total: number }

type Bus = {
	model: Model,
	chassis: BasePart,
	line: string,
	path: Path,
	stops: { { s: number, name: string } },
	nextStop: number,
	s: number,
	v: number,
	dwellUntil: number,
	holding: boolean, -- o da equipa, parado ate lhe mandarem arrancar
	align: AlignPosition,
	turn: AlignOrientation,
	motors: { HingeConstraint },
	doors: { { weld: Weld, closed: CFrame, open: CFrame } },
	doorsOpen: boolean,
}

local buses: { Bus } = {}
local teamBus: Bus? = nil
local onTeamArrived: (() -> ())? = nil

--------------------------------------------------------------------------------
-- O percurso
--------------------------------------------------------------------------------

--[[
	A linha a seguir: dos pontos do mapa (no meio da rua), a faixa da direita,
	com cada esquina trocada por uma curva de raio T.cornerRadius.
]]
local function buildPath(nodes: { Vector3 }): Path
	local n = #nodes
	local corners: { { at: Vector3, a: Vector3, b: Vector3 } } = {}
	for i = 1, n do
		local prev = nodes[(i - 2) % n + 1]
		local here = nodes[i]
		local nextN = nodes[i % n + 1]
		local a = Vector3.new(here.X - prev.X, 0, here.Z - prev.Z).Unit
		local b = Vector3.new(nextN.X - here.X, 0, nextN.Z - here.Z).Unit
		local ra = a:Cross(Vector3.yAxis)
		local rb = b:Cross(Vector3.yAxis)
		-- A esquina da faixa (a da direita das duas ruas).
		local at = Vector3.new(here.X, ROAD_Y, here.Z) + (ra + rb) * (T.laneOffset / (1 + a:Dot(b)))
		table.insert(corners, { at = at, a = a, b = b })
	end

	local points: { Vector3 } = {}
	for _, c in corners do
		if c.a:Dot(c.b) > 0.99 then
			table.insert(points, c.at)
		else
			-- A curva: da entrada a saida, puxada pela esquina.
			local r = T.cornerRadius
			local p0 = c.at - c.a * r
			local p2 = c.at + c.b * r
			for k = 0, 8 do
				local t = k / 8
				table.insert(points, p0 * (1 - t) ^ 2 + c.at * 2 * (1 - t) * t + p2 * t * t)
			end
		end
	end

	local lengths: { number } = { 0 }
	local total = 0
	for i = 1, #points do
		local a = points[i]
		local b = points[i % #points + 1]
		total += (b - a).Magnitude
		lengths[i + 1] = total
	end
	return { points = points, lengths = lengths, total = total }
end

local function pointAt(path: Path, s: number): Vector3
	s = s % path.total
	local lo, hi = 1, #path.points
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if path.lengths[mid] <= s then
			lo = mid
		else
			hi = mid - 1
		end
	end
	local a = path.points[lo]
	local b = path.points[lo % #path.points + 1]
	local seg = path.lengths[lo + 1] - path.lengths[lo]
	local t = if seg > 0 then (s - path.lengths[lo]) / seg else 0
	return a:Lerp(b, t)
end

local function headingAt(path: Path, s: number): Vector3
	local d = pointAt(path, s + 3) - pointAt(path, s - 3)
	local flat = Vector3.new(d.X, 0, d.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
end

-- A distancia ao longo do percurso do ponto mais perto de `at`.
local function project(path: Path, at: Vector3): (number, number)
	local bestS, bestD = 0, math.huge
	for i = 1, #path.points do
		local a = path.points[i]
		local b = path.points[i % #path.points + 1]
		local ab = b - a
		local len2 = ab:Dot(ab)
		local t = if len2 > 0 then math.clamp((at - a):Dot(ab) / len2, 0, 1) else 0
		local p = a + ab * t
		local d = Vector3.new(p.X - at.X, 0, p.Z - at.Z).Magnitude
		if d < bestD then
			bestD = d
			bestS = path.lengths[i] + math.sqrt(len2) * t
		end
	end
	return bestS, bestD
end

--------------------------------------------------------------------------------
-- O autocarro fisico
--------------------------------------------------------------------------------

local GROUP = "Autocarros"

local function setupGroup()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end

local function makePhysical(model: Model): (BasePart, AlignPosition, AlignOrientation, { HingeConstraint }, { { weld: Weld, closed: CFrame, open: CFrame } })
	local chassis = model.PrimaryPart :: BasePart
	local motors: { HingeConstraint } = {}
	local doors = {}

	local wheels: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Roda" then
			table.insert(wheels, d)
		end
	end

	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") or d == chassis then
			continue
		end
		d.CollisionGroup = GROUP
		d.Massless = true
		if d.Name == "Roda" then
			d.CanCollide = false
			local a0 = Instance.new("Attachment")
			a0.CFrame = chassis.CFrame:ToObjectSpace(d.CFrame)
			a0.Parent = chassis
			local a1 = Instance.new("Attachment")
			a1.Parent = d
			local hinge = Instance.new("HingeConstraint")
			hinge.Attachment0 = a0
			hinge.Attachment1 = a1
			hinge.ActuatorType = Enum.ActuatorType.Motor
			hinge.MotorMaxTorque = 1e6
			hinge.MotorMaxAcceleration = 60
			hinge.Parent = d
			table.insert(motors, hinge)
		elseif d.Name == "Jante" then
			-- A jante gira com a roda mais perto.
			d.CanCollide = false
			local nearest, best = nil, math.huge
			for _, w in wheels do
				local dist = (w.Position - d.Position).Magnitude
				if dist < best then
					nearest, best = w, dist
				end
			end
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = nearest or chassis
			weld.Part1 = d
			weld.Parent = d
		elseif d.Name == "Porta" then
			local weld = Instance.new("Weld")
			weld.Part0 = chassis
			weld.Part1 = d
			weld.C0 = chassis.CFrame:ToObjectSpace(d.CFrame)
			weld.Parent = d
			local slide = (d:GetAttribute("Slide") :: number?) or 1
			table.insert(doors, { weld = weld, closed = weld.C0, open = weld.C0 * CFrame.new(0, 0, slide * (d.Size.Z - 0.1)) })
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = chassis
			weld.Part1 = d
			weld.Parent = d
		end
	end

	local attach = Instance.new("Attachment")
	attach.Name = "Guia"
	attach.Parent = chassis
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attach
	align.RigidityEnabled = true
	align.Position = chassis.Position
	align.Parent = chassis
	local turn = Instance.new("AlignOrientation")
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = attach
	turn.RigidityEnabled = true
	turn.CFrame = chassis.CFrame.Rotation
	turn.Parent = chassis

	chassis.CollisionGroup = GROUP
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	pcall(function()
		chassis:SetNetworkOwner(nil)
	end)
	return chassis, align, turn, motors, doors
end

local function setDoors(bus: Bus, open: boolean)
	if bus.doorsOpen == open then
		return
	end
	bus.doorsOpen = open
	for _, door in bus.doors do
		door.weld.C0 = if open then door.open else door.closed
	end
end

--------------------------------------------------------------------------------
-- Conduzir
--------------------------------------------------------------------------------

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Tem alguem (uma pessoa ou outro autocarro) mesmo a frente?
local function blocked(bus: Bus, heading: Vector3, reach: number): boolean
	local front = bus.chassis.Position + heading * (HALF_LENGTH + 0.5) + Vector3.new(0, 1.5, 0)
	rayParams.FilterDescendantsInstances = { bus.model }
	for _, side in { -3, 0, 3 } do
		local from = front + heading:Cross(Vector3.yAxis) * side
		local hit = workspace:Raycast(from, heading * reach, rayParams)
		if hit then
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if model and (model:FindFirstChildOfClass("Humanoid") or model.Name:sub(1, 9) == "Autocarro") then
				return true
			end
		end
	end
	return false
end

local function step(bus: Bus, dt: number, now: number)
	local path = bus.path

	-- Parado numa paragem (ou o da equipa, a espera de ordem).
	if bus.holding or now < bus.dwellUntil then
		bus.v = 0
	else
		setDoors(bus, false)
		-- A velocidade que se quer: a de cruzeiro, menos nas curvas e antes da paragem.
		local want = T.cruise
		for ahead = 4, 44, 5 do
			local a = headingAt(path, bus.s + ahead - 4)
			local b = headingAt(path, bus.s + ahead + 4)
			if a:Dot(b) < 0.985 then
				want = math.min(want, math.sqrt(T.turnSpeed ^ 2 + 2 * T.brake * math.max(ahead - 6, 0)))
			end
		end
		local stop = bus.stops[bus.nextStop]
		if stop then
			local ds = (stop.s - bus.s) % path.total
			want = math.min(want, math.sqrt(2 * T.brake * math.max(ds - 0.3, 0)) + 0.5)
			if ds < 0.6 then
				-- Chegou: encosta, abre as portas.
				bus.v = 0
				bus.dwellUntil = now + T.dwell
				setDoors(bus, true)
				bus.nextStop = bus.nextStop % #bus.stops + 1
				if bus == teamBus then
					if stop.name:find("Academia") then
						bus.holding = true -- espera pela proxima ida
					elseif onTeamArrived then
						task.spawn(onTeamArrived :: () -> ())
					end
				end
				return
			end
		end
		local heading = headingAt(path, bus.s)
		if blocked(bus, heading, math.max(8, bus.v * 1.4)) then
			want = 0
		end
		local rate = if want > bus.v then T.accel else T.brake
		bus.v = if want > bus.v then math.min(want, bus.v + rate * dt) else math.max(want, bus.v - rate * dt)
		bus.s = (bus.s + bus.v * dt) % path.total
	end

	local at = pointAt(path, bus.s) + Vector3.new(0, RIDE, 0)
	local heading = headingAt(path, bus.s)
	bus.align.Position = at
	bus.turn.CFrame = CFrame.lookAt(Vector3.zero, heading)
	for _, motor in bus.motors do
		-- A frente do autocarro e -Z: as rodas giram para tras no eixo X.
		motor.AngularVelocity = bus.v / BusBuilder.WHEEL_R
	end
end

--------------------------------------------------------------------------------

-- O autocarro da equipa: abre as portas na academia e, passado `wait`, arranca.
function Transit.boardTeamBus(wait: number)
	local bus = teamBus
	if not bus then
		return
	end
	bus.holding = true
	setDoors(bus, true)
	task.delay(wait, function()
		bus.holding = false
		bus.dwellUntil = 0
	end)
end

-- Chama-se quando o autocarro da equipa chega ao estadio.
function Transit.onTeamArrived(fn: () -> ())
	onTeamArrived = fn
end

-- Quem esta dentro do autocarro da equipa (sentado ou de pe).
function Transit.teamPassengers(): { Player }
	local bus = teamBus
	local list: { Player } = {}
	if not bus then
		return list
	end
	local cf, size = bus.model:GetBoundingBox()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local rel = cf:PointToObjectSpace(root.Position)
			if math.abs(rel.X) < size.X / 2 and math.abs(rel.Y) < size.Y / 2 + 2 and math.abs(rel.Z) < size.Z / 2 then
				table.insert(list, player)
			end
		end
	end
	return list
end

function Transit.start()
	local root = workspace:FindFirstChild("Transportes")
	if not root then
		warn("[Ultras FC] Sem Workspace.Transportes: nao ha autocarros.")
		return
	end
	setupGroup()

	-- Os percursos, a partir dos pontos do mapa; o tracado de ver no Studio sai.
	local paths: { [string]: Path } = {}
	local routes = root:FindFirstChild("Rotas")
	for _, folder in (if routes then routes:GetChildren() else {}) do
		local points: { BasePart } = {}
		for _, p in folder:GetChildren() do
			if p:IsA("BasePart") and p.Name == "Ponto" then
				table.insert(points, p)
				p.Transparency = 1
			end
		end
		local drawn = folder:FindFirstChild("Tracado")
		if drawn then
			drawn:Destroy()
		end
		table.sort(points, function(a, b)
			return ((a:GetAttribute("Order") :: number?) or 0) < ((b:GetAttribute("Order") :: number?) or 0)
		end)
		if #points >= 2 then
			local nodes = {}
			for _, p in points do
				table.insert(nodes, p.Position)
			end
			paths[folder.Name] = buildPath(nodes)
		end
	end

	-- As paragens de cada linha, pela ordem do percurso.
	local stopModels = root:FindFirstChild("Paragens")
	local function stopsFor(line: string, path: Path)
		local list = {}
		for _, m in (if stopModels then stopModels:GetChildren() else {}) do
			local lines = m:GetAttribute("Linhas")
			if m:IsA("Model") and type(lines) == "string" and table.find(string.split(lines, ","), line) then
				local s, d = project(path, m:GetPivot().Position)
				if d <= T.stopReach then
					table.insert(list, { s = s, name = (m:GetAttribute("Nome") :: string?) or m.Name })
				end
			end
		end
		table.sort(list, function(a, b)
			return a.s < b.s
		end)
		return list
	end

	local busFolder = root:FindFirstChild("Autocarros")
	for _, model in (if busFolder then busFolder:GetChildren() else {}) do
		if not model:IsA("Model") or not model.PrimaryPart then
			continue
		end
		local line = tostring(model:GetAttribute("Line") or "")
		local path = paths[line]
		if not path then
			continue
		end
		local s = project(path, model:GetPivot().Position)
		local stops = stopsFor(line, path)
		-- A proxima paragem e a primeira a frente de onde ele esta.
		local nextStop = 1
		for i, stop in stops do
			if stop.s > s + 1 then
				nextStop = i
				break
			end
		end
		local chassis, align, turn, motors, doors = makePhysical(model)
		local bus: Bus = {
			model = model,
			chassis = chassis,
			line = line,
			path = path,
			stops = stops,
			nextStop = nextStop,
			s = s,
			v = 0,
			dwellUntil = 0,
			holding = line == "E",
			align = align,
			turn = turn,
			motors = motors,
			doors = doors,
			doorsOpen = false,
		}
		table.insert(buses, bus)
		if line == "E" then
			teamBus = bus
			-- Parado na academia: a primeira paragem que conta e a do estadio.
			for i, stop in stops do
				if stop.name:find("Estadio") then
					bus.nextStop = i
				end
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, bus in buses do
			if bus.chassis.Parent then
				step(bus, dt, now)
			end
		end
	end)
end

return Transit
