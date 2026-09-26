--!strict
--[[
	O painel do perfil (botao PERFIL ou tecla P): os Escudos, os tres niveis
	(adepto, jogador, arbitro) com a barra de XP e a proxima recompensa, a
	recompensa diaria, e as escolhas que o nivel de jogador desbloqueia
	(numero, posicao, botas).

	Aqui so se mostra e se pede: quem conta XP e dinheiro, e quem valida as
	escolhas, e o servidor (Progress).

	Tambem mostra os avisos: subir de nivel, a recompensa diaria e o resumo do
	fim de cada jogo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local P = Config.Progress

local INK = Color3.fromRGB(22, 20, 18)
local CARD = Color3.fromRGB(38, 34, 30)
local TEXT = Color3.fromRGB(236, 234, 230)
local MUTED = Color3.fromRGB(150, 146, 140)
local BRASS = Color3.fromRGB(217, 164, 65)
local GOOD = Color3.fromRGB(96, 196, 110)

local PATHS = {
	{ id = "adepto", title = "ADEPTO", colour = Color3.fromRGB(214, 80, 60) },
	{ id = "jogador", title = "JOGADOR", colour = Color3.fromRGB(80, 170, 100) },
	{ id = "arbitro", title = "ARBITRO", colour = Color3.fromRGB(230, 200, 70) },
}

local gui = Instance.new("ScreenGui")
gui.Name = "Perfil"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
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
	l.Parent = parent
	return l
end

local function button(parent: Instance, value: string, size: number, fill: Color3, colour: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = fill
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.Text = value
	b.TextSize = size
	b.TextColor3 = colour or TEXT
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 6)
	return b
end

--------------------------------------------------------------------------------
-- O botao e o painel
--------------------------------------------------------------------------------

local open = button(gui, "PERFIL", 14, INK, BRASS)
open.Font = Enum.Font.GothamBlack
open.AnchorPoint = Vector2.new(0, 0.5)
open.Size = UDim2.fromOffset(96, 34)
open.Position = UDim2.new(0, 16, 0.5, 60)
local openStroke = Instance.new("UIStroke")
openStroke.Color = BRASS
openStroke.Thickness = 1.5
openStroke.Parent = open

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.fromOffset(780, 470)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = INK
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 30
panel.Parent = gui
corner(panel, 12)
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(90, 70, 40)
panelStroke.Thickness = 2
panelStroke.Parent = panel

local title = text(panel, "PERFIL", 26, BRASS, Enum.Font.GothamBlack)
title.Size = UDim2.fromOffset(300, 30)
title.Position = UDim2.fromOffset(20, 16)
title.ZIndex = 31

local escudos = text(panel, "", 22, TEXT, Enum.Font.GothamBlack)
escudos.TextXAlignment = Enum.TextXAlignment.Right
escudos.Size = UDim2.fromOffset(220, 28)
escudos.Position = UDim2.new(1, -290, 0, 16)
escudos.ZIndex = 31

local dailyLine = text(panel, "", 13, MUTED, Enum.Font.Gotham)
dailyLine.Size = UDim2.fromOffset(500, 18)
dailyLine.Position = UDim2.fromOffset(20, 48)
dailyLine.ZIndex = 31

local close = button(panel, "X", 18, Color3.fromRGB(70, 60, 52))
close.Font = Enum.Font.GothamBlack
close.AnchorPoint = Vector2.new(1, 0)
close.Size = UDim2.fromOffset(36, 36)
close.Position = UDim2.new(1, -16, 0, 14)
close.ZIndex = 32

type Column = { level: TextLabel, bar: Frame, xp: TextLabel, reward: TextLabel }
local columns: { [string]: Column } = {}

for i, path in PATHS do
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(238, 180)
	card.Position = UDim2.fromOffset(20 + (i - 1) * 250, 76)
	card.BackgroundColor3 = CARD
	card.BorderSizePixel = 0
	card.ZIndex = 31
	card.Parent = panel
	corner(card, 10)

	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(1, 0, 0, 4)
	stripe.BackgroundColor3 = path.colour
	stripe.BorderSizePixel = 0
	stripe.ZIndex = 32
	stripe.Parent = card

	local name = text(card, path.title, 15, path.colour, Enum.Font.GothamBlack)
	name.Size = UDim2.fromOffset(200, 20)
	name.Position = UDim2.fromOffset(14, 14)
	name.ZIndex = 32

	local level = text(card, "NIVEL 1", 30, TEXT, Enum.Font.GothamBlack)
	level.Size = UDim2.fromOffset(210, 36)
	level.Position = UDim2.fromOffset(14, 38)
	level.ZIndex = 32

	local track = Instance.new("Frame")
	track.Size = UDim2.fromOffset(210, 10)
	track.Position = UDim2.fromOffset(14, 84)
	track.BackgroundColor3 = Color3.fromRGB(58, 52, 46)
	track.BorderSizePixel = 0
	track.ZIndex = 32
	track.Parent = card
	corner(track, 5)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = path.colour
	bar.BorderSizePixel = 0
	bar.ZIndex = 33
	bar.Parent = track
	corner(bar, 5)

	local xp = text(card, "", 12, MUTED, Enum.Font.Gotham)
	xp.Size = UDim2.fromOffset(210, 16)
	xp.Position = UDim2.fromOffset(14, 100)
	xp.ZIndex = 32

	local reward = text(card, "", 13, BRASS)
	reward.TextWrapped = true
	reward.TextYAlignment = Enum.TextYAlignment.Top
	reward.Size = UDim2.fromOffset(210, 50)
	reward.Position = UDim2.fromOffset(14, 122)
	reward.ZIndex = 32

	columns[path.id] = { level = level, bar = bar, xp = xp, reward = reward }
end

--------------------------------------------------------------------------------
-- As escolhas do jogador (numero, posicao, botas)
--------------------------------------------------------------------------------

local choices = Instance.new("Frame")
choices.Size = UDim2.fromOffset(740, 186)
choices.Position = UDim2.fromOffset(20, 268)
choices.BackgroundColor3 = CARD
choices.BorderSizePixel = 0
choices.ZIndex = 31
choices.Parent = panel
corner(choices, 10)

local choicesTitle = text(choices, "EQUIPAMENTO DE JOGADOR  ·  so aspeto: o nivel nunca te faz jogar melhor", 13, MUTED)
choicesTitle.Size = UDim2.fromOffset(700, 18)
choicesTitle.Position = UDim2.fromOffset(14, 10)
choicesTitle.ZIndex = 32

-- Numero da camisola.
local numberLabel = text(choices, "NUMERO", 12, MUTED)
numberLabel.Size = UDim2.fromOffset(200, 16)
numberLabel.Position = UDim2.fromOffset(14, 38)
numberLabel.ZIndex = 32
local chosenNumber = 10
local minus = button(choices, "-", 18, Color3.fromRGB(70, 60, 52))
minus.Size = UDim2.fromOffset(34, 34)
minus.Position = UDim2.fromOffset(14, 58)
minus.ZIndex = 32
local numberBox = text(choices, "10", 24, TEXT, Enum.Font.GothamBlack)
numberBox.TextXAlignment = Enum.TextXAlignment.Center
numberBox.Size = UDim2.fromOffset(56, 34)
numberBox.Position = UDim2.fromOffset(52, 58)
numberBox.ZIndex = 32
local plus = button(choices, "+", 18, Color3.fromRGB(70, 60, 52))
plus.Size = UDim2.fromOffset(34, 34)
plus.Position = UDim2.fromOffset(112, 58)
plus.ZIndex = 32
local saveNumber = button(choices, "VESTIR", 13, BRASS, INK)
saveNumber.Font = Enum.Font.GothamBlack
saveNumber.Size = UDim2.fromOffset(90, 34)
saveNumber.Position = UDim2.fromOffset(152, 58)
saveNumber.ZIndex = 32
local numberLock = text(choices, "", 12, MUTED, Enum.Font.Gotham)
numberLock.Size = UDim2.fromOffset(240, 16)
numberLock.Position = UDim2.fromOffset(14, 98)
numberLock.ZIndex = 32

-- Posicao.
local positionLabel = text(choices, "POSICAO PREFERIDA", 12, MUTED)
positionLabel.Size = UDim2.fromOffset(200, 16)
positionLabel.Position = UDim2.fromOffset(270, 38)
positionLabel.ZIndex = 32
local positionButtons: { [string]: TextButton } = {}
for i, zone in { "ataque", "meio", "defesa" } do
	local b = button(choices, string.upper(zone), 12, Color3.fromRGB(58, 52, 46))
	b.Size = UDim2.fromOffset(76, 34)
	b.Position = UDim2.fromOffset(270 + (i - 1) * 82, 58)
	b.ZIndex = 32
	b.Activated:Connect(function()
		Remotes.Perfil:FireServer("posicao", zone)
	end)
	positionButtons[zone] = b
end
local positionLock = text(choices, "", 12, MUTED, Enum.Font.Gotham)
positionLock.Size = UDim2.fromOffset(240, 16)
positionLock.Position = UDim2.fromOffset(270, 98)
positionLock.ZIndex = 32

-- Botas.
local bootsLabel = text(choices, "BOTAS", 12, MUTED)
bootsLabel.Size = UDim2.fromOffset(200, 16)
bootsLabel.Position = UDim2.fromOffset(534, 38)
bootsLabel.ZIndex = 32
local bootButtons: { TextButton } = {}
for i, boot in Config.BootColours do
	local b = button(choices, "", 10, boot.color)
	b.Size = UDim2.fromOffset(24, 24)
	b.Position = UDim2.fromOffset(534 + ((i - 1) % 7) * 28, 62)
	b.ZIndex = 32
	corner(b, 12)
	b.Activated:Connect(function()
		Remotes.Perfil:FireServer("botas", i)
	end)
	bootButtons[i] = b
end
local bootsLock = text(choices, "", 12, MUTED, Enum.Font.Gotham)
bootsLock.Size = UDim2.fromOffset(200, 16)
bootsLock.Position = UDim2.fromOffset(534, 98)
bootsLock.ZIndex = 32

local savedNote = text(choices, "", 12, Color3.fromRGB(230, 120, 90), Enum.Font.Gotham)
savedNote.Size = UDim2.fromOffset(700, 16)
savedNote.Position = UDim2.fromOffset(14, 150)
savedNote.ZIndex = 32

minus.Activated:Connect(function()
	chosenNumber = if chosenNumber <= 1 then 99 else chosenNumber - 1
	numberBox.Text = tostring(chosenNumber)
end)
plus.Activated:Connect(function()
	chosenNumber = if chosenNumber >= 99 then 1 else chosenNumber + 1
	numberBox.Text = tostring(chosenNumber)
end)
saveNumber.Activated:Connect(function()
	Remotes.Perfil:FireServer("numero", chosenNumber)
end)

--------------------------------------------------------------------------------
-- Pintar o que o servidor diz
--------------------------------------------------------------------------------

local profile: { [string]: any }? = nil

local function paint()
	local p = profile
	if not p then
		return
	end
	escudos.Text = tostring(p.escudos) .. "$"
	if player:GetAttribute("MoedasInfinitas") then
		escudos.Text = "∞$"
	end
	local streak = p.streak or 0
	dailyLine.Text = if streak > 0 then "Recompensa diaria: dia " .. streak .. " de " .. #P.daily .. " seguidos" else "Recompensa diaria: entra todos os dias"
	for _, path in PATHS do
		local data = p.paths[path.id]
		local col = columns[path.id]
		if data and col then
			col.level.Text = "NIVEL " .. data.level
			if data.level >= P.maxLevel then
				col.bar.Size = UDim2.fromScale(1, 1)
				col.xp.Text = data.total .. " XP · nivel maximo"
			else
				col.bar.Size = UDim2.fromScale(math.clamp(data.xp / data.need, 0, 1), 1)
				col.xp.Text = data.xp .. " / " .. data.need .. " XP  ·  total " .. data.total
			end
			col.reward.Text = data.nextReward
		end
	end

	local level = if p.paths.jogador then p.paths.jogador.level else 1
	local K = P.perks
	local canNumber = level >= K.numberAt
	for _, b in { minus, plus, saveNumber } do
		b.Active = canNumber
		b.AutoButtonColor = canNumber
		b.BackgroundTransparency = if canNumber then 0 else 0.6
	end
	numberLock.Text = if canNumber then (if p.prefs.number then "Vestes o " .. p.prefs.number .. " (se ninguem da equipa o tiver)" else "Escolhe e carrega em VESTIR") else "Desbloqueia no nivel " .. K.numberAt .. " de jogador"
	if canNumber and p.prefs.number and numberBox.Text == "10" then
		chosenNumber = p.prefs.number
		numberBox.Text = tostring(chosenNumber)
	end
	local canPosition = level >= K.positionAt
	for zone, b in positionButtons do
		b.Active = canPosition
		b.BackgroundColor3 = if p.prefs.position == zone then BRASS else Color3.fromRGB(58, 52, 46)
		b.TextColor3 = if p.prefs.position == zone then INK else TEXT
		b.BackgroundTransparency = if canPosition then 0 else 0.6
	end
	positionLock.Text = if canPosition then "Ficas com um lugar dessa zona, se houver" else "Desbloqueia no nivel " .. K.positionAt .. " de jogador"
	local canBoots = level >= K.bootsAt
	for i, b in bootButtons do
		b.Active = canBoots
		b.BackgroundTransparency = if canBoots then 0 else 0.7
		local stroke = b:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = if p.prefs.boots == i then 2 else 0
		stroke.Parent = b
	end
	bootsLock.Text = if level >= K.goldBootsAt then "Botas douradas (nivel " .. K.goldBootsAt .. ")" elseif canBoots then "A cor das tuas botas" else "Desbloqueia no nivel " .. K.bootsAt .. " de jogador"
	savedNote.Text = if p.saved then "" else "O teu perfil ainda nao carregou: o que ganhares agora soma-se quando carregar."
end

local function toggle(show: boolean?)
	panel.Visible = if show ~= nil then show else not panel.Visible
	if panel.Visible then
		Remotes.Perfil:FireServer("pedir")
	end
end
open.Activated:Connect(function()
	toggle()
end)
close.Activated:Connect(function()
	toggle(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.P then
		toggle()
	end
end)

--------------------------------------------------------------------------------
-- Avisos: subir de nivel, recompensa diaria, resumo do jogo
--------------------------------------------------------------------------------

local toast = Instance.new("Frame")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Size = UDim2.fromOffset(460, 64)
toast.Position = UDim2.new(0.5, 0, 0, 90)
toast.BackgroundColor3 = INK
toast.BackgroundTransparency = 0.05
toast.BorderSizePixel = 0
toast.Visible = false
toast.ZIndex = 40
toast.Parent = gui
corner(toast, 10)
local toastStroke = Instance.new("UIStroke")
toastStroke.Color = BRASS
toastStroke.Thickness = 2
toastStroke.Parent = toast
local toastTitle = text(toast, "", 20, BRASS, Enum.Font.GothamBlack)
toastTitle.TextXAlignment = Enum.TextXAlignment.Center
toastTitle.Size = UDim2.new(1, -20, 0, 26)
toastTitle.Position = UDim2.fromOffset(10, 8)
toastTitle.ZIndex = 41
local toastLine = text(toast, "", 14, TEXT, Enum.Font.Gotham)
toastLine.TextXAlignment = Enum.TextXAlignment.Center
toastLine.Size = UDim2.new(1, -20, 0, 20)
toastLine.Position = UDim2.fromOffset(10, 36)
toastLine.ZIndex = 41

local toastStamp = 0
local function showToast(head: string, line: string, seconds: number)
	toastTitle.Text = head
	toastLine.Text = line
	toast.Visible = true
	local stamp = os.clock()
	toastStamp = stamp
	task.delay(seconds, function()
		if toastStamp == stamp then
			toast.Visible = false
		end
	end)
end

-- O resumo do fim do jogo: uma caixa com as linhas de cada papel.
local summary = Instance.new("Frame")
summary.AnchorPoint = Vector2.new(0.5, 0.5)
summary.Size = UDim2.fromOffset(460, 200)
summary.Position = UDim2.fromScale(0.5, 0.42)
summary.BackgroundColor3 = INK
summary.BorderSizePixel = 0
summary.Visible = false
summary.ZIndex = 40
summary.Parent = gui
corner(summary, 12)
local summaryStroke = Instance.new("UIStroke")
summaryStroke.Color = BRASS
summaryStroke.Thickness = 2
summaryStroke.Parent = summary
local summaryTitle = text(summary, "FIM DO JOGO", 22, BRASS, Enum.Font.GothamBlack)
summaryTitle.TextXAlignment = Enum.TextXAlignment.Center
summaryTitle.Size = UDim2.new(1, 0, 0, 30)
summaryTitle.Position = UDim2.fromOffset(0, 12)
summaryTitle.ZIndex = 41
local summaryBody = text(summary, "", 15, TEXT, Enum.Font.Gotham)
summaryBody.TextXAlignment = Enum.TextXAlignment.Center
summaryBody.TextYAlignment = Enum.TextYAlignment.Top
summaryBody.TextWrapped = true
summaryBody.Size = UDim2.new(1, -30, 1, -96)
summaryBody.Position = UDim2.fromOffset(15, 48)
summaryBody.ZIndex = 41
local summaryPay = text(summary, "", 20, GOOD, Enum.Font.GothamBlack)
summaryPay.TextXAlignment = Enum.TextXAlignment.Center
summaryPay.Size = UDim2.new(1, 0, 0, 26)
summaryPay.Position = UDim2.new(0, 0, 1, -40)
summaryPay.ZIndex = 41

local PATH_TITLE = { adepto = "ADEPTO", jogador = "JOGADOR", arbitro = "ARBITRO" }

Remotes.Perfil.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	if data.kind == "perfil" then
		profile = data
		paint()
	elseif data.kind == "nivel" then
		showToast("SUBISTE DE NIVEL", (PATH_TITLE[data.path] or "") .. " · NIVEL " .. tostring(data.level), 4)
	elseif data.kind == "diaria" then
		showToast("RECOMPENSA DIARIA", "Dia " .. tostring(data.day) .. " seguido · +" .. tostring(data.reward) .. "$", 5)
	elseif data.kind == "resumo" and type(data.lines) == "table" then
		summaryBody.Text = table.concat(data.lines, "\n")
		summaryPay.Text = if (data.pay or 0) > 0 then "+" .. tostring(data.pay) .. "$" else ""
		summary.Visible = true
		task.delay(12, function()
			summary.Visible = false
		end)
	end
end)

-- Pede o perfil logo que o ecra arranca.
Remotes.Perfil:FireServer("pedir")
