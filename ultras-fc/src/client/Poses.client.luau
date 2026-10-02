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
local PanoRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PanoRig"))
local PanoSim = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PanoSim"))
local PanoMesh = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PanoMesh"))
local Rigs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rigs"))
local Animacoes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Animacoes"))

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
		text.Text = if team then team.nameUpper else ""
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
	fly: Vector3?, -- para onde o pano voa (atras do movimento do mastro)
	lastTop: Vector3?,
	lastT: number?,
}

local flags: { [Player]: HeldFlag } = {}

local POLE = Color3.fromRGB(70, 60, 48)
local SMALL_POLE = 4.5 -- o pau da bandeirinha
local MASTRO_POLE = 11 -- o mastro da bandeira grande (o pano e que e grande)
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
	local design = Pano.designFor(if kind == "bandeirinha" then "bandeirinha" else kind, teamId)
	design.colour = colour
	local cloth = if kind == "bandeira"
		then Pano.new(folder, 5.5, BIG_HEIGHT, 7, design, { mode = "pinned", pixels = 24, seed = player.UserId })
		elseif kind == "mastro" then Pano.new(folder, 12, 8, 16, design, { mode = "flag", pixels = 14, seed = player.UserId })
		else Pano.new(folder, 3.2, 2.1, 5, design, { mode = "flag", pixels = 20, maxDistance = 220, seed = player.UserId })

	local poles: { BasePart } = {}
	for _ = 1, if kind == "bandeira" then 2 else 1 do
		local pole = Instance.new("Part")
		pole.Name = "Haste"
		pole.Size = if kind == "mastro"
			then Vector3.new(0.32, MASTRO_POLE, 0.32)
			else Vector3.new(0.14, if kind == "bandeira" then BIG_POLE else SMALL_POLE, 0.14)
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

