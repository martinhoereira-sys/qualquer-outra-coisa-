--!strict
--[[
	Os tiros das velas romanas, desenhados neste ecra.

	Cada clique de quem tem a vela acesa (o servidor avisa: Remotes.Candle)
	dispara uma bola de fogo pela ponta da vela, para onde ela aponta: um
	clarao e fumo na boca, e a bola a subir com rasto de faiscas, a abrandar
	e a apagar-se la em cima.

	Sao feitas aqui e nao no servidor porque so aqui a vela esta onde se ve:
	o braco levantado e cada ecra que o poe (Poses.client). O servidor ve o
	braco caido, e dali os tiros saiam do chao.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local SPEED = 70 -- studs/s a saida
local GRAVITY = 24 -- abranda-a ate se apagar la em cima
local LIFE = 2

local HOT = Color3.fromRGB(255, 244, 214)
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxassetid://10822615828"
local GLOW = "rbxassetid://6673021984"

type Shot = { ball: Part, velocity: Vector3, born: number }

local shots: { Shot } = {}

local folder = Instance.new("Folder")
folder.Name = "TirosDasVelas"
folder.Parent = workspace

local function curve(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

local function emitter(texture: string, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.LightInfluence = 0
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = parent
	return e
end

-- O clarao e a nuvem de fumo na boca da vela, no instante do tiro.
local function muzzle(at: Vector3, colour: Color3)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(at)
	holder.Parent = folder
	local a = Instance.new("Attachment")
	a.Parent = holder

	local flash = emitter(GLOW, a)
	flash.Color = ColorSequence.new(colour:Lerp(HOT, 0.4))
	flash.LightEmission = 1
	flash.Size = curve(3, 5)
	flash.Transparency = curve(0.2, 1)
	flash.Lifetime = NumberRange.new(0.12, 0.18)
	flash.Speed = NumberRange.new(0, 0)
	flash.Enabled = false
	flash:Emit(2)

	local puff = emitter(SMOKE, a)
	puff.Color = ColorSequence.new(Color3.fromRGB(215, 212, 208))
	puff.LightInfluence = 0.7
	puff.Size = curve(1, 4)
	puff.Transparency = curve(0.4, 1)
	puff.Lifetime = NumberRange.new(1.2, 2)
	puff.Speed = NumberRange.new(1, 3)
	puff.SpreadAngle = Vector2.new(60, 60)
	puff.Acceleration = Vector3.new(0, 3, 0)
	puff.Enabled = false
	puff:Emit(6)

	task.delay(2.5, function()
		holder:Destroy()
	end)
end

local function fireball(from: Vector3, direction: Vector3, colour: Color3)
	local ball = Instance.new("Part")
	ball.Name = "BolaDeFogo"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.45, 0.45, 0.45)
	ball.Material = Enum.Material.Neon
	ball.Color = HOT
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.CFrame = CFrame.new(from)

	local a = Instance.new("Attachment")
	a.Parent = ball

	-- A chama a volta do nucleo: e ela que faz disto uma bola de fogo.
	local flame = emitter(FIRE, a)
	flame.Color = ColorSequence.new(HOT, colour)
	flame.LightEmission = 1
	flame.Size = curve(1.6, 0.4)
	flame.Transparency = curve(0, 1)
	flame.Lifetime = NumberRange.new(0.12, 0.22)
	flame.Rate = 90
	flame.Speed = NumberRange.new(0, 1)
	flame.RotSpeed = NumberRange.new(-200, 200)

	-- O brilho, para se ver de longe e de noite.
	local glow = emitter(GLOW, a)
	glow.Color = ColorSequence.new(colour:Lerp(HOT, 0.3))
	glow.LightEmission = 1
	glow.Size = curve(2.2, 2.2)
	glow.Transparency = curve(0.55, 1)
	glow.Lifetime = NumberRange.new(0.08, 0.12)
	glow.Rate = 30
	glow.Speed = NumberRange.new(0, 0)

	-- O rasto: faiscas que ficam para tras a cair.
	local trail = emitter(SPARK, a)
	trail.Color = ColorSequence.new(HOT, colour)
	trail.LightEmission = 1
	trail.Size = curve(0.18, 0)
	trail.Lifetime = NumberRange.new(0.35, 0.7)
	trail.Rate = 70
	trail.Speed = NumberRange.new(0, 2)
	trail.SpreadAngle = Vector2.new(180, 180)
	trail.Acceleration = Vector3.new(0, -18, 0)

	ball.Parent = folder
	table.insert(shots, { ball = ball, velocity = direction * SPEED, born = os.clock() })
end

Remotes.Candle.OnClientEvent:Connect(function(shooter)
	if typeof(shooter) ~= "Instance" or not shooter:IsA("Player") then
		return
	end
	local character = shooter.Character
	local inHand = character and character:FindFirstChild("NaMao")
	local tip = inHand and inHand:FindFirstChild("Ponta") :: BasePart?
	local team = Config.Teams[shooter:GetAttribute("Team") or ""]
	if not tip or not team then
		return
	end
	-- A cor escolhida no dealer, se houver; senao a da claque.
	local chosen = shooter:GetAttribute("Cor_vela")
	local colour = if typeof(chosen) == "Color3" then chosen else team.color
	-- Pela boca da vela, para onde ela aponta (quase sempre para o ceu).
	local up = tip.CFrame.UpVector
	local aim = if up.Y > 0.3 then up else Vector3.yAxis
	local wobble = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.08
	local mouth = tip.Position + aim * 0.3
	muzzle(mouth, colour)
	fireball(mouth, (aim + wobble).Unit, colour)
end)

-- Cada bola sobe, abranda, e apaga-se la em cima.
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for i = #shots, 1, -1 do
		local shot = shots[i]
		local age = now - shot.born
		if age >= LIFE then
			shot.ball:Destroy()
			table.remove(shots, i)
		else
			shot.velocity -= Vector3.new(0, GRAVITY * dt, 0)
			shot.ball.CFrame = shot.ball.CFrame + shot.velocity * dt
			-- A apagar-se no ultimo terco.
			local fade = math.clamp((age - LIFE * 0.65) / (LIFE * 0.35), 0, 1)
			shot.ball.Transparency = fade
			for _, e in shot.ball:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					e.Enabled = fade < 0.9
				end
			end
		end
	end
end)
