--!strict
--[[
	A academia a funcionar (o campo esta no mapa: Workspace.Academia).

	Antes do jogo (sede e corteo) quem joga aparece aqui, a treinar, em vez de
	no estadio. Ha uma bola de treino a serio (fisica: empurra-se a andar e
	chuta-se com os botoes do jogo), golos com "GOLO" no ecra de quem esta
	perto, e um guarda-redes de treino na baliza nascente para se rematar.

	Os bonecos do plantel nao jogam aqui: ficam fora das linhas a ver, um por
	cada lugar da equipa que ainda nao tem pessoa. Quando entram pessoas, os
	bonecos desses lugares saem.

	No corteo o autocarro da equipa leva toda a gente ao estadio (Transit);
	quando chega, a academia fecha ate ao proximo jogo.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Academy = {}

local A = Config.Academy
local BALL_SIZE = 2.2
local GROUP = "BolaTreino"

local open = true
local root: Instance? = nil
local ball: BasePart? = nil
local lastKicker: Player? = nil
local scoredAt = 0
local keeper: Model? = nil
local keeperHolding = 0 -- ate quando o guarda-redes tem a bola nas maos
local spots: { Vector3 } = {}
local watchers: { Model } = {}

-- Esta aberta (antes do jogo, ate o autocarro chegar ao estadio)?
function Academy.isOpen(): boolean
	return open and root ~= nil
end

function Academy.setOpen(on: boolean)
	open = on
end

--[[
	Onde aparece quem joga: perto da entrada do relvado, cada equipa na sua
	metade, e cada um no seu sitio (pelo numero do lugar), para nao nascerem
	uns em cima dos outros.
]]
function Academy.spotFor(teamId: string, slot: number): Vector3
	local c = A.centre
	local side = Config.Teams[teamId].side
	local column = (slot - 1) % 3
	local line = (slot - 1) // 3
	return Vector3.new(c.X + side * (12 + column * 7), A.groundY + 3.2, c.Z - A.pitchWidth / 2 + 8 + line * 6)
end

--------------------------------------------------------------------------------
-- A bola de treino
--------------------------------------------------------------------------------

--[[
	Joga-se como no jogo a serio (as mesmas regras do Football): quem chega a
	bola fica com ela colada a frente dos pes; outro que encoste rouba-a;
	chuta-se com a barra de forca, altura e efeito; de primeira tambem. Solta,
	rola e trava na relva. So as pessoas que jogam lhe tocam.
]]
local F = Config.Football
local R = BALL_SIZE / 2

local carrier: Player? = nil
local carriedSince = 0
local flightUntil = 0
local noClaim: { [Player]: number } = {}
local curve = 0
local curveUntil = 0

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.xAxis
end

local function groundY(): number
	return A.groundY + 0.4 + R
end

local function resetBall()
	local b = ball
	if not b then
		return
	end
	carrier = nil
	b.AssemblyLinearVelocity = Vector3.zero
	b.AssemblyAngularVelocity = Vector3.zero
	b.CFrame = CFrame.new(A.centre.X, groundY() + 0.5, A.centre.Z)
end

local function makeBall(parent: Instance)
	local b = Instance.new("Part")
	b.Name = "BolaTreino"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(BALL_SIZE, BALL_SIZE, BALL_SIZE)
	b.Color = Color3.fromRGB(248, 248, 248)
	b.Material = Enum.Material.SmoothPlastic
	b.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.4, 0.45, 1, 1)
	b.CollisionGroup = GROUP
	b.Parent = parent
	ball = b
	resetBall()
	pcall(function()
		b:SetNetworkOwner(nil)
	end)
end

-- Quem pode jogar a bola de treino: as pessoas que jogam e estao vivas.
local function players(): { { player: Player, root: BasePart } }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Team") == "jogador" then
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

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

--[[
	Um chuto, como no jogo: `power` 0 a 1 (a barra), `curveIn` -1 a 1 (o
	efeito), `height` -1 a 1 (rasteira, normal, chapeu). Com a bola nos pes, ou
	de primeira numa bola solta que passa ao alcance. Devolve se o chuto era
	da academia (senao e o Football que o trata).
]]
function Academy.kick(player: Player, power: number, curveIn: number, height: number): boolean
	local b = ball
	local root = rootOf(player)
	if not Academy.isOpen() or not b or not root then
		return false
	end
	local now = os.clock()
	local mine = carrier == player
	if not mine then
		local reach = horizontal(b.Position, root.Position)
		local tooHigh = b.Position.Y - (root.Position.Y - 3) > F.claimHeight + 1
		if carrier ~= nil or reach > F.claimRange + 2.4 or tooHigh or (noClaim[player] or 0) > now then
			-- Longe da bola: se esta na academia, o chuto fica por aqui.
			return horizontal(root.Position, A.centre) < A.pitchLength
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
	carrier = nil
	flightUntil = now + F.kickFlight
	noClaim[player] = now + F.kickLockout
	b.AssemblyAngularVelocity = Vector3.zero
	b.AssemblyLinearVelocity = dir * speed + Vector3.new(0, speed * liftFraction, 0)
	curve = math.clamp(curveIn, -1, 1) * F.curveAccel
	curveUntil = now + F.curveTime
	lastKicker = player
	return true
end

-- A bola a cada instante: nos pes de quem a tem, ou solta a rolar.
local function stepBall(dt: number, now: number)
	local b = ball
	if not b or now < keeperHolding then
		return
	end
	local list = players()

	local owner = carrier
	if owner then
		local root = rootOf(owner)
		if not root or horizontal(root.Position, A.centre) > A.pitchLength then
			carrier = nil
		else
			-- Roubo: quem encosta a bola fica com ela (menos logo a seguir a ganha-la).
			if now - carriedSince > F.tackleImmunity then
				for _, other in list do
					if other.player ~= owner and horizontal(other.root.Position, b.Position) < F.tackleRange and (noClaim[other.player] or 0) <= now then
						carrier = other.player
						carriedSince = now
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
	if curve ~= 0 and now < curveUntil and hv.Magnitude > 4 then
		hv += hv.Unit:Cross(Vector3.yAxis) * curve * dt
	end
	b.AssemblyLinearVelocity = hv + Vector3.new(0, v.Y, 0)

	-- Quem chega a ela fica com ela.
	if now >= flightUntil then
		local best: Player? = nil
		local bestD = F.claimRange
		for _, other in list do
			local d = horizontal(other.root.Position, b.Position)
			if d < bestD and b.Position.Y - (other.root.Position.Y - 3) < F.claimHeight and (noClaim[other.player] or 0) <= now then
				best, bestD = other.player, d
			end
		end
		if best then
			carrier = best
			carriedSince = now
			lastKicker = best
		end
	end
end

-- A bola entrou numa das balizas?
local function checkGoal(now: number)
	local b = ball
	if not b or now - scoredAt < 3 then
		return
	end
	local c = A.centre
	local p = b.Position
	local depth = math.abs(p.X - c.X) - A.pitchLength / 2
	if depth > BALL_SIZE / 2 + 0.8 and depth < A.goalDepth + 1 and math.abs(p.Z - c.Z) < A.goalHalfWidth and p.Y < A.groundY + A.goalHeight then
		scoredAt = now
		local who = lastKicker
		Remotes.Academia:FireAllClients({ kind = "golo", name = if who then who.DisplayName else nil })
		task.delay(2.5, resetBall)
	end
	-- Fora do campo ha muito tempo (passou a vedacao): volta ao meio.
	if math.abs(p.X - c.X) > A.pitchLength / 2 + 30 or math.abs(p.Z - c.Z) > A.pitchWidth / 2 + 30 or p.Y < A.groundY - 20 then
		resetBall()
	end
end

--------------------------------------------------------------------------------
-- O guarda-redes de treino
--------------------------------------------------------------------------------

local function stepKeeper(dt: number, now: number)
	local k = keeper
	local b = ball
	if not k or not b or not k.PrimaryPart then
		return
	end
	local c = A.centre
	local goalX = c.X + A.pitchLength / 2 - 1.8
	local here = k:GetPivot().Position
	local bp = b.Position

	-- Com a bola nas maos: fica com ela um pouco e depois repoe para o meio.
	if now < keeperHolding then
		b.AssemblyLinearVelocity = Vector3.zero
		b.CFrame = CFrame.new(here + Vector3.new(-1.6, 0, 0)) -- a frente do peito
		return
	elseif keeperHolding > 0 then
		keeperHolding = 0
		b.AssemblyLinearVelocity = Vector3.new(-48, 22, (math.random() - 0.5) * 20)
	end

	-- Acompanha a bola ao longo da linha, sem sair da baliza.
	local targetZ = c.Z
	if bp.X > c.X then
		targetZ = math.clamp(bp.Z, c.Z - A.goalHalfWidth + 1.2, c.Z + A.goalHalfWidth - 1.2)
	end
	local z = here.Z + math.clamp(targetZ - here.Z, -A.keeperSpeed * dt, A.keeperSpeed * dt)
	-- O pivo do boneco e o tronco, 3 studs acima do chao.
	local at = Vector3.new(goalX, A.groundY, z)
	k:PivotTo(CFrame.lookAt(at + Vector3.new(0, 3, 0), Vector3.new(c.X, A.groundY + 3, z)))

	-- Defende: se a bola vem ao alcance das maos, agarra-a (nem sempre).
	local toBall = bp - (at + Vector3.new(0, 3, 0))
	local incoming = b.AssemblyLinearVelocity.X > 4
	if incoming and Vector3.new(toBall.X, 0, toBall.Z).Magnitude < 3.2 and toBall.Y < 4.5 then
		local fast = b.AssemblyLinearVelocity.Magnitude > 55
		if not fast or math.random() < 0.5 then
			keeperHolding = now + 1.4
			carrier = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Os bonecos que ficam a ver
--------------------------------------------------------------------------------

local function watcher(teamId: string, number: number, at: Vector3, parent: Instance): Model
	local team = Config.Teams[teamId]
	local model = Instance.new("Model")
	model.Name = "AVer"
	local facing = CFrame.lookAt(at, Vector3.new(A.centre.X, at.Y, A.centre.Z))
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
	model.Parent = parent
	return model
end

--[[
	Um boneco a ver por cada lugar da equipa ainda sem pessoa. `bots` e a
	lista desses lugares (equipa e numero), que o Main tira do Squad.
]]
function Academy.setWatchers(bots: { { teamId: string, number: number } })
	local parent = root
	if not parent then
		return
	end
	local wanted = if Academy.isOpen() then math.min(#bots, #spots) else 0
	-- Refaz so se mudou.
	local same = #watchers == wanted
	if same then
		for i, m in watchers do
			local b = bots[i]
			if not b or m:GetAttribute("Key") ~= b.teamId .. b.number then
				same = false
			end
		end
	end
	if same then
		return
	end
	for _, m in watchers do
		m:Destroy()
	end
	table.clear(watchers)
	for i = 1, wanted do
		local b = bots[i]
		local m = watcher(b.teamId, b.number, spots[i], parent)
		m:SetAttribute("Key", b.teamId .. b.number)
		table.insert(watchers, m)
	end
end

--------------------------------------------------------------------------------

function Academy.start()
	local folder = workspace:FindFirstChild("Academia")
	if not folder then
		warn("[Ultras FC] Sem Workspace.Academia: quem joga aparece no estadio.")
		return
	end
	root = folder

	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
	end)
	-- A bola de treino bate nas paredes invisiveis da vedacao (BallWall).
	PhysicsService:CollisionGroupSetCollidable(GROUP, "BallWall", true)
	-- Como a bola do jogo: quem joga nao a empurra com o corpo, so as regras a mexem.
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(GROUP, "Footballers", false)
	end)

	-- Os marcadores do mapa ficam invisiveis no jogo.
	local arrival = folder:FindFirstChild("Chegada")
	if arrival and arrival:IsA("BasePart") then
		arrival.Transparency = 1
	end
	local places = folder:FindFirstChild("Lugares")
	for _, p in (if places then places:GetChildren() else {}) do
		if p:IsA("BasePart") then
			table.insert(spots, Vector3.new(p.Position.X, A.groundY, p.Position.Z))
			p.Transparency = 1
		end
	end
	keeper = folder:FindFirstChild("GuardaRedes") :: Model?

	makeBall(folder)
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		if not Academy.isOpen() then
			return
		end
		stepBall(dt, now)
		checkGoal(now)
		stepKeeper(dt, now)
	end)
end

return Academy