--[[
	Para onde voa o pano: para tras do movimento da ponta do mastro (quem
	agita da uma chicotada e o pano segue atras), com um pouco de vento para o
	lado. Alisado, para nao saltar de um lado para o outro.
]]
local function flyDir(f: HeldFlag, top: Vector3, axis: Vector3, wind: Vector3): Vector3
	local now = os.clock()
	local dt = math.clamp(now - (f.lastT or now), 1 / 240, 0.1)
	local velocity = (top - (f.lastTop or top)) / dt
	f.lastTop = top
	f.lastT = now
	local want = wind * 0.6 - velocity * 0.12
	want -= axis * want:Dot(axis)
	if want.Magnitude < 0.05 then
		want = wind - axis * wind:Dot(axis)
	end
	local current = f.fly or want.Unit
	local blended = current:Lerp(want.Unit, math.clamp(dt * 12, 0, 1))
	blended -= axis * blended:Dot(axis)
	f.fly = if blended.Magnitude > 1e-3 then blended.Unit else want.Unit
	return f.fly :: Vector3
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
	elseif kind == "mastro" then
		local left = character:FindFirstChild("LeftHand") :: BasePart?
		local rightHand = character:FindFirstChild("RightHand") :: BasePart?
		if not left or not rightHand then
			return
		end
		--[[
			O mastro nas duas maos. A agitar: grandes arcos de um lado para o
			outro por cima da claque (e um pouco para a frente e para tras); o
			pano chicoteia atras do movimento. Parado: quase direito.
		]]
		local look = root.CFrame.LookVector
		-- A agitar: arcos de 180 graus por cima da cabeca, de um lado ao outro.
		local swing = if waving then math.sin(t * 1.6) * 1.35 else math.sin(t * 0.8) * 0.07
		local pitch = if waving then math.sin(t * 3.2) * 0.12 else 0
		local axis = (CFrame.fromAxisAngle(look, swing) * CFrame.fromAxisAngle(right, pitch)):VectorToWorldSpace(Vector3.yAxis)
		local grip = (left.Position + rightHand.Position) / 2
		local cf, top = poleFrame(grip, axis, MASTRO_POLE)
		table.insert(flagParts, f.poles[1])
		table.insert(flagFrames, cf)
		local base = CFrame.fromMatrix(top, flyDir(f, top, axis, right), axis)
		Pano.pose(f.cloth, base, t, if waving then 1 else 0.5, flagParts, flagFrames)
	else
		local hand = character:FindFirstChild("RightHand") :: BasePart?
		if not hand then
			return
		end
		--[[
			Como se agita uma bandeira a serio: arcos de 180 graus por cima da
			cabeca, de um lado ao outro. O pano vai sempre atras da ponta (flyDir)
			e chicoteia em cada mudanca de lado. Parado, so balanca.
		]]
		local angle = if waving then math.sin(t * 4.2) * 1.35 else math.sin(t * 2) * 0.08
		local axis = (Vector3.yAxis * math.cos(angle) + right * math.sin(angle)).Unit
		local cf, top = poleFrame(hand.Position, axis, SMALL_POLE)
		table.insert(flagParts, f.poles[1])
		table.insert(flagFrames, cf)
		-- O pano sai do pau para o lado e segue atras do movimento do pau.
		local base = CFrame.fromMatrix(top, flyDir(f, top, axis, right), axis)
		Pano.pose(f.cloth, base, t, if waving then 1 else 0.55, flagParts, flagFrames)
	end
	workspace:BulkMoveTo(flagParts, flagFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

--------------------------------------------------------------------------------
-- A bandeira grande e a bandeirinha: rigs com juntas (Rigs), mexidas aqui
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- A bandeira grande agitada pelo jogo: duas maos, arcos por cima da cabeca
--------------------------------------------------------------------------------

--[[
	Como no video de referencia (bandeira 2x2 m, haste 3 m):
	- a mao de baixo (direita) segura o fundo da haste a altura da barriga e
	  faz de apoio: anda um pouco para o lado contrario, como uma alavanca;
	- a mao de cima (esquerda) empurra a haste mais acima;
	- a haste faz arcos largos por cima da cabeca, de um lado ao outro, sem
	  pressa (controlado);
	- o pano vai sempre atras da haste; nas mudancas de lado passa por tras,
	  por cima da cabeca, e enrola-se nas pontas.
	Os bracos chegam a haste por calculo (dois ossos: ombro e cotovelo).
]]

-- Onde fica uma junta do corpo (Motor6D ou AnimationConstraint), e o seu referencial.
local function jointFrame(joint: any): CFrame?
	if joint:IsA("Motor6D") then
		local part0 = joint.Part0
		return if part0 then part0.CFrame * joint.C0 else nil
	end
	local a0 = joint.Attachment0
	return if a0 then a0.WorldCFrame else nil
end

--[[
	Um braco a chegar a `target` (no mundo): o ombro aponta o braco, o
	cotovelo dobra o que for preciso. `side` 1 direito, -1 esquerdo.
]]
local function reach(shoulder: any, elbow: any?, wrist: any?, side: number, target: Vector3)
	local sFrame = jointFrame(shoulder)
	local eFrame = elbow and jointFrame(elbow)
	local wFrame = wrist and jointFrame(wrist)
	if not sFrame then
		return
	end
	-- Os comprimentos do braco (medidos no proprio corpo: serve a qualquer avatar).
	local a = if eFrame then (eFrame.Position - sFrame.Position).Magnitude else 1.3
	local b = if eFrame and wFrame then (wFrame.Position - eFrame.Position).Magnitude + 0.25 else 1.3
	a = math.clamp(a, 0.6, 2.5)
	b = math.clamp(b, 0.6, 2.5)

	local d = sFrame.Rotation:VectorToObjectSpace(target - sFrame.Position)
	local L = math.clamp(d.Magnitude, math.abs(a - b) + 0.05, a + b - 0.02)
	local dir = if d.Magnitude > 1e-3 then d.Unit else Vector3.new(0, -1, 0)
	-- O cotovelo aponta para fora e para tras (como quem segura um mastro).
	local hint = Vector3.new(side * 0.7, -0.4, 0.6)
	local perp = hint - dir * hint:Dot(dir)
	perp = if perp.Magnitude > 1e-3 then perp.Unit else Vector3.new(side, 0, 0)
	local alpha = math.acos(math.clamp((a * a + L * L - b * b) / (2 * a * L), -1, 1))
	local beta = math.pi - math.acos(math.clamp((a * a + b * b - L * L) / (2 * a * b), -1, 1))
	local upper = dir * math.cos(alpha) + perp * math.sin(alpha)

	-- O ombro: o braco (que em repouso aponta para baixo) passa a apontar para `upper`.
	local yAxis = -upper
	local xAxis = upper:Cross(dir)
	xAxis = if xAxis.Magnitude > 1e-4 then xAxis.Unit else Vector3.xAxis
	local zAxis = xAxis:Cross(yAxis).Unit
	xAxis = yAxis:Cross(zAxis).Unit
	shoulder.Transform = CFrame.fromMatrix(Vector3.zero, xAxis, yAxis, zAxis)

	if elbow then
		-- Dobra para o lado em que o antebraco fica virado para o alvo.
		local toTarget = (d - upper * a).Unit
		local rot = CFrame.fromMatrix(Vector3.zero, xAxis, yAxis, zAxis)
		local plus = rot:VectorToWorldSpace(Vector3.new(0, -math.cos(beta), -math.sin(beta)))
		local minus = rot:VectorToWorldSpace(Vector3.new(0, -math.cos(beta), math.sin(beta)))
		elbow.Transform = if plus:Dot(toTarget) >= minus:Dot(toTarget)
			then CFrame.Angles(beta, 0, 0)
			else CFrame.Angles(-beta, 0, 0)
	end
end

-- O lado para onde o pano da bandeira grande vai, alisado por pessoa (angulo a volta da haste).
local clothPhi: { [Player]: number } = {}
local lastWave: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player)
	clothPhi[player] = nil
	lastWave[player] = nil
