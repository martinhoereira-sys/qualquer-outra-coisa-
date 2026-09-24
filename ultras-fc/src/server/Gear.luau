--!strict
--[[
	O material de claque: tochas, bombas de fumo, cachecol e, para o lider, o
	tambor.

	E a imagem do jogo. Uma bancada as escuras e um ponto de luz a arder no
	meio dela, o fumo a encher o topo e a ver-se do outro lado do campo. Por
	isso e o servidor que as acende: uma tocha que so quem a acendeu visse nao
	servia de nada.

	Esta sempre na barra de baixo de quem e de claque, desde que escolhe o
	lado: nada de ir a uma caixa buscar. Quem nao e de claque nao tem nada.
	Acender gasta um do stock do jogo (ou nada, com Config.GearStock.unlimited),
	e o objecto fica na mao, apagado, pronto para o proximo.

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

local Gear = {}

local KINDS = Config.Gear

-- A ordem na barra: 1 tocha, 2 fumo, 3 cachecol, 4 tambor.
local ORDER = { "tocha", "fumo", "cachecol", "tambor" }

local LABEL: { [string]: string } = {
	tocha = "Tocha",
	fumo = "Fumo",
	cachecol = "Cachecol",
	tambor = "Tambor",
}

-- As texturas de fogo, fumo e faiscas que vem com o proprio Roblox.
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local HOT = Color3.fromRGB(255, 244, 214) -- o branco do centro de uma chama

-- Contagens por tipo: cada material tem o seu stock e a sua espera.
local remaining: { [Player]: { [string]: number } } = {}
local nextAllowed: { [Player]: { [string]: number } } = {}

-- O objecto de cada tipo que cada um tem, na barra ou na mao.
local tools: { [Player]: { [string]: Tool } } = {}

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

-- Cachecois no ar, a rodar.
local raised: { [Tool]: { player: Player, teamId: string } } = {}

local onDrumHit: ((Player) -> ())? = nil
local onCountChanged: ((Player, { [string]: number }) -> ())? = nil

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
	return {
		tocha = if Teams.get(player) then Gear.remaining(player, "tocha") else 0,
		fumo = if Teams.get(player) then Gear.remaining(player, "fumo") else 0,
		tambor = if Teams.isLeader(player) then 1 else 0,
	}
end

local function announce(player: Player)
	if onCountChanged then
		onCountChanged(player, Gear.counts(player))
	end
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
	A tocha: uma chama branca e forte no centro, a cor da equipa a volta, um
	halo que se ve de longe, faiscas a saltar e fumo a sair dela.

	As chamas e o fumo sobem por aceleracao, nao pela direcao da ponta: seja
	qual for o angulo da mao, o fogo vai sempre para cima, como um a serio.
]]
local function flareEffects(at: Attachment, colour: Color3)
	local flame = emitter("Chama", FIRE, at)
	flame.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, HOT),
		ColorSequenceKeypoint.new(0.3, colour:Lerp(HOT, 0.45)),
		ColorSequenceKeypoint.new(1, colour),
	})
	flame.LightEmission = 1
	flame.LightInfluence = 0
	flame.Size = curve({ { 0, 1.7 }, { 0.5, 1.1 }, { 1, 0.2 } })
	flame.Transparency = curve({ { 0, 0 }, { 0.7, 0.35 }, { 1, 1 } })
	flame.Lifetime = NumberRange.new(0.25, 0.5)
	flame.Rate = 80
	flame.Speed = NumberRange.new(1, 3)
	flame.SpreadAngle = Vector2.new(25, 25)
	flame.Acceleration = Vector3.new(0, 16, 0)
	flame.RotSpeed = NumberRange.new(-140, 140)

	-- O halo: e ele que faz a tocha ver-se do outro lado do estadio.
	local glow = emitter("Halo", FIRE, at)
	glow.Color = ColorSequence.new(colour:Lerp(HOT, 0.2))
	glow.LightEmission = 1
	glow.LightInfluence = 0
	glow.Size = curve({ { 0, 5 }, { 1, 6.5 } })
	glow.Transparency = curve({ { 0, 0.55 }, { 1, 1 } })
	glow.Lifetime = NumberRange.new(0.12, 0.2)
	glow.Rate = 30
	glow.Speed = NumberRange.new(0, 0)

	local sparks = emitter("Faiscas", SPARK, at)
	sparks.Color = ColorSequence.new(HOT, colour:Lerp(HOT, 0.5))
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = curve({ { 0, 0.35 }, { 1, 0 } })
	sparks.Lifetime = NumberRange.new(0.4, 0.9)
	sparks.Rate = 40
	sparks.Speed = NumberRange.new(6, 13)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -22, 0)
	sparks.Drag = 1

	local smoke = emitter("Fumo", SMOKE, at)
	smoke.Color = ColorSequence.new(colour:Lerp(Color3.fromRGB(210, 210, 210), 0.45), Color3.fromRGB(170, 170, 175))
	smoke.LightEmission = 0.15
	smoke.LightInfluence = 0.6
	smoke.Size = curve({ { 0, 1.2 }, { 0.3, 6 }, { 1, 11 } })
	smoke.Transparency = curve({ { 0, 0.35 }, { 0.5, 0.5 }, { 1, 1 } })
	smoke.Lifetime = NumberRange.new(4, 6.5)
	smoke.Rate = 16
	smoke.Speed = NumberRange.new(3, 5)
	smoke.SpreadAngle = Vector2.new(20, 20)
	smoke.Acceleration = Vector3.new(0, 3, 0)
	smoke.Drag = 0.5
	smoke.RotSpeed = NumberRange.new(-30, 30)
