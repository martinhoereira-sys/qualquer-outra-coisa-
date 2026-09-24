--!strict
--[[
	As animacoes de toda a gente, feitas neste ecra.

	Cada pessoa tem dois atributos que o servidor poe:
	- "Hold": o que tem no ar — "tocha" ou "fumo" (braco direito levantado) ou
	  "cachecol" (os dois bracos a frente, com o cachecol esticado entre as maos);
	- "Emote": a animacao de adepto que escolheu no menu.

	Aqui, a cada frame, dobram-se as juntas de cada corpo (o Transform de cada
	Motor6D ou AnimationConstraint)
	depois das animacoes do Roblox, para toda a gente ver o mesmo sem nada
	passar pela rede alem dos dois atributos. So para avatares R15; num R6 nao
	acontece nada. Andar para a animacao (a tocha continua no ar).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local me = Players.LocalPlayer
local lastStop = 0

local RAISED = math.rad(Config.Poses.raisedArm)

--[[
	Uma junta do corpo. Os avatares antigos tem Motor6D; os novos (juntas
	com fisica) tem AnimationConstraint. As duas tem Transform, e e so isso
	que aqui se mexe.
]]
type Joint = any

type Rig = {
	character: Model,
	root: BasePart,
	rightShoulder: Joint,
	leftShoulder: Joint,
	rightElbow: Joint?,
	leftElbow: Joint?,
	waist: Joint?,
	rootJoint: Joint?,
	rightHip: Joint?,
	leftHip: Joint?,
	rightKnee: Joint?,
	leftKnee: Joint?,
}

local rigs: { [Model]: Rig } = {}

local function motor(character: Model, part: string, name: string): Joint?
	local host = character:FindFirstChild(part)
	local found = host and host:FindFirstChild(name)
	if found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) then
		return found
	end
	return nil
end

local function rigOf(character: Model): Rig?
	local cached = rigs[character]
	if cached and cached.root.Parent then
		return cached
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rightShoulder = motor(character, "RightUpperArm", "RightShoulder")
	local leftShoulder = motor(character, "LeftUpperArm", "LeftShoulder")
	if not root or not rightShoulder or not leftShoulder then
		return nil
	end
	local rig: Rig = {
		character = character,
		root = root,
		rightShoulder = rightShoulder,
		leftShoulder = leftShoulder,
		rightElbow = motor(character, "RightLowerArm", "RightElbow"),
		leftElbow = motor(character, "LeftLowerArm", "LeftElbow"),
		waist = motor(character, "UpperTorso", "Waist"),
		rootJoint = motor(character, "LowerTorso", "Root"),
		rightHip = motor(character, "RightUpperLeg", "RightHip"),
		leftHip = motor(character, "LeftUpperLeg", "LeftHip"),
		rightKnee = motor(character, "RightLowerLeg", "RightKnee"),
		leftKnee = motor(character, "LeftLowerLeg", "LeftKnee"),
	}
	rigs[character] = rig
	character.AncestryChanged:Connect(function()
		if not character.Parent then
			rigs[character] = nil
		end
	end)
	return rig
end

--[[
	Um braco. `lift` e quanto sobe para a frente (0 caido, 90 a frente, 180 no
	ar); `out` abre-o para o lado; `turn` roda-o para dentro, a frente do peito.
	`side` e 1 no direito e -1 no esquerdo, para os dois abrirem para fora.
]]
local function arm(joint: Joint, side: number, lift: number, out: number?, turn: number?)
	joint.Transform = CFrame.Angles(0, (turn or 0) * side, 0)
		* CFrame.Angles(0, 0, -(out or 0) * side)
		* CFrame.Angles(lift, 0, 0)
end

local function set(joint: Joint?, cf: CFrame)
	if joint then
		joint.Transform = cf
	end
end

-- Um numero entre 0 e 1 fixo por pessoa, para nao fazerem todos o mesmo ao mesmo tempo.
local function phaseOf(player: Player): number
	return (player.UserId % 97) / 97
end

local EMOTES: { [string]: (Rig, number) -> () } = {
	-- Bracos a frente, as maos a baterem uma na outra.
	aplaudir = function(rig, t)
		local clap = math.abs(math.sin(t * 7))
		arm(rig.rightShoulder, 1, math.rad(80), 0, 0.25 + 0.3 * clap)
		arm(rig.leftShoulder, -1, math.rad(80), 0, 0.25 + 0.3 * clap)
		set(rig.rightElbow, CFrame.Angles(math.rad(25), 0, 0))
		set(rig.leftElbow, CFrame.Angles(math.rad(25), 0, 0))
	end,

	-- Os dois bracos no ar, a puxar ao ritmo.
	maos = function(rig, t)
		local pump = math.sin(t * 5) * math.rad(10)
		arm(rig.rightShoulder, 1, math.rad(165) + pump, math.rad(15))
		arm(rig.leftShoulder, -1, math.rad(165) + pump, math.rad(15))
	end,

	-- A saltar no sitio, de bracos no ar.
	saltar = function(rig, t)
		local lift = math.abs(math.sin(t * math.pi * 1.8)) * 1.3
		set(rig.rootJoint, CFrame.new(0, lift, 0))
		arm(rig.rightShoulder, 1, math.rad(160), math.rad(20))
		arm(rig.leftShoulder, -1, math.rad(160), math.rad(20))
	end,

	-- De um lado para o outro, com os bracos no ar a acompanhar.
	balancar = function(rig, t)
		local sway = math.sin(t * 3)
		set(rig.waist, CFrame.Angles(0, 0, sway * 0.25))
		arm(rig.rightShoulder, 1, math.rad(155), math.rad(20) + sway * 0.3)
		arm(rig.leftShoulder, -1, math.rad(155), math.rad(20) - sway * 0.3)
	end,

	-- Agachado, como a claque antes de saltar toda ao mesmo tempo.
	agachado = function(rig, _t)
		set(rig.rootJoint, CFrame.new(0, -1.2, 0))
		set(rig.waist, CFrame.Angles(math.rad(-15), 0, 0))
		set(rig.rightHip, CFrame.Angles(math.rad(85), 0, 0))
		set(rig.leftHip, CFrame.Angles(math.rad(85), 0, 0))
		set(rig.rightKnee, CFrame.Angles(math.rad(-110), 0, 0))
		set(rig.leftKnee, CFrame.Angles(math.rad(-110), 0, 0))
		arm(rig.rightShoulder, 1, math.rad(40), math.rad(10))
		arm(rig.leftShoulder, -1, math.rad(40), math.rad(10))
	end,
}

--------------------------------------------------------------------------------
-- O cachecol esticado entre as maos
--------------------------------------------------------------------------------

local scarves: { [Player]: Part } = {}

local function scarfFor(player: Player, colour: Color3): Part
	local existing = scarves[player]
	if existing and existing.Parent then
		return existing
	end
	local p = Instance.new("Part")
	p.Name = "CachecolNoAr"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Fabric
	p.Color = colour
	p.Size = Vector3.new(4, 0.8, 0.08)

	-- O nome da claque dos dois lados, como num cachecol a serio.
	local team = Config.Teams[player:GetAttribute("Team") or ""]
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sign = Instance.new("SurfaceGui")
		sign.Face = face
		sign.CanvasSize = Vector2.new(400, 80)
		sign.LightInfluence = 0.6
		sign.Parent = p
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(245, 245, 245)
		text.Text = if team then string.upper(team.name) else ""
		text.Parent = sign
	end

	p.Parent = workspace
	scarves[player] = p
	return p
end

local function dropScarf(player: Player)
	local p = scarves[player]
	if p then
		p:Destroy()
		scarves[player] = nil
	end
end

Players.PlayerRemoving:Connect(dropScarf)

local function placeScarf(player: Player, character: Model)
	local left = character:FindFirstChild("LeftHand") :: BasePart?
	local right = character:FindFirstChild("RightHand") :: BasePart?
	local team = Config.Teams[player:GetAttribute("Team") or ""]
	if not left or not right or not team then
		dropScarf(player)
		return
	end
	local a, b = left.Position, right.Position
	local span = b - a
	if span.Magnitude < 0.5 then
		return
	end
	local p = scarfFor(player, team.color)
	local across = span.Unit
	local up = Vector3.yAxis
	local front = across:Cross(up)
	if front.Magnitude < 0.1 then
		return
	end
	up = front.Unit:Cross(across)
	-- Um pouco acima das maos, e a cair por baixo delas: esticado pelas pontas.
	local mid = (a + b) / 2 + up * 0.1
	p.Size = Vector3.new(span.Magnitude + 0.6, 0.8, 0.08)
	p.CFrame = CFrame.fromMatrix(mid - up * 0.35, across, up)
end

--------------------------------------------------------------------------------

RunService.Stepped:Connect(function()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hold = player:GetAttribute("Hold")
		local emote = player:GetAttribute("Emote")
		if not character or (hold == nil and emote == nil) then
			dropScarf(player)
			continue
		end
		local rig = rigOf(character)
		if not rig then
			continue
		end
		local t = now + phaseOf(player) * 10

		-- A andar, a animacao de adepto para; a tocha continua no ar.
		local v = rig.root.AssemblyLinearVelocity
		local walking = Vector3.new(v.X, 0, v.Z).Magnitude > 2
		local play = if type(emote) == "string" and not walking then EMOTES[emote] else nil
		-- Quem se mexe acaba a sua animacao (so o proprio a pode parar).
		if player == me and walking and emote ~= nil and now - lastStop > 1 then
			lastStop = now
			Remotes.Emote:FireServer("")
		end
		if play then
			play(rig, t)
		end

		if hold == "tocha" or hold == "fumo" then
			-- O braco direito no ar, a agitar a tocha: para a frente e para tras,
			-- para cima e para baixo, como se faz numa bancada.
			local wave = math.sin(t * 4.5) * math.rad(18)
			local side = math.sin(t * 3.1) * math.rad(12)
			arm(rig.rightShoulder, 1, RAISED + wave, math.rad(8) + side)
			set(rig.rightElbow, CFrame.identity)
			dropScarf(player)
		elseif hold == "cachecol" then
			-- Os dois bracos a frente, abertos, com o cachecol esticado entre as
			-- maos a altura da cara, a subir e a descer ao ritmo.
			local pump = math.sin(t * 3) * math.rad(10)
			arm(rig.rightShoulder, 1, math.rad(115) + pump, math.rad(28))
			arm(rig.leftShoulder, -1, math.rad(115) + pump, math.rad(28))
			set(rig.rightElbow, CFrame.identity)
			set(rig.leftElbow, CFrame.identity)
			placeScarf(player, character)
		else
			dropScarf(player)
		end
	end
end)
