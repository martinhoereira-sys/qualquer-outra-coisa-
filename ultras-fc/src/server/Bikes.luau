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

	-- O centro invisivel onde tudo se prende (e onde se solda a quem pedala).
	local frame = piece("Quadro", Vector3.new(0.2, 0.2, 0.2), colour, model)
	frame.Transparency = 1
	frame.CFrame = base * CFrame.new(0, 0.9, 0)
	model.PrimaryPart = frame

	local function add(p: Part, offset: CFrame)
		p.CFrame = base * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = frame
		weld.Part1 = p
		weld.Parent = p
	end

	local METAL = Color3.fromRGB(170, 172, 176)
	-- Um tubo entre dois pontos (em coordenadas da bicicleta).
	local function tube(name: string, from: Vector3, to: Vector3, thick: number, c: Color3)
		local mid = (from + to) / 2
		local p = piece(name, Vector3.new(thick, thick, (to - from).Magnitude), c, model)
		add(p, CFrame.lookAt(mid, to))
	end

	for _, z in { -1.6, 1.6 } do
		-- Roda: pneu escuro, aro claro e o cubo ao meio.
		add(piece("Roda", Vector3.new(0.22, 2.4, 2.4), TYRE, model, Enum.PartType.Cylinder), CFrame.new(0, 0, z))
		add(piece("Aro", Vector3.new(0.24, 1.95, 1.95), METAL, model, Enum.PartType.Cylinder), CFrame.new(0, 0, z))
		add(piece("Raios", Vector3.new(0.26, 1.7, 1.7), Color3.fromRGB(58, 60, 64), model, Enum.PartType.Cylinder), CFrame.new(0, 0, z))
		add(piece("Cubo", Vector3.new(0.4, 0.35, 0.35), METAL, model, Enum.PartType.Cylinder), CFrame.new(0, 0, z))
	end

	-- O quadro em diamante, da cor da claque.
	local crank = Vector3.new(0, 0.1, 0.2)
	local seatTop = Vector3.new(0, 1.25, 0.55)
	local head = Vector3.new(0, 1.15, -1.05)
	tube("TuboSelim", crank, seatTop, 0.2, colour)
	tube("TuboCima", seatTop + Vector3.new(0, -0.1, 0), head, 0.2, colour)
	tube("TuboBaixo", crank, head + Vector3.new(0, -0.25, 0), 0.24, colour)
	tube("Escora", crank, Vector3.new(0, 0, 1.6), 0.14, colour)
	tube("EscoraCima", seatTop + Vector3.new(0, -0.15, 0), Vector3.new(0, 0, 1.6), 0.12, colour)
	tube("Garfo", head, Vector3.new(0, 0, -1.6), 0.16, FRAME_DARK)
	tube("Avanco", head, head + Vector3.new(0, 0.35, 0.1), 0.16, FRAME_DARK)

	-- Selim, guiador com punhos, e os pedais.
	add(piece("Selim", Vector3.new(0.45, 0.18, 0.85), FRAME_DARK, model), CFrame.new(seatTop + Vector3.new(0, 0.12, 0.05)))
	local bar = head + Vector3.new(0, 0.4, 0.1)
	add(piece("Guiador", Vector3.new(1.5, 0.14, 0.14), FRAME_DARK, model), CFrame.new(bar))
	for _, x in { -0.68, 0.68 } do
		add(piece("Punho", Vector3.new(0.25, 0.2, 0.2), TYRE, model), CFrame.new(bar + Vector3.new(x, 0, 0)))
	end
	add(piece("Pedaleiro", Vector3.new(0.3, 0.5, 0.5), METAL, model, Enum.PartType.Cylinder), CFrame.new(crank))
	for _, side in { -1, 1 } do
		local arm = crank + Vector3.new(side * 0.25, side * 0.35, 0)
		tube("Biela", crank + Vector3.new(side * 0.25, 0, 0), arm, 0.1, METAL)
		add(piece("Pedal", Vector3.new(0.4, 0.08, 0.3), TYRE, model), CFrame.new(arm + Vector3.new(side * 0.2, 0, 0)))
	end

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
	local role = player:GetAttribute("Team")
	if riding[player] or role == "jogador" or role == "arbitro" then
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
	-- Ninguem pedala de emote, nem de tocha na mao.
	player:SetAttribute("Emote", nil)
	humanoid:UnequipTools()
	riding[player] = { bike = bike, humanoid = humanoid, colour = colour }
	player:SetAttribute("Riding", true)

	-- Morrer ou renascer tira a bicicleta.
	humanoid.Died:Once(function()
		Bikes.dismount(player, false)
	end)

	local watching: { RBXScriptConnection } = {}
	local function stopWatching()
		for _, c in watching do
			c:Disconnect()
		end
	end
	-- Mudar de papel (jogador, guarda-redes, arbitro) desce logo da bicicleta.
	for _, attribute in { "Team", "Keeper" } do
		table.insert(watching, player:GetAttributeChangedSignal(attribute):Connect(function()
			Bikes.dismount(player)
		end))
	end
	-- De bicicleta as maos estao no guiador: pegar numa ferramenta arruma-a logo.
	table.insert(watching, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(function()
				humanoid:UnequipTools()
			end)
		end
	end))
	table.insert(watching, bike.AncestryChanged:Connect(function()
		if not bike.Parent then
			stopWatching()
		end
	end))
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
				local team = player:GetAttribute("Team")
				if team == "jogador" or team == "arbitro" or not player.Character then
					Bikes.dismount(player)
				end
			end
		end
	end)
end

return Bikes
