--!strict
--[[
	O material de claque: tochas, bombas de fumo, cachecol e, para o lider, o
	tambor.

	E a imagem do jogo. Uma bancada as escuras e pontos de luz a arder no meio
	dela, o fumo a encher o topo e a ver-se do outro lado do campo. Por isso e
	o servidor que as acende: uma tocha que so quem a acendeu visse nao servia
	de nada. Cada uma sozinha e modesta, como na vida real; e a bancada inteira
	acesa que faz a imagem.

	Esta sempre na barra de baixo de quem e de claque, desde que escolhe o
	lado: nada de ir a uma caixa buscar. Quem nao e de claque nao tem nada.
	Acender gasta um do stock do jogo (ou nada, com Config.GearStock.unlimited),
	e o objecto fica na mao, apagado, pronto para o proximo.

	Como se segura: a tocha e a lata de fumo vao presas a mao direita, e acesas
	sobem com o braco por cima da cabeca. O cachecol vai ao pescoco; clicar
	estica-o por cima da cabeca, com as duas maos. Os bracos quem os mexe e o
	Poses.client, em todos os ecras, pelo atributo "Hold" de cada pessoa.

	O que estava partido antes, para nao voltar:
	- o tambor do lider ocupava o unico "lugar aceso" que cada um tinha, e o
	  lider nunca conseguia acender uma tocha;
	- a ponta da tocha era colada ao cabo antes de ser posta no sitio, e ficava
	  escondida dentro dele;
	- os Fire e Smoke antigos do Roblox sao pequenos e baços, nao se viam de
	  longe;
	- o material perdia-se ao renascer, e so voltava indo a caixa da sede.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Teams = require(script.Parent:WaitForChild("Teams"))

local Gear = {}

local KINDS = Config.Gear

-- A ordem na barra: tocha, fumo, vela romana, estrobo, cachecol e (lider) tambor.
local ORDER = { "tocha", "fumo", "vela", "estrobo", "cachecol", "tambor" }

-- O que se acende e se segura no ar.
local PYRO: { [string]: boolean } = { tocha = true, fumo = true, vela = true, estrobo = true }

local LABEL: { [string]: string } = {
	tocha = "Tocha",
	fumo = "Fumo",
	vela = "Vela",
	estrobo = "Estrobo",
	cachecol = "Cachecol",
	tambor = "Tambor",
}

--[[
	As texturas. Tiradas de pirotecnia da Toolbox (bengalas e velas romanas
	feitas para claques): so as imagens, nunca os scripts desses modelos. A
	chama de bengala, o fogo, o brilho, as faiscas e um fumo realista.
]]
local FIRE = "rbxassetid://4753372559"
local GLOW = "rbxassetid://6673021984"
local SPARK = "rbxassetid://10822615828"
local SMOKE = "rbxassetid://9013694245"
-- O fogo e o fumo do proprio Roblox: a chama da tocha de que se gostou.
local BASE_FIRE = "rbxasset://textures/particles/fire_main.dds"
local BASE_SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local HOT = Color3.fromRGB(255, 244, 214) -- o branco do centro de uma chama
local WHITE = Color3.fromRGB(240, 240, 240)

--[[
	O angulo do braco com a tocha acesa, a contar do braco caido (0) ate ao
	braco todo no ar (180). Tem de ser o mesmo que o Poses.client usa: e com
	ele que se calcula para onde a tocha aponta dentro da mao, para ficar de pe.
]]
local RAISED = math.rad(Config.Poses.raisedArm)

-- Contagens por tipo: cada material tem o seu stock e a sua espera.
local remaining: { [Player]: { [string]: number } } = {}
local nextAllowed: { [Player]: { [string]: number } } = {}

-- O objecto de cada tipo que cada um tem, na barra ou na mao.
local tools: { [Player]: { [string]: Tool } } = {}

-- O que esta na mao de cada objecto equipado: a peca solta e a solda a mao.
type Held = {
	model: Model,
	body: BasePart,
	tip: BasePart,
	weld: Weld,
	length: number,
}
local held: { [Tool]: Held } = {}

type Lit = {
	player: Player,
	tool: Tool,
	kind: string,
	teamId: string,
	until_: number,
	effects: Attachment,
}

-- O que esta aceso agora, um por objecto: o tambor do lider ja nao tapa a tocha.
local lit: { [Tool]: Lit } = {}

-- Cachecois esticados no ar.
local raised: { [Tool]: { player: Player, teamId: string } } = {}

local onDrumHit: ((Player) -> ())? = nil
local onCountChanged: ((Player, { [string]: number }) -> ())? = nil

local onEmpty: ((Player, string) -> ())? = nil

-- Quem tentou acender algo que ja nao tem (para o avisar).
function Gear.onEmpty(fn: (Player, string) -> ())
	onEmpty = fn
end

function Gear.onDrumHit(fn: (Player) -> ())
	onDrumHit = fn
end

function Gear.onCountChanged(fn: (Player, { [string]: number }) -> ())
	onCountChanged = fn
end

--------------------------------------------------------------------------------
-- Stock
--------------------------------------------------------------------------------

-- Quantos restam deste tipo. -1 quer dizer sem limite.
function Gear.remaining(player: Player, kind: string): number
	if Config.GearStock.unlimited then
		return -1
	end
	local mine = remaining[player]
	local stock = mine and mine[kind]
	return if stock ~= nil then stock else KINDS[kind].perMatch
end

local function spend(player: Player, kind: string)
	if Config.GearStock.unlimited then
		return
	end
	remaining[player] = remaining[player] or {}
	remaining[player][kind] = Gear.remaining(player, kind) - 1
end

-- O que o rodape do ecra mostra: o stock de cada um, e se tem tambor.
function Gear.counts(player: Player): { [string]: number }
	local counts: { [string]: number } = {
		tambor = if Teams.isLeader(player) then 1 else 0,
	}
	for kind in PYRO do
		counts[kind] = if Teams.get(player) then Gear.remaining(player, kind) else 0
	end
	return counts
end

local function announce(player: Player)
	if onCountChanged then
		onCountChanged(player, Gear.counts(player))
	end
end

-- Mais stock deste material (comprado a um dealer, por exemplo).
function Gear.give(player: Player, kind: string, amount: number)
	if not PYRO[kind] or Config.GearStock.unlimited then
		return
	end
	remaining[player] = remaining[player] or {}
	remaining[player][kind] = Gear.remaining(player, kind) + amount
	announce(player)
end

-- Quanto e que o material aceso desta bancada empurra o ambiente por segundo.
function Gear.heatFor(teamId: string): number
	local total = 0
	for _, entry in lit do
		if entry.teamId == teamId then
			total += KINDS[entry.kind].gainPerSecond
		end
	end
	for _, entry in raised do
		if entry.teamId == teamId then
			total += KINDS.cachecol.gainPerSecond
		end
	end
	return total
end

--------------------------------------------------------------------------------
-- Os efeitos
--------------------------------------------------------------------------------

local function curve(points: { { number } }): NumberSequence
	local keys = {}
	for _, point in points do
		table.insert(keys, NumberSequenceKeypoint.new(point[1], point[2]))
	end
	return NumberSequence.new(keys)
end

local function emitter(name: string, texture: string, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = texture
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = parent
	return e
end

-- As luzes das tochas e fumos acesos. Uma que ja saiu do jogo deixa de contar.
local lights: { [PointLight]: boolean } = {}

local function litCount(): number
	local n = 0
	for light in lights do
		if light.Parent then
			n += 1
		else
			lights[light] = nil
		end
	end
	return n
end

local function smokesBurning(): number
	local n = 0
	for _, entry in lit do
		if entry.kind == "fumo" then
			n += 1
		end
	end
	return n
end

--[[
	A tocha: uma chama pequena e muito viva na ponta, branca no centro e da
	cor da equipa a volta, faiscas a saltar e um fio de fumo a sair. Sozinha e
	modesta; uma bancada inteira delas e que enche o topo.

	As chamas e o fumo sobem por aceleracao, nao pela direcao da ponta: seja
	qual for o angulo da mao, o fogo vai sempre para cima.
]]
local function flareEffects(at: Attachment, colour: Color3)
	-- A chama: a de sempre (fogo do proprio Roblox), da cor da equipa com o
	-- centro quase branco, a tremer e a subir.
	local flame = emitter("Chama", BASE_FIRE, at)
	flame.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, HOT),
		ColorSequenceKeypoint.new(0.3, colour:Lerp(HOT, 0.45)),
		ColorSequenceKeypoint.new(1, colour),
	})
	flame.LightEmission = 1
	flame.LightInfluence = 0
	flame.Size = curve({ { 0, 1.1 }, { 0.5, 0.75 }, { 1, 0.15 } })
	flame.Transparency = curve({ { 0, 0 }, { 0.7, 0.3 }, { 1, 1 } })
	flame.Lifetime = NumberRange.new(0.22, 0.42)
	flame.Rate = 55
	flame.Speed = NumberRange.new(0.5, 2)
	flame.SpreadAngle = Vector2.new(18, 18)
	flame.Acceleration = Vector3.new(0, 12, 0)
	flame.RotSpeed = NumberRange.new(-140, 140)

	-- O nucleo branco, colado a ponta: uma tocha a serio queima a branco.
	local core = emitter("Nucleo", FIRE, at)
	core.Color = ColorSequence.new(Color3.new(1, 1, 1), HOT)
	core.LightEmission = 1
	core.LightInfluence = 0
	core.Size = curve({ { 0, 0.55 }, { 1, 0.25 } })
	core.Transparency = curve({ { 0, 0 }, { 1, 0.9 } })
	core.Lifetime = NumberRange.new(0.06, 0.1)
	core.Rate = 70
	core.Speed = NumberRange.new(0, 0.3)

	-- O brilho a volta, a pulsar: e o que se ve do outro lado do estadio.
	local glow = emitter("Halo", GLOW, at)
	glow.Color = ColorSequence.new(colour:Lerp(HOT, 0.3))
	glow.LightEmission = 1
	glow.LightInfluence = 0
	glow.Size = curve({ { 0, 2.6 }, { 1, 3.4 } })
	glow.Transparency = curve({ { 0, 0.62 }, { 1, 1 } })
	glow.Lifetime = NumberRange.new(0.1, 0.2)
	glow.Rate = 22
	glow.Speed = NumberRange.new(0, 0)

	-- Faiscas e escorias a pingar da ponta.
	local sparks = emitter("Faiscas", SPARK, at)
	sparks.Color = ColorSequence.new(HOT, colour:Lerp(HOT, 0.5))
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = curve({ { 0, 0.1 }, { 1, 0 } })
	sparks.Lifetime = NumberRange.new(0.5, 1)
	sparks.Rate = 26
	sparks.Speed = NumberRange.new(3, 8)
	sparks.SpreadAngle = Vector2.new(80, 80)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Drag = 0.8

	-- Fumo: muito, que e o que uma tocha deita. Claro, com um toque da cor.
	local smoke = emitter("Fumo", BASE_SMOKE, at)
	smoke.Color = ColorSequence.new(colour:Lerp(Color3.fromRGB(225, 222, 218), 0.6), Color3.fromRGB(180, 178, 176))
	smoke.LightEmission = 0.15
	smoke.LightInfluence = 0.6
	smoke.Size = curve({ { 0, 1 }, { 0.3, 4.5 }, { 1, 9 } })
	smoke.Transparency = curve({ { 0, 0.4 }, { 0.5, 0.6 }, { 1, 1 } })
	smoke.Lifetime = NumberRange.new(4, 6.5)
	smoke.Rate = 12
	smoke.Speed = NumberRange.new(2, 4)
	smoke.SpreadAngle = Vector2.new(20, 20)
	smoke.Acceleration = Vector3.new(0, 3, 0)
	smoke.Drag = 0.5
	smoke.RotSpeed = NumberRange.new(-30, 30)
