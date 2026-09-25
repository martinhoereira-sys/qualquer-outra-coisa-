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

local riding: { [Player]: { bike: Model, humanoid: Humanoid } } = {}

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

function Bikes.dismount(player: Player)
	local ride = riding[player]
	if not ride then
		return
	end
	riding[player] = nil
	ride.bike:Destroy()
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
	riding[player] = { bike = bike, humanoid = humanoid }
	player:SetAttribute("Riding", true)

	-- Morrer ou renascer tira a bicicleta.
	humanoid.Died:Once(function()
		Bikes.dismount(player)
	end)
	return true
end

function Bikes.start()
	Players.PlayerRemoving:Connect(function(player)
		riding[player] = nil
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
