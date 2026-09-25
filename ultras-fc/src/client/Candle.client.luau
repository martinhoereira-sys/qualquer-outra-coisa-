--!strict
--[[
	Os tiros das velas romanas, desenhados neste ecra.

	Quem tem uma vela acesa (atributo "Hold" = "vela") dispara bolinhas de luz
	da cor da claque, uma de cada vez, pela ponta da vela, na direcao para
	onde ela aponta. Sobem, abrandam, e apagam-se no ar.

	Sao feitas aqui e nao no servidor porque so aqui a vela esta onde se ve:
	o braco levantado e cada ecra que o poe (Poses.client). O servidor ve o
	braco caido, e dali os tiros saiam do chao.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local EVERY = 0.6 -- segundos entre tiros
local SPEED = 55 -- studs/s a saida
local GRAVITY = 26 -- abranda-as ate se apagarem la em cima
local LIFE = 1.7

local HOT = Color3.fromRGB(255, 244, 214)
local SPARK = "rbxassetid://10822615828"

type Shot = { ball: Part, velocity: Vector3, born: number }

local shots: { Shot } = {}
local nextShot: { [Player]: number } = {}

local folder = Instance.new("Folder")
folder.Name = "TirosDasVelas"
folder.Parent = workspace

local function fire(from: Vector3, direction: Vector3, colour: Color3, now: number)
	local ball = Instance.new("Part")
	ball.Name = "Tiro"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.5, 0.5, 0.5)
	ball.Material = Enum.Material.Neon
	ball.Color = colour:Lerp(HOT, 0.35)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.CFrame = CFrame.new(from)

	-- O rasto: faiscas que ficam para tras a cair.
	local at = Instance.new("Attachment")
	at.Parent = ball
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = SPARK
	trail.Color = ColorSequence.new(HOT, colour)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Size = NumberSequence.new(0.25, 0)
	trail.Lifetime = NumberRange.new(0.25, 0.5)
	trail.Rate = 60
	trail.Speed = NumberRange.new(0, 1.5)
	trail.SpreadAngle = Vector2.new(180, 180)
	trail.Acceleration = Vector3.new(0, -15, 0)
	trail.Parent = at

	ball.Parent = folder
	table.insert(shots, { ball = ball, velocity = direction * SPEED, born = now })
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()

	-- Quem esta com a vela acesa dispara.
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Hold") ~= "vela" then
			nextShot[player] = nil
			continue
		end
		if now < (nextShot[player] or 0) then
			continue
		end
		nextShot[player] = now + EVERY
		local character = player.Character
		local inHand = character and character:FindFirstChild("NaMao")
		local tip = inHand and inHand:FindFirstChild("Ponta") :: BasePart?
		local team = Config.Teams[player:GetAttribute("Team") or ""]
		if tip and team then
			-- Pela boca da vela, para onde ela aponta (quase sempre para o ceu).
			local up = tip.CFrame.UpVector
			local aim = if up.Y > 0.3 then up else Vector3.yAxis
			local wobble = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.12
			fire(tip.Position + aim * 0.4, (aim + wobble).Unit, team.color, now)
		end
	end

	-- Cada tiro sobe, abranda, e apaga-se.
	for i = #shots, 1, -1 do
		local shot = shots[i]
		local age = now - shot.born
		if age >= LIFE then
			shot.ball:Destroy()
			table.remove(shots, i)
		else
			shot.velocity -= Vector3.new(0, GRAVITY * dt, 0)
			shot.ball.CFrame = shot.ball.CFrame + shot.velocity * dt
			shot.ball.Transparency = math.max(0, (age - LIFE * 0.7) / (LIFE * 0.3))
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	nextShot[player] = nil
end)
