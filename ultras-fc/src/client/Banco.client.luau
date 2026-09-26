--!strict
--[[
	O ecra do multibanco (abre-se no botao "Multibanco" das maquinas da
	cidade): o saldo, e enviar Escudos a outra pessoa que esteja no jogo.

	Escolhe-se a pessoa (com a cara dela), o valor (a escrever ou nos botoes
	rapidos), e ENVIAR. Quem decide se passa e o servidor (Bank); aqui so se
	pede e se mostra a resposta. Quem recebe ve um aviso.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local SCREEN = Color3.fromRGB(12, 34, 66)
local SCREEN_2 = Color3.fromRGB(8, 60, 110)
local CARD = Color3.fromRGB(22, 52, 92)
local TEXT = Color3.fromRGB(240, 246, 255)
local MUTED = Color3.fromRGB(150, 180, 215)
local GOLD = Color3.fromRGB(255, 200, 70)
local GREEN = Color3.fromRGB(80, 210, 120)
local RED = Color3.fromRGB(240, 90, 80)

local gui = Instance.new("ScreenGui")
gui.Name = "Multibanco"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 8
gui.Parent = player:WaitForChild("PlayerGui")

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

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function text(parent: Instance, value: string, size: number, colour: Color3, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.Text = value
	l.TextSize = size
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = 61
	l.Parent = parent
	return l
end

local function button(parent: Instance, value: string, size: number, fill: Color3, colour: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = fill
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBlack
	b.Text = value
	b.TextSize = size
	b.TextColor3 = colour or TEXT
	b.AutoButtonColor = true
	b.ZIndex = 62
	b.Parent = parent
	corner(b, 10)
	return b
end

local function grouped(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^%s+", ""))
end

--------------------------------------------------------------------------------

local machine = Instance.new("Frame")
machine.AnchorPoint = Vector2.new(0.5, 0.5)
machine.Size = UDim2.fromOffset(640, 440)
machine.Position = UDim2.fromScale(0.5, 0.5)
machine.BackgroundColor3 = Color3.fromRGB(60, 64, 72)
machine.BorderSizePixel = 0
machine.Visible = false
machine.ZIndex = 60
machine.Parent = gui
corner(machine, 18)
local shell = Instance.new("UIGradient")
shell.Color = ColorSequence.new(Color3.fromRGB(96, 100, 110), Color3.fromRGB(46, 48, 56))
shell.Rotation = 90
shell.Parent = machine

-- O ecra azul da maquina.
local screen = Instance.new("Frame")
screen.Size = UDim2.new(1, -28, 1, -28)
screen.Position = UDim2.fromOffset(14, 14)
screen.BackgroundColor3 = SCREEN
screen.BorderSizePixel = 0
screen.ZIndex = 60
screen.Parent = machine
corner(screen, 12)
local glow = Instance.new("UIGradient")
glow.Color = ColorSequence.new(SCREEN_2, SCREEN)
glow.Rotation = 90
glow.Parent = screen

local header = text(screen, "🏧  MULTIBANCO", 24, TEXT, Enum.Font.GothamBlack)
header.Size = UDim2.fromOffset(360, 30)
header.Position = UDim2.fromOffset(20, 14)
local close = button(screen, "X", 18, RED)
close.AnchorPoint = Vector2.new(1, 0)
close.Size = UDim2.fromOffset(38, 38)
close.Position = UDim2.new(1, -14, 0, 12)

local balanceLabel = text(screen, "SALDO", 13, MUTED, Enum.Font.GothamBlack)
balanceLabel.Size = UDim2.fromOffset(200, 16)
balanceLabel.Position = UDim2.fromOffset(20, 54)
local balance = text(screen, "0$", 40, GOLD, Enum.Font.GothamBlack)
balance.Size = UDim2.fromOffset(300, 46)
balance.Position = UDim2.fromOffset(20, 70)

-- A lista de pessoas no jogo.
local whoLabel = text(screen, "ENVIAR A", 13, MUTED, Enum.Font.GothamBlack)
whoLabel.Size = UDim2.fromOffset(200, 16)
whoLabel.Position = UDim2.fromOffset(20, 126)
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.fromOffset(280, 236)
list.Position = UDim2.fromOffset(20, 146)
list.BackgroundColor3 = CARD
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ZIndex = 61
list.Parent = screen
corner(list, 10)
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Parent = list
local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 6)
listPad.PaddingLeft = UDim.new(0, 6)
listPad.PaddingRight = UDim.new(0, 10)
listPad.Parent = list
local empty = text(list, "Ninguem mais no jogo agora.", 14, MUTED, Enum.Font.Gotham)
empty.Size = UDim2.new(1, 0, 0, 30)

-- O valor.
local amountLabel = text(screen, "VALOR", 13, MUTED, Enum.Font.GothamBlack)
amountLabel.Size = UDim2.fromOffset(200, 16)
amountLabel.Position = UDim2.fromOffset(320, 126)
local amountBox = Instance.new("TextBox")
amountBox.Size = UDim2.fromOffset(272, 56)
amountBox.Position = UDim2.fromOffset(320, 146)
amountBox.BackgroundColor3 = Color3.fromRGB(240, 246, 255)
amountBox.BorderSizePixel = 0
amountBox.Font = Enum.Font.GothamBlack
amountBox.TextSize = 30
amountBox.TextColor3 = SCREEN
amountBox.PlaceholderText = "0"
amountBox.Text = ""
amountBox.ClearTextOnFocus = false
amountBox.ZIndex = 62
amountBox.Parent = screen
corner(amountBox, 10)
amountBox:GetPropertyChangedSignal("Text"):Connect(function()
	local digits = amountBox.Text:gsub("%D", ""):sub(1, 4)
	if digits ~= amountBox.Text then
		amountBox.Text = digits
	end
end)
for i, v in { 10, 50, 100, 500 } do
	local b = button(screen, "+" .. v, 16, CARD)
	b.Size = UDim2.fromOffset(62, 38)
	b.Position = UDim2.fromOffset(320 + (i - 1) * 70, 210)
	b.Activated:Connect(function()
		local now = tonumber(amountBox.Text) or 0
		amountBox.Text = tostring(math.min(now + v, 1000))
	end)
end

local selectedLabel = text(screen, "Escolhe a pessoa na lista.", 14, MUTED, Enum.Font.GothamBold)
selectedLabel.TextWrapped = true
selectedLabel.Size = UDim2.fromOffset(272, 36)
selectedLabel.Position = UDim2.fromOffset(320, 256)

local send = button(screen, "ENVIAR", 22, GREEN, SCREEN)
send.Size = UDim2.fromOffset(272, 56)
send.Position = UDim2.fromOffset(320, 296)

local status = text(screen, "", 14, TEXT, Enum.Font.GothamBold)
status.TextXAlignment = Enum.TextXAlignment.Center
status.TextWrapped = true
status.Size = UDim2.new(1, -40, 0, 30)
status.Position = UDim2.new(0, 20, 1, -40)

--------------------------------------------------------------------------------

local selected: Player? = nil
local rows: { [Player]: TextButton } = {}

local function paintRows()
	for who, row in rows do
		row.BackgroundColor3 = if who == selected then GOLD else Color3.fromRGB(34, 70, 120)
		local name = row:FindFirstChild("Nome") :: TextLabel?
		if name then
			name.TextColor3 = if who == selected then SCREEN else TEXT
		end
	end
	selectedLabel.Text = if selected then "Enviar a " .. selected.DisplayName else "Escolhe a pessoa na lista."
	selectedLabel.TextColor3 = if selected then TEXT else MUTED
end

local function rebuildList()
	for _, row in rows do
		row:Destroy()
	end
	table.clear(rows)
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			count += 1
			local row = button(list, "", 1, Color3.fromRGB(34, 70, 120))
			row.Name = other.DisplayName
			row.Size = UDim2.new(1, 0, 0, 48)
			local face = Instance.new("ImageLabel")
			face.Size = UDim2.fromOffset(40, 40)
			face.Position = UDim2.fromOffset(4, 4)
			face.BackgroundColor3 = CARD
			face.ZIndex = 63
			face.Parent = row
			corner(face, 20)
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(other.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				end)
				if ok and face.Parent then
					face.Image = image
				end
			end)
			local name = text(row, other.DisplayName, 16, TEXT, Enum.Font.GothamBlack)
			name.Name = "Nome"
			name.ZIndex = 63
			name.Size = UDim2.new(1, -56, 1, 0)
			name.Position = UDim2.fromOffset(52, 0)
			row.Activated:Connect(function()
				selected = other
				paintRows()
			end)
			rows[other] = row
		end
	end
	empty.Visible = count == 0
	if selected and not rows[selected] then
		selected = nil
	end
	paintRows()
end

local function paintBalance()
	local value = player:GetAttribute("Moedas")
	balance.Text = if type(value) == "number" then grouped(value) .. "$" else "0$"
end
player:GetAttributeChangedSignal("Moedas"):Connect(paintBalance)

local function openMachine()
	machine.Visible = true
	status.Text = ""
	paintBalance()
	rebuildList()
end

close.Activated:Connect(function()
	machine.Visible = false
end)
Players.PlayerAdded:Connect(function()
	if machine.Visible then
		rebuildList()
	end
end)
Players.PlayerRemoving:Connect(function(who)
	if machine.Visible then
		task.defer(rebuildList)
	end
	if selected == who then
		selected = nil
	end
end)

send.Activated:Connect(function()
	local value = tonumber(amountBox.Text)
	local who = selected
	if not who then
		status.TextColor3 = RED
		status.Text = "Escolhe a quem enviar."
		return
	end
	if not value or value < 1 then
		status.TextColor3 = RED
		status.Text = "Escreve quanto queres enviar."
		return
	end
	status.TextColor3 = MUTED
	status.Text = "A enviar..."
	Remotes.Banco:FireServer("enviar", who.UserId, value)
end)

-- Afastar-se da maquina fecha o ecra.
local openedAt: Vector3? = nil
RunService.Heartbeat:Connect(function()
	if not machine.Visible then
		openedAt = nil
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		openedAt = openedAt or root.Position
		if (root.Position - (openedAt :: Vector3)).Magnitude > 16 then
			machine.Visible = false
		end
	end
end)

--------------------------------------------------------------------------------
-- Aviso de dinheiro recebido
--------------------------------------------------------------------------------

local toast = Instance.new("Frame")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Size = UDim2.fromOffset(420, 62)
toast.Position = UDim2.new(0.5, 0, 0, -80)
toast.BackgroundColor3 = GREEN
toast.BorderSizePixel = 0
toast.ZIndex = 70
toast.Parent = gui
corner(toast, 12)
local toastText = text(toast, "", 18, SCREEN, Enum.Font.GothamBlack)
toastText.TextXAlignment = Enum.TextXAlignment.Center
toastText.Size = UDim2.fromScale(1, 1)
toastText.ZIndex = 71

local function received(amount: number, from: string)
	toastText.Text = "💸 " .. from .. " enviou-te " .. grouped(amount) .. "$"
	TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 64) }):Play()
	task.delay(4, function()
		TweenService:Create(toast, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
	end)
end

Remotes.Banco.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	if data.kind == "abrir" then
		openMachine()
	elseif data.kind == "resposta" then
		status.TextColor3 = if data.ok then GREEN else RED
		status.Text = tostring(data.message)
		if data.ok then
			amountBox.Text = ""
		end
	elseif data.kind == "recebido" then
		received(tonumber(data.amount) or 0, tostring(data.from))
	end
end)
