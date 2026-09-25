--!strict
--[[
	O que o jogador ve e carrega.

	Segurar carrega a forca, largar chuta. Um toque e um passe, carregado a fundo
	e um remate — a forca e de quem chuta.

	Clique esquerdo: chuta direito, e o rato fica livre para virar a camara e
	apontar. Clique direito: enquanto se segura, mexer o rato da o efeito (para
	os lados) e a altura (para cima, chapeu; para baixo, rasteira). Shift e
	correr.

	Aqui so ha input e barras. Quem tem a bola, para onde ela vai e se o remate
	conta e tudo decidido no servidor.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local F = Config.Football
local player = Players.LocalPlayer

local TEXT = Color3.fromRGB(232, 234, 237)
local MUTED = Color3.fromRGB(141, 150, 163)
local TRACK = Color3.fromRGB(43, 51, 61)
local BRASS = Color3.fromRGB(217, 164, 65)
local SPENT = Color3.fromRGB(190, 70, 60)

local gui = Instance.new("ScreenGui")
gui.Name = "FootballHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(y: number, width: number, height: number): (Frame, Frame)
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Size = UDim2.fromOffset(width, height)
	track.Position = UDim2.new(0.5, 0, 1, y)
	track.BackgroundColor3 = TRACK
	track.BackgroundTransparency = 0.25
	track.BorderSizePixel = 0
	track.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, height // 2)
	corner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill
	return track, fill
end

local function text(parent: Instance, content: string, size: number, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.Text = content
	l.TextSize = size
	l.TextColor3 = colour
	l.Parent = parent
	return l
end

-- A forca do remate: so aparece enquanto se carrega.
local powerTrack, powerFill = bar(-150, 260, 14)
powerTrack.Visible = false
powerFill.BackgroundColor3 = BRASS

-- O folego, sempre a vista.
local staminaTrack, staminaFill = bar(-122, 200, 6)
staminaFill.BackgroundColor3 = TEXT
local staminaTag = text(staminaTrack, "folego", 11, MUTED)
staminaTag.Font = Enum.Font.Gotham
staminaTag.AnchorPoint = Vector2.new(1, 0.5)
staminaTag.Position = UDim2.new(0, -8, 0.5, 0)

--[[
	O efeito e a altura: um quadrado por cima da barra de forca, com um ponto
	que segue o rato. Ao centro, sem efeito e altura normal; a direita curva
	para a direita; em cima e chapeu, em baixo rasteira.
]]
local pad = Instance.new("Frame")
pad.AnchorPoint = Vector2.new(0.5, 1)
pad.Size = UDim2.fromOffset(64, 64)
pad.Position = UDim2.new(0.5, 0, 1, -172)
pad.BackgroundColor3 = TRACK
pad.BackgroundTransparency = 0.35
pad.BorderSizePixel = 0
pad.Visible = false
pad.Parent = gui
local padCorner = Instance.new("UICorner")
padCorner.CornerRadius = UDim.new(0, 8)
padCorner.Parent = pad
for _, cross in { UDim2.new(1, -12, 0, 1), UDim2.new(0, 1, 1, -12) } do
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = cross
	line.BackgroundColor3 = MUTED
	line.BackgroundTransparency = 0.5
	line.BorderSizePixel = 0
	line.Parent = pad
end
local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Size = UDim2.fromOffset(10, 10)
dot.BackgroundColor3 = BRASS
dot.BorderSizePixel = 0
dot.Parent = pad
local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot
local padTag = text(pad, "efeito · altura", 11, MUTED)
padTag.Font = Enum.Font.Gotham
padTag.AnchorPoint = Vector2.new(0.5, 1)
padTag.Position = UDim2.new(0.5, 0, 0, -4)

local hint = text(gui, "clique esquerdo  chutar    ·    clique direito  chutar com efeito    ·    Shift  correr    ·    Ctrl  trancar camara", 12, MUTED)
hint.Font = Enum.Font.Gotham
hint.Size = UDim2.new(1, 0, 0, 16)
hint.Position = UDim2.new(0, 0, 1, -26)

-- "3, 2, 1" antes do apito do pontape de saida.
local countdown = text(gui, "", 64, TEXT)
countdown.Font = Enum.Font.GothamBlack
countdown.AnchorPoint = Vector2.new(0.5, 0.5)
countdown.Position = UDim2.fromScale(0.5, 0.36)
countdown.Size = UDim2.fromOffset(400, 80)
local countdownNote = text(gui, "", 16, MUTED)
countdownNote.AnchorPoint = Vector2.new(0.5, 0.5)
countdownNote.Position = UDim2.new(0.5, 0, 0.36, 50)
countdownNote.Size = UDim2.fromOffset(400, 22)

local function playing(): boolean
	return player:GetAttribute("Team") == "jogador"
end

local function isKeeper(): boolean
	return playing() and player:GetAttribute("Keeper") == true
end

--[[
	O guarda-redes: Q (ou o botao, no telemovel) atira-o para o lado da bola.
	Chega mais longe, mas se falhar fica um segundo no chao. Com a bola nas
	maos tem uns segundos para a por em jogo, e a contagem aparece aqui.
]]
local diveButton = Instance.new("TextButton")
diveButton.AnchorPoint = Vector2.new(1, 1)
diveButton.Size = UDim2.fromOffset(110, 44)
diveButton.Position = UDim2.new(1, -24, 1, -150)
diveButton.BackgroundColor3 = Color3.fromRGB(58, 62, 72)
diveButton.BackgroundTransparency = 0.15
diveButton.BorderSizePixel = 0
diveButton.Font = Enum.Font.GothamBold
diveButton.TextSize = 14
diveButton.TextColor3 = TEXT
diveButton.Text = "ATIRAR-SE"
diveButton.Visible = false
diveButton.Parent = gui
local diveCorner = Instance.new("UICorner")
diveCorner.CornerRadius = UDim.new(0, 8)
diveCorner.Parent = diveButton

local holdLabel = text(gui, "", 18, BRASS)
holdLabel.Font = Enum.Font.GothamBlack
holdLabel.AnchorPoint = Vector2.new(0.5, 1)
holdLabel.Size = UDim2.fromOffset(420, 24)
holdLabel.Position = UDim2.new(0.5, 0, 1, -200)

local function refresh()
	gui.Enabled = playing()
	diveButton.Visible = isKeeper()
end
player:GetAttributeChangedSignal("Team"):Connect(refresh)
player:GetAttributeChangedSignal("Keeper"):Connect(refresh)
refresh()

local lastDive = 0
local diving = false

--[[
	O mergulho, desenhado aqui porque o corpo e desta pessoa: um salto em arco
	para o lado, o corpo deitado de lado no ar com os bracos esticados, a
	queda de lado no relvado, e levantar. Nada de empurrar o boneco e deixar a
	fisica decidir — assim rebolava, travava na relva e caia de cara.

	Tempos (somam F.keeperDiveTime): voo, deitado, levantar.
]]
local AIR = 0.42
local DOWN = 0.38
local DIVE_DISTANCE = 9 -- studs de lado (o servidor da alcance F.keeperDiveReach)
local ARC = 2.2

local function ease(t: number): number
	return 1 - (1 - t) * (1 - t)
end

local function dive()
	if diving or not isKeeper() or os.clock() - lastDive < F.keeperDiveCooldown then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local ball = workspace:FindFirstChild("Ball", true) :: BasePart?
	if not character or not root or not humanoid then
		return
	end
	lastDive = os.clock()
	diving = true

	--[[
		Para onde, com as teclas vistas de quem esta na baliza a olhar para o
		campo (nao da camara): A e D atiram-se para os lados, W para a frente
		(a sair aos pes), S salta a direito para cima (bolas altas). Sem
		nenhuma, para o lado da bola.
	]]
	local team = Config.Teams[player:GetAttribute("PitchTeam") or ""]
	local look = if team then Vector3.new(team.side, 0, 0) else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local right = look:Cross(Vector3.yAxis)
	local keys = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		keys -= right
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		keys += right
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		keys += look
	end
	local upward = UserInputService:IsKeyDown(Enum.KeyCode.S) and keys.Magnitude < 0.1
	-- No telemovel nao ha teclas: o analogico, como estiver.
	local moving = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
	local towards = if ball then ball.Position - root.Position else look
	local lateral = right * math.sign(Vector3.new(towards.X, 0, towards.Z):Dot(right))
	local flat = if keys.Magnitude > 0.1 then keys elseif moving.Magnitude > 0.1 then moving else lateral
	local dir = if flat.Magnitude > 0.1 then flat.Unit else right

	if upward then
		-- O salto para cima: sobe de bracos esticados e cai de pe onde estava.
		humanoid.AutoRotate = false
		player:SetAttribute("Diving", true)
		Remotes.Football:FireServer("dive")
		local start = root.Position
		local began = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function()
			local k = (os.clock() - began) / (AIR + 0.15)
			if k >= 1 or not root.Parent then
				connection:Disconnect()
				humanoid.AutoRotate = true
				player:SetAttribute("Diving", nil)
				diving = false
				return
			end
			local pos = start + Vector3.new(0, 4.5 * math.sin(math.pi * k), 0)
			root.CFrame = CFrame.lookAt(pos, pos + look)
			root.AssemblyLinearVelocity = Vector3.zero
		end)
		return
	end

	-- Continua virado para o jogo; o corpo deita-se para o lado do mergulho.
	local side = dir:Dot(right)
	local ahead = dir:Dot(look)
	local roll = -math.sign(side) * math.rad(85) * math.min(1, math.abs(side) * 1.4)
	local pitch = if math.abs(side) < 0.5 then -math.rad(80) * math.sign(ahead) * (1 - math.abs(side)) else 0

	-- Nao atravessa postes nem paredes: o voo para onde bater.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { character }
	if ball then
		table.insert(ignore, ball)
	end
	params.FilterDescendantsInstances = ignore
	local start = root.Position
	local distance = DIVE_DISTANCE
	local hit = workspace:Raycast(start, dir * (DIVE_DISTANCE + 1.5), params)
	if hit then
		distance = math.max(0, (hit.Position - start).Magnitude - 1.5)
	end
	local standY = start.Y
	local lyingY = start.Y - humanoid.HipHeight - root.Size.Y / 2 + 0.9

	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	player:SetAttribute("Diving", true)
	Remotes.Football:FireServer("dive")

	local began = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - began
		if not root.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			diving = false
			return
		end
		local pos, lie
		if t < AIR then
			local k = t / AIR
			local along = distance * ease(k)
			local y = standY + (lyingY - standY) * k + ARC * math.sin(math.pi * k)
			pos = Vector3.new(start.X, 0, start.Z) + dir * along + Vector3.new(0, y, 0)
			lie = math.min(1, k * 2.2)
		elseif t < AIR + DOWN then
			pos = Vector3.new(start.X, lyingY, start.Z) + dir * distance
			lie = 1
		else
			-- Levanta-se onde caiu.
			connection:Disconnect()
			local at = Vector3.new(start.X, standY, start.Z) + dir * distance
			root.CFrame = CFrame.lookAt(at, at + look)
			root.AssemblyLinearVelocity = Vector3.zero
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			player:SetAttribute("Diving", nil)
			diving = false
			return
		end
		root.CFrame = CFrame.lookAt(pos, pos + look) * CFrame.Angles(pitch * lie, 0, roll * lie)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
end
diveButton.Activated:Connect(dive)

--[[
	Na baliza, o espaco e para se atirar, nao para saltar: por cima do salto do
	Roblox, e so para o guarda-redes. Os outros saltam como sempre.
]]
ContextActionService:BindActionAtPriority("Mergulhar", function(_, state)
	if not isKeeper() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		dive()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 100, Enum.KeyCode.Space)

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

local chargingSince: number? = nil
local withSpin = false -- a carregar com o clique direito: o rato da efeito e altura
local moved = Vector2.zero -- o que o rato andou desde que se carregou
local sprinting = false

local function charge(): number
	local since = chargingSince
	if not since then
		return 0
	end
	return math.clamp((os.clock() - since) / F.chargeTime, 0, 1)
end

-- O efeito e a altura, de -1 a 1, pelo que o rato andou desde que se carregou.
local function aim(): (number, number)
	if not chargingSince or not withSpin then
		return 0, 0
	end
	return math.clamp(moved.X / F.aimPixels, -1, 1), math.clamp(-moved.Y / F.aimPixels, -1, 1)
end


--[[
	No telemovel nao ha rato: botoes de toque. CHUTAR carrega a forca enquanto
	se segura e chuta ao largar, para onde o boneco esta virado (o efeito e a
	altura sao do rato, ficam para o computador). CORRER liga e desliga o
	sprint. O botao de se atirar do guarda-redes fica por cima deles.
]]
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function rescale()
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	uiScale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.5, 1)
end
rescale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

local function roundButton(label: string, size: number, position: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 1)
	b.Size = UDim2.fromOffset(size, size)
	b.Position = position
	b.BackgroundColor3 = Color3.fromRGB(30, 34, 42)
	b.BackgroundTransparency = 0.25
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 16
	b.TextColor3 = TEXT
	b.Text = label
	b.AutoButtonColor = true
	b.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = BRASS
	stroke.Thickness = 2
	stroke.Parent = b
	return b
end

if touchOnly then
	local kickButton = roundButton("CHUTAR", 120, UDim2.new(1, -190, 1, -40))
	local sprintButton = roundButton("CORRER", 84, UDim2.new(1, -330, 1, -50))

	kickButton.MouseButton1Down:Connect(function()
		if playing() then
			chargingSince = os.clock()
			withSpin = false
			moved = Vector2.zero
		end
	end)
	local function release()
		if chargingSince and not withSpin then
			Remotes.Football:FireServer("kick", { power = charge(), curve = 0, height = 0 })
			chargingSince = nil
		end
	end
	kickButton.MouseButton1Up:Connect(release)
	kickButton.MouseLeave:Connect(release)

	sprintButton.Activated:Connect(function()
		sprinting = not sprinting
		Remotes.Football:FireServer("sprint", sprinting)
		sprintButton.BackgroundColor3 = if sprinting then BRASS:Lerp(Color3.new(0, 0, 0), 0.3) else Color3.fromRGB(30, 34, 42)
	end)

	-- O de se atirar, redondo e por cima do CHUTAR.
	diveButton.Size = UDim2.fromOffset(96, 96)
	diveButton.Position = UDim2.new(1, -200, 1, -180)
	diveButton.Text = "ATIRAR"
	local diveRound = diveButton:FindFirstChildOfClass("UICorner")
	if diveRound then
		diveRound.CornerRadius = UDim.new(1, 0)
	end
	hint.Visible = false
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not playing() then
		return
	end
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2) and not chargingSince then
		chargingSince = os.clock()
		withSpin = input.UserInputType == Enum.UserInputType.MouseButton2
		moved = Vector2.zero
	elseif input.KeyCode == Enum.KeyCode.Q then
		dive()
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprinting = true
		Remotes.Football:FireServer("sprint", true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not playing() then
		return
	end
	local button = if withSpin then Enum.UserInputType.MouseButton2 else Enum.UserInputType.MouseButton1
	if input.UserInputType == button and chargingSince then
		local curve, height = aim()
		Remotes.Football:FireServer("kick", { power = charge(), curve = curve, height = height })
		chargingSince = nil
	elseif (input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift) and sprinting then
		sprinting = false
		Remotes.Football:FireServer("sprint", false)
	end
end)

