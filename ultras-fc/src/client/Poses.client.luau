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
local Pano = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pano"))

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

-- O compasso do tambor de uma claque (pasta Stadium.Crowd), em pancadas.
local function beatFor(teamId: any): number?
	local stadium = workspace:FindFirstChild("Stadium")
	local crowd = stadium and stadium:FindFirstChild("Crowd")
	if type(teamId) ~= "string" or not crowd then
		return nil
	end
	local stamp = crowd:GetAttribute("Stamp")
	local beat = crowd:GetAttribute("Beat_" .. teamId)
	local rate = crowd:GetAttribute("Rate_" .. teamId)
	if type(stamp) ~= "number" or type(beat) ~= "number" or type(rate) ~= "number" then
		return nil
	end
	return beat + rate * (workspace:GetServerTimeNow() - stamp)
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

--------------------------------------------------------------------------------
-- As bandeiras na mao (Pano): a bandeirinha num pau, a grande entre duas hastes
--------------------------------------------------------------------------------

type HeldFlag = {
	kind: string,
	colour: Color3,
	cloth: Pano.Cloth,
	poles: { BasePart },
	folder: Folder,
}

local flags: { [Player]: HeldFlag } = {}

local POLE = Color3.fromRGB(70, 60, 48)
local SMALL_POLE = 3.6 -- o pau da bandeirinha
local BIG_POLE = 7.5 -- cada haste da bandeira grande
local BIG_HEIGHT = 3.4

local function flagColour(player: Player, kind: string): Color3
	local chosen = player:GetAttribute("Cor_" .. kind)
	if typeof(chosen) == "Color3" then
		return chosen
	end
	local team = Config.Teams[player:GetAttribute("Team") or ""]
	return if team then team.color else Color3.new(1, 1, 1)
end

local function dropFlag(player: Player)
	local f = flags[player]
	if f then
		f.folder:Destroy()
		flags[player] = nil
	end
end

Players.PlayerRemoving:Connect(dropFlag)

local function flagFor(player: Player, kind: string): HeldFlag?
	local teamId = player:GetAttribute("Team")
	if type(teamId) ~= "string" or not Config.Teams[teamId] then
		return nil
	end
	local colour = flagColour(player, kind)
	local existing = flags[player]
	if existing and existing.kind == kind and existing.colour == colour and existing.folder.Parent then
		return existing
	end
	dropFlag(player)

	local folder = Instance.new("Folder")
	folder.Name = "Bandeira_" .. player.Name
	local design = Pano.designFor(if kind == "bandeira" then "bandeira" else "bandeirinha", teamId)
	design.colour = colour
	local cloth = if kind == "bandeira"
		then Pano.new(folder, 5.5, BIG_HEIGHT, 7, design, { mode = "pinned", pixels = 24, seed = player.UserId })
		else Pano.new(folder, 2.4, 1.6, 3, design, { mode = "flag", pixels = 20, maxDistance = 200, seed = player.UserId })

	local poles: { BasePart } = {}
	for _ = 1, if kind == "bandeira" then 2 else 1 do
		local pole = Instance.new("Part")
		pole.Name = "Haste"
		pole.Size = Vector3.new(0.14, if kind == "bandeira" then BIG_POLE else SMALL_POLE, 0.14)
		pole.Color = POLE
		pole.Material = Enum.Material.Wood
		pole.Anchored = true
		pole.CanCollide = false
		pole.CanQuery = false
		pole.CanTouch = false
		pole.CastShadow = false
		pole.Parent = folder
		table.insert(poles, pole)
	end
	folder.Parent = workspace

	local made: HeldFlag = { kind = kind, colour = colour, cloth = cloth, poles = poles, folder = folder }
	flags[player] = made
	return made
end

-- Uma haste da mao `from` ao longo de `axis`: devolve o CFrame e a ponta de cima.
local function poleFrame(from: Vector3, axis: Vector3, length: number): (CFrame, Vector3)
	local top = from + axis * (length - 0.6)
	local mid = from + axis * (length / 2 - 0.6)
	local side = if math.abs(axis:Dot(Vector3.zAxis)) < 0.95 then Vector3.zAxis else Vector3.xAxis
	return CFrame.fromMatrix(mid, axis:Cross(side).Unit, axis), top
end

local flagParts: { BasePart } = {}
local flagFrames: { CFrame } = {}

