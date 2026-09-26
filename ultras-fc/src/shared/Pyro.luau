--!strict
--[[
	A pirotecnia: como e uma tocha e uma bomba de fumo acesas.

	Serve o servidor (o material das pessoas, Gear) e os ecras (as tochas dos
	bonecos). Assim uma tocha e igual na mao de quem for.

	A TOCHA (como nas bancadas a serio)
	- um nucleo branco-quente colado a ponta e a chama da cor da claque a volta;
	- um halo largo e uma luz forte: ve-se do outro lado do estadio;
	- faiscas e escorias a cair da ponta, com peso;
	- um rolo de fumo denso sempre a sair, que sobe e se abre;
	- no fim nao se apaga de repente: `fade` baixa chama, luz e faiscas aos
	  poucos, e o fumo ainda sai um bocado depois da chama morrer.

	O FUMO
	- sai com forca da lata (o jacto) nos primeiros segundos;
	- depois abre numa nuvem enorme que tapa quem esta a volta, sobe acima do
	  telhado e fica no ar muito tempo, a desfazer-se devagar;
	- varias ao mesmo tempo juntam-se numa so: a bancada fica tapada.

	O LIMITE
	No jogo a serio nao ha limite nenhum. `Config.Performance.studioBaixo`
	so conta dentro do Studio (RunService:IsStudio()), para as maquinas
	fracas de quem testa: menos luzes e metade das particulas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Pyro = {}

-- Texturas: imagens de pirotecnia da Toolbox (so as imagens) e as do Roblox.
local FIRE = "rbxassetid://4753372559"
local GLOW = "rbxassetid://6673021984"
local SPARK = "rbxassetid://10822615828"
local SMOKE = "rbxassetid://9013694245"
local BASE_FIRE = "rbxasset://textures/particles/fire_main.dds"
local BASE_SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local HOT = Color3.fromRGB(255, 244, 214)
local GREY = Color3.fromRGB(205, 202, 198)

export type Limits = {
	maxLights: number,
	maxSmokes: number,
	particles: number, -- multiplica todas as taxas (1 = tudo)
}

local FULL: Limits = { maxLights = math.huge, maxSmokes = math.huge, particles = 1 }

-- O limite que vale aqui: nenhum no jogo, o modo baixo so no Studio.
function Pyro.limits(): Limits
	local P = Config.Performance
	if P.studioBaixo and RunService:IsStudio() then
		return P.baixo
	end
	return FULL
end

local function curve(points: { { number } }): NumberSequence
	local keys = {}
	for _, point in points do
		table.insert(keys, NumberSequenceKeypoint.new(point[1], point[2]))
	end
	return NumberSequence.new(keys)
end

local function emitter(name: string, texture: string, parent: Instance, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = texture
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = rate * Pyro.limits().particles
	-- A taxa cheia, para o `fade` saber de onde baixar.
	e:SetAttribute("FullRate", e.Rate)
	e.Parent = parent
	return e
end

-- Aumenta tudo o que e tamanho (a tocha grande do nivel de adepto).
function Pyro.scale(at: Instance, by: number)
	for _, e in at:GetChildren() do
		if e:IsA("ParticleEmitter") then
			local keys = {}
			for _, k in e.Size.Keypoints do
				table.insert(keys, NumberSequenceKeypoint.new(k.Time, k.Value * by, k.Envelope * by))
			end
			e.Size = NumberSequence.new(keys)
		elseif e:IsA("PointLight") then
			e.Range = math.min(e.Range * by, 60)
		end
	end
end

--[[
	A luz de uma tocha ou fumo. `count` e quantas ja estao acesas (quem chama
	e que conta); passado o limite, nao se poe luz, e a chama chega.
]]
function Pyro.light(at: Instance, colour: Color3, brightness: number, range: number, count: number): PointLight?
	if count >= Pyro.limits().maxLights then
		return nil
	end
	local light = Instance.new("PointLight")
	light.Name = "Luz"
	light.Brightness = brightness
	light.Range = range
	light.Color = colour:Lerp(HOT, 0.25)
	-- Sombras de uma luz pequena sao das coisas mais caras que ha.
	light.Shadows = false
	light:SetAttribute("FullBrightness", brightness)
	light.Parent = at
	return light
end

--[[
	A tocha. `at` e o Attachment na ponta. O fogo sobe por aceleracao, seja
	qual for o angulo da mao.
]]
function Pyro.flare(at: Attachment, colour: Color3)
	-- O nucleo: branco-quente, pequeno e muito vivo, colado a ponta.
	local core = emitter("Nucleo", FIRE, at, 90)
	core.Color = ColorSequence.new(Color3.new(1, 1, 1), HOT)
	core.LightEmission = 1
	core.LightInfluence = 0
	core.Brightness = 3
	core.Size = curve({ { 0, 0.8 }, { 1, 0.35 } })
	core.Transparency = curve({ { 0, 0 }, { 1, 0.85 } })
	core.Lifetime = NumberRange.new(0.06, 0.12)
	core.Speed = NumberRange.new(0, 0.4)

	-- A chama: da cor da claque, com o centro quase branco, a tremer e a subir.
	local flame = emitter("Chama", BASE_FIRE, at, 70)
	flame.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, HOT),
		ColorSequenceKeypoint.new(0.25, colour:Lerp(HOT, 0.4)),
		ColorSequenceKeypoint.new(1, colour),
	})
	flame.LightEmission = 1
	flame.LightInfluence = 0
	flame.Brightness = 2
	flame.Size = curve({ { 0, 1.5 }, { 0.45, 1.1 }, { 1, 0.2 } })
	flame.Transparency = curve({ { 0, 0 }, { 0.7, 0.25 }, { 1, 1 } })
	flame.Lifetime = NumberRange.new(0.25, 0.5)
	flame.Speed = NumberRange.new(1, 3)
	flame.SpreadAngle = Vector2.new(20, 20)
	flame.Acceleration = Vector3.new(0, 14, 0)
	flame.RotSpeed = NumberRange.new(-160, 160)

	-- O halo largo, a pulsar: e o que se le do outro lado do estadio.
	local glow = emitter("Halo", GLOW, at, 26)
	glow.Color = ColorSequence.new(colour:Lerp(HOT, 0.35))
	glow.LightEmission = 1
	glow.LightInfluence = 0
	glow.Brightness = 2
	glow.Size = curve({ { 0, 4.5 }, { 1, 6 } })
	glow.Transparency = curve({ { 0, 0.55 }, { 1, 1 } })
	glow.Lifetime = NumberRange.new(0.1, 0.22)
	glow.Speed = NumberRange.new(0, 0)

	-- Faiscas e escorias a cair: saltam da ponta e pingam com peso.
	local sparks = emitter("Faiscas", SPARK, at, 40)
	sparks.Color = ColorSequence.new(HOT, colour:Lerp(HOT, 0.5))
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = curve({ { 0, 0.14 }, { 1, 0 } })
	sparks.Lifetime = NumberRange.new(0.6, 1.3)
	sparks.Speed = NumberRange.new(3, 9)
	sparks.SpreadAngle = Vector2.new(85, 85)
	sparks.Acceleration = Vector3.new(0, -34, 0)
	sparks.Drag = 0.6

	local drips = emitter("Escorias", SPARK, at, 8)
	drips.Color = ColorSequence.new(HOT, Color3.fromRGB(255, 150, 60))
	drips.LightEmission = 1
	drips.LightInfluence = 0
	drips.Size = curve({ { 0, 0.22 }, { 1, 0.05 } })
	drips.Lifetime = NumberRange.new(0.8, 1.2)
	drips.Speed = NumberRange.new(0, 1)
	drips.Acceleration = Vector3.new(0, -40, 0)

	-- O fumo da tocha: denso e sem parar, claro com um toque da cor.
	local smoke = emitter("Fumo", SMOKE, at, 18)
	smoke.Color = ColorSequence.new(colour:Lerp(GREY, 0.55), GREY)
	smoke.LightEmission = 0.1
	smoke.LightInfluence = 0.7
	smoke.Size = curve({ { 0, 1.2 }, { 0.25, 5 }, { 1, 13 } })
	smoke.Transparency = curve({ { 0, 0.3 }, { 0.5, 0.5 }, { 1, 1 } })
	smoke.Lifetime = NumberRange.new(6, 9)
	smoke.Speed = NumberRange.new(3, 5)
	smoke.SpreadAngle = Vector2.new(18, 18)
	smoke.Acceleration = Vector3.new(0, 2.5, 0)
	smoke.Drag = 0.35
	smoke.RotSpeed = NumberRange.new(-25, 25)