end

--[[
	A bomba de fumo: uma nuvem grossa, da cor da equipa, que sai com forca,
	abre, sobe devagar e fica no ar. Tem de encher o topo e ver-se do outro
	lado do campo.
]]
local function smokeEffects(at: Attachment, colour: Color3)
	local plume = emitter("Nuvem", SMOKE, at)
	plume.Color = ColorSequence.new(colour:Lerp(Color3.new(1, 1, 1), 0.08), colour:Lerp(Color3.new(1, 1, 1), 0.3))
	plume.LightEmission = 0.1
	plume.LightInfluence = 0.7
	plume.Size = curve({ { 0, 2 }, { 0.15, 9 }, { 1, 19 } })
	plume.Transparency = curve({ { 0, 0.05 }, { 0.6, 0.2 }, { 1, 1 } })
	plume.Lifetime = NumberRange.new(7, 11)
	plume.Rate = if smokesBurning() >= Config.Performance.maxSmokes then 13 else 26
	plume.Speed = NumberRange.new(7, 11)
	plume.SpreadAngle = Vector2.new(22, 22)
	plume.Acceleration = Vector3.new(0, 1.2, 0)
	plume.Drag = 0.5
	plume.RotSpeed = NumberRange.new(-25, 25)

	-- O jacto a sair da lata, com a cor viva, antes de abrir em nuvem.
	local jet = emitter("Jacto", SMOKE, at)
	jet.Color = ColorSequence.new(colour)
	jet.LightEmission = 0.3
	jet.LightInfluence = 0.5
	jet.Size = curve({ { 0, 0.8 }, { 1, 4 } })
	jet.Transparency = curve({ { 0, 0 }, { 1, 1 } })
	jet.Lifetime = NumberRange.new(0.6, 1)
	jet.Rate = 30
	jet.Speed = NumberRange.new(10, 14)
	jet.SpreadAngle = Vector2.new(10, 10)
end

--------------------------------------------------------------------------------
-- O objecto
--------------------------------------------------------------------------------

local function weldTo(handle: BasePart, piece: BasePart, offset: CFrame)
	-- Primeiro no sitio, depois a solda: soldar antes deixava a ponta presa
	-- dentro do cabo, que era onde a tocha acabava escondida.
	piece.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.Parent = handle
end

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

local function buildTool(kind: string, colour: Color3): Tool
	local tool = Instance.new("Tool")
	tool.Name = LABEL[kind]
	tool.ToolTip = LABEL[kind]
	tool:SetAttribute("Kind", kind)
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	-- Com pega, o Roblox poe sozinho a pose de segurar: o braco sobe e a mao
	-- fecha-se no cabo, sem ser preciso animacao nenhuma.
	tool.Grip = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-20), 0, 0)

	local handle = loosePart("Handle", Vector3.new(0.35, 1.8, 0.35), Color3.fromRGB(26, 26, 29), tool)

	if kind == "tambor" then
		handle.Size = Vector3.new(2.6, 2.2, 2.6)
		handle.Shape = Enum.PartType.Cylinder
		handle.Color = Color3.fromRGB(196, 186, 168)
		-- Deitado e a tiracolo, como se leva um bombo.
		tool.Grip = CFrame.new(0, -1.4, 0) * CFrame.Angles(0, 0, math.rad(90))

		local skin = loosePart("Skin", Vector3.new(0.3, 2.3, 2.3), colour, tool)
		skin.Shape = Enum.PartType.Cylinder
		weldTo(handle, skin, CFrame.new(1.4, 0, 0))
	elseif kind == "cachecol" then
		-- Uma tira comprida da cor da equipa, com as pontas brancas.
		handle.Size = Vector3.new(0.25, 5, 0.9)
		handle.Color = colour
		handle.Material = Enum.Material.Fabric
		tool.Grip = CFrame.new(0, -2.1, 0)
		for _, y in { 2.2, -2.2 } do
			local tip = loosePart("Ponta", Vector3.new(0.27, 0.6, 0.92), Color3.fromRGB(240, 240, 240), tool)
			tip.Material = Enum.Material.Fabric
			weldTo(handle, tip, CFrame.new(0, y, 0))
		end
	else
		if kind == "fumo" then
			-- Uma lata, mais grossa e mais curta do que uma tocha.
			handle.Size = Vector3.new(0.6, 1.3, 0.6)
			handle.Color = Color3.fromRGB(46, 48, 54)
			local band = loosePart("Banda", Vector3.new(0.62, 0.4, 0.62), colour, tool)
			weldTo(handle, band, CFrame.new(0, 0.1, 0))
		end

		local tip = loosePart("Tip", Vector3.new(0.42, 0.3, 0.42), colour, tool)
		tip.Material = Enum.Material.Neon
		tip.Transparency = 1 -- so acende quando for acesa
		weldTo(handle, tip, CFrame.new(0, handle.Size.Y / 2 + 0.12, 0))
	end

	return tool
