--!strict
--[[
	Os jogadores e a bola.

	Sao NPCs de proposito: o futebol aqui so precisa de ser suficiente para a
	bancada ter algo a que reagir. Mas suficiente quer dizer com intencao — quem
	tem a bola sabe para que baliza vai, leva-a para la, e remata quando chega
	perto. Passar a bola ao calhas lia-se logo como ruido.

	Nada disto usa fisica nem Humanoid: e tudo movido a mao, frame a frame. Fica
	previsivel, barato, e nunca ha bonecos a cair do ceu.

	Os golos nascem daqui, nao de um sorteio — e a pontaria do remate depende do
	ambiente da bancada. E o que liga cantar a marcar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Atmosphere = require(script.Parent:WaitForChild("Atmosphere"))

local Pitch = {}

local P = Config.Pitch
local S = Config.Stadium
local HALF = S.pitchLength / 2

type Footballer = {
	root: BasePart,
	home: Vector3,
	teamId: string,
}

local squad: { Footballer } = {}
local ball: BasePart? = nil

-- Para que lado ataca cada equipa. "home" vai a baliza do lado +X.
local function attackingX(teamId: string): number
	return teamId == "home" and HALF or -HALF
end

local state = {
	mode = "loose" :: "loose" | "carry" | "kick",
	carrier = nil :: Footballer?,
	target = Vector3.new(0, 1.2, 0),
	lastTeam = nil :: string?,
	resetAt = 0,
}

local onGoal: ((string) -> ())? = nil

function Pitch.onGoal(fn: (string) -> ())
	onGoal = fn
end

--------------------------------------------------------------------------------
-- Construcao
--------------------------------------------------------------------------------

local function makePart(name: string, size: Vector3, colour: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildFootballer(teamId: string, home: Vector3, parent: Instance): Footballer
	local team = Config.Teams[teamId]

	local model = Instance.new("Model")
	model.Name = "Player_" .. teamId
	model.Parent = parent

	local torso = makePart("Torso", Vector3.new(2, 2.4, 1), team.color, model)
	torso.CFrame = CFrame.new(home)
	model.PrimaryPart = torso

	local function attach(name: string, size: Vector3, colour: Color3, offset: CFrame)
		local piece = makePart(name, size, colour, model)
		piece.CFrame = torso.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = piece
		weld.Parent = torso
	end

	attach("Head", Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(215, 178, 140), CFrame.new(0, 1.8, 0))
	attach("Legs", Vector3.new(1.8, 2, 0.9), Color3.fromRGB(26, 28, 34), CFrame.new(0, -2.2, 0))

	return { root = torso, home = home, teamId = teamId }
end

local function formationFor(teamId: string): { Vector3 }
	local sign = teamId == "home" and 1 or -1
	local spots = { Vector3.new(HALF * 0.93 * sign, 1.2, 0) }

	for _, line in { { x = 0.62, n = 2 }, { x = 0.32, n = 2 }, { x = 0.1, n = 1 } } do
		for i = 1, line.n do
			local spread = (i - (line.n + 1) / 2) * (S.pitchWidth / (line.n + 1))
			table.insert(spots, Vector3.new(HALF * line.x * sign, 1.2, spread))
		end
	end

	return spots
end

function Pitch.build(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Match"
	folder.Parent = parent

	table.clear(squad)
	for _, teamId in Config.TeamOrder do
		for _, spot in formationFor(teamId) do
			table.insert(squad, buildFootballer(teamId, spot, folder))
		end
	end

	local b = makePart("Ball", Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(246, 246, 246), folder)
	b.Shape = Enum.PartType.Ball
	b.CFrame = CFrame.new(0, 1.2, 0)
	ball = b
end

--------------------------------------------------------------------------------
-- Decisoes
--------------------------------------------------------------------------------

-- Os dois mais proximos de uma equipa, que e quem vai a bola.
local function twoNearest(position: Vector3, teamId: string): { Footballer }
	local mine = {}
	for _, f in squad do
		if f.teamId == teamId then
			table.insert(mine, f)
		end
	end
	table.sort(mine, function(a, b)
		return (a.root.Position - position).Magnitude < (b.root.Position - position).Magnitude
	end)
	return { mine[1], mine[2] }
end

local function nearest(position: Vector3, teamId: string?): Footballer?
	local best: Footballer? = nil
	local bestDist = math.huge
	for _, f in squad do
		if teamId == nil or f.teamId == teamId then
			local d = (f.root.Position - position).Magnitude
			if d < bestDist then
				bestDist = d
				best = f
			end
		end
	end
	return best
end

--[[
	Rematar a baliza contraria. O desvio vem do ambiente da propria bancada:
	calada, o remate sai torto; ao rubro, vai onde deve.
]]
local function shoot(from: Footballer)
	local goalX = attackingX(from.teamId)
	local heat = Atmosphere.fraction(from.teamId)
	local spread = P.shotSpreadCold + (P.shotSpreadHot - P.shotSpreadCold) * heat

	state.mode = "kick"
	state.carrier = nil
	state.lastTeam = from.teamId
	state.target = Vector3.new(
		goalX + (goalX > 0 and 3 or -3),
		math.random() * 5 + 1.5,
		math.clamp(math.random() * spread * 2 - spread, -22, 22)
	)
end

local function passForward(from: Footballer)
	local sign = from.teamId == "home" and 1 or -1
	local edge = S.pitchWidth / 2 - 6

	state.mode = "kick"
	state.carrier = nil
	state.lastTeam = from.teamId
	state.target = Vector3.new(
		math.clamp(from.root.Position.X + sign * math.random(24, 44), -HALF + 5, HALF - 5),
		1.2,
		math.clamp(math.random(-edge, edge), -edge, edge)
	)
end

local function crossedGoalLine(position: Vector3): string?
	if math.abs(position.Z) > P.goalHalfWidth or position.Y > P.goalHeight then
		return nil
	end
	if position.X >= HALF - 1 then
		return "home" -- marcou quem ataca este lado
	elseif position.X <= -HALF + 1 then
		return "away"
	end
	return nil
end

--------------------------------------------------------------------------------
-- Movimento
--------------------------------------------------------------------------------

local function moveTowards(f: Footballer, goal: Vector3, speed: number, dt: number)
	local here = f.root.Position
	local delta = Vector3.new(goal.X - here.X, 0, goal.Z - here.Z)
	if delta.Magnitude < 0.3 then
		return
	end
	local step = delta.Unit * math.min(speed * dt, delta.Magnitude)
	local landed = here + step
	f.root.CFrame = CFrame.lookAt(landed, landed + delta.Unit)
end

function Pitch.kickOff()
	local b = ball
	if b then
		b.CFrame = CFrame.new(0, 1.2, 0)
	end
	state.mode = "loose"
	state.carrier = nil
	state.target = Vector3.new(0, 1.2, 0)
	state.resetAt = 0
end

function Pitch.step(dt: number, playing: boolean)
	local b = ball
	if not b then
		return
	end

	if not playing then
		for _, f in squad do
			moveTowards(f, f.home, P.speed, dt)
		end
		return
	end

	-- Pausa curta depois do golo, para se ver a bola na rede.
	if state.resetAt > 0 then
		if os.clock() >= state.resetAt then
			Pitch.kickOff()
		end
		for _, f in squad do
			moveTowards(f, f.home, P.speed, dt)
		end
		return
	end

	if state.mode == "carry" then
		local carrier = state.carrier
		if carrier then
			--[[
				Roubar. Sem isto quem apanhava a bola levava-a sempre ate ao fim,
				e o jogo lia-se como um desfile em vez de uma disputa. O defesa
				mais proximo que encoste, fica com ela.
			]]
			for _, f in squad do
				if f.teamId ~= carrier.teamId then
					local gap = (f.root.Position - carrier.root.Position).Magnitude
					if gap <= P.tackleRange then
						state.carrier = f
						state.lastTeam = f.teamId
						carrier = f
						break
					end
				end
			end

			local goalX = attackingX(carrier.teamId)
			local aim = Vector3.new(goalX, 1.2, 0)
			moveTowards(carrier, aim, P.speed, dt)

			-- A bola vai a frente dos pes de quem a leva.
			local forward = carrier.root.CFrame.LookVector
			b.CFrame = CFrame.new(carrier.root.Position + forward * 2 + Vector3.new(0, -0.5, 0))

			local distance = math.abs(goalX - carrier.root.Position.X)
			if distance <= P.shootRange then
				shoot(carrier)
			elseif math.random() < dt * 0.35 then
				passForward(carrier)
			end
		else
			state.mode = "loose"
		end
	else
		-- A bola viaja para onde foi mandada.
		local toTarget = state.target - b.Position
		local speed = state.mode == "kick" and P.ballSpeed or P.passSpeed
		if toTarget.Magnitude > 0.6 then
			b.CFrame = b.CFrame + toTarget.Unit * math.min(speed * dt, toTarget.Magnitude)
		else
			state.mode = "loose"
		end

		local scorer = crossedGoalLine(b.Position)
		if scorer and state.lastTeam == scorer then
			state.resetAt = os.clock() + 2.5
			state.lastTeam = nil
			if onGoal then
				onGoal(scorer)
			end
			return
		end

		-- Quem chegar primeiro fica com ela.
		local claimer = nearest(b.Position, nil)
		if claimer and (claimer.root.Position - b.Position).Magnitude <= P.controlRange then
			state.mode = "carry"
			state.carrier = claimer
			state.lastTeam = claimer.teamId
		end
	end

	--[[
		Dois de cada equipa vao a bola, os outros seguram a forma.

		Dois, nao um: com um so, quem levava a bola nunca era incomodado. O
		segundo e o que transforma isto numa disputa — e e ele que vai roubar.
	]]
	local carrier = state.carrier
	for _, teamId in Config.TeamOrder do
		local chasers = twoNearest(b.Position, teamId)
		for _, f in squad do
			if f.teamId == teamId and f ~= carrier then
				if table.find(chasers, f) then
					local aim = (carrier and carrier.teamId ~= teamId) and carrier.root.Position or b.Position
					moveTowards(f, aim, P.chaseSpeed, dt)
				else
					moveTowards(f, f.home, P.speed, dt)
				end
			end
		end
	end
end

return Pitch
