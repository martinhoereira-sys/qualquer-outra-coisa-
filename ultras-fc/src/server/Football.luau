--!strict
--[[
	A bola e as regras.

	A bola e fisica normal do Roblox: chuta-se dando-lhe uma velocidade, e ela
	rola, salta e bate nos postes sozinha. So ha duas ajudas por cima disso — um
	travao leve, para rolar e parar sempre da mesma maneira, e, com a posse, a
	bola vai colada a frente dos pes. E o mais previsivel, e e o que se usa nos
	jogos de futebol do Roblox.

	Posse, roubo, golo, bola fora e pontape de saida vivem aqui. O servidor e
	que decide tudo: o cliente so diz "chutei com esta forca".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Squad = require(script.Parent:WaitForChild("Squad"))

type Footballer = Squad.Footballer

local Football = {}

local F = Config.Football
local S = Config.Stadium
local HALF = S.pitchLength / 2
local WIDTH2 = S.pitchWidth / 2
local R = F.ballSize / 2
local BOX_DEPTH = S.pitchLength * 16.5 / 105
local BOX_WIDTH = S.pitchWidth * 40.3 / 68

local ball: Part? = nil

local state = {
	carrier = nil :: Footballer?,
	lastTouch = nil :: string?, -- equipa do ultimo toque, para a bola fora
	noClaim = {} :: { [Footballer]: number },
	priorityTeam = nil :: string?,
	priorityUntil = 0,
	live = false, -- os golos contam
	botsPlay = false,
	waitUntil = 0, -- bola na rede, ou fora, a espera de recomecar
	afterWait = nil :: (() -> ())?,
	releaseAt = 0, -- fim da espera do pontape de saida
	kickingTeam = nil :: string?,
	flightUntil = 0, -- acabada de chutar, ainda ninguem lhe pode tocar
}

local onGoal: ((string) -> ())? = nil

function Football.onGoal(fn: (string) -> ())
	onGoal = fn
end

--------------------------------------------------------------------------------
-- Construcao
--------------------------------------------------------------------------------

local function wall(name: string, size: Vector3, at: Vector3, parent: Instance)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(at)
	p.Anchored = true
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	p.CollisionGroup = "BallWall"
	p.Parent = parent
end

function Football.build(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Match"
	folder.Parent = parent

	-- A bola nunca vai parar a bancada: paredes que so ela sente, uns metros
	-- fora das linhas, e um tecto.
	local endX = HALF + F.goalDepth + 1.5
	local sideZ = WIDTH2 + 4
	for _, sign in { 1, -1 } do
		wall("BallWallX", Vector3.new(2, 80, sideZ * 2 + 4), Vector3.new(sign * (endX + 1), 40, 0), folder)
		wall("BallWallZ", Vector3.new(endX * 2 + 4, 80, 2), Vector3.new(0, 40, sign * (sideZ + 1)), folder)
	end
	wall("BallCeiling", Vector3.new(endX * 2 + 4, 2, sideZ * 2 + 4), Vector3.new(0, 70, 0), folder)

	local b = Instance.new("Part")
	b.Name = "Ball"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(F.ballSize, F.ballSize, F.ballSize)
	b.Color = Color3.fromRGB(248, 248, 248)
	b.Material = Enum.Material.SmoothPlastic
	b.CustomPhysicalProperties = PhysicalProperties.new(0.35, 0.25, 0.5, 1, 1)
	b.CollisionGroup = "Ball"
	b.CFrame = CFrame.new(0, R + 0.05, 0)
	b.Parent = folder
	b:SetNetworkOwner(nil)
	ball = b
end

--------------------------------------------------------------------------------
-- Consultas (para os bonecos e para o ecra)
--------------------------------------------------------------------------------

function Football.ballPosition(): Vector3
	local b = ball
	return if b then b.Position else Vector3.zero
end

function Football.ballVelocity(): Vector3
	local b = ball
	return if b then b.AssemblyLinearVelocity else Vector3.zero
end

function Football.carrier(): Footballer?
	return state.carrier
end

function Football.botsPlay(): boolean
	return state.botsPlay
end

-- A baliza que esta equipa ataca.
function Football.goalFor(teamId: string): Vector3
	return Vector3.new(Squad.attackSign(teamId) * HALF, 0, 0)
end

--------------------------------------------------------------------------------
-- Chutar
--------------------------------------------------------------------------------

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.xAxis
end

local function release(f: Footballer, direction: Vector3, speed: number, lift: number)
	local b = ball
	local root = f.root
	if not b or not root then
		return
	end
	local dir = flat(direction)
	state.carrier = nil
	state.lastTouch = f.teamId
	state.noClaim[f] = os.clock() + F.kickLockout
	-- Ninguem lhe toca no primeiro instante: sem isto, quem estava colado a
	-- quem chutou ficava com a bola antes de ela sair dos pes.
	state.flightUntil = os.clock() + F.kickFlight

	local from = root.Position
	b.CFrame = CFrame.new(from.X + dir.X * F.dribbleDistance, R + 0.1, from.Z + dir.Z * F.dribbleDistance)
	b.AssemblyAngularVelocity = Vector3.zero
	b.AssemblyLinearVelocity = dir * speed + Vector3.new(0, lift, 0)
end

--[[
	Rematar. `power` e 0 a 1, a barra de forca. Mais forca, mais velocidade e
	mais altura — um remate cheio de perto vai por cima, e e para ir.
]]
function Football.shoot(f: Footballer, power: number, direction: Vector3?): boolean
	if state.carrier ~= f or not f.root then
		return false
	end
	local p = math.clamp(power, 0, 1)
	local speed = F.shotSpeedMin + (F.shotSpeedMax - F.shotSpeedMin) * p
	local lift = speed * (F.shotLiftMin + (F.shotLiftMax - F.shotLiftMin) * p)
	release(f, direction or (f.root :: BasePart).CFrame.LookVector, speed, lift)
	return true
end

local function passSpeed(distance: number): number
	return math.clamp(18 + distance * 0.75, F.passSpeedMin, F.passSpeedMax)
end

function Football.passTo(f: Footballer, target: Footballer): boolean
	local root = f.root
	local other = target.root
	if state.carrier ~= f or not root or not other then
		return false
	end
	-- Um pouco a frente de quem recebe, para nao lhe chegar aos calcanhares.
	local aim = other.Position + Vector3.new(other.AssemblyLinearVelocity.X, 0, other.AssemblyLinearVelocity.Z) * 0.35
	local delta = aim - root.Position
	release(f, delta, passSpeed(Vector3.new(delta.X, 0, delta.Z).Magnitude), 0)
	return true
end

--[[
	Passar: um toque rasteiro. Se houver um colega a frente, dentro do cone, a
	bola vai para ele; se nao, vai em frente com forca media.
]]
function Football.pass(f: Footballer, direction: Vector3?): boolean
	local root = f.root
	if state.carrier ~= f or not root then
		return false
	end
	local dir = flat(direction or root.CFrame.LookVector)
	local cosCone = math.cos(math.rad(F.passCone))

	local best: Footballer? = nil
	local bestScore = -math.huge
	for _, mate in Squad.team(f.teamId) do
		local other = mate.root
		if mate ~= f and other then
			local delta = Vector3.new(other.Position.X - root.Position.X, 0, other.Position.Z - root.Position.Z)
			local distance = delta.Magnitude
			if distance > 4 and distance <= F.passRange then
				local alignment = delta.Unit:Dot(dir)
				if alignment >= cosCone then
					-- Mais alinhado vale mais do que mais perto.
					local score = alignment * 2 - distance / F.passRange
					if score > bestScore then
						bestScore = score
						best = mate
					end
				end
			end
		end
	end

	if best then
		return Football.passTo(f, best)
	end
	release(f, dir, passSpeed(30), 0)
	return true
end

--------------------------------------------------------------------------------
-- Recomecos
--------------------------------------------------------------------------------

local function placeBall(at: Vector3)
	local b = ball
	if not b then
		return
	end
	b.CFrame = CFrame.new(at.X, R + 0.1, at.Z)
	b.AssemblyLinearVelocity = Vector3.zero
	b.AssemblyAngularVelocity = Vector3.zero
end

local function giveTo(teamId: string?, seconds: number)
	state.priorityTeam = teamId
	state.priorityUntil = os.clock() + seconds
end

local function otherTeam(teamId: string): string
	for _, id in Config.TeamOrder do
		if id ~= teamId then
			return id
		end
	end
	return teamId
end

--[[
	Pontape de saida: toda a gente ao seu lugar, bola ao centro, dois segundos
	parados e apito. Sai quem esta a comecar a parte, ou quem sofreu o golo.
]]
function Football.kickOff(teamId: string)
	state.carrier = nil
	state.afterWait = nil
	state.waitUntil = 0
	table.clear(state.noClaim)
	placeBall(Vector3.zero)
	Squad.placeForKickoff(teamId)
	Squad.setFrozen(true)
	state.kickingTeam = teamId
	state.releaseAt = os.clock() + F.kickoffFreeze
	workspace:SetAttribute("KickoffAt", workspace:GetServerTimeNow() + F.kickoffFreeze)
	workspace:SetAttribute("KickoffTeam", teamId)
end

--[[
	A fase do jogo. So nas partes os golos contam; no aquecimento joga-se na
	mesma, que e o que se faz antes de um jogo; no intervalo e no fim os
	bonecos voltam ao lugar e a bola fica no centro.
]]
function Football.setPhase(phase: string)
	state.live = phase == "first" or phase == "second"
	local wasPlaying = state.botsPlay
	state.botsPlay = state.live or phase == "warmup"
	if not state.botsPlay and wasPlaying then
		state.carrier = nil
		placeBall(Vector3.zero)
	end
end

local function hold(seconds: number, after: () -> ())
	state.waitUntil = os.clock() + seconds
	state.afterWait = after
end

--[[
	Golo: a bola inteira passou a linha, entre os postes e por baixo da trave.
	Marca sempre quem ataca aquela baliza, seja quem for que lhe tocou por
	ultimo — um autogolo e golo na mesma.
]]
local function checkGoal(p: Vector3): boolean
	if math.abs(p.X) < HALF + R or math.abs(p.Z) > F.goalHalfWidth or p.Y > F.goalHeight then
		return false
	end
	local side = if p.X > 0 then 1 else -1
	local scorer = Config.TeamOrder[1]
	for _, teamId in Config.TeamOrder do
		if Squad.attackSign(teamId) == side then
			scorer = teamId
		end
	end

	state.carrier = nil
	local counted = state.live
	hold(F.goalPause, function()
		if counted then
			Football.kickOff(otherTeam(scorer))
		else
			placeBall(Vector3.zero)
		end
	end)
	if counted and onGoal then
		onGoal(scorer)
	end
	return true
end

--[[
	Bola fora: passado um segundo volta ao campo no ponto onde saiu, e a equipa
	que nao lhe tocou por ultimo tem prioridade para a jogar. Pela linha de
	fundo volta a entrada da area.
]]
local function checkOut(p: Vector3): boolean
	local spot: Vector3
	if math.abs(p.Z) > WIDTH2 + R then
		spot = Vector3.new(math.clamp(p.X, -HALF + 2, HALF - 2), 0, math.sign(p.Z) * (WIDTH2 - 1.5))
	elseif math.abs(p.X) > HALF + R then
		spot = Vector3.new(math.sign(p.X) * (HALF - BOX_DEPTH), 0, math.clamp(p.Z, -BOX_WIDTH / 2 + 4, BOX_WIDTH / 2 - 4))
	else
		return false
	end

	state.carrier = nil
	local restartTeam = if state.lastTouch then otherTeam(state.lastTouch) else nil
	hold(F.outDelay, function()
		placeBall(spot)
		giveTo(restartTeam, F.restartPriority)
	end)
	return true
end

--------------------------------------------------------------------------------
-- Posse e roubo
--------------------------------------------------------------------------------

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function canPlay(f: Footballer, now: number): boolean
	if Squad.isDown(f, now) then
		return false
	end
	if (state.noClaim[f] or 0) > now then
		return false
	end
	if state.priorityTeam and now < state.priorityUntil and f.teamId ~= state.priorityTeam then
		return false
	end
	-- Fora do aquecimento e das partes, os bonecos nao jogam.
	if not state.botsPlay and not f.player then
		return false
	end
	return true
end

local function claim(b: BasePart, now: number)
	if b.Position.Y - R > F.claimHeight then
		return
	end
	local best: Footballer? = nil
	local bestDistance = F.claimRange
	for _, f in Squad.active() do
		local root = f.root :: BasePart
		local d = horizontal(root.Position, b.Position)
		if d <= bestDistance and canPlay(f, now) then
			bestDistance = d
			best = f
		end
	end
	if best then
		-- Um instante para a dominar: sem isto, apanhar a bola ao lado de um
		-- adversario era perde-la no mesmo frame.
		best.immuneUntil = math.max(best.immuneUntil, now + F.claimImmunity)
		state.carrier = best
		state.lastTouch = best.teamId
	end
end

--[[
	Roubar: encostar a quem tem a bola chega. Quem a perdeu cai; quem a ganhou
	fica um segundo imune, senao a bola andava de pe em pe sem ninguem a jogar.
]]
local function tackle(carrier: Footballer, now: number): Footballer
	if now < carrier.immuneUntil then
		return carrier
	end
	local root = carrier.root :: BasePart
	for _, f in Squad.active() do
		if f.teamId ~= carrier.teamId and canPlay(f, now) then
			if horizontal((f.root :: BasePart).Position, root.Position) <= F.tackleRange then
				Squad.fall(carrier, now)
				state.noClaim[carrier] = now + F.fallTime
				f.immuneUntil = now + F.tackleImmunity
				state.carrier = f
				state.lastTouch = f.teamId
				return f
			end
		end
	end
	return carrier
end

--------------------------------------------------------------------------------

function Football.step(dt: number)
	local b = ball
	if not b then
		return
	end
	local now = os.clock()

	-- A espera do pontape de saida.
	if state.releaseAt > 0 then
		if now < state.releaseAt then
			return
		end
		state.releaseAt = 0
		Squad.setFrozen(false)
		giveTo(state.kickingTeam, F.restartPriority)
	end

	-- A bola caiu do mundo: volta ao centro.
	if b.Position.Y < -20 then
		placeBall(Vector3.zero)
	end

	if state.waitUntil > 0 then
		if now < state.waitUntil then
			return
		end
		state.waitUntil = 0
		local after = state.afterWait
		state.afterWait = nil
		if after then
			after()
		end
		return
	end

	local carrier = state.carrier
	if carrier then
		local root = carrier.root
		local humanoid = carrier.humanoid
		if not root or not humanoid or not humanoid.Parent or Squad.isDown(carrier, now) then
			state.carrier = nil
		else
			carrier = tackle(carrier, now)
			local r = carrier.root :: BasePart
			local look = flat(r.CFrame.LookVector)
			local at = r.Position + look * F.dribbleDistance
			local v = r.AssemblyLinearVelocity
			b.CFrame = CFrame.new(at.X, R + 0.05, at.Z)
			b.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
			b.AssemblyAngularVelocity = Vector3.new(v.Z, 0, -v.X) / R
		end
	else
		-- O travao: forte no chao, fraco no ar.
		local v = b.AssemblyLinearVelocity
		local onGround = b.Position.Y < R + 0.4
		local keep = math.exp(-(if onGround then F.rollDrag else F.airDrag) * dt)
		b.AssemblyLinearVelocity = Vector3.new(v.X * keep, v.Y, v.Z * keep)
	end

	local p = b.Position
	if checkGoal(p) or checkOut(p) then
		return
	end

	if not state.carrier and not Squad.isFrozen() and now >= state.flightUntil then
		claim(b, now)
	end

	-- Quem a tem, a vista de todos (ecra e testes).
	local holder = state.carrier
	local name = if holder and holder.model then holder.model.Name else nil
	if b:GetAttribute("Carrier") ~= name then
		b:SetAttribute("Carrier", name)
	end
end

return Football