end

local function ignite(player: Player, tool: Tool, kind: string, teamId: string)
	local tip = tool:FindFirstChild("Tip") :: BasePart?
	if not tip then
		return
	end

	local colour = Config.Teams[teamId].color
	tip.Color = colour
	tip.Transparency = 0

	-- Os efeitos novos de cada vez: os do acendimento anterior ainda se estao a
	-- desfazer no ar, e ficam la ate acabarem.
	local effects = Instance.new("Attachment")
	effects.Name = "Aceso"
	effects.Parent = tip

	if kind == "tocha" then
		flareEffects(effects, colour)
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
	if litCount() >= Config.Performance.maxLights then
		return
	end
	local light = Instance.new("PointLight")
	light.Brightness = if kind == "tocha" then 8 else 3
	light.Range = if kind == "tocha" then 34 else 24
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
	task.delay(12, function()
		effects:Destroy()
	end)
	local tip = entry.tool:FindFirstChild("Tip") :: BasePart?
	if tip then
		tip.Transparency = 1
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

	-- O cachecol levanta-se e baixa-se.
	if kind == "cachecol" then
		if raised[tool] then
			raised[tool] = nil
			tool.Grip = CFrame.new(0, -2.1, 0)
		else
			raised[tool] = { player = player, teamId = teamId }
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
		return
	end

	spend(player, kind)
	nextAllowed[player] = nextAllowed[player] or {}
	nextAllowed[player][kind] = os.clock() + KINDS[kind].duration + KINDS[kind].cooldown
	ignite(player, tool, kind, teamId)
	announce(player)
end

--------------------------------------------------------------------------------
-- Quem tem o que
--------------------------------------------------------------------------------

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
	local entry = lit[tool]
	if entry then
		extinguish(entry)
	end
	raised[tool] = nil
	tool:Destroy()
end

--[[
	Poe na barra de cada um o que lhe cabe, e tira o que ja nao cabe. Pode ser
	chamado as vezes que for preciso: so mexe no que falta ou esta a mais.
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
			local fresh = buildTool(kind, Config.Teams[teamId].color)
			fresh:SetAttribute("Team", teamId)
			fresh.Activated:Connect(function()
				activate(player, fresh, kind)
			end)
			fresh.Parent = backpack
			mine[kind] = fresh
			touched = true
		end
	end

	if touched then
		announce(player)
	end
end

--[[
	Enquanto arde, o material balanca na mao; o cachecol no ar roda. E
	movimento a serio sem animacao carregada: mexer o Grip mexe o objecto
	dentro da mao, e e isso que se ve da outra ponta do estadio.
]]
local function sway(tool: Tool, now: number)
	local t = now * 5.5
	tool.Grip = CFrame.new(math.sin(t) * 0.12, -0.4, 0)
		* CFrame.Angles(math.rad(-20) + math.sin(t) * 0.35, math.sin(t * 0.7) * 0.25, math.cos(t) * 0.2)
end

local function twirl(tool: Tool, now: number)
	tool.Grip = CFrame.new(0, -2.1, 0) * CFrame.Angles(0, now * 9, math.sin(now * 9) * 0.5)
end

function Gear.start()
	Teams.onChanged(Gear.sync)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
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
				if Teams.get(player) then
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
				tool.Grip = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-20), 0, 0)
			else
				sway(tool, now)
			end
		end
		for tool in raised do
			if not tool.Parent then
				raised[tool] = nil
			else
				twirl(tool, now)
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
