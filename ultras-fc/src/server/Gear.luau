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

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Teams = require(script.Parent:WaitForChild("Teams"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Pyro = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pyro"))

-- A vela romana dispara a clique: quantos tiros tem cada uma, e o intervalo minimo.
local CANDLE_SHOTS = 10
local CANDLE_GAP = 0.35
local candleShots: { [Tool]: number } = {}
local candleNext: { [Tool]: number } = {}

local Gear = {}

local KINDS = Config.Gear

-- A ordem na barra: tocha, fumo, vela romana, estrobo, cachecol e (lider) tambor.
local ORDER = { "tocha", "fumo", "vela", "estrobo", "cachecol", "bandeirinha", "bandeira", "tambor" }

-- O que se acende e se segura no ar.
local PYRO: { [string]: boolean } = { tocha = true, fumo = true, vela = true, estrobo = true }

--[[
	As bandeiras: nao se gastam. O pano desenha-o cada ecra (Poses.client, Pano)
	a partir do atributo "Hold"; clicar poe-na a agitar com forca ("Wave").
	A bandeirinha e de toda a gente; a de duas hastes e grande, tem de se ter
	(dealer ou o lider) e quem a segura fica no lugar.
]]
local FLAGS: { [string]: boolean } = { bandeirinha = true, bandeira = true }

local LABEL: { [string]: string } = {
	tocha = "Tocha",
	fumo = "Fumo",
	vela = "Vela",
	estrobo = "Estrobo",
	cachecol = "Cachecol",
	bandeirinha = "Bandeirinha",
	bandeira = "Bandeira",
	tambor = "Tambor",
}

--[[
	As texturas. Tiradas de pirotecnia da Toolbox (bengalas e velas romanas
	feitas para claques): so as imagens, nunca os scripts desses modelos. A
	chama de bengala, o fogo, o brilho, as faiscas e um fumo realista.
]]
local GLOW = "rbxassetid://6673021984"
local SPARK = "rbxassetid://10822615828"
local SMOKE = "rbxassetid://9013694245"
-- O fogo e o fumo do proprio Roblox: a chama da tocha de que se gostou.
local BASE_FIRE = "rbxasset://textures/particles/fire_main.dds"

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
	fadeAt: number, -- daqui ate until_ esta a morrer
	fading: boolean,
	settleAt: number?, -- o fumo: quando acaba o jacto
}

-- O que esta aceso agora, um por objecto: o tambor do lider ja nao tapa a tocha.
local lit: { [Tool]: Lit } = {}

-- Cachecois esticados no ar e bandeiras a agitar.
local raised: { [Tool]: { player: Player, teamId: string, kind: string } } = {}

-- Quem segura a bandeira grande fica no lugar: a velocidade que tinha antes.
local rooted: { [Player]: { walk: number, jump: number } } = {}

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
--[[
	O que os niveis de adepto dao (Progress): mais material por jogo, a tocha
	grande, a vela com mais tiros, e quem fica com o tambor quando nao ha
	lider. Quem liga isto e o Main; sem nada ligado, fica tudo como era.
]]
export type Perks = { bigFlare: boolean, candleShots: number }
local bonusHook: ((Player, string) -> number)? = nil
local perksHook: ((Player) -> Perks)? = nil
local drumHook: ((Player) -> boolean)? = nil
local igniteHook: ((Player, string) -> ())? = nil

function Gear.setBonus(fn: (Player, string) -> number)
	bonusHook = fn
end
function Gear.setPerks(fn: (Player) -> Perks)
	perksHook = fn
end
function Gear.setDrumRule(fn: (Player) -> boolean)
	drumHook = fn
end
-- Chamado sempre que alguem acende alguma coisa.
function Gear.onIgnite(fn: (Player, string) -> ())
	igniteHook = fn
end

-- Tem direito ao tambor: o lider, ou (sem lider) quem o Progress disser.
function Gear.hasDrum(player: Player): boolean
	if Teams.isLeader(player) then
		return true
	end
	local rule = drumHook
	return rule ~= nil and rule(player)
end

function Gear.remaining(player: Player, kind: string): number
	if Config.GearStock.unlimited then
		return -1
	end
	local mine = remaining[player]
	local stock = mine and mine[kind]
	if stock ~= nil then
		return stock
	end
	local bonus = if bonusHook then bonusHook(player, kind) else 0
	return KINDS[kind].perMatch + bonus
end

local function spend(player: Player, kind: string)
	if Config.GearStock.unlimited then
		return
	end
	remaining[player] = remaining[player] or {}
	remaining[player][kind] = Gear.remaining(player, kind) - 1
end

-- O que o rodape do ecra mostra: o stock de cada um, e se tem tambor.
-- A cor escolhida no dealer para este material, ou a da claque.
function Gear.colourFor(player: Player, kind: string, teamId: string): Color3
	local chosen = player:GetAttribute("Cor_" .. kind)
	return if typeof(chosen) == "Color3" then chosen else Config.Teams[teamId].color
end

function Gear.counts(player: Player): { [string]: number }
	local counts: { [string]: number } = {
		tambor = if Gear.hasDrum(player) then 1 else 0,
	}
	for kind in PYRO do
		counts[kind] = if Teams.get(player) then Gear.remaining(player, kind) else 0
	end
	for kind in FLAGS do
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
	if not (PYRO[kind] or FLAGS[kind]) or Config.GearStock.unlimited then
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
			total += KINDS[entry.kind].gainPerSecond
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

-- A tocha e a bomba de fumo sao as da Pyro (as mesmas nas maos dos bonecos).
local function flareEffects(at: Attachment, colour: Color3)
	Pyro.flare(at, colour)
end

--[[
	A vela romana, na mao: arde como uma tocha pequena, com faiscas e fumo a
	sair da boca. As bolinhas que dispara desenha-as cada ecra (Candle.client),
	a partir da ponta tal como ele a ve levantada: o servidor nao ve o braco no
	ar, e dali sairiam do chao.
]]
local function candleEffects(at: Attachment, colour: Color3)
	local flame = emitter("Chama", BASE_FIRE, at)
	flame.Color = ColorSequence.new(HOT, colour)
	flame.LightEmission = 1
	flame.LightInfluence = 0
	flame.Size = curve({ { 0, 0.7 }, { 1, 0.1 } })
	flame.Transparency = curve({ { 0, 0 }, { 1, 1 } })
	flame.Lifetime = NumberRange.new(0.15, 0.3)
	flame.Rate = 40
	flame.Speed = NumberRange.new(0.5, 1.5)
	flame.Acceleration = Vector3.new(0, 10, 0)

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

local function smokeEffects(at: Attachment, colour: Color3)
	Pyro.smoke(at, colour)
end

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

	local colour = Gear.colourFor(player, kind, teamId)
	h.tip.Color = colour
	h.tip.Transparency = 0
	-- Acesa, sobe com o braco e fica de pe.
	h.weld.C0 = gripFor(h, stickDirection(RAISED))
	setHold(player, kind)

	local effects = Instance.new("Attachment")
	effects.Name = "Aceso"
	effects.Position = Vector3.new(0, 0.1, 0)
	effects.Parent = h.tip

	local perks = if perksHook then perksHook(player) else nil
	if igniteHook then
		task.spawn(igniteHook :: (Player, string) -> (), player, kind)
	end
	if kind == "tocha" then
		flareEffects(effects, colour)
		-- A tocha grande (nivel de adepto): chama e brilho maiores.
		if perks and perks.bigFlare then
			Pyro.scale(effects, 1.4)
		end
	elseif kind == "vela" then
		candleEffects(effects, colour)
	elseif kind == "estrobo" then
		strobeEffects(effects)
	else
		smokeEffects(effects, colour)
	end

	local now = os.clock()
	local info = KINDS[kind]
	lit[tool] = {
		player = player,
		tool = tool,
		kind = kind,
		teamId = teamId,
		until_ = now + info.duration,
		effects = effects,
		fadeAt = now + info.duration - (info.fade or 0),
		fading = false,
		settleAt = if info.jet then now + info.jet else nil,
	}

	-- Luz propria: sem limite no jogo; no Studio, so ate ao teto do modo baixo.
	if kind == "estrobo" then
		return
	end
	local flare = kind == "tocha" or kind == "vela"
	local light = Pyro.light(effects, colour, if flare then 5 else 1.8, if flare then 28 else 18, litCount())
	if light then
		lights[light] = true
	end
end

-- Apaga: deixa de sair fogo e fumo, e o que ja saiu desfaz-se no ar.
local function extinguish(entry: Lit)
	lit[entry.tool] = nil
	local effects = entry.effects
	-- A chama e a luz acabam; o fumo que ainda sai morre devagar (Pyro.fade).
	if not entry.fading then
		Pyro.fade(effects, 1.5)
	end
	for _, child in effects:GetChildren() do
		if child:IsA("PointLight") then
			child:Destroy()
		elseif child:IsA("ParticleEmitter") and child.Name ~= "Fumo" and child.Name ~= "Nuvem" and child.Name ~= "Rolo" then
			child.Enabled = false
		end
	end
	-- O fumo mais lento ainda leva muito tempo a sumir no ar.
	task.delay(Pyro.LINGER, function()
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

--[[
	A bandeira na mao: o "Hold" diz a todos os ecras para a desenharem. A
	grande prende quem a segura ao sitio (e pesada, e agita-se parado).
]]
local function raiseFlag(player: Player, kind: string)
	setHold(player, kind)
	player:SetAttribute("Wave", nil)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if kind == "bandeira" and humanoid and not rooted[player] then
		rooted[player] = { walk = humanoid.WalkSpeed, jump = humanoid.JumpHeight }
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
	end
end

local function lowerFlag(player: Player, kind: string)
	if player:GetAttribute("Hold") == kind then
		setHold(player, nil)
	end
	player:SetAttribute("Wave", nil)
	local before = rooted[player]
	rooted[player] = nil
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if before and humanoid then
		humanoid.WalkSpeed = if before.walk > 0 then before.walk else 16
		humanoid.JumpHeight = if before.jump > 0 then before.jump else 7.2
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
	local kind = tool:GetAttribute("Kind")
	if type(kind) == "string" and FLAGS[kind] then
		lowerFlag(player, kind)
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
	-- De bicicleta as maos estao no guiador: nada se acende nem se bate.
	if not teamId or player:GetAttribute("Riding") then
		return
	end

	-- O tambor bate-se as vezes que forem precisas.
	if kind == "tambor" then
		if onDrumHit then
			onDrumHit(player)
		end
		return
	end

	-- A bandeira: clicar agita-a com forca; outra vez, volta a so a segurar.
	if FLAGS[kind] then
		if raised[tool] then
			raised[tool] = nil
			player:SetAttribute("Wave", nil)
		else
			raised[tool] = { player = player, teamId = teamId, kind = kind }
			player:SetAttribute("Wave", true)
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
			raised[tool] = { player = player, teamId = teamId, kind = "cachecol" }
			setHold(player, "cachecol")
			showScarf(player.Character, false)
		end
		return
	end

	--[[
		A vela acesa dispara uma bola de fogo por clique, pela ponta. Quem a
		desenha e cada ecra (Candle.client), a partir da ponta como a ve; aqui
		conta-se so os tiros. Acabados, a vela apaga-se.
	]]
	local burning = lit[tool]
	if burning then
		if kind == "vela" and os.clock() >= (candleNext[tool] or 0) then
			candleNext[tool] = os.clock() + CANDLE_GAP
			local perks = if perksHook then perksHook(player) else nil
			local shots = if perks then perks.candleShots else CANDLE_SHOTS
			candleShots[tool] = (candleShots[tool] or shots) - 1
			Remotes.Candle:FireAllClients(player)
			if candleShots[tool] <= 0 then
				candleShots[tool] = nil
				extinguish(burning)
			end
		end
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
	elseif FLAGS[kind] then
		tool.Equipped:Connect(function()
			raiseFlag(player, kind)
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
		-- A bandeira grande so aparece a quem tem uma (dealer ou lider).
		local wanted = teamId ~= nil
			and (kind ~= "tambor" or Gear.hasDrum(player))
			and (kind ~= "bandeira" or Gear.remaining(player, kind) ~= 0)
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
			player:SetAttribute("Wave", nil)
			rooted[player] = nil
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
			else
				if entry.settleAt and now >= entry.settleAt then
					entry.settleAt = nil
					Pyro.settle(entry.effects)
				end
				if not entry.fading and now >= entry.fadeAt then
					-- A morrer: nao se apaga de repente.
					entry.fading = true
					Pyro.fade(entry.effects, entry.until_ - now)
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
	rooted[player] = nil
end

return Gear
