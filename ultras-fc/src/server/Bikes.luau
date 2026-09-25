--!strict
--[[
	As bicicletas das sedes: para andar mais depressa pela cidade (ir aos
	dealers, chegar ao estadio).

	Nao e um veiculo com fisica, de proposito: sao pecas presas por baixo de
	quem pedala, que anda ao passo de uma bicicleta (Config.Bikes.speed). Uma
	bicicleta com fisica a serio do Roblox caia, capotava e prendia-se nos
	passeios; esta vai por onde a pessoa vai. As pernas a pedalar e as maos no
	guiador poe-nas cada ecra (Poses.client, atributo "Riding").

	Quem joga a bola nao pedala: em campo quem manda na velocidade e o Squad.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Bikes = {}

local B = Config.Bikes

local riding: { [Player]: { bike: Model, humanoid: Humanoid, colour: Color3 } } = {}

-- A bicicleta que cada um deixou parada na rua (so uma por pessoa).
local parkedBy: { [Player]: Model } = {}
local PARK_LIFE = 600 -- ao fim de 10 minutos parada, desaparece

local parkedFolder: Folder? = nil
local function parkedParent(): Folder
	if not parkedFolder or not parkedFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "BicicletasParadas"
		f.Parent = workspace
		parkedFolder = f
	end
	return parkedFolder :: Folder
end

local FRAME_DARK = Color3.fromRGB(34, 36, 40)
local TYRE = Color3.fromRGB(20, 20, 22)

local function piece(name: string, size: Vector3, colour: Color3, parent: Instance, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

--[[
	Uma bicicleta de pecas: duas rodas, o quadro da cor da claque, o selim e o
	guiador. `base` e o centro, ao nivel do eixo das rodas, virada para -Z.
	Serve tanto para as do suporte (paradas) como para a que se leva.
]]
function Bikes.build(colour: Color3, base: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Bicicleta"

	local frame = piece("Quadro", Vector3.new(0.25, 0.25, 3.2), colour, model)
	frame.CFrame = base * CFrame.new(0, 0.9, 0)
	model.PrimaryPart = frame

	local function add(p: Part, offset: CFrame)
		p.CFrame = base * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = frame
		weld.Part1 = p
		weld.Parent = p
	end

	for _, z in { -1.6, 1.6 } do
		-- Roda: um cilindro deitado, pneu escuro com o aro claro por dentro.
		add(piece("Roda", Vector3.new(0.2, 2.4, 2.4), TYRE, model, Enum.PartType.Cylinder), CFrame.new(0, 0, z))
		add(piece("Aro", Vector3.new(0.22, 1.9, 1.9), Color3.fromRGB(170, 172, 176), model, Enum.PartType.Cylinder), CFrame.new(0, 0, z))
	end
	add(piece("Tubo", Vector3.new(0.22, 1.6, 0.22), colour, model), CFrame.new(0, 0.5, 0.4) * CFrame.Angles(math.rad(-25), 0, 0))
	add(piece("Garfo", Vector3.new(0.2, 1.4, 0.2), FRAME_DARK, model), CFrame.new(0, 0.7, -1.4) * CFrame.Angles(math.rad(15), 0, 0))
	add(piece("Selim", Vector3.new(0.5, 0.2, 0.9), FRAME_DARK, model), CFrame.new(0, 1.35, 0.7))
	add(piece("Guiador", Vector3.new(1.6, 0.18, 0.18), FRAME_DARK, model), CFrame.new(0, 1.45, -1.3))

	model.Parent = parent
	return model
end

function Bikes.isRiding(player: Player): boolean
	return riding[player] ~= nil
end

local function clearParked(player: Player)
	local old = parkedBy[player]
	parkedBy[player] = nil
	if old then
		old:Destroy()
	end
end

--[[
	Deixa a bicicleta parada onde se desceu, de pe e com as rodas no chao, e
	com o botao para voltar a pegar nela (quem quer que seja).
]]
local function park(player: Player, colour: Color3, at: CFrame)
	clearParked(player)
	local look = at.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = -Vector3.zAxis
	end
	-- O chao por baixo (a rua, o passeio), ignorando pessoas e a propria bicicleta.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { parkedParent() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(at.Position + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0), params)
	local groundY = if hit then hit.Position.Y else at.Position.Y - 1.2
	local base = CFrame.lookAt(Vector3.new(at.Position.X, groundY + 1.2, at.Position.Z), Vector3.new(at.Position.X, groundY + 1.2, at.Position.Z) + flat.Unit)
		* CFrame.new(1.5, 0, 0) -- ao lado de quem desceu, nao por baixo

	local bike = Bikes.build(colour, base, parkedParent())
	for _, d in bike:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	parkedBy[player] = bike

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pegar bicicleta"
	prompt.ObjectText = "Bicicleta"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = bike.PrimaryPart
	prompt.Triggered:Connect(function(who)
		if bike.Parent and Bikes.mount(who, colour) then
			if parkedBy[player] == bike then
				parkedBy[player] = nil
			end
			bike:Destroy()
		end
	end)

	task.delay(PARK_LIFE, function()
		if parkedBy[player] == bike then
			parkedBy[player] = nil
		end
		if bike.Parent then
			bike:Destroy()
		end
	end)
end

function Bikes.dismount(player: Player, leave: boolean?)
	local ride = riding[player]
	if not ride then
		return
	end
	riding[player] = nil
	local frame = ride.bike.PrimaryPart
	local at = if frame then frame.CFrame else nil
	ride.bike:Destroy()
	-- Descer (botao, F, entrar em campo) deixa-a parada; morrer ou sair nao.
	if leave ~= false and at and ride.humanoid.Parent and ride.humanoid.Health > 0 then
		park(player, ride.colour, at)
	end
	if ride.humanoid.Parent then
		ride.humanoid.WalkSpeed = 16
	end
	player:SetAttribute("Riding", nil)
end

-- Pega numa bicicleta da claque: vai por baixo de quem pedala, e anda mais.
function Bikes.mount(player: Player, colour: Color3): boolean
	if riding[player] or player:GetAttribute("Team") == "jogador" then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end

	-- As rodas no chao: o eixo fica a meio metro do chao, por baixo da anca.
	local toGround = humanoid.HipHeight + root.Size.Y / 2
	local bike = Bikes.build(colour, root.CFrame * CFrame.new(0, -toGround + 1.2, 0), character)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bike.PrimaryPart
	weld.Parent = bike

	humanoid.WalkSpeed = B.speed
	riding[player] = { bike = bike, humanoid = humanoid, colour = colour }
	player:SetAttribute("Riding", true)

	-- Morrer ou renascer tira a bicicleta.
	humanoid.Died:Once(function()
		Bikes.dismount(player, false)
	end)
	return true
end

function Bikes.start()
	Players.PlayerRemoving:Connect(function(player)
		riding[player] = nil
		clearParked(player)
	end)
	-- Quem entra em campo desce: la a velocidade e do Squad.
	task.spawn(function()
		while true do
			task.wait(1)
			for player in riding do
				if player:GetAttribute("Team") == "jogador" or not player.Character then
					Bikes.dismount(player)
				end
			end
		end
	end)
end

return Bikes