end

--[[
	A vela romana, na mao: faiscas e fumo a sair da boca. As bolas de fogo que
	dispara sao pecas a serio (fireball, mais abaixo), para subirem alto.
]]
local function candleEffects(at: Attachment, colour: Color3)
	local trail = emitter("Rasto", SPARK, at)
	trail.Color = ColorSequence.new(HOT, colour)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Size = curve({ { 0, 0.12 }, { 1, 0 } })
	trail.Lifetime = NumberRange.new(0.3, 0.6)
	trail.Rate = 40
	trail.Speed = NumberRange.new(8, 16)
	trail.SpreadAngle = Vector2.new(12, 12)
	trail.Acceleration = Vector3.new(0, -20, 0)

	local smoke = emitter("Fumo", SMOKE, at)
	smoke.Color = ColorSequence.new(Color3.fromRGB(200, 196, 190))
	smoke.LightInfluence = 0.7
	smoke.Size = curve({ { 0, 0.6 }, { 1, 5 } })
	smoke.Transparency = curve({ { 0, 0.55 }, { 1, 1 } })
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(2, 4)
	smoke.Acceleration = Vector3.new(0, 2, 0)
end

--[[
	O estrobo (o pisca-pisca): claroes brancos secos e rapidos. Nao ilumina,
	pisca: e o que faz a bancada parecer uma trovoada a noite.
]]
local function strobeEffects(at: Attachment)
	local flash = emitter("Clarao", GLOW, at)
	flash.Color = ColorSequence.new(Color3.new(1, 1, 1))
	flash.LightEmission = 1
	flash.LightInfluence = 0
	flash.Size = curve({ { 0, 7 }, { 1, 7 } })
	flash.Transparency = curve({ { 0, 0 }, { 1, 0.4 } })
	flash.Lifetime = NumberRange.new(0.05, 0.07)
	flash.Rate = 7
	flash.Speed = NumberRange.new(0, 0)

	local spark = emitter("Faisca", SPARK, at)
	spark.Color = ColorSequence.new(Color3.new(1, 1, 1))
	spark.LightEmission = 1
	spark.Size = curve({ { 0, 0.3 }, { 1, 0 } })
	spark.Lifetime = NumberRange.new(0.1, 0.2)
	spark.Rate = 20
	spark.Speed = NumberRange.new(1, 3)
	spark.SpreadAngle = Vector2.new(180, 180)
