--!strict
--[[
	As pecas do material de claque que se seguram ou vestem: a tocha, a lata
	de fumo, a vela romana, o estrobo, o tambor e o cachecol ao pescoco.

	E daqui que o jogo (Gear) as faz, e as copias de ServerStorage.Modelos
	tambem: o codigo e a fonte, as copias sao so para ver.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Emblem = require(script.Parent:WaitForChild("Emblem"))

local Material = {}

local WHITE = Color3.fromRGB(240, 240, 240)

-- O angulo do braco com a tocha acesa (o mesmo do Poses.client).
Material.RAISED = math.rad(Config.Poses.raisedArm)

export type Held = {
	model: Model,
	body: BasePart,
	tip: BasePart,
	weld: Weld,
	length: number,
}

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


-- O cachecol ao pescoco: a volta e as duas pontas a cair a frente.
local NECK = "CachecolPescoco"

local function wearScarf(character: Model, colour: Color3, club: any?)
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
	local ring = loosePart("Volta", Vector3.new(1.24, 0.3, 1.12), colour, model)
	ring.Material = Enum.Material.Fabric
	ring.CFrame = torso.CFrame * CFrame.new(0, top - 0.02, 0)
	for _, x in { -0.22, 0.22 } do
		local strip = loosePart("Ponta", Vector3.new(0.3, 0.5, 0.08), colour, model)
		strip.Material = Enum.Material.Fabric
		strip.CFrame = torso.CFrame * CFrame.new(x, top - 0.3, -torso.Size.Z / 2 - 0.1)
		local fringe = loosePart("Franja", Vector3.new(0.31, 0.09, 0.09), WHITE, model)
		weldTo(strip, fringe, CFrame.new(0, -0.25, 0))
		-- The club emblem on one end.
		if club and club.emblem and x < 0 then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Emblema"
			gui.Face = Enum.NormalId.Front
			gui.CanvasSize = Vector2.new(60, 100)
			gui.LightInfluence = 0.7
			gui.Parent = strip
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromOffset(52, 52)
			holder.Position = UDim2.fromOffset(4, 40)
			holder.Parent = gui
			Emblem.draw(holder, club, { simple = true, year = false })
		end
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

-- O tambor: o bombo com a pele da cor da claque. Devolve a pega (Handle).
local function drum(parent: Instance, colour: Color3): BasePart
	local handle = loosePart("Handle", Vector3.new(2.6, 2.2, 2.6), Color3.fromRGB(196, 186, 168), parent)
	handle.Shape = Enum.PartType.Cylinder
	local skin = loosePart("Skin", Vector3.new(0.3, 2.3, 2.3), colour, parent)
	skin.Shape = Enum.PartType.Cylinder
	weldTo(handle, skin, CFrame.new(1.4, 0, 0))
	return handle
end

-- Como o tambor vai preso (a pega de um Tool): deitado, a tiracolo.
Material.DRUM_GRIP = CFrame.new(0, -1.4, 0) * CFrame.Angles(0, 0, math.rad(90))

Material.loosePart = loosePart
Material.weldTo = weldTo
Material.stickDirection = stickDirection
Material.gripFor = gripFor
Material.LOW = LOW
Material.handOf = handOf
Material.buildHeld = buildHeld
Material.NECK = NECK
Material.wearScarf = wearScarf

--[[
	THE GEMELLAGGIO SCARF: half in the colours of one club, half in the other's,
	with the two names. One model for every pair: it reads the two clubs.
]]
function Material.wearGemScarf(character: Model, a: any, b: any)
	local old = character:FindFirstChild(NECK)
	if old then
		old:Destroy()
	end
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	local model = Instance.new("Model")
	model.Name = NECK
	model:SetAttribute("Gemellaggio", true)
	local top = torso.Size.Y / 2
	for i, club in { a, b } do
		local side = if i == 1 then -1 else 1
		local half = loosePart("Volta", Vector3.new(0.62, 0.3, 1.12), club.color, model)
		half.Material = Enum.Material.Fabric
		half.CFrame = torso.CFrame * CFrame.new(side * 0.31, top - 0.02, 0)
		local strip = loosePart("Ponta", Vector3.new(0.3, 0.5, 0.08), club.color, model)
		strip.Material = Enum.Material.Fabric
		strip.CFrame = torso.CFrame * CFrame.new(side * 0.22, top - 0.3, -torso.Size.Z / 2 - 0.1)
		local fringe = loosePart("Franja", Vector3.new(0.31, 0.09, 0.09), WHITE, model)
		weldTo(strip, fringe, CFrame.new(0, -0.25, 0))
		if club.emblem then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Emblema"
			gui.Face = Enum.NormalId.Front
			gui.CanvasSize = Vector2.new(60, 100)
			gui.LightInfluence = 0.7
			gui.Parent = strip
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromOffset(52, 52)
			holder.Position = UDim2.fromOffset(4, 40)
			holder.Parent = gui
			Emblem.draw(holder, club, { simple = true, year = false })
		end
	end
	-- The two names across the chest, on the scarf.
	local plate = loosePart("Nomes", Vector3.new(1.3, 0.24, 0.05), Color3.fromRGB(20, 20, 24), model)
	plate.CFrame = torso.CFrame * CFrame.new(0, top - 0.02, -0.6)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(390, 72)
	gui.LightInfluence = 0.7
	gui.AutoLocalize = false
	gui.Parent = plate
	local words = Instance.new("TextLabel")
	words.BackgroundTransparency = 1
	words.Size = UDim2.fromScale(1, 1)
	words.Font = Enum.Font.GothamBlack
	words.TextScaled = true
	words.TextColor3 = WHITE
	words.Text = a.short .. "  ·  " .. b.short
	words.Parent = gui
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
Material.drum = drum

return Material
