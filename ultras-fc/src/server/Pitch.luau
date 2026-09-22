--!strict
--[[
	Os jogadores e a bola.

	Sao NPCs de proposito. O futebol aqui so precisa de ser suficiente para a
	bancada ter algo a que reagir — gastar meses a fazer fisica de bola era
	gastar no sitio errado, quando o que faz este jogo e a bancada.

	Por isso nada disto usa fisica nem Humanoid: e tudo movido a mao, frame a
	frame. Fica previsivel, barato, e nunca ha bonecos a cair do ceu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Pitch = {}

local P = Config.Pitch
local S = Config.Stadium

type Footballer = {
	model: Model,
	root: BasePart,
	home: Vector3, -- onde fica quando nao anda atras da bola
	teamId: string,
}

local footballers: { Footballer } = {}
local ball: BasePart? = nil
local ballTarget = Vector3.new(0, 1.5, 0)
local holder: Footballer? = nil
local root: Folder? = nil

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

	local head = makePart("Head", Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(215, 178, 140), model)
	head.CFrame = torso.CFrame * CFrame.new(0, 1.8, 0)
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = torso
	headWeld.Part1 = head
	headWeld.Parent = torso

	local legs = makePart("Legs", Vector3.new(1.8, 2, 0.9), Color3.fromRGB(28, 30, 36), model)
	legs.CFrame = torso.CFrame * CFrame.new(0, -2.2, 0)
	local legWeld = Instance.new("WeldConstraint")
	legWeld.Part0 = torso
	legWeld.Part1 = legs
	legWeld.Parent = torso

	return { model = model, root = torso, home = home, teamId = teamId }
end

-- Uma formacao simples: guarda-redes, defesas, meio, avancados.
local function formationFor(teamId: string): { Vector3 }
	local sign = teamId == "home" and 1 or -1
	local half = S.pitchLength / 2
	local spots = {}

	table.insert(spots, Vector3.new(half * 0.92 * sign, 1.2, 0))

	local lines = { { x = 0.62, count = 2 }, { x = 0.3, count = 2 }, { x = 0.08, count = 1 } }
	for _, line in lines do
		for i = 1, line.count do
			local spread = (i - (line.count + 1) / 2) * (S.pitchWidth / (line.count + 1))
			table.insert(spots, Vector3.new(half * line.x * sign, 1.2, spread))
		end
	end

	while #spots < P.perSide do
		table.insert(spots, Vector3.new(half * 0.2 * sign, 1.2, 0))
	end

	return spots
end

local function nearestTo(position: Vector3): Footballer?
	local best: Footballer? = nil
	local bestDist = math.huge
	for _, f in footballers do
		local d = (f.root.Position - position).Magnitude
		if d < bestDist then
			bestDist = d
			best = f
		end
	end
	return best
end

-- Para onde a bola vai a seguir: um passe para a frente, com ruido.
local function pickTarget(from: Footballer?): Vector3
	local half = S.pitchLength / 2 - 6
	local edge = S.pitchWidth / 2 - 6

	if from then
		local sign = from.teamId == "home" and 1 or -1
		local forward = math.clamp(from.root.Position.X + sign * math.random(25, 50), -half, half)
		return Vector3.new(forward, 1.5, math.clamp(math.random(-edge, edge), -edge, edge))
	end

	return Vector3.new(math.random(-half, half), 1.5, math.random(-edge, edge))
end

function Pitch.build(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Match"
	folder.Parent = parent
	root = folder

	table.clear(footballers)

	for _, teamId in Config.TeamOrder do
		for _, spot in formationFor(teamId) do
			table.insert(footballers, buildFootballer(teamId, spot, folder))
		end
	end

	local b = makePart("Ball", Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(245, 245, 245), folder)
	b.Shape = Enum.PartType.Ball
	b.CFrame = CFrame.new(0, 1.5, 0)
	b.Material = Enum.Material.SmoothPlastic
	ball = b
	ballTarget = pickTarget(nil)
end

--[[
	Manda a bola para uma das balizas — e o que se ve quando ha golo. Quem decide
	que houve golo e o MatchLoop; isto e so a imagem.
]]
function Pitch.driveToGoal(teamId: string)
	local sign = teamId == "home" and 1 or -1
	ballTarget = Vector3.new((S.pitchLength / 2 - 2) * sign, 3, math.random(-6, 6))
	holder = nil
end

function Pitch.kickOff()
	if ball then
		ball.CFrame = CFrame.new(0, 1.5, 0)
	end
	ballTarget = pickTarget(nil)
	holder = nil
end

function Pitch.step(dt: number, playing: boolean)
	local b = ball
	if not b then
		return
	end

	-- Entre partes toda a gente volta ao seu lugar e a bola fica quieta.
	if not playing then
		for _, f in footballers do
			local goal = f.home
			local here = f.root.Position
			if (goal - here).Magnitude > 1 then
				local step = (goal - here).Unit * math.min(P.speed * dt, (goal - here).Magnitude)
				f.root.CFrame = CFrame.lookAt(here + step, goal)
			end
		end
		return
	end

	-- A bola viaja para o alvo. Ao chegar, quem estiver perto chuta outra vez.
	local toTarget = ballTarget - b.Position
	if toTarget.Magnitude > 0.5 then
		local step = toTarget.Unit * math.min(P.ballSpeed * dt, toTarget.Magnitude)
		b.CFrame = b.CFrame + step
	else
		holder = nearestTo(b.Position)
		ballTarget = pickTarget(holder)
	end

	-- Os dois mais proximos perseguem a bola; os outros seguram a posicao. Chega
	-- para se ler um jogo sem ter de simular um.
	local chaser = nearestTo(b.Position)
	for _, f in footballers do
		local goal = (f == chaser) and b.Position or f.home
		local here = f.root.Position
		local delta = Vector3.new(goal.X - here.X, 0, goal.Z - here.Z)

		if delta.Magnitude > P.kickRange * 0.4 then
			local step = delta.Unit * math.min(P.speed * dt, delta.Magnitude)
			f.root.CFrame = CFrame.lookAt(here + step, here + step + delta.Unit)
		end
	end
end

return Pitch