end

--[[
	A bomba de fumo: uma nuvem da cor da equipa que sai com forca da lata,
	abre, sobe devagar e fica no ar.
]]
local function smokeEffects(at: Attachment, colour: Color3)
	local plume = emitter("Nuvem", SMOKE, at)
	plume.Color = ColorSequence.new(colour:Lerp(Color3.new(1, 1, 1), 0.1), colour:Lerp(Color3.new(1, 1, 1), 0.35))
	plume.LightEmission = 0.05
	plume.LightInfluence = 0.75
	plume.Size = curve({ { 0, 1.5 }, { 0.15, 6 }, { 1, 13 } })
	plume.Transparency = curve({ { 0, 0.15 }, { 0.6, 0.35 }, { 1, 1 } })
	plume.Lifetime = NumberRange.new(6, 9)
	plume.Rate = if smokesBurning() >= Config.Performance.maxSmokes then 9 else 16
	plume.Speed = NumberRange.new(5, 8)
	plume.SpreadAngle = Vector2.new(22, 22)
	plume.Acceleration = Vector3.new(0, 1.2, 0)
	plume.Drag = 0.5
	plume.RotSpeed = NumberRange.new(-25, 25)

	-- O jacto a sair da lata, com a cor viva, antes de abrir em nuvem.
	local jet = emitter("Jacto", SMOKE, at)
	jet.Color = ColorSequence.new(colour)
	jet.LightEmission = 0.2
	jet.LightInfluence = 0.5
	jet.Size = curve({ { 0, 0.5 }, { 1, 2.5 } })
	jet.Transparency = curve({ { 0, 0.1 }, { 1, 1 } })
	jet.Lifetime = NumberRange.new(0.5, 0.8)
	jet.Rate = 20
	jet.Speed = NumberRange.new(7, 10)
	jet.SpreadAngle = Vector2.new(10, 10)
