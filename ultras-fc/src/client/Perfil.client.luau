--!strict
--[[
	O painel do perfil (botao PERFIL ou tecla P), em tres separadores:

	- NIVEIS: um cartao grande e colorido por caminho (adepto, jogador,
	  arbitro), com o nivel, a barra, quanto falta, como se ganha XP e a
	  proxima recompensa;
	- DINHEIRO: quantos Escudos tens, como se ganham (com o teu salario de
	  agora) e onde se gastam;
	- EQUIPAMENTO: o que o nivel de jogador desbloqueia (numero, posicao,
	  botas).

	Aqui so se mostra e se pede: quem conta XP e dinheiro, e valida as
	escolhas, e o servidor (Progress). Tambem mostra os avisos: subir de nivel,
	a recompensa diaria e o resumo do fim de cada jogo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local P = Config.Progress
local K = P.perks

local BG = Color3.fromRGB(18, 20, 28)
local CARD = Color3.fromRGB(30, 33, 44)
local TEXT = Color3.fromRGB(244, 244, 248)
local MUTED = Color3.fromRGB(160, 166, 184)
local GOLD = Color3.fromRGB(255, 200, 70)
local GREEN = Color3.fromRGB(90, 210, 120)

type PathInfo = { id: string, title: string, icon: string, colour: Color3, dark: Color3, how: { string } }
local PATHS: { PathInfo } = {
	{
		id = "adepto",
		title = "ADEPTO",
		icon = "📣",
		colour = Color3.fromRGB(240, 90, 70),
		dark = Color3.fromRGB(120, 36, 30),
		how = { "Marchar no corteo perto da faixa", "Estar na bancada durante o jogo", "Tocha ou fumo depois de um golo", "Estar no apito inicial" },
	},
	{
		id = "jogador",
		title = "JOGADOR",
		icon = "⚽",
		colour = Color3.fromRGB(70, 200, 110),
		dark = Color3.fromRGB(26, 96, 50),
		how = { "Minutos jogados", "Golos e assistencias", "Roubar a bola", "Defesas (guarda-redes)" },
	},
	{
		id = "arbitro",
		title = "ARBITRO",
		icon = "🟨",
		colour = Color3.fromRGB(250, 200, 60),
		dark = Color3.fromRGB(120, 90, 20),
		how = { "Apitar o jogo inteiro", "Decidir o que e justo", "Nao ser apanhado em corrupcao" },
	},
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

local function gradient(parent: Instance, a: Color3, b: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation or 90
	g.Parent = parent
end

local function text(parent: Instance, value: string, size: number, colour: Color3, font: Enum.Font?, z: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.Text = value
	l.TextSize = size
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = z or 32
	l.Parent = parent
	return l
end

local function button(parent: Instance, value: string, size: number, fill: Color3, colour: Color3?, z: number?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = fill
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBlack
	b.Text = value
	b.TextSize = size
	b.TextColor3 = colour or TEXT
	b.AutoButtonColor = true
	b.ZIndex = z or 32
	b.Parent = parent
	corner(b, 8)
	return b
end

local function box(parent: Instance, size: UDim2, pos: UDim2, colour: Color3, z: number?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.ZIndex = z or 31
	f.Parent = parent
	return f
end

--------------------------------------------------------------------------------
-- O botao e o painel
--------------------------------------------------------------------------------

local open = button(gui, "⭐ PERFIL", 15, GOLD, BG, 10)
open.AnchorPoint = Vector2.new(0, 0.5)
open.Size = UDim2.fromOffset(112, 38)
open.Position = UDim2.new(0, 16, 0.5, 60)

local panel = box(gui, UDim2.fromOffset(820, 500), UDim2.fromScale(0.5, 0.5), BG, 30)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Visible = false
corner(panel, 14)

-- O topo: titulo, os escudos grandes, e o X.
local top = box(panel, UDim2.new(1, 0, 0, 64), UDim2.fromOffset(0, 0), Color3.fromRGB(60, 50, 120), 31)
corner(top, 14)
gradient(top, Color3.fromRGB(110, 70, 200), Color3.fromRGB(40, 90, 190), 0)
local title = text(top, "O TEU PERFIL", 26, TEXT, Enum.Font.GothamBlack)
title.Size = UDim2.fromOffset(300, 64)
title.Position = UDim2.fromOffset(20, 0)
local wallet = button(top, "💰 0$", 22, Color3.fromRGB(30, 26, 20), GOLD)
wallet.AnchorPoint = Vector2.new(1, 0.5)
wallet.Size = UDim2.fromOffset(170, 42)
wallet.Position = UDim2.new(1, -66, 0.5, 0)
local close = button(top, "X", 18, Color3.fromRGB(200, 60, 60))
close.AnchorPoint = Vector2.new(1, 0.5)
close.Size = UDim2.fromOffset(40, 40)
close.Position = UDim2.new(1, -14, 0.5, 0)

-- Os separadores.
local tabs: { [string]: { button: TextButton, page: Frame } } = {}
local TAB_ORDER = { { id = "niveis", label = "⭐ NIVEIS" }, { id = "dinheiro", label = "💰 DINHEIRO" }, { id = "equipamento", label = "👕 EQUIPAMENTO" } }
for i, t in TAB_ORDER do
	local b = button(panel, t.label, 15, CARD)
	b.Size = UDim2.fromOffset(200, 38)
	b.Position = UDim2.fromOffset(20 + (i - 1) * 210, 76)
	local page = box(panel, UDim2.new(1, -40, 1, -134), UDim2.fromOffset(20, 122), BG, 31)
	page.BackgroundTransparency = 1
	page.Visible = false
	tabs[t.id] = { button = b, page = page }
end

local function showTab(id: string)
	for key, t in tabs do
		local on = key == id
		t.page.Visible = on
		t.button.BackgroundColor3 = if on then GOLD else CARD
		t.button.TextColor3 = if on then BG else TEXT
	end
end
for key, t in tabs do
	t.button.Activated:Connect(function()
		showTab(key)
	end)
end
wallet.Activated:Connect(function()
	showTab("dinheiro")
end)

--------------------------------------------------------------------------------
-- NIVEIS: um cartao por caminho
--------------------------------------------------------------------------------

type Card = { level: TextLabel, bar: Frame, missing: TextLabel, reward: TextLabel }
local cards: { [string]: Card } = {}

for i, path in PATHS do
	local card = box(tabs.niveis.page, UDim2.fromOffset(250, 360), UDim2.fromOffset((i - 1) * 262, 0), path.colour, 32)
	corner(card, 14)
	gradient(card, path.colour, path.dark, 90)

	local head = text(card, path.icon .. "  " .. path.title, 20, TEXT, Enum.Font.GothamBlack, 33)
	head.Size = UDim2.new(1, -24, 0, 28)
	head.Position = UDim2.fromOffset(14, 12)

	-- O nivel num circulo grande.
	local circle = box(card, UDim2.fromOffset(92, 92), UDim2.fromOffset(79, 46), Color3.fromRGB(255, 255, 255), 33)
	circle.BackgroundTransparency = 0.82
	corner(circle, 46)
	local small = text(circle, "NIVEL", 12, TEXT, Enum.Font.GothamBold, 34)
	small.TextXAlignment = Enum.TextXAlignment.Center
	small.Size = UDim2.new(1, 0, 0, 16)
	small.Position = UDim2.fromOffset(0, 14)
	local level = text(circle, "1", 42, TEXT, Enum.Font.GothamBlack, 34)
	level.TextXAlignment = Enum.TextXAlignment.Center
	level.Size = UDim2.new(1, 0, 0, 46)
	level.Position = UDim2.fromOffset(0, 30)

	local track = box(card, UDim2.new(1, -28, 0, 14), UDim2.fromOffset(14, 150), Color3.fromRGB(0, 0, 0), 33)
	track.BackgroundTransparency = 0.6
	corner(track, 7)
	local bar = box(track, UDim2.fromScale(0, 1), UDim2.fromOffset(0, 0), Color3.fromRGB(255, 255, 255), 34)
	corner(bar, 7)
	local missing = text(card, "", 13, TEXT, Enum.Font.GothamBold, 33)
	missing.TextXAlignment = Enum.TextXAlignment.Center
	missing.Size = UDim2.new(1, -24, 0, 18)
	missing.Position = UDim2.fromOffset(12, 168)

	local howTitle = text(card, "COMO GANHAR XP", 12, TEXT, Enum.Font.GothamBlack, 33)
	howTitle.Size = UDim2.new(1, -24, 0, 16)
	howTitle.Position = UDim2.fromOffset(14, 196)
	local how = text(card, "• " .. table.concat(path.how, "\n• "), 13, TEXT, Enum.Font.Gotham, 33)
	how.TextYAlignment = Enum.TextYAlignment.Top
	how.TextWrapped = true
	how.Size = UDim2.new(1, -24, 0, 80)
	how.Position = UDim2.fromOffset(14, 214)

	local rewardBox = box(card, UDim2.new(1, -20, 0, 54), UDim2.fromOffset(10, 296), Color3.fromRGB(0, 0, 0), 33)
	rewardBox.BackgroundTransparency = 0.55
	corner(rewardBox, 10)
	local reward = text(rewardBox, "", 13, GOLD, Enum.Font.GothamBold, 34)
	reward.TextWrapped = true
	reward.Size = UDim2.new(1, -16, 1, -8)
	reward.Position = UDim2.fromOffset(8, 4)

	cards[path.id] = { level = level, bar = bar, missing = missing, reward = reward }
end

--------------------------------------------------------------------------------
-- DINHEIRO: quanto tens, como se ganha, onde se gasta
--------------------------------------------------------------------------------

local moneyPage = tabs.dinheiro.page
local balance = box(moneyPage, UDim2.fromOffset(250, 150), UDim2.fromOffset(0, 0), GOLD, 32)
corner(balance, 14)
gradient(balance, Color3.fromRGB(255, 210, 80), Color3.fromRGB(200, 130, 30), 90)
local balanceTitle = text(balance, "TENS", 16, BG, Enum.Font.GothamBlack, 33)
balanceTitle.TextXAlignment = Enum.TextXAlignment.Center
balanceTitle.Size = UDim2.new(1, 0, 0, 24)
balanceTitle.Position = UDim2.fromOffset(0, 16)
local balanceValue = text(balance, "0$", 48, BG, Enum.Font.GothamBlack, 33)
balanceValue.TextXAlignment = Enum.TextXAlignment.Center
balanceValue.Size = UDim2.new(1, 0, 0, 56)
balanceValue.Position = UDim2.fromOffset(0, 42)
local balanceNote = text(balance, "Escudos: o dinheiro do jogo", 13, BG, Enum.Font.GothamBold, 33)
balanceNote.TextXAlignment = Enum.TextXAlignment.Center
balanceNote.Size = UDim2.new(1, 0, 0, 18)
balanceNote.Position = UDim2.fromOffset(0, 108)

local function infoCard(parent: Instance, pos: UDim2, size: UDim2, colour: Color3, heading: string): TextLabel
	local c = box(parent, size, pos, CARD, 32)
	corner(c, 14)
	local stripe = box(c, UDim2.new(0, 6, 1, -20), UDim2.fromOffset(10, 10), colour, 33)
	corner(stripe, 3)
	local h = text(c, heading, 17, colour, Enum.Font.GothamBlack, 33)
	h.Size = UDim2.new(1, -40, 0, 24)
	h.Position = UDim2.fromOffset(26, 10)
	local body = text(c, "", 14, TEXT, Enum.Font.Gotham, 33)
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.RichText = true
	body.Size = UDim2.new(1, -40, 1, -44)
	body.Position = UDim2.fromOffset(26, 38)
	return body
end

local earnBody = infoCard(moneyPage, UDim2.fromOffset(262, 0), UDim2.fromOffset(518, 214), GREEN, "COMO GANHAR ESCUDOS")
local spendBody = infoCard(moneyPage, UDim2.fromOffset(262, 226), UDim2.fromOffset(518, 134), GOLD, "ONDE GASTAR")
spendBody.Text = "<b>Dealers na rua</b>: tochas, fumo, estrobo, vela romana e cores. Procura o letreiro DEALER por cima deles (vai-se depressa de bicicleta: pega numa a porta da sede).\nAbre a loja a falar com ele."
local dailyCard = infoCard(moneyPage, UDim2.fromOffset(0, 162), UDim2.fromOffset(250, 144), Color3.fromRGB(120, 170, 255), "RECOMPENSA DIARIA")

--------------------------------------------------------------------------------
-- EQUIPAMENTO: o que o nivel de jogador desbloqueia
--------------------------------------------------------------------------------

local kitPage = tabs.equipamento.page
local kitNote = text(kitPage, "⚽ So aspeto: o nivel nunca te faz jogar melhor. Desbloqueia-se com o nivel de JOGADOR.", 14, MUTED, Enum.Font.GothamBold)
kitNote.Size = UDim2.new(1, 0, 0, 20)
kitNote.Position = UDim2.fromOffset(0, 0)

local function kitCard(x: number, heading: string, colour: Color3): (Frame, TextLabel)
	local c = box(kitPage, UDim2.fromOffset(250, 300), UDim2.fromOffset(x, 32), CARD, 32)
	corner(c, 14)
	local h = text(c, heading, 18, colour, Enum.Font.GothamBlack, 33)
	h.Size = UDim2.new(1, -24, 0, 26)
	h.Position = UDim2.fromOffset(14, 12)
	local lock = text(c, "", 13, MUTED, Enum.Font.GothamBold, 33)
	lock.TextWrapped = true
	lock.TextYAlignment = Enum.TextYAlignment.Top
	lock.Size = UDim2.new(1, -24, 0, 60)
	lock.Position = UDim2.new(0, 14, 1, -70)
	return c, lock
end

-- Numero.
local numberCard, numberLock = kitCard(0, "🔢 NUMERO", Color3.fromRGB(120, 170, 255))
local chosenNumber = 10
local numberBox = text(numberCard, "10", 64, TEXT, Enum.Font.GothamBlack, 33)
numberBox.TextXAlignment = Enum.TextXAlignment.Center
numberBox.Size = UDim2.new(1, 0, 0, 80)
numberBox.Position = UDim2.fromOffset(0, 50)
local minus = button(numberCard, "−", 26, Color3.fromRGB(60, 66, 88), TEXT, 33)
minus.Size = UDim2.fromOffset(56, 44)
minus.Position = UDim2.fromOffset(20, 138)
local plus = button(numberCard, "+", 26, Color3.fromRGB(60, 66, 88), TEXT, 33)
plus.Size = UDim2.fromOffset(56, 44)
plus.Position = UDim2.new(1, -76, 0, 138)
local wear = button(numberCard, "VESTIR", 16, GOLD, BG, 33)
wear.Size = UDim2.new(1, -40, 0, 40)
wear.Position = UDim2.fromOffset(20, 190)

-- Posicao.
local positionCard, positionLock = kitCard(265, "📍 POSICAO", Color3.fromRGB(70, 200, 110))
local positionButtons: { [string]: TextButton } = {}
for i, zone in { "ataque", "meio", "defesa" } do
	local b = button(positionCard, string.upper(zone), 16, Color3.fromRGB(60, 66, 88), TEXT, 33)
	b.Size = UDim2.new(1, -40, 0, 46)
	b.Position = UDim2.fromOffset(20, 50 + (i - 1) * 56)
	b.Activated:Connect(function()
		Remotes.Perfil:FireServer("posicao", zone)
	end)
	positionButtons[zone] = b
end

-- Botas.
local bootsCard, bootsLock = kitCard(530, "👟 BOTAS", Color3.fromRGB(255, 140, 60))
local bootButtons: { TextButton } = {}
for i, boot in Config.BootColours do
	local b = button(bootsCard, "", 10, boot.color, TEXT, 33)
	b.Size = UDim2.fromOffset(52, 52)
	b.Position = UDim2.fromOffset(20 + ((i - 1) % 3) * 72, 52 + ((i - 1) // 3) * 62)
	corner(b, 26)
	b.Activated:Connect(function()
		Remotes.Perfil:FireServer("botas", i)
	end)
	bootButtons[i] = b
end

minus.Activated:Connect(function()
	chosenNumber = if chosenNumber <= 1 then 99 else chosenNumber - 1
	numberBox.Text = tostring(chosenNumber)
end)
plus.Activated:Connect(function()
	chosenNumber = if chosenNumber >= 99 then 1 else chosenNumber + 1
	numberBox.Text = tostring(chosenNumber)
end)
wear.Activated:Connect(function()
	Remotes.Perfil:FireServer("numero", chosenNumber)
end)

--------------------------------------------------------------------------------
-- Pintar o que o servidor diz
--------------------------------------------------------------------------------

local profile: { [string]: any }? = nil
local numberShown = false

local function salaryText(p: { [string]: any }): string
	local S = P.salary
	local la = p.paths.adepto.level
	local lj = p.paths.jogador.level
	local lr = p.paths.arbitro.level
	local a = S.adepto.base + S.adepto.perLevel * la
	local j = S.jogador.base + S.jogador.perLevel * lj
	local r = S.arbitro.base + S.arbitro.perLevel * lr
	return "<b>1. Salario no fim de cada jogo</b> (sobe com o nivel). Hoje recebes:\n"
		.. "   📣 adepto " .. a .. "$ a " .. (a + Config.Money.perCorteo) .. "$ (mais se fizeres o corteo)\n"
		.. "   ⚽ jogador " .. j .. "$ (+" .. S.jogador.perGoal .. "$ por golo)   🟨 arbitro " .. r .. "$\n"
		.. "<b>2. Recompensa diaria</b>: entra todos os dias.\n"
		.. "<b>3. Assaltar caixas</b> nas lojas da cidade: 15$ a 35$.\n"
		.. "<b>4. Golos da tua equipa</b>: +" .. Config.Money.perGoal .. "$ a toda a claque."
end

local function paint()
	local p = profile
	if not p then
		return
	end
	local rich = player:GetAttribute("MoedasInfinitas") == true
	local money = if rich then "∞" else tostring(p.escudos)
	wallet.Text = "💰 " .. money .. "$"
	balanceValue.Text = money .. "$"

	for _, path in PATHS do
		local data = p.paths[path.id]
		local card = cards[path.id]
		if data and card then
			card.level.Text = tostring(data.level)
			if data.level >= P.maxLevel then
				card.bar.Size = UDim2.fromScale(1, 1)
				card.missing.Text = "NIVEL MAXIMO!"
			else
				card.bar.Size = UDim2.fromScale(math.clamp(data.xp / data.need, 0, 1), 1)
				card.missing.Text = "Faltam " .. (data.need - data.xp) .. " XP para o nivel " .. (data.level + 1)
			end
			card.reward.Text = "🎁 " .. data.nextReward
		end
	end

	earnBody.Text = salaryText(p)
	local streak = p.streak or 0
	local nextDay = (streak % #P.daily) + 1
	dailyCard.Text = "Hoje: dia <b>" .. math.max(streak, 1) .. "</b> de " .. #P.daily .. " seguidos.\n\nAmanha, se voltares: <b>+" .. P.daily[nextDay] .. "$</b>\nFalhar um dia volta ao dia 1.\nO dia 7 da " .. P.daily[#P.daily] .. "$!"

	local level = p.paths.jogador.level
	local canNumber = level >= K.numberAt
	for _, b in { minus, plus, wear } do
		b.Active = canNumber
		b.AutoButtonColor = canNumber
		b.BackgroundTransparency = if canNumber then 0 else 0.7
	end
	if canNumber and p.prefs.number and not numberShown then
		numberShown = true
		chosenNumber = p.prefs.number
		numberBox.Text = tostring(chosenNumber)
	end
	numberLock.Text = if canNumber then (if p.prefs.number then "Vestes o " .. p.prefs.number .. " (se ninguem da tua equipa o tiver)." else "Escolhe e carrega em VESTIR.") else "🔒 Nivel " .. K.numberAt .. " de jogador"
	local canPosition = level >= K.positionAt
	for zone, b in positionButtons do
		local on = p.prefs.position == zone
		b.Active = canPosition
		b.BackgroundColor3 = if on then Color3.fromRGB(70, 200, 110) else Color3.fromRGB(60, 66, 88)
		b.BackgroundTransparency = if canPosition then 0 else 0.7
	end
	positionLock.Text = if canPosition then "Ficas num lugar dessa zona do campo, se houver livre." else "🔒 Nivel " .. K.positionAt .. " de jogador"
	local canBoots = level >= K.bootsAt
	for i, b in bootButtons do
		b.Active = canBoots
		b.BackgroundTransparency = if canBoots then 0 else 0.75
		local stroke = b:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = if p.prefs.boots == i then 3 else 0
		stroke.Parent = b
	end
	bootsLock.Text = if level >= K.goldBootsAt then "✨ Botas douradas (nivel " .. K.goldBootsAt .. ")" elseif canBoots then "A cor das tuas botas." else "🔒 Nivel " .. K.bootsAt .. " de jogador"
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
showTab("niveis")

--------------------------------------------------------------------------------
-- A carteira: os Escudos sempre a vista, la em cima
--------------------------------------------------------------------------------

local TweenService = game:GetService("TweenService")

-- 1250 -> "1 250"
local function grouped(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^%s+", ""))
end

local pill = button(gui, "", 1, Color3.fromRGB(20, 18, 16), TEXT, 20)
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.Size = UDim2.fromOffset(170, 40)
pill.Position = UDim2.new(0.5, 0, 0, 12)
corner(pill, 20)
local pillStroke = Instance.new("UIStroke")
pillStroke.Color = GOLD
pillStroke.Thickness = 2
pillStroke.Parent = pill
local coin = box(pill, UDim2.fromOffset(30, 30), UDim2.fromOffset(5, 5), GOLD, 21)
corner(coin, 15)
gradient(coin, Color3.fromRGB(255, 226, 120), Color3.fromRGB(220, 150, 30), 45)
local coinMark = text(coin, "$", 20, Color3.fromRGB(120, 70, 10), Enum.Font.GothamBlack, 22)
coinMark.TextXAlignment = Enum.TextXAlignment.Center
coinMark.Size = UDim2.fromScale(1, 1)
local amount = text(pill, "0", 22, TEXT, Enum.Font.GothamBlack, 21)
amount.TextXAlignment = Enum.TextXAlignment.Right
amount.Size = UDim2.new(1, -50, 1, 0)
amount.Position = UDim2.fromOffset(38, 0)
-- O ponto vermelho: ha recompensa diaria por receber.
local dot = box(pill, UDim2.fromOffset(14, 14), UDim2.new(1, -8, 0, -4), Color3.fromRGB(240, 60, 60), 23)
corner(dot, 7)
dot.Visible = false

local shown = Instance.new("NumberValue")
shown.Value = 0
shown.Changed:Connect(function(v)
	amount.Text = if player:GetAttribute("MoedasInfinitas") then "∞" else grouped(v)
end)

-- "+40$" a subir e a apagar-se, ao lado da carteira.
local function floater(delta: number)
	local f = text(gui, (if delta > 0 then "+" else "−") .. grouped(math.abs(delta)) .. "$", 22, if delta > 0 then GREEN else Color3.fromRGB(240, 90, 80), Enum.Font.GothamBlack, 24)
	f.AnchorPoint = Vector2.new(0, 0.5)
	f.Size = UDim2.fromOffset(160, 30)
	f.Position = UDim2.new(0.5, 94, 0, 32)
	f.TextStrokeTransparency = 0.4
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(f, info, { Position = UDim2.new(0.5, 94, 0, 76), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.7, function()
		f:Destroy()
	end)
	-- A moeda da carteira da um pulo.
	TweenService:Create(coin, TweenInfo.new(0.12), { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(3, 3) }):Play()
	task.delay(0.14, function()
		TweenService:Create(coin, TweenInfo.new(0.2), { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(5, 5) }):Play()
	end)
end

local lastCoins: number? = nil
local function updateWallet()
	local value = player:GetAttribute("Moedas")
	if type(value) ~= "number" then
		return
	end
	if lastCoins ~= nil and value ~= lastCoins then
		floater(value - lastCoins)
	end
	lastCoins = value
	TweenService:Create(shown, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = value }):Play()
end
player:GetAttributeChangedSignal("Moedas"):Connect(updateWallet)
player:GetAttributeChangedSignal("MoedasInfinitas"):Connect(function()
	amount.Text = if player:GetAttribute("MoedasInfinitas") then "∞" else grouped(shown.Value)
end)
updateWallet()

pill.Activated:Connect(function()
	panel.Visible = true
	showTab("dinheiro")
	Remotes.Perfil:FireServer("pedir")
end)

--------------------------------------------------------------------------------
-- O calendario da recompensa diaria
--------------------------------------------------------------------------------

local calendar = box(gui, UDim2.fromOffset(700, 360), UDim2.fromScale(0.5, 0.5), BG, 50)
calendar.AnchorPoint = Vector2.new(0.5, 0.5)
calendar.Visible = false
corner(calendar, 16)
local calStroke = Instance.new("UIStroke")
calStroke.Color = GOLD
calStroke.Thickness = 3
calStroke.Parent = calendar
local calTop = box(calendar, UDim2.new(1, 0, 0, 70), UDim2.fromOffset(0, 0), GOLD, 51)
corner(calTop, 16)
gradient(calTop, Color3.fromRGB(255, 200, 70), Color3.fromRGB(240, 120, 40), 0)
local calTitle = text(calTop, "🎁 RECOMPENSA DIARIA", 28, BG, Enum.Font.GothamBlack, 52)
calTitle.Size = UDim2.new(1, -80, 0, 40)
calTitle.Position = UDim2.fromOffset(22, 6)
local calSub = text(calTop, "Entra todos os dias: cada dia seguido da mais! Falhar um dia volta ao dia 1.", 14, BG, Enum.Font.GothamBold, 52)
calSub.Size = UDim2.new(1, -80, 0, 18)
calSub.Position = UDim2.fromOffset(22, 44)
local calClose = button(calTop, "X", 18, Color3.fromRGB(40, 30, 20), TEXT, 53)
calClose.AnchorPoint = Vector2.new(1, 0.5)
calClose.Size = UDim2.fromOffset(38, 38)
calClose.Position = UDim2.new(1, -14, 0.5, 0)

type DayCard = { frame: Frame, stroke: UIStroke, label: TextLabel, reward: TextLabel, check: TextLabel, badge: TextLabel }
local days: { DayCard } = {}
local x = 20
for i = 1, #P.daily do
	local big = i == #P.daily
	local w = if big then 136 else 76
	local card = box(calendar, UDim2.fromOffset(w, 150), UDim2.fromOffset(x, 90), CARD, 51)
	corner(card, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 0
	stroke.Parent = card
	local label = text(card, "DIA " .. i, 13, MUTED, Enum.Font.GothamBlack, 52)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Position = UDim2.fromOffset(0, 8)
	local icon = text(card, if big then "🎁" else "💰", if big then 44 else 30, TEXT, Enum.Font.GothamBlack, 52)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.Size = UDim2.new(1, 0, 0, 56)
	icon.Position = UDim2.fromOffset(0, 32)
	local reward = text(card, "+" .. P.daily[i] .. "$", if big then 22 else 17, GOLD, Enum.Font.GothamBlack, 52)
	reward.TextXAlignment = Enum.TextXAlignment.Center
	reward.Size = UDim2.new(1, 0, 0, 24)
	reward.Position = UDim2.fromOffset(0, 94)
	local badge = text(card, "", 12, BG, Enum.Font.GothamBlack, 53)
	badge.TextXAlignment = Enum.TextXAlignment.Center
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = GOLD
	badge.Size = UDim2.new(1, -16, 0, 20)
	badge.Position = UDim2.fromOffset(8, 122)
	corner(badge, 6)
	local check = text(card, "✓", 60, GREEN, Enum.Font.GothamBlack, 54)
	check.TextXAlignment = Enum.TextXAlignment.Center
	check.Size = UDim2.fromScale(1, 1)
	check.TextStrokeTransparency = 0.3
	check.Visible = false
	days[i] = { frame = card, stroke = stroke, label = label, reward = reward, check = check, badge = badge }
	x += w + 8
end

local claim = button(calendar, "RECEBER", 22, GREEN, BG, 52)
claim.AnchorPoint = Vector2.new(0.5, 1)
claim.Size = UDim2.fromOffset(320, 56)
claim.Position = UDim2.new(0.5, 0, 1, -22)
corner(claim, 14)

local dailyInfo: { [string]: any }? = nil
local dailyReceivedAt = 0

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

local function paintCalendar()
	local d = dailyInfo
	if not d then
		return
	end
	for i, card in days do
		local claimed = if d.claimable then i < d.day else i <= d.day
		local isToday = i == d.day
		card.check.Visible = claimed
		card.frame.BackgroundColor3 = if claimed then Color3.fromRGB(34, 60, 44) elseif isToday then Color3.fromRGB(70, 56, 24) else CARD
		card.stroke.Thickness = if isToday and d.claimable then 3 else 0
		card.badge.Visible = isToday or claimed
		card.badge.Text = if claimed then "RECEBIDO" elseif isToday then "HOJE" else ""
		card.badge.BackgroundColor3 = if claimed then GREEN else GOLD
		card.label.TextColor3 = if isToday then GOLD else MUTED
	end
	if d.claimable then
		claim.Text = "RECEBER  +" .. P.daily[d.day] .. "$"
		claim.BackgroundColor3 = GREEN
		claim.Active = true
		claim.AutoButtonColor = true
	else
		local left = (d.secondsLeft or 0) - (os.clock() - dailyReceivedAt)
		claim.Text = "VOLTA AMANHA  ·  " .. clock(left)
		claim.BackgroundColor3 = Color3.fromRGB(70, 74, 90)
		claim.Active = false
		claim.AutoButtonColor = false
	end
	dot.Visible = d.claimable == true
end

-- O relogio do "volta amanha" anda sozinho.
task.spawn(function()
	while true do
		task.wait(1)
		if calendar.Visible then
			paintCalendar()
		end
	end
end)

claim.Activated:Connect(function()
	local d = dailyInfo
	if d and d.claimable then
		Remotes.Perfil:FireServer("receber_diaria")
		claim.Text = "..."
	end
end)
calClose.Activated:Connect(function()
	calendar.Visible = false
end)
dot.Active = false

local function openCalendar()
	calendar.Visible = true
	paintCalendar()
end

-- O botao do calendario, no separador do dinheiro.
local calButton = button(moneyPage, "📅 VER CALENDARIO", 14, Color3.fromRGB(120, 170, 255), BG, 33)
calButton.Size = UDim2.fromOffset(214, 34)
calButton.Position = UDim2.fromOffset(18, 314)
calButton.Activated:Connect(openCalendar)

local function onDaily(d: any)
	if type(d) ~= "table" then
		return
	end
	dailyInfo = d
	dailyReceivedAt = os.clock()
	paintCalendar()
end

--------------------------------------------------------------------------------
-- Avisos: subir de nivel, recompensa diaria, resumo do jogo
--------------------------------------------------------------------------------

local toast = box(gui, UDim2.fromOffset(480, 70), UDim2.new(0.5, 0, 0, 90), GOLD, 40)
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Visible = false
corner(toast, 12)
gradient(toast, Color3.fromRGB(255, 210, 80), Color3.fromRGB(230, 140, 40), 90)
local toastTitle = text(toast, "", 22, BG, Enum.Font.GothamBlack, 41)
toastTitle.TextXAlignment = Enum.TextXAlignment.Center
toastTitle.Size = UDim2.new(1, -20, 0, 28)
toastTitle.Position = UDim2.fromOffset(10, 8)
local toastLine = text(toast, "", 15, BG, Enum.Font.GothamBold, 41)
toastLine.TextXAlignment = Enum.TextXAlignment.Center
toastLine.Size = UDim2.new(1, -20, 0, 22)
toastLine.Position = UDim2.fromOffset(10, 38)

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

-- O resumo do fim do jogo.
local summary = box(gui, UDim2.fromOffset(480, 220), UDim2.fromScale(0.5, 0.42), BG, 40)
summary.AnchorPoint = Vector2.new(0.5, 0.5)
summary.Visible = false
corner(summary, 14)
local summaryStroke = Instance.new("UIStroke")
summaryStroke.Color = GOLD
summaryStroke.Thickness = 3
summaryStroke.Parent = summary
local summaryTitle = text(summary, "🏁 FIM DO JOGO", 24, GOLD, Enum.Font.GothamBlack, 41)
summaryTitle.TextXAlignment = Enum.TextXAlignment.Center
summaryTitle.Size = UDim2.new(1, 0, 0, 32)
summaryTitle.Position = UDim2.fromOffset(0, 12)
local summaryBody = text(summary, "", 16, TEXT, Enum.Font.GothamBold, 41)
summaryBody.TextXAlignment = Enum.TextXAlignment.Center
summaryBody.TextYAlignment = Enum.TextYAlignment.Top
summaryBody.TextWrapped = true
summaryBody.Size = UDim2.new(1, -30, 1, -104)
summaryBody.Position = UDim2.fromOffset(15, 52)
local summaryPay = text(summary, "", 28, GREEN, Enum.Font.GothamBlack, 41)
summaryPay.TextXAlignment = Enum.TextXAlignment.Center
summaryPay.Size = UDim2.new(1, 0, 0, 34)
summaryPay.Position = UDim2.new(0, 0, 1, -46)

local PATH_TITLE = { adepto = "📣 ADEPTO", jogador = "⚽ JOGADOR", arbitro = "🟨 ARBITRO" }

Remotes.Perfil.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	if data.kind == "perfil" then
		profile = data
		paint()
		onDaily(data.daily)
	elseif data.kind == "diaria_pronta" then
		onDaily(data.daily)
		openCalendar()
	elseif data.kind == "nivel" then
		showToast("⭐ SUBISTE DE NIVEL!", (PATH_TITLE[data.path] or "") .. "  ·  NIVEL " .. tostring(data.level), 4)
	elseif data.kind == "diaria" then
		showToast("🎁 RECOMPENSA DIARIA", "Dia " .. tostring(data.day) .. " seguido  ·  +" .. tostring(data.reward) .. "$", 5)
	elseif data.kind == "resumo" and type(data.lines) == "table" then
		summaryBody.Text = table.concat(data.lines, "\n")
		summaryPay.Text = if (data.pay or 0) > 0 then "💰 +" .. tostring(data.pay) .. "$" else ""
		summary.Visible = true
		task.delay(12, function()
			summary.Visible = false
		end)
	end
end)

-- Pede o perfil logo que o ecra arranca.
Remotes.Perfil:FireServer("pedir")