-- O rato conta pelo que anda, nao por onde esta: com a camara trancada ou a
-- rodar com o botao direito, o cursor fica parado no sitio.
UserInputService.InputChanged:Connect(function(input)
	if chargingSince and withSpin and input.UserInputType == Enum.UserInputType.MouseMovement then
		moved += Vector2.new(input.Delta.X, input.Delta.Y)
	end
end)

--------------------------------------------------------------------------------
-- Barras
--------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		return
	end

	local power = charge()
	powerTrack.Visible = chargingSince ~= nil
	powerFill.Size = UDim2.fromScale(math.max(power, 0.02), 1)
	powerFill.BackgroundColor3 = BRASS:Lerp(SPENT, math.max(power - 0.75, 0) * 4)

	local curve, height = aim()
	pad.Visible = chargingSince ~= nil and withSpin
	dot.Position = UDim2.fromScale(0.5 + curve * 0.5, 0.5 - height * 0.5)

	local stamina = player:GetAttribute("Stamina")
	local fraction = if type(stamina) == "number" then stamina else 1
	staminaFill.Size = UDim2.fromScale(fraction, 1)
	staminaFill.BackgroundColor3 = if player:GetAttribute("Exhausted") then SPENT else TEXT

	-- Bola nas maos de um guarda-redes: quanto tempo falta para a perder.
	local heldUntil = workspace:GetAttribute("HeldUntil")
	if type(heldUntil) == "number" and isKeeper() and workspace:GetAttribute("HeldTeam") == player:GetAttribute("PitchTeam") then
		holdLabel.Text = string.format("BOLA NAS MAOS  ·  %d", math.max(math.ceil(heldUntil - workspace:GetServerTimeNow()), 0))
	else
		holdLabel.Text = ""
	end

	local at = workspace:GetAttribute("KickoffAt")
	local left = if type(at) == "number" then at - workspace:GetServerTimeNow() else -1
	if left > 0 then
		countdown.Text = tostring(math.ceil(left))
		local teamId = workspace:GetAttribute("KickoffTeam")
		local team = Config.Teams[if type(teamId) == "string" then teamId else ""]
		countdownNote.Text = if team then "pontape de saida  ·  " .. team.name else "pontape de saida"
	elseif left > -0.8 then
		countdown.Text = "APITO"
		countdownNote.Text = ""
	else
		countdown.Text = ""
		countdownNote.Text = ""
	end