end)

-- Arco de um lado ao outro: ~2,9 s por ida e volta, controlado.
local SWING_SPEED = 2.2
local SWING_WIDTH = 0.95 -- radianos para cada lado (~55 graus)

--[[
	A haste e os bracos da bandeira grande, sem animacao feita. Devolve onde
	fica a haste (CFrame: Y ao longo dela, X para o lado do pano).
]]
local function waveBigFlag(player: Player, character: Model, rig: Rig?, spec: any, t: number): CFrame?
	local clock = os.clock()
	local dt = math.clamp(clock - (lastWave[player] or clock), 0, 0.1)
	lastWave[player] = clock
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local waving = player:GetAttribute("Wave") == true
	local w = t * SWING_SPEED
	local a = if waving then math.sin(w) * SWING_WIDTH else math.sin(t * 0.7) * 0.06
	local rootCF = root.CFrame

	-- A haste: inclinada para o lado do arco e um pouco para a frente.
	local axisLocal = Vector3.new(math.sin(a), math.cos(a), -0.45).Unit -- bem inclinada para a frente: passa a frente e por cima, longe do corpo
	local axis = rootCF:VectorToWorldSpace(axisLocal)
	-- A mao de baixo, a barriga; anda para o lado contrario (alavanca).
	local bottomLocal = Vector3.new(0.2 - 0.5 * math.sin(a), -1.1, -1.6) -- baixa e a frente: o braco vai esticado
	local bottom = rootCF:PointToWorldSpace(bottomLocal)
	local top = bottom + axis * 2.2

	-- Para onde vai o pano: atras do movimento; nas mudancas de lado passa por
	-- tras (por cima da cabeca).
	local tangent = rootCF:VectorToWorldSpace(Vector3.new(math.cos(a), -math.sin(a), 0))
	tangent = (tangent - axis * tangent:Dot(axis)).Unit
	local back = tangent:Cross(axis).Unit
	local moving = math.cos(w) -- > 0: a ir para a direita
	local target = if not waving then math.pi / 2 elseif moving > 0 then math.pi else 0
	local phi = clothPhi[player] or target
	phi += math.clamp(target - phi, -dt * 4.5, dt * 4.5)
	clothPhi[player] = phi
	local side = tangent * math.cos(phi) + back * math.sin(phi)

	local centre = bottom + axis * (spec.pole / 2 - spec.grip)
	local pole = CFrame.fromMatrix(centre, side, axis)

	-- Os bracos: a direita no fundo, a esquerda mais acima.
	if rig then
		reach(rig.rightShoulder, rig.rightElbow, motor(character, "RightHand", "RightWrist"), 1, bottom)
		reach(rig.leftShoulder, rig.leftElbow, motor(character, "LeftHand", "LeftWrist"), -1, top)
	end
	return pole
end

-- O pano simulado de cada bandeira na mao (PanoSim), pelo modelo do rig.
local sims: { [Instance]: PanoSim.Sim } = setmetatable({}, { __mode = "k" }) :: any
local lastSim: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
-- O pano liso (PanoMesh) de cada bandeira; false = nao se pode, fica o de tiras.
local smooth: { [Instance]: any } = {}

-- As bandeiras que ja se largaram: o pano liso sai com elas.
task.spawn(function()
	while true do
		task.wait(2)
		for model, cloth in smooth do
			if not model.Parent then
				if cloth then
					PanoMesh.destroy(cloth)
				end
				smooth[model] = nil
			end
		end
	end
end)