end

--[[
	A bomba de fumo. Comeca com o jacto a sair com forca; `Pyro.settle`
	(chamado uns segundos depois) baixa o jacto e deixa a nuvem a crescer.
]]
function Pyro.smoke(at: Attachment, colour: Color3)
	local lighter = colour:Lerp(Color3.new(1, 1, 1), 0.3)

	-- O jacto: cor viva, rapido, a sair da lata.
	local jet = emitter("Jacto", SMOKE, at, 34)
	jet.Color = ColorSequence.new(colour, lighter)
	jet.LightEmission = 0.15
	jet.LightInfluence = 0.6
	jet.Size = curve({ { 0, 0.8 }, { 1, 6 } })
	jet.Transparency = curve({ { 0, 0.05 }, { 0.7, 0.3 }, { 1, 1 } })
	jet.Lifetime = NumberRange.new(0.9, 1.4)
	jet.Speed = NumberRange.new(14, 20)
	jet.SpreadAngle = Vector2.new(12, 12)
	jet.Drag = 1.6

	-- A nuvem: particulas enormes e lentas, que abrem para os lados, sobem
	-- acima do telhado e ficam no ar muito tempo.
	local cloud = emitter("Nuvem", SMOKE, at, 11)
	cloud.Color = ColorSequence.new(colour:Lerp(Color3.new(1, 1, 1), 0.08), lighter)
	cloud.LightEmission = 0.05
	cloud.LightInfluence = 0.8
	cloud.Size = curve({ { 0, 4 }, { 0.15, 14 }, { 0.6, 26 }, { 1, 34 } })
	cloud.Transparency = curve({ { 0, 0.1 }, { 0.55, 0.2 }, { 0.85, 0.55 }, { 1, 1 } })
	cloud.Lifetime = NumberRange.new(18, 26)
	cloud.Speed = NumberRange.new(6, 12)
	cloud.SpreadAngle = Vector2.new(70, 70)
	cloud.Acceleration = Vector3.new(0, 1.6, 0)
	cloud.Drag = 0.45
	cloud.RotSpeed = NumberRange.new(-12, 12)

	-- O rolo baixo, que tapa as pessoas a volta de quem acendeu.
	local low = emitter("Rolo", BASE_SMOKE, at, 9)
	low.Color = ColorSequence.new(lighter)
	low.LightEmission = 0.05
	low.LightInfluence = 0.8
	low.Size = curve({ { 0, 3 }, { 0.3, 10 }, { 1, 16 } })
	low.Transparency = curve({ { 0, 0.2 }, { 0.6, 0.35 }, { 1, 1 } })
	low.Lifetime = NumberRange.new(9, 13)
	low.Speed = NumberRange.new(4, 8)
	low.SpreadAngle = Vector2.new(180, 20)
	low.Acceleration = Vector3.new(0, 0.4, 0)
	low.Drag = 0.7
end

-- O jacto acaba e a nuvem fica: quem acendeu o fumo chama isto uns segundos depois.
function Pyro.settle(at: Instance)
	local jet = at:FindFirstChild("Jacto")
	if jet and jet:IsA("ParticleEmitter") then
		TweenService:Create(jet, TweenInfo.new(1.5), { Rate = (jet:GetAttribute("FullRate") :: number) * 0.35 }):Play()
	end
end

--[[
	A morrer: tudo o que brilha baixa ate zero em `seconds`. O fumo baixa
	mais devagar e fica a sair metade do tempo a mais: primeiro morre a chama,
	depois o fumo.
]]
function Pyro.fade(at: Instance, seconds: number)
	for _, child in at:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local smoky = child.Name == "Fumo" or child.Name == "Nuvem" or child.Name == "Rolo" or child.Name == "Jacto"
			local info = TweenInfo.new(if smoky then seconds * 1.5 else seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(child, info, { Rate = 0 }):Play()
		elseif child:IsA("PointLight") then
			local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(child, info, { Brightness = 0, Range = child.Range * 0.4 }):Play()
		end
	end
end

-- Quanto tempo o fumo mais lento leva a sumir depois de apagado.
Pyro.LINGER = 28

return Pyro