local function placeFlag(player: Player, character: Model, kind: string, t: number)
	local f = flagFor(player, kind)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not f or not root then
		dropFlag(player)
		return
	end
	local waving = player:GetAttribute("Wave") == true
	table.clear(flagParts)
	table.clear(flagFrames)
	local right = root.CFrame.RightVector

	if kind == "bandeira" then
		local left = character:FindFirstChild("LeftHand") :: BasePart?
		local rightHand = character:FindFirstChild("RightHand") :: BasePart?
		if not left or not rightHand then
			return
		end
		-- As hastes abrem para fora e para cima; a agitar, balancam juntas.
		local sway = if waving then math.sin(t * 3.2) * 0.35 else math.sin(t * 1.3) * 0.06
		local tops = {}
		for i, hand in { left, rightHand } do
			local out = if i == 1 then -1 else 1
			local axis = (Vector3.yAxis + right * (out * 0.28 + sway)).Unit
			local cf, top = poleFrame(hand.Position, axis, BIG_POLE)
			table.insert(flagParts, f.poles[i])
			table.insert(flagFrames, cf)
			tops[i] = top
		end
		Pano.resize(f.cloth, (tops[2] - tops[1]).Magnitude)
		Pano.pose(f.cloth, Pano.between(tops[1], tops[2], Vector3.yAxis), t, if waving then 1 else 0.45, flagParts, flagFrames)
	else
		local hand = character:FindFirstChild("RightHand") :: BasePart?
		if not hand then
			return
		end
		local sway = if waving then math.sin(t * 6) * 0.5 else math.sin(t * 2) * 0.08
		local axis = (Vector3.yAxis + right * sway).Unit
		local cf, top = poleFrame(hand.Position, axis, SMALL_POLE)
		table.insert(flagParts, f.poles[1])
		table.insert(flagFrames, cf)
		-- O pano sai do pau para o lado, virado para a frente de quem a segura.
		local base = CFrame.fromMatrix(top, right, axis)
		Pano.pose(f.cloth, base, t, if waving then 1 else 0.55, flagParts, flagFrames)
	end
	workspace:BulkMoveTo(flagParts, flagFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

--------------------------------------------------------------------------------

RunService.Stepped:Connect(function()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hold = player:GetAttribute("Hold")
		local emote = player:GetAttribute("Emote")
		local riding = player:GetAttribute("Riding") == true
		local diving = player:GetAttribute("Diving") == true
		if not character or (hold == nil and emote == nil and not riding and not diving) then
			dropScarf(player)
			dropFlag(player)
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
		if player == me and walking and emote ~= nil and not riding and now - lastStop > 1 then
			lastStop = now
			Remotes.Emote:FireServer("")
		end
		if play then
			if emote == "saltar" then
				-- O salto vai ao compasso do tambor da claque (o da bancada): um
				-- salto por pancada, toda a gente ao mesmo tempo.
				local beat = beatFor(player:GetAttribute("Team"))
				play(rig, if beat then beat / 1.8 else t)
			else
				play(rig, t)
			end
		end

		-- O guarda-redes a atirar-se: os dois bracos esticados por cima da cabeca,
		-- as pernas juntas e direitas.
		if diving then
			arm(rig.rightShoulder, 1, math.rad(170), math.rad(10))
			arm(rig.leftShoulder, -1, math.rad(170), math.rad(10))
			set(rig.rightElbow, CFrame.identity)
			set(rig.leftElbow, CFrame.identity)
			set(rig.rightHip, CFrame.Angles(math.rad(-10), 0, 0))
			set(rig.leftHip, CFrame.Angles(math.rad(10), 0, 0))
			set(rig.rightKnee, CFrame.identity)
			set(rig.leftKnee, CFrame.identity)
			continue
		end

		-- De bicicleta: sentado, as pernas a pedalar e as maos no guiador.
		if riding then
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local crank = now * (2 + speed * 0.25)
			set(rig.rightHip, CFrame.Angles(math.rad(70) + math.sin(crank) * 0.45, 0, 0))
			set(rig.leftHip, CFrame.Angles(math.rad(70) - math.sin(crank) * 0.45, 0, 0))
			set(rig.rightKnee, CFrame.Angles(math.rad(-80) - math.cos(crank) * 0.4, 0, 0))
			set(rig.leftKnee, CFrame.Angles(math.rad(-80) + math.cos(crank) * 0.4, 0, 0))
			set(rig.waist, CFrame.Angles(math.rad(-15), 0, 0))
			if hold == nil then
				arm(rig.rightShoulder, 1, math.rad(70), 0, 0.15)
				arm(rig.leftShoulder, -1, math.rad(70), 0, 0.15)
			end
		end

		if hold == "tocha" or hold == "fumo" or hold == "vela" or hold == "estrobo" then
			-- O braco direito no ar, a agitar a tocha: para a frente e para tras,
			-- para cima e para baixo, como se faz numa bancada.
			local wave = math.sin(t * 4.5) * math.rad(18)
			local side = math.sin(t * 3.1) * math.rad(12)
			arm(rig.rightShoulder, 1, RAISED + wave, math.rad(8) + side)
			set(rig.rightElbow, CFrame.identity)
			dropScarf(player)
			dropFlag(player)
		elseif hold == "bandeirinha" then
			-- O braco direito no ar com o pau; a agitar, vai de um lado ao outro.
			local waving = player:GetAttribute("Wave") == true
			local swing = if waving then math.sin(t * 6) * math.rad(28) else math.sin(t * 2) * math.rad(6)
			arm(rig.rightShoulder, 1, RAISED, math.rad(10) + swing)
			set(rig.rightElbow, CFrame.identity)
			dropScarf(player)
			placeFlag(player, character, "bandeirinha", t)
		elseif hold == "bandeira" then
			-- Os dois bracos no ar, abertos, uma haste em cada mao.
			local waving = player:GetAttribute("Wave") == true
			local swing = if waving then math.sin(t * 3.2) * math.rad(14) else 0
			arm(rig.rightShoulder, 1, math.rad(165), math.rad(22) + swing)
			arm(rig.leftShoulder, -1, math.rad(165), math.rad(22) - swing)
			set(rig.rightElbow, CFrame.identity)
			set(rig.leftElbow, CFrame.identity)
			dropScarf(player)
			placeFlag(player, character, "bandeira", t)
		elseif hold == "cachecol" then
			-- Os dois bracos a frente, abertos, com o cachecol esticado entre as
			-- maos a altura da cara, a subir e a descer ao ritmo.
			local pump = math.sin(t * 3) * math.rad(10)
			arm(rig.rightShoulder, 1, math.rad(115) + pump, math.rad(28))
			arm(rig.leftShoulder, -1, math.rad(115) + pump, math.rad(28))
			set(rig.rightElbow, CFrame.identity)
			set(rig.leftElbow, CFrame.identity)
			placeScarf(player, character)
			dropFlag(player)
		else
			dropScarf(player)
			dropFlag(player)
		end
	end
end)