end

--[[
	Uma bola de fogo da vela romana: sobe a direito, alto, com rasto de fogo e
	faiscas, e apaga-se no ar. E uma peca com fisica a serio, mas com a
	gravidade quase toda anulada (VectorForce), senao nao passava dos 12 studs.
]]
local function fireball(from: Vector3, colour: Color3, parent: Instance)
	local ball = Instance.new("Part")
	ball.Name = "BolaDeFogo"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1, 1, 1)
	ball.Material = Enum.Material.Neon
	ball.Color = colour:Lerp(HOT, 0.25)
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.CFrame = CFrame.new(from)

	local at = Instance.new("Attachment")
	at.Parent = ball
	local lift = Instance.new("VectorForce")
	lift.Attachment0 = at
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.ApplyAtCenterOfMass = true
	lift.Parent = ball

	local trail = emitter("Rasto", FIRE, at)
	trail.Color = ColorSequence.new(HOT, colour)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Size = curve({ { 0, 1.4 }, { 1, 0 } })
	trail.Transparency = curve({ { 0, 0 }, { 1, 1 } })
	trail.Lifetime = NumberRange.new(0.25, 0.45)
	trail.Rate = 90
	trail.Speed = NumberRange.new(0, 1)

	local sparks = emitter("Faiscas", SPARK, at)
	sparks.Color = ColorSequence.new(HOT)
	sparks.LightEmission = 1
	sparks.Size = curve({ { 0, 0.12 }, { 1, 0 } })
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Rate = 40
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -20, 0)

	ball.Parent = parent
	lift.Force = Vector3.new(0, ball:GetMass() * workspace.Gravity * 0.85, 0)
	ball:SetNetworkOwner(nil)
	local wobble = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.15
	ball.AssemblyLinearVelocity = (Vector3.yAxis + wobble).Unit * 72
	Debris:AddItem(ball, 2.4)