end)

--[[
	Marcaste: o jogo leva-te a correr ate a tua claque, de bracos abertos (os
	bracos poe-os o servidor). Mexer nos controlos devolve-te o boneco na hora;
	senao vais ate la, ou ate a festa acabar.
]]
local MOVE_KEYS = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.Down] = true,
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.Right] = true,
	[Enum.KeyCode.Thumbstick1] = true,
}

Remotes.Celebrate.OnClientEvent:Connect(function(spot)
	if typeof(spot) ~= "Vector3" then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end

	local tookOver = false
	local input = UserInputService.InputBegan:Connect(function(event, processed)
		if processed then
			return
		end
		if MOVE_KEYS[event.KeyCode] or event.UserInputType == Enum.UserInputType.Touch then
			tookOver = true
		end
	end)

	-- O MoveTo desiste sozinho ao fim de uns segundos: volta-se a pedir.
	local deadline = os.clock() + Config.Match.celebrationLength - 3
	while not tookOver and os.clock() < deadline and humanoid.Parent do
		local flat = Vector3.new(root.Position.X - spot.X, 0, root.Position.Z - spot.Z)
		if flat.Magnitude < 3 then
			break
		end
		humanoid:MoveTo(spot)
		task.wait(0.25)
	end
	input:Disconnect()
end)

--[[
	A entrada em campo: o jogo leva-te do balneario, pelo tunel, ate ao teu
	lugar na fila, e vira-te para a bancada principal. Na fila ficas preso uns
	segundos (quem prende e o servidor); e o momento de olhar para as bancadas.
]]
Remotes.Escort.OnClientEvent:Connect(function(points, facing)
	if type(points) ~= "table" or typeof(facing) ~= "Vector3" then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end

	local deadline = os.clock() + Config.Entrance.lineAt + 2
	for _, point in points do
		if typeof(point) ~= "Vector3" then
			continue
		end
		while os.clock() < deadline and humanoid.Parent do
			local flat = Vector3.new(root.Position.X - point.X, 0, root.Position.Z - point.Z)
			if flat.Magnitude < 1.5 then
				break
			end
			humanoid:MoveTo(Vector3.new(point.X, root.Position.Y, point.Z))
			task.wait(0.2)
		end
	end
	if humanoid.Parent then
		local here = root.Position
		root.CFrame = CFrame.lookAt(here, here + facing)
	end
end)