-- O desenho do pano liso: a cor escolhida no dealer, ou a da claque, e a sigla.
local function smoothDesign(player: Player, kind: string): PanoMesh.Design
	local team = Config.Teams[player:GetAttribute("Team") or ""]
	local chosen = player:GetAttribute("Cor_" .. kind)
	return {
		kind = kind,
		colour = if typeof(chosen) == "Color3" then chosen elseif team then team.color else Color3.new(1, 1, 1),
		short = if team then team.short else nil,
		teamId = if team then team.id else nil,
		hoops = if team then team.hoops == true else false,
	}
end

--[[
	A bandeira grande e a bandeirinha. O MASTRO: com animacao feita
	(Config.Animations.bandeira e bandeirinha) e ela que o mexe; sem ela, o
	jogo faz os arcos de 180 graus. O PANO e sempre simulado (PanoSim): vai
	atras do mastro como tecido, seja qual for quem mexe o mastro.
]]
local function poseRigFlag(player: Player, character: Model, kind: string, t: number, rig: Rig?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hand = character:FindFirstChild("RightHand") :: BasePart?
	local spec = Rigs.FLAGS[kind]
	if not root or not hand or not spec then
		return
	end
	local cloth, poleJoint = Rigs.findFlag(character, kind)
	if not cloth or not poleJoint then
		return
	end
	local waving = player:GetAttribute("Wave") == true
	local animated = Animacoes.has(if kind == "mastro" then "bandeira" else kind)

	local pole: CFrame
	if animated then
		-- O mastro esta onde a animacao o pos.
		pole = (poleJoint.Part1 :: BasePart).CFrame
	elseif kind == "mastro" then
		-- A bandeira grande: o jogo agita-a com as duas maos (waveBigFlag).
		local placed = waveBigFlag(player, character, rig, spec, t)
		if not placed then
			return
		end
		pole = placed
		-- Part0 * C0 * Transform = Part1 * C1
		poleJoint.Transform = (hand.CFrame * poleJoint.C0):Inverse() * pole * poleJoint.C1
	else
		-- O mastro: arcos de um lado ao outro por cima da cabeca.
		local right = root.CFrame.RightVector
		local look = root.CFrame.LookVector
		local axis: Vector3
		if kind == "mastro" then
			local swing = if waving then math.sin(t * 1.6) * 1.35 else math.sin(t * 0.8) * 0.07
			local pitch = if waving then math.sin(t * 3.2) * 0.12 else 0
			axis = (CFrame.fromAxisAngle(look, swing) * CFrame.fromAxisAngle(right, pitch)):VectorToWorldSpace(Vector3.yAxis)
		else
			local angle = if waving then math.sin(t * 4.2) * 1.35 else math.sin(t * 2) * 0.08
			axis = (Vector3.yAxis * math.cos(angle) + right * math.sin(angle)).Unit
		end
		local grip = (hand.CFrame * poleJoint.C0).Position
		local side = axis:Cross(look)
		side = if side.Magnitude > 1e-3 then side.Unit else right
		pole = CFrame.fromMatrix(grip + axis * (spec.pole / 2 - spec.grip), side, axis)
		-- Part0 * C0 * Transform = Part1 * C1
		poleJoint.Transform = (hand.CFrame * poleJoint.C0):Inverse() * pole * poleJoint.C1
	end

	-- O pano: preso ao mastro pela beira, o resto pela fisica.
	local model = poleJoint.Parent and poleJoint.Parent.Parent
	if not model then
		return
	end
	local corner = pole * cloth.joints[1][1].C0
	--[[
		A bandeira grande com animacao: quem anima roda o pano a volta do mastro
		(a junta Bandeira_C1L1) para ele varrer de um lado ao outro. O pano liso
		vai para onde essa junta aponta (vento e forma puxam para la) e continua
		a ondular como tecido. (A bandeirinha fica como esta: so fisica.)
	]]
	local followAnim = animated and kind == "mastro"
	if followAnim then
		corner *= cloth.joints[1][1].Transform.Rotation
	end
	local sim = sims[model]
	if not sim or sim.rig.joints[1][1] ~= cloth.joints[1][1] then
		sim = PanoSim.new(cloth, corner)
		sims[model] = sim
	end
	local now = os.clock()
	local dt = math.clamp(now - (lastSim[model] or now), 0, 0.1)
	lastSim[model] = now
	-- A bandeirinha e leve e firme (fica esticada como no Animation Editor);
	-- a grande e mais pesada e solta. Nenhuma passa por dentro de quem a segura.
	local avoid = {}
	local head = character:FindFirstChild("Head") :: BasePart?
	local chest = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if head then
		table.insert(avoid, { head.Position, 1.5 })
	end
	if chest then
		table.insert(avoid, { chest.Position, 1.7 })
	end
	PanoSim.step(sim, dt, corner, if waving then 1 else 0.35, t, {
		shape = if kind == "bandeirinha" then 0.35 elseif followAnim then 0.3 else 0.12,
		gravity = if kind == "bandeirinha" then 24 else 26,
		-- A grande: o ar trava-a e fica para tras do mastro; pouco vento, e o
		-- movimento de quem a agita que a mexe.
		drag = if kind == "bandeirinha" then nil else 2.2,
		flutter = if kind == "bandeirinha" then nil else 2.4,
		avoid = avoid,
	})

	-- O pano liso, se este ecra o conseguir fazer; senao, as tiras do rig.
	local liso = smooth[model]
	if liso == nil then
		liso = PanoMesh.new(sim.cols, sim.rows, spec.width, spec.height, smoothDesign(player, kind), workspace) or false
		smooth[model] = liso
		if liso then
			-- As tiras ficam la (para as animacoes), mas nao se veem neste ecra.
			for _, column in cloth.parts do
				for _, piece in column do
					-- (Transparency e nao LocalTransparencyModifier: esse, nas pecas da
					-- personagem, o Roblox repoe a cada frame. So muda neste ecra.)
					piece.Transparency = 1
					for _, gui in piece:GetChildren() do
						if gui:IsA("SurfaceGui") then
							gui.Enabled = false
						end
					end
				end
			end
		end
	end
	if liso then
		PanoMesh.update(liso, corner, sim.pos)
	else
		PanoSim.apply(sim, pole)
	end
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
		-- (Uma ordem do lider aceite nao acaba por se andar: pausa e volta ao parar.)
		local ordered = player:GetAttribute("EmoteUntil")
		local byOrder = type(ordered) == "number" and workspace:GetServerTimeNow() < ordered
		if player == me and walking and emote ~= nil and not riding and not byOrder and now - lastStop > 1 then
			lastStop = now
			Remotes.Emote:FireServer("")
		end
		-- Com a animacao "salto" feita, e ela que salta.
		if play and emote == "saltar" and Animacoes.has("salto") then
			play = nil
		end
		if play then
			if emote == "saltar" then
				-- O salto vai ao compasso do tambor da claque (o da bancada): um
				-- salto por pancada, toda a gente ao mesmo tempo.
				local beat = beatFor(player:GetAttribute("Team"))
				play(rig, if beat then beat / 1.8 else t)
			elseif emote == "balancar" then
				-- O balanco tambem ao compasso: um lado por pancada.
				local beat = beatFor(player:GetAttribute("Team"))
				play(rig, if beat then beat * math.pi / 3 else t)
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
			-- Com animacao feita para isto (tocha, fumo, velaromana), e ela que mexe.
			local made = if hold == "tocha" then "tocha" elseif hold == "fumo" then "fumo" elseif hold == "vela" then "velaromana" else nil
			if not (made and Animacoes.has(made)) then
				arm(rig.rightShoulder, 1, RAISED + wave, math.rad(8) + side)
				set(rig.rightElbow, CFrame.identity)
			end
			dropScarf(player)
			dropFlag(player)
		elseif hold == "bandeirinha" then
			-- O braco direito no ar com o pau; a agitar, vai de um lado ao outro.
			local waving = player:GetAttribute("Wave") == true
			-- A agitar: o braco vai de um lado ao outro com o pau.
			dropScarf(player)
			dropFlag(player)
			if not Animacoes.has("bandeirinha") then
				local swing = if waving then math.sin(t * 4.2) * math.rad(40) else math.sin(t * 2) * math.rad(6)
				arm(rig.rightShoulder, 1, RAISED, math.rad(10) + swing)
				set(rig.rightElbow, CFrame.identity)
			end
			-- O pano e sempre simulado (com ou sem animacao do corpo).
			poseRigFlag(player, character, "bandeirinha", t)
		elseif hold == "mastro" then
			-- As duas maos no mastro, por cima da cabeca, a acompanhar os arcos.
			dropScarf(player)
			dropFlag(player)
			-- Sem animacao feita, os bracos sao postos na haste (waveBigFlag).
			poseRigFlag(player, character, "mastro", t, if Animacoes.has("bandeira") then nil else rig)
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