end

local shotAt: { [Tool]: number } = {}

--------------------------------------------------------------------------------
-- O que se tem na mao
--------------------------------------------------------------------------------

local function loosePart(name: string, size: Vector3, colour: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Cola `piece` a `body`, no sitio certo: primeiro o sitio, depois a solda.
local function weldTo(body: BasePart, piece: BasePart, offset: CFrame)
	piece.CFrame = body.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = piece
	weld.Parent = body
end

--[[
	Para onde aponta o objecto dentro da mao. Com o braco levantado `angle`
	(0 caido, 180 no ar), este e o sentido que, no mundo, fica a apontar para
	cima. Apagado vai com o braco caido, um pouco para a frente.
]]
local function stickDirection(angle: number): Vector3
	return Vector3.new(0, math.cos(angle), -math.sin(angle))
end

local function gripFor(h: Held, up: Vector3): CFrame
	local unit = up.Unit
	return CFrame.fromMatrix(unit * (h.length / 2 - 0.35), Vector3.xAxis, unit)
end

local LOW = Vector3.new(0, 0.55, -0.85) -- apagado: na mao, a apontar para a frente e para cima

local function handOf(character: Model): BasePart?
	return (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
end

--[[
	A tocha e a lata, feitas pecas soltas presas a mao. Uma tocha a serio e um
	bastao fino e vermelho, com a chama so na ponta; a lata e mais grossa e
	curta, com uma banda da cor da equipa.
]]
local function buildHeld(kind: string, colour: Color3): Held
	local model = Instance.new("Model")
	model.Name = "NaMao"

	local body: BasePart
	local length: number
	if kind == "vela" then
		-- Um tubo comprido e grosso, de cartao pintado.
		length = 2.6
		body = loosePart("Vela", Vector3.new(0.34, length, 0.34), colour:Lerp(Color3.fromRGB(30, 30, 30), 0.35), model)
		local band = loosePart("Banda", Vector3.new(0.36, 0.3, 0.36), Color3.fromRGB(240, 240, 240), model)
		weldTo(body, band, CFrame.new(0, 0.5, 0))
	elseif kind == "estrobo" then
		-- Uma caixinha branca, com a lente em cima.
		length = 0.8
		body = loosePart("Estrobo", Vector3.new(0.5, length, 0.5), Color3.fromRGB(220, 220, 216), model)
	elseif kind == "tocha" then
		length = 1.7
		body = loosePart("Tocha", Vector3.new(0.2, length, 0.2), Color3.fromRGB(196, 38, 34), model)
		local cap = loosePart("Tampa", Vector3.new(0.22, 0.28, 0.22), Color3.fromRGB(40, 40, 44), model)
		weldTo(body, cap, CFrame.new(0, -length / 2 + 0.14, 0))
	else
		length = 1.1
		body = loosePart("Lata", Vector3.new(0.5, length, 0.5), Color3.fromRGB(46, 48, 54), model)
		local band = loosePart("Banda", Vector3.new(0.52, 0.34, 0.52), colour, model)
		weldTo(body, band, CFrame.new(0, 0.1, 0))
	end

	local tip = loosePart("Ponta", Vector3.new(0.24, 0.14, 0.24), colour, model)
	tip.Material = Enum.Material.Neon
	tip.Transparency = 1 -- so se ve acesa
	weldTo(body, tip, CFrame.new(0, length / 2 + 0.05, 0))

	local weld = Instance.new("Weld")
	weld.Name = "Mao"
	weld.Part1 = body
	weld.Parent = body

	model.PrimaryPart = body
	return { model = model, body = body, tip = tip, weld = weld, length = length }
end

-- Pega: o objecto aparece na mao direita.
local function equip(tool: Tool, kind: string, teamId: string)
	local character = tool.Parent
	if not character or not character:IsA("Model") then
		return
	end
	local hand = handOf(character)
	if not hand then
		return
	end
	local h = buildHeld(kind, Config.Teams[teamId].color)
	h.weld.Part0 = hand
	h.weld.C0 = gripFor(h, LOW)
	h.model.Parent = character
	held[tool] = h
end

-- O cachecol ao pescoco: a volta e as duas pontas a cair a frente.
local NECK = "CachecolPescoco"

local function wearScarf(character: Model, colour: Color3)
	if character:FindFirstChild(NECK) then
		return
	end
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	local model = Instance.new("Model")
	model.Name = NECK

	local top = torso.Size.Y / 2
	local ring = loosePart("Volta", Vector3.new(1.3, 0.32, 1.1), colour, model)
	ring.Material = Enum.Material.Fabric
	ring.CFrame = torso.CFrame * CFrame.new(0, top - 0.1, 0)
	for _, x in { -0.3, 0.3 } do
		local strip = loosePart("Ponta", Vector3.new(0.36, 1.2, 0.08), colour, model)
		strip.Material = Enum.Material.Fabric
		strip.CFrame = torso.CFrame * CFrame.new(x, top - 0.75, -torso.Size.Z / 2 - 0.05)
		local fringe = loosePart("Franja", Vector3.new(0.37, 0.18, 0.09), WHITE, model)
		weldTo(strip, fringe, CFrame.new(0, -0.6, 0))
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = torso
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.Parent = character
end

local function showScarf(character: Model?, visible: boolean)
	local scarf = character and character:FindFirstChild(NECK)
	if not scarf then
		return
	end
	for _, part in scarf:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = if visible then 0 else 1
		end
	end
end

--------------------------------------------------------------------------------
-- Acender e apagar
--------------------------------------------------------------------------------

-- O braco no ar, em todos os ecras: o Poses.client le isto.
local function setHold(player: Player, what: string?)
	player:SetAttribute("Hold", what)
end

local function ignite(player: Player, tool: Tool, kind: string, teamId: string)
	local h = held[tool]
	if not h then
		return
	end

	local colour = Config.Teams[teamId].color
	h.tip.Color = colour
	h.tip.Transparency = 0
	-- Acesa, sobe com o braco e fica de pe.
	h.weld.C0 = gripFor(h, stickDirection(RAISED))
	setHold(player, kind)

	local effects = Instance.new("Attachment")
	effects.Name = "Aceso"
	effects.Position = Vector3.new(0, 0.1, 0)
	effects.Parent = h.tip

	if kind == "tocha" then
		flareEffects(effects, colour)
	elseif kind == "vela" then
		candleEffects(effects, colour)
	elseif kind == "estrobo" then
		strobeEffects(effects)
	else
		smokeEffects(effects, colour)
	end

	lit[tool] = {
		player = player,
		tool = tool,
		kind = kind,
		teamId = teamId,
		until_ = os.clock() + KINDS[kind].duration,
		effects = effects,
	}

	--[[
		Luz propria so ate ao teto. Uma bancada inteira de tochas acesas, cada
		uma com a sua luz, deitava abaixo um telemovel; a partir dai a chama e o
		fumo chegam para se ver a tocha.
	]]
	if kind == "estrobo" or litCount() >= Config.Performance.maxLights then
		return
	end
	local light = Instance.new("PointLight")
	light.Brightness = if kind == "tocha" or kind == "vela" then 4 else 1.5
	light.Range = if kind == "tocha" or kind == "vela" then 22 else 16
	light.Color = colour:Lerp(HOT, 0.2)
	-- Sombras de uma luz pequena sao das coisas mais caras que ha.
	light.Shadows = false
	light.Parent = effects
	lights[light] = true
end

-- Apaga: deixa de sair fogo e fumo, e o que ja saiu desfaz-se no ar.
local function extinguish(entry: Lit)
	lit[entry.tool] = nil
	local effects = entry.effects
	for _, child in effects:GetChildren() do
		if child:IsA("ParticleEmitter") then
			child.Enabled = false
		elseif child:IsA("PointLight") then
			child:Destroy()
		end
	end
	-- O fumo mais lento ainda leva uns segundos a sumir.
	task.delay(10, function()
		effects:Destroy()
	end)

	local h = held[entry.tool]
	if h then
		h.tip.Transparency = 1
		h.weld.C0 = gripFor(h, LOW)
	end
	if entry.player:GetAttribute("Hold") == entry.kind then
		setHold(entry.player, nil)
	end
end

-- Larga: o que estava na mao some, e aceso apaga-se.
local function unequip(player: Player, tool: Tool)
	local entry = lit[tool]
	if entry then
		extinguish(entry)
	end
	if raised[tool] then
		raised[tool] = nil
		setHold(player, nil)
		showScarf(player.Character, true)
	end
	local h = held[tool]
	held[tool] = nil
	if h then
		-- O fumo que ja saiu fica no ar: so se tira a peca da mao.
		h.model:Destroy()
	end
end

local function activate(player: Player, tool: Tool, kind: string)
	local teamId = Teams.get(player)
	if not teamId then
		return
	end

	-- O tambor bate-se as vezes que forem precisas.
	if kind == "tambor" then
		if onDrumHit then
			onDrumHit(player)
		end
		return
	end

	-- O cachecol: do pescoco para cima da cabeca, esticado, e de volta.
	if kind == "cachecol" then
		if raised[tool] then
			raised[tool] = nil
			setHold(player, nil)
			showScarf(player.Character, true)
		else
			raised[tool] = { player = player, teamId = teamId }
			setHold(player, "cachecol")
			showScarf(player.Character, false)
		end
		return
	end

	if lit[tool] then
		return
	end
	local waits = nextAllowed[player]
	if waits and (waits[kind] or 0) > os.clock() then
		return
	end
	if Gear.remaining(player, kind) == 0 then
		-- Sem stock: diz-se porque, em vez de nao acontecer nada.
		if onEmpty then
			onEmpty(player, kind)
		end
		return
	end

	spend(player, kind)
	nextAllowed[player] = nextAllowed[player] or {}
	nextAllowed[player][kind] = os.clock() + KINDS[kind].duration + KINDS[kind].cooldown
	ignite(player, tool, kind, teamId)
	announce(player)
end

--------------------------------------------------------------------------------
-- A barra
--------------------------------------------------------------------------------

local function buildTool(player: Player, kind: string, teamId: string): Tool
	local colour = Config.Teams[teamId].color
	local tool = Instance.new("Tool")
	tool.Name = LABEL[kind]
	tool.ToolTip = LABEL[kind]
	tool:SetAttribute("Kind", kind)
	tool:SetAttribute("Team", teamId)
	tool.CanBeDropped = false

	if kind == "tambor" then
		-- O tambor continua um objecto do Roblox com pega: deitado, a tiracolo.
		tool.RequiresHandle = true
		tool.Grip = CFrame.new(0, -1.4, 0) * CFrame.Angles(0, 0, math.rad(90))
		local handle = loosePart("Handle", Vector3.new(2.6, 2.2, 2.6), Color3.fromRGB(196, 186, 168), tool)
		handle.Shape = Enum.PartType.Cylinder
		local skin = loosePart("Skin", Vector3.new(0.3, 2.3, 2.3), colour, tool)
		skin.Shape = Enum.PartType.Cylinder
		weldTo(handle, skin, CFrame.new(1.4, 0, 0))
	else
		-- Sem pega: o que se ve na mao poe-se a parte, preso a mao (equip).
		tool.RequiresHandle = false
	end

	if PYRO[kind] then
		tool.Equipped:Connect(function()
			equip(tool, kind, teamId)
		end)
	end
	tool.Unequipped:Connect(function()
		unequip(player, tool)
	end)
	tool.Activated:Connect(function()
		activate(player, tool, kind)
	end)
	return tool
end

local function has(player: Player, tool: Tool?): boolean
	if not tool or not tool.Parent then
		return false
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	return tool.Parent == backpack or tool.Parent == player.Character
end

local function drop(player: Player, kind: string)
	local mine = tools[player]
	local tool = mine and mine[kind]
	if not tool then
		return
	end
	mine[kind] = nil
	unequip(player, tool)
	tool:Destroy()
end

--[[
	Poe na barra de cada um o que lhe cabe, e tira o que ja nao cabe; e o
	cachecol ao pescoco de quem e de claque. Pode ser chamado as vezes que for
	preciso: so mexe no que falta ou esta a mais.
]]
function Gear.sync(player: Player)
	if not player.Parent then
		return
	end
	local teamId = Teams.get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	tools[player] = tools[player] or {}
	local mine = tools[player]
	local touched = false

	local character = player.Character
	if character then
		local scarf = character:FindFirstChild(NECK)
		if scarf and scarf:GetAttribute("Team") ~= teamId then
			scarf:Destroy()
		end
		if teamId and not character:FindFirstChild(NECK) then
			wearScarf(character, Config.Teams[teamId].color)
			local worn = character:FindFirstChild(NECK)
			if worn then
				worn:SetAttribute("Team", teamId)
			end
		end
	end

	for _, kind in ORDER do
		local wanted = teamId ~= nil and (kind ~= "tambor" or Teams.isLeader(player))
		local tool = mine[kind]

		-- Mudou de lado: o material do outro lado tinha a cor errada.
		if tool and tool:GetAttribute("Team") ~= teamId then
			drop(player, kind)
			tool = nil
			touched = true
		end

		if not wanted then
			if tool then
				drop(player, kind)
				touched = true
			end
		elseif not has(player, tool) and backpack and teamId then
			if tool then
				drop(player, kind)
			end
			local fresh = buildTool(player, kind, teamId)
			fresh.Parent = backpack
			mine[kind] = fresh
			touched = true
		end
	end

	if touched then
		announce(player)
	end
end

function Gear.start()
	Teams.onChanged(Gear.sync)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Hold", nil)
			-- O Roblox esvazia a mochila ao renascer; da-se-lhe tempo e volta a encher.
			task.wait(0.5)
			Gear.sync(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)

	-- A rede de seguranca: se algum objecto se perdeu por outro caminho, volta.
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				if Teams.get(player) or tools[player] then
					Gear.sync(player)
				end
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for tool, entry in lit do
			if not tool.Parent then
				lit[tool] = nil
			elseif now >= entry.until_ then
				extinguish(entry)
				shotAt[tool] = nil
			elseif entry.kind == "vela" and now >= (shotAt[tool] or 0) then
				-- Uma bola de fogo de cada vez, pela boca da vela.
				shotAt[tool] = now + 0.8
				local h = held[tool]
				if h then
					fireball(h.tip.Position + Vector3.new(0, 0.6, 0), Config.Teams[entry.teamId].color, workspace)
				end
			end
		end
		for tool in raised do
			if not tool.Parent then
				raised[tool] = nil
			end
		end
		for tool, h in held do
			if not tool.Parent or not h.model.Parent then
				held[tool] = nil
			end
		end
	end)
end

-- Dia de jogo novo: stock cheio outra vez.
function Gear.refill()
	for _, player in Players:GetPlayers() do
		remaining[player] = {}
		nextAllowed[player] = {}
		announce(player)
	end
end

function Gear.forget(player: Player)
	local mine = tools[player]
	if mine then
		for _, kind in ORDER do
			drop(player, kind)
		end
	end
	tools[player] = nil
	remaining[player] = nil
	nextAllowed[player] = nil
end

return Gear
