--!strict
--[[
	O que os bonecos decidem.

	Simples de proposito, mas com intencao: de cada equipa, o mais perto vai a
	bola e os outros seguram a forma; se o adversario tem a bola, vao dois
	aperta-lo, que e o que faz haver disputa. Com a bola, avancam para a baliza,
	passam se forem apertados e rematam quando chegam perto.

	Jogam pelas mesmas regras das pessoas — roubam, caem, passam e rematam pelo
	Football, como toda a gente. Se uma pessoa da equipa esta mais perto da
	bola, nenhum boneco lha vai tirar: e dela.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Squad = require(script.Parent:WaitForChild("Squad"))
local Football = require(script.Parent:WaitForChild("Football"))

type Footballer = Squad.Footballer

local Bots = {}

local F = Config.Football
local S = Config.Stadium
local HALF = S.pitchLength / 2
local WIDTH2 = S.pitchWidth / 2

local nextThink: { [Footballer]: number } = {}
local accumulator = 0
local lastCarrier: Footballer? = nil

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function moveTo(f: Footballer, at: Vector3, sprint: boolean)
	local humanoid = f.humanoid
	local root = f.root
	if not humanoid or not root then
		return
	end
	f.wantSprint = sprint
	f.dribbling = false
	local target = Vector3.new(
		math.clamp(at.X, -HALF - 2, HALF + 2),
		root.Position.Y,
		math.clamp(at.Z, -WIDTH2 - 2, WIDTH2 + 2)
	)
	if flatDistance(target, root.Position) < 1.2 then
		humanoid:Move(Vector3.zero)
		return
	end
	humanoid:MoveTo(target)
end

--[[
	O lugar de cada um sem bola: a posicao da formacao, puxada para o lado da
	bola e empurrada para a frente quando a equipa ataca.
]]
local function shapeSpot(f: Footballer, ballAt: Vector3, attacking: boolean): Vector3
	local home = Squad.homeSpot(f)
	local sign = Squad.attackSign(f.teamId)
	local x = home.X + ballAt.X * 0.45 + (if attacking then sign * HALF * 0.18 else 0)
	local z = home.Z * 0.85 + ballAt.Z * 0.25
	return Vector3.new(math.clamp(x, -HALF + 6, HALF - 6), 0, math.clamp(z, -WIDTH2 + 6, WIDTH2 - 6))
end

local function opponentsNear(f: Footballer, radius: number, ahead: Vector3?): number
	local root = f.root :: BasePart
	local count = 0
	for _, other in Squad.active() do
		if other.teamId ~= f.teamId then
			local delta = (other.root :: BasePart).Position - root.Position
			local flatDelta = Vector3.new(delta.X, 0, delta.Z)
			if flatDelta.Magnitude <= radius and (not ahead or flatDelta.Unit:Dot(ahead) > 0.2) then
				count += 1
			end
		end
	end
	return count
end

-- O colega mais bem colocado: livre, e de preferencia mais a frente.
local function bestMate(f: Footballer): Footballer?
	local root = f.root :: BasePart
	local sign = Squad.attackSign(f.teamId)
	local best: Footballer? = nil
	local bestScore = -math.huge
	for _, mate in Squad.team(f.teamId) do
		local other = mate.root
		if mate ~= f and other then
			local distance = flatDistance(other.Position, root.Position)
			if distance > 8 and distance < F.passRange then
				local free = opponentsNear(mate, 7, nil) == 0
				local forward = (other.Position.X - root.Position.X) * sign
				local score = forward + (if free then 30 else 0) - distance * 0.2
				if score > bestScore then
					bestScore = score
					best = mate
				end
			end
		end
	end
	return best
end

-- Com a bola: rematar, passar ou avancar.
local function withBall(f: Footballer, now: number)
	local root = f.root :: BasePart
	local goal = Football.goalFor(f.teamId)
	local toGoal = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
	local ahead = toGoal.Unit

	if now >= (nextThink[f] or 0) then
		nextThink[f] = now + F.botThink

		if toGoal.Magnitude <= F.botShootRange then
			local aim = goal + Vector3.new(0, 0, (math.random() * 2 - 1) * (F.goalHalfWidth - 1.5))
			local power = 0.55 + math.random() * 0.35
			Football.shoot(f, power, aim - root.Position)
			return
		end

		local pressed = opponentsNear(f, F.botPressure, ahead) > 0
		if (pressed and math.random() < 0.8) or math.random() < 0.05 then
			local mate = bestMate(f)
			if mate then
				Football.passTo(f, mate)
				return
			end
		end
	end

	-- Avanca para a baliza, a fugir um pouco de quem esta a frente.
	local dodge = Vector3.zero
	for _, other in Squad.active() do
		if other.teamId ~= f.teamId then
			local delta = root.Position - (other.root :: BasePart).Position
			local d = Vector3.new(delta.X, 0, delta.Z)
			if d.Magnitude < 10 and d.Magnitude > 0.1 then
				dodge += d.Unit * (10 - d.Magnitude) / 10
			end
		end
	end
	local heading = (ahead + Vector3.new(0, 0, dodge.Z) * 0.8).Unit
	moveTo(f, root.Position + heading * 12, f.stamina > 45)
	f.dribbling = true
end

--------------------------------------------------------------------------------
-- Reposicoes
--------------------------------------------------------------------------------

local R = Config.Rules
local BOX_DEPTH = S.pitchLength * 16.5 / 105
local BOX_WIDTH = S.pitchWidth * 40.3 / 68

local GAP: { [string]: number } = {
	lancamento = R.throwInGap,
	canto = R.cornerGap,
	livre = R.freeKickGap,
}

--[[
	Um boneco da equipa que nao repoe fica fora da zona proibida. So os bonecos:
	as pessoas ficam onde quiserem.
]]
local function keepOut(f: Footballer, target: Vector3, piece: Football.SetPiece): Vector3
	local spot = piece.spot
	if piece.kind == "penalti" then
		-- Toda a gente, das duas equipas, fora da area e atras da bola.
		local side = math.sign(spot.X)
		if target.X * side > HALF - BOX_DEPTH - 2 then
			return Vector3.new(side * (HALF - BOX_DEPTH - 4), 0, math.clamp(target.Z, -BOX_WIDTH / 2, BOX_WIDTH / 2))
		end
		return target
	end
	if f.teamId == piece.team then
		return target
	end
	local gap = GAP[piece.kind]
	if gap then
		local away = Vector3.new(target.X - spot.X, 0, target.Z - spot.Z)
		if away.Magnitude < gap + 1 then
			local dir = if away.Magnitude > 0.5 then away.Unit else -Football.goalFor(f.teamId).Unit
			return spot + dir * (gap + 2)
		end
	elseif piece.kind == "baliza" then
		-- Fora da grande area de quem bate.
		local side = math.sign(spot.X)
		if target.X * side > HALF - BOX_DEPTH - 2 and math.abs(target.Z) < BOX_WIDTH / 2 + 2 then
			return Vector3.new(side * (HALF - BOX_DEPTH - 4), 0, target.Z)
		end
	end
	return target
end

-- Quem bate: um passe, um cruzamento, um pontape longo — conforme o que e.
local function takePiece(f: Footballer, piece: Football.SetPiece, now: number)
	if now < piece.takenAt + R.botTakerDelay then
		return
	end
	local root = f.root :: BasePart
	local here = root.Position
	local kind = piece.kind

	if kind == "canto" then
		local side = math.sign(piece.spot.X)
		local target = Vector3.new(side * (HALF - 20), 0, (math.random() * 2 - 1) * 10)
		Football.kick(f, 0.45, 0, 0.8, target - here)
	elseif kind == "baliza" then
		local target = Vector3.new(0, 0, (math.random() * 2 - 1) * 35)
		Football.kick(f, 0.85, 0, 0.35, target - here)
	elseif kind == "penalti" then
		local goal = Football.goalFor(f.teamId)
		local target = goal + Vector3.new(0, 0, (if math.random() < 0.5 then -1 else 1) * (F.goalHalfWidth - 2))
		Football.kick(f, 0.6 + math.random() * 0.3, 0, -0.3, target - here)
	else
		local goal = Football.goalFor(f.teamId)
		if kind == "livre" and (goal - here).Magnitude <= F.botShootRange then
			local target = goal + Vector3.new(0, 0, (math.random() * 2 - 1) * (F.goalHalfWidth - 1.5))
			Football.kick(f, 0.7, (math.random() * 2 - 1) * 0.6, 0.1, target - here)
			return
		end
		local mate = bestMate(f)
		if mate then
			Football.passTo(f, mate)
		else
			Football.kick(f, 0.35, 0, -1, piece.aim)
		end
	end
end

function Bots.step(dt: number)
	accumulator += dt
	if accumulator < 0.1 then
		return
	end
	accumulator = 0

	local now = os.clock()
	local ballAt = Football.ballPosition()
	local carrier = Football.carrier()
	local play = Football.botsPlay() and not Squad.isFrozen()

	-- Quem acabou de receber olha antes de decidir, como toda a gente.
	if carrier and carrier ~= lastCarrier then
		nextThink[carrier] = now + F.botThink * 1.5
	end
	lastCarrier = carrier

	for _, teamId in Config.TeamOrder do
		local team = Squad.team(teamId)
		local bots = {}
		for _, f in team do
			if not f.player and f.root and f.humanoid then
				table.insert(bots, f)
			end
		end

		-- Quem vai a bola, e quem faz cobertura.
		local chasers: { [Footballer]: boolean } = {}
		local cover: Footballer? = nil
		if play then
			local target = ballAt
			local opponentHas = carrier ~= nil and carrier.teamId ~= teamId
			if carrier and opponentHas then
				target = (carrier.root :: BasePart).Position
			end

			local byDistance = {}
			for _, f in team do
				if f.root and not Squad.isDown(f, now) then
					table.insert(byDistance, f)
				end
			end
			table.sort(byDistance, function(a, b)
				return flatDistance((a.root :: BasePart).Position, target) < flatDistance((b.root :: BasePart).Position, target)
			end)

			if opponentHas then
				--[[
					Um aperta, o segundo fica entre a bola e a baliza. Dois a
					apertar tiravam a bola a toda a gente num segundo, e sem ter a
					bola uns instantes ninguem joga.
				]]
				for _, f in byDistance do
					if not f.player then
						if not next(chasers) then
							chasers[f] = true
						else
							cover = f
							break
						end
					end
				end
			elseif not carrier then
				-- Bola solta: vai o mais perto, a nao ser que seja uma pessoa.
				local first = byDistance[1]
				if first and not first.player then
					chasers[first] = true
				end
			end
		end

		local piece = Football.setPiece()
		if piece and play then
			-- Reposicao: quem bate bate, os outros tomam posicao, e os
			-- adversarios ficam fora da zona.
			for _, f in bots do
				if carrier == f then
					takePiece(f, piece, now)
				elseif not Squad.isDown(f, now) then
					local spot = keepOut(f, shapeSpot(f, piece.spot, teamId == piece.team), piece)
					moveTo(f, spot, true)
				end
			end
			continue
		end

		for _, f in bots do
			if not play or Squad.isDown(f, now) then
				if not play then
					moveTo(f, Squad.homeSpot(f), false)
				end
			elseif carrier == f then
				withBall(f, now)
			elseif chasers[f] then
				local aim = ballAt
				if carrier and carrier.teamId ~= teamId then
					local root = carrier.root :: BasePart
					aim = root.Position + Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z) * 0.25
				else
					aim = ballAt + Vector3.new(Football.ballVelocity().X, 0, Football.ballVelocity().Z) * 0.2
				end
				moveTo(f, aim, true)
			elseif f == cover and carrier then
				local at = (carrier.root :: BasePart).Position
				local ownGoal = -Football.goalFor(teamId)
				local toGoal = Vector3.new(ownGoal.X - at.X, 0, ownGoal.Z - at.Z)
				moveTo(f, at + toGoal.Unit * math.min(10, toGoal.Magnitude), true)
			else
				local attacking = carrier ~= nil and carrier.teamId == teamId
				moveTo(f, shapeSpot(f, ballAt, attacking), false)
			end
		end
	end
end

return Bots
