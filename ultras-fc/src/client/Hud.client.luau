--!strict
--[[
	O que o adepto ve.

	Escolhe-se o lado a entrada e o resto e material: tocha, fumo, tambor. Nao ha
	minijogo de ritmo nenhum — o apoio e estar la, levar material e bater no
	tambor, nao acertar num botao ao compasso.

	Regra do ecra: ESPACO E PARA SALTAR, sempre. Um jogo passado numa bancada tem
	de deixar saltar.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local TifoDesigns = require(Shared:WaitForChild("TifoDesigns"))

local player = Players.LocalPlayer
local myTeam: string? = nil

local INK = Color3.fromRGB(14, 17, 22)
local TEXT = Color3.fromRGB(232, 234, 237)
local MUTED = Color3.fromRGB(141, 150, 163)
local BRASS = Color3.fromRGB(217, 164, 65)

local gui = Instance.new("ScreenGui")
gui.Name = "UltrasHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent: Instance, text: string, size: number, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.Text = text
	l.TextSize = size
	l.TextColor3 = colour
	l.Parent = parent
	return l
end

--------------------------------------------------------------------------------
-- Menu de entrada
--------------------------------------------------------------------------------

--[[
	Escolhe-se o papel a entrada e o servidor poe cada um no seu sitio: os
	adeptos a porta da sede da claque, o arbitro na praca.

	O balcao da sede continua a funcionar para trocar de lado depois — o menu e
	para nao se ficar parado na rua a adivinhar, nao para substituir o mundo.
]]
local menu = Instance.new("Frame")
menu.Size = UDim2.fromScale(1, 1)
menu.BackgroundColor3 = INK
menu.BackgroundTransparency = 0.06
menu.Parent = gui

local title = label(menu, "Escolhe o teu papel", 34, TEXT)
title.Size = UDim2.new(1, -40, 0, 44)
title.Position = UDim2.new(0, 20, 0.5, -196)

local subtitle = label(menu, "Sais da sede, vais com o corteo, e entras no estadio", 16, MUTED)
subtitle.Font = Enum.Font.Gotham
subtitle.Size = UDim2.new(1, -40, 0, 22)
subtitle.Position = UDim2.new(0, 20, 0.5, -154)

local function choice(text: string, note: string, colour: Color3, x: number, width: number, y: number, pick: string)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, width, 0, 76)
	button.Position = UDim2.new(0.5, x, 0.5, y)
	button.BackgroundColor3 = colour
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = ""
	button.Parent = menu

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	local name = label(button, text, 19, TEXT)
	name.Size = UDim2.new(1, 0, 0, 24)
	name.Position = UDim2.new(0, 0, 0, 16)

	local hintText = label(button, note, 13, Color3.fromRGB(232, 234, 237))
	hintText.Font = Enum.Font.Gotham
	hintText.TextTransparency = 0.35
	hintText.Size = UDim2.new(1, 0, 0, 18)
	hintText.Position = UDim2.new(0, 0, 0, 42)

	button.Activated:Connect(function()
		Remotes.PickTeam:FireServer(pick)
		menu.Visible = false
	end)
end

for index, teamId in Config.TeamOrder do
	local team = Config.Teams[teamId]
	choice(team.name, "claque  ·  tochas, fumo, corteo", team.color, (index == 1) and -232 or 12, 220, -100, teamId)
end

-- Jogar: escolhe-se a equipa, e fica-se com o primeiro lugar livre. Com o
-- lugar vazio joga um boneco, por isso ha sempre jogo.
for index, teamId in Config.TeamOrder do
	local team = Config.Teams[teamId]
	local x = (index == 1) and -232 or 12
	choice("Jogar pelo " .. team.short, "jogador  ·  4 + guarda-redes", team.color:Lerp(INK, 0.35), x, 150, -8, "jogador:" .. teamId)
	-- A baliza, ao lado: se ninguem a quiser, fica la um boneco.
	choice("GR", "baliza", team.keeperColor:Lerp(INK, 0.35), x + 156, 64, -8, "baliza:" .. teamId)
end

choice("Apitar o jogo", "arbitro  ·  decides, e podes ceder", Color3.fromRGB(46, 50, 58), -232, 452, 84, "arbitro")

--------------------------------------------------------------------------------
-- Quem sou
--------------------------------------------------------------------------------

local function myRole(): string?
	return player:GetAttribute("Team")
end

local roleLabel = label(gui, "", 14, MUTED)
roleLabel.Font = Enum.Font.Gotham
roleLabel.Size = UDim2.new(1, 0, 0, 20)
roleLabel.Position = UDim2.new(0, 0, 1, -166)

local function refreshRole()
	local role = myRole()
	if role == "arbitro" then
		myTeam = nil
		roleLabel.Text = "apitas este jogo"
		roleLabel.TextColor3 = TEXT
	elseif role == "jogador" then
		myTeam = nil
		local pitchTeam = Config.Teams[player:GetAttribute("PitchTeam") or ""]
		if pitchTeam then
			local where = if player:GetAttribute("Keeper") == true then "  ·  na baliza" else ""
			roleLabel.Text = "jogas pelo " .. pitchTeam.name .. "  ·  n.º " .. tostring(player:GetAttribute("Number") or "") .. where
			roleLabel.TextColor3 = pitchTeam.color
		end
	elseif role and Config.Teams[role] then
		myTeam = role
		local suffix = player:GetAttribute("Leader") and "  ·  lider" or ""
		roleLabel.Text = "claque do " .. Config.Teams[role].name .. suffix
		roleLabel.TextColor3 = Config.Teams[role].color
	else
		myTeam = nil
		roleLabel.Text = "segue um dos feixes de luz ate a sede de uma claque"
		roleLabel.TextColor3 = MUTED
	end
end

player:GetAttributeChangedSignal("Team"):Connect(refreshRole)
player:GetAttributeChangedSignal("Leader"):Connect(refreshRole)
refreshRole()

--------------------------------------------------------------------------------
-- Marcador
--------------------------------------------------------------------------------

--[[
	O marcador, num canto, sempre: na rua, na sede, na bancada ou no relvado.
	O jogo acontece com ou sem quem o ve, e toda a gente quer saber como vai.
	Em cima o resultado e o relogio; em baixo a fase e o que vem a seguir.
]]
local phaseBox = Instance.new("Frame")
phaseBox.Size = UDim2.fromOffset(300, 70)
phaseBox.Position = UDim2.fromOffset(16, 60)
phaseBox.BackgroundColor3 = INK
phaseBox.BackgroundTransparency = 0.2
phaseBox.BorderSizePixel = 0
phaseBox.ZIndex = 5
phaseBox.Parent = gui

local phaseBoxCorner = Instance.new("UICorner")
phaseBoxCorner.CornerRadius = UDim.new(0, 8)
phaseBoxCorner.Parent = phaseBox

-- As cores das duas equipas, uma risca de cada lado do marcador.
for index, teamId in Config.TeamOrder do
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.fromOffset(4, 26)
	stripe.Position = if index == 1 then UDim2.fromOffset(6, 7) else UDim2.fromOffset(204, 7)
	stripe.BackgroundColor3 = Config.Teams[teamId].color
	stripe.BorderSizePixel = 0
	stripe.ZIndex = 6
	stripe.Parent = phaseBox
end

local scoreLabel = label(phaseBox, "", 18, TEXT)
scoreLabel.Font = Enum.Font.GothamBlack
scoreLabel.Size = UDim2.fromOffset(188, 30)
scoreLabel.Position = UDim2.fromOffset(14, 5)
scoreLabel.ZIndex = 6

local phaseClock = label(phaseBox, "", 22, TEXT)
phaseClock.Font = Enum.Font.GothamBlack
phaseClock.TextXAlignment = Enum.TextXAlignment.Right
phaseClock.Size = UDim2.fromOffset(80, 30)
phaseClock.Position = UDim2.new(1, -90, 0, 5)
phaseClock.ZIndex = 6

local phaseLabel = label(phaseBox, "", 12, BRASS)
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
phaseLabel.Size = UDim2.new(1, -24, 0, 14)
phaseLabel.Position = UDim2.fromOffset(12, 37)
phaseLabel.ZIndex = 6

local phaseNote = label(phaseBox, "", 12, MUTED)
phaseNote.Font = Enum.Font.Gotham
phaseNote.TextXAlignment = Enum.TextXAlignment.Left
phaseNote.Size = UDim2.new(1, -24, 0, 14)
phaseNote.Position = UDim2.fromOffset(12, 52)
phaseNote.ZIndex = 6

-- A hora do dia no jogo, ao canto: de noite acendem-se as luzes.
local dayClock = label(phaseBox, "", 12, MUTED)
dayClock.TextXAlignment = Enum.TextXAlignment.Right
dayClock.Size = UDim2.fromOffset(60, 14)
dayClock.Position = UDim2.new(1, -72, 0, 37)
dayClock.ZIndex = 6

task.spawn(function()
	local Lighting = game:GetService("Lighting")
	while true do
		local hour = Lighting.ClockTime
		dayClock.Text = string.format("%02d:%02d", math.floor(hour), math.floor((hour % 1) * 60))
		task.wait(1)
	end
end)

--[[
	Voltar a sede quando se quer. Ninguem e mandado para casa a forca: o dia de
	jogo recomeca la, e quem quiser ir carrega aqui.
]]
local homeButton = Instance.new("TextButton")
homeButton.Size = UDim2.fromOffset(84, 28)
homeButton.Position = UDim2.fromOffset(16, 136)
homeButton.BackgroundColor3 = Color3.fromRGB(58, 62, 72)
homeButton.BackgroundTransparency = 0.15
homeButton.BorderSizePixel = 0
homeButton.Font = Enum.Font.GothamBold
homeButton.TextSize = 12
homeButton.TextColor3 = TEXT
homeButton.Text = "SEDE"
homeButton.Parent = gui

local homeCorner = Instance.new("UICorner")
homeCorner.CornerRadius = UDim.new(0, 6)
homeCorner.Parent = homeButton

homeButton.Activated:Connect(function()
	Remotes.Home:FireServer()
end)

--[[
	Trocar de equipa ou de papel a qualquer altura: claque, jogador, baliza ou
	apito. Abre o mesmo menu da entrada; o X fecha-o sem mudar nada.
]]
local swapButton = Instance.new("TextButton")
swapButton.Size = UDim2.fromOffset(84, 28)
swapButton.Position = UDim2.fromOffset(16, 170)
swapButton.BackgroundColor3 = BRASS:Lerp(INK, 0.35)
swapButton.BackgroundTransparency = 0.1
swapButton.BorderSizePixel = 0
swapButton.Font = Enum.Font.GothamBold
swapButton.TextSize = 12
swapButton.TextColor3 = TEXT
swapButton.Text = "TROCAR"
swapButton.Parent = gui

local swapCorner = Instance.new("UICorner")
swapCorner.CornerRadius = UDim.new(0, 6)
swapCorner.Parent = swapButton

-- Segundos que faltam ate se poder trocar outra vez (o servidor decide; isto so mostra).
local function switchWait(): number
	local readyAt = player:GetAttribute("SwitchReadyAt")
	if type(readyAt) ~= "number" then
		return 0
	end
	return math.max(math.ceil(readyAt - workspace:GetServerTimeNow()), 0)
end

swapButton.Activated:Connect(function()
	if switchWait() == 0 then
		menu.Visible = true
	end
end)

task.spawn(function()
	while true do
		local wait = switchWait()
		swapButton.Text = if wait > 0 then string.format("TROCAR %ds", wait) else "TROCAR"
		swapButton.TextTransparency = if wait > 0 then 0.45 else 0
		task.wait(0.5)
	end
end)

local closeMenu = Instance.new("TextButton")
closeMenu.AnchorPoint = Vector2.new(1, 0)
closeMenu.Size = UDim2.fromOffset(44, 44)
closeMenu.Position = UDim2.new(1, -24, 0, 70)
closeMenu.BackgroundColor3 = Color3.fromRGB(58, 62, 72)
closeMenu.BorderSizePixel = 0
closeMenu.Font = Enum.Font.GothamBlack
closeMenu.TextSize = 22
closeMenu.TextColor3 = TEXT
closeMenu.Text = "X"
closeMenu.Parent = menu

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeMenu

closeMenu.Activated:Connect(function()
	menu.Visible = false
end)

--[[
	O menu de animacoes de adepto (G, ou o botao). Escolher uma poe-na a
	andar; escolher a mesma outra vez, ou mexer-se, para-a. Toda a gente a ve:
	o servidor guarda qual e, e cada ecra anima-a (Poses.client).
]]
local emoteButton = Instance.new("TextButton")
emoteButton.AnchorPoint = Vector2.new(1, 1)
emoteButton.Size = UDim2.fromOffset(130, 30)
emoteButton.Position = UDim2.new(1, -20, 1, -96)
emoteButton.BackgroundColor3 = Color3.fromRGB(58, 62, 72)
emoteButton.BackgroundTransparency = 0.15
emoteButton.BorderSizePixel = 0
emoteButton.Font = Enum.Font.GothamBold
emoteButton.TextSize = 12
emoteButton.TextColor3 = TEXT
emoteButton.Text = "G  ANIMACOES"
emoteButton.Parent = gui

local emoteCorner = Instance.new("UICorner")
emoteCorner.CornerRadius = UDim.new(0, 6)
emoteCorner.Parent = emoteButton

local emotePanel = Instance.new("Frame")
emotePanel.AnchorPoint = Vector2.new(1, 1)
emotePanel.Size = UDim2.fromOffset(170, 12 + #Config.Emotes * 34)
emotePanel.Position = UDim2.new(1, -20, 1, -132)
emotePanel.BackgroundColor3 = INK
emotePanel.BackgroundTransparency = 0.15
emotePanel.BorderSizePixel = 0
emotePanel.Visible = false
emotePanel.Parent = gui

local emotePanelCorner = Instance.new("UICorner")
emotePanelCorner.CornerRadius = UDim.new(0, 8)
emotePanelCorner.Parent = emotePanel

local emoteRows: { [string]: TextButton } = {}
for index, emote in Config.Emotes do
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -12, 0, 30)
	row.Position = UDim2.fromOffset(6, 6 + (index - 1) * 34)
	row.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
	row.BorderSizePixel = 0
	row.Font = Enum.Font.GothamBold
	row.TextSize = 14
	row.TextColor3 = TEXT
	row.Text = emote.label
	row.Parent = emotePanel
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 6)
	rowCorner.Parent = row
	emoteRows[emote.id] = row

	row.Activated:Connect(function()
		local current = player:GetAttribute("Emote")
		Remotes.Emote:FireServer(if current == emote.id then "" else emote.id)
	end)
end

-- A que esta a andar fica acesa na lista.
local function refreshEmotes()
	local current = player:GetAttribute("Emote")
	for id, row in emoteRows do
		row.BackgroundColor3 = if id == current then BRASS:Lerp(INK, 0.3) else Color3.fromRGB(40, 44, 52)
	end
end
player:GetAttributeChangedSignal("Emote"):Connect(refreshEmotes)

local function toggleEmotes()
	emotePanel.Visible = not emotePanel.Visible
end
emoteButton.Activated:Connect(toggleEmotes)
ContextActionService:BindAction("Animacoes", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		toggleEmotes()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.G)

local goalLabel = label(gui, "", 30, TEXT)
goalLabel.Size = UDim2.new(1, 0, 0, 36)
goalLabel.Position = UDim2.new(0, 0, 0, 88)

--[[
	O golo, e o resultado final, em grande no meio do ecra. Num golo fica uns
	segundos e volta para o marcador la em cima; no fim fica durante o rescaldo.
]]
local bigTitle = label(gui, "", 64, TEXT)
bigTitle.Font = Enum.Font.GothamBlack
bigTitle.Size = UDim2.new(1, 0, 0, 72)
bigTitle.Position = UDim2.new(0, 0, 0.3, 0)
bigTitle.TextStrokeTransparency = 0.4
bigTitle.Visible = false

local bigScore = label(gui, "", 30, TEXT)
bigScore.Size = UDim2.new(1, 0, 0, 36)
bigScore.Position = UDim2.new(0, 0, 0.3, 76)
bigScore.TextStrokeTransparency = 0.5
bigScore.Visible = false

local bigNote = label(gui, "", 20, BRASS)
bigNote.Size = UDim2.new(1, 0, 0, 26)
bigNote.Position = UDim2.new(0, 0, 0.3, 118)
bigNote.TextStrokeTransparency = 0.5
bigNote.Visible = false

--[[
	A reposicao em curso, para toda a gente, e para se perceber em dois
	segundos: o que aconteceu, de quem e, quem bate, e quanto falta.
]]
local RESTART_TEXT = {
	lancamento = "LANCAMENTO",
	canto = "CANTO",
	baliza = "PONTAPE DE BALIZA",
	livre = "FALTA  ·  LIVRE",
	penalti = "PENALTI",
}

local restartBox = Instance.new("Frame")
restartBox.AnchorPoint = Vector2.new(0.5, 0)
restartBox.Size = UDim2.fromOffset(360, 64)
restartBox.Position = UDim2.new(0.5, 0, 0, 140)
restartBox.BackgroundColor3 = INK
restartBox.BackgroundTransparency = 0.2
restartBox.BorderSizePixel = 0
restartBox.Visible = false
restartBox.Parent = gui

local restartCorner = Instance.new("UICorner")
restartCorner.CornerRadius = UDim.new(0, 8)
restartCorner.Parent = restartBox

local restartStripe = Instance.new("Frame")
restartStripe.Size = UDim2.new(0, 6, 1, 0)
restartStripe.BorderSizePixel = 0
restartStripe.Parent = restartBox

local restartLabel = label(restartBox, "", 22, TEXT)
restartLabel.Font = Enum.Font.GothamBlack
restartLabel.TextXAlignment = Enum.TextXAlignment.Left
restartLabel.Size = UDim2.new(1, -80, 0, 28)
restartLabel.Position = UDim2.fromOffset(18, 6)

local restartTaker = label(restartBox, "", 14, MUTED)
restartTaker.Font = Enum.Font.Gotham
restartTaker.TextXAlignment = Enum.TextXAlignment.Left
restartTaker.Size = UDim2.new(1, -80, 0, 18)
restartTaker.Position = UDim2.fromOffset(18, 36)

local restartCount = label(restartBox, "", 30, TEXT)
restartCount.Font = Enum.Font.GothamBlack
restartCount.TextXAlignment = Enum.TextXAlignment.Right
restartCount.Size = UDim2.fromOffset(60, 52)
restartCount.Position = UDim2.new(1, -72, 0, 6)

local function refreshRestart()
	local value = workspace:GetAttribute("Restart")
	if type(value) ~= "string" then
		restartBox.Visible = false
		return
	end
	local kind, teamId = string.match(value, "^(%w+):(%w+)$")
	local team = Config.Teams[teamId or ""]
	restartLabel.Text = RESTART_TEXT[kind or ""] or ""
	restartStripe.BackgroundColor3 = if team then team.color else TEXT
	local taker = workspace:GetAttribute("RestartTaker")
	local teamName = if team then team.short else ""
	restartTaker.Text = if type(taker) == "string" then "bate " .. taker .. "  ·  " .. teamName else teamName
	restartBox.Visible = true
end
workspace:GetAttributeChangedSignal("Restart"):Connect(refreshRestart)
workspace:GetAttributeChangedSignal("RestartTaker"):Connect(refreshRestart)
refreshRestart()

-- A contagem dos segundos que faltam para a bola ficar viva ali.
RunService.Heartbeat:Connect(function()
	if not restartBox.Visible then
		return
	end
	local untilAt = workspace:GetAttribute("RestartUntil")
	if type(untilAt) == "number" then
		restartCount.Text = tostring(math.max(math.ceil(untilAt - workspace:GetServerTimeNow()), 0))
	else
		restartCount.Text = ""
	end
end)

--------------------------------------------------------------------------------
-- As duas bancadas
--------------------------------------------------------------------------------

local bars: { [string]: Frame } = {}

for index, teamId in Config.TeamOrder do
	local team = Config.Teams[teamId]
	local onLeft = index == 1

	local track = Instance.new("Frame")
	track.Size = UDim2.new(0, 22, 0, 220)
	track.Position = UDim2.new(onLeft and 0 or 1, onLeft and 20 or -42, 0.5, -110)
	track.BackgroundColor3 = Color3.fromRGB(43, 51, 61)
	track.BackgroundTransparency = 0.25
	track.BorderSizePixel = 0
	track.Parent = gui

	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = team.color
	fill.BorderSizePixel = 0
	fill.Parent = track

	local tag = label(track, team.short, 12, MUTED)
	tag.Font = Enum.Font.Gotham
	tag.Size = UDim2.new(1, 20, 0, 16)
	tag.Position = UDim2.new(0, -10, 1, 5)

	bars[teamId] = fill
end

-- A da propria bancada junto ao rodape, onde a vista ja esta: as das bordas
-- ficam longe do sitio para onde se esta a olhar.
local ownTrack = Instance.new("Frame")
ownTrack.AnchorPoint = Vector2.new(0.5, 1)
ownTrack.Size = UDim2.fromOffset(240, 6)
ownTrack.Position = UDim2.new(0.5, 0, 1, -94)
ownTrack.BackgroundColor3 = Color3.fromRGB(43, 51, 61)
ownTrack.BackgroundTransparency = 0.3
ownTrack.BorderSizePixel = 0
ownTrack.Parent = gui

local ownFill = Instance.new("Frame")
ownFill.Size = UDim2.fromScale(0, 1)
ownFill.BackgroundColor3 = BRASS
ownFill.BorderSizePixel = 0
ownFill.Parent = ownTrack

--------------------------------------------------------------------------------
-- Material
--------------------------------------------------------------------------------

local gearLabel = label(gui, "", 13, BRASS)
gearLabel.Size = UDim2.new(1, 0, 0, 18)
gearLabel.Position = UDim2.new(0.5, 0, 1, -142)
gearLabel.AnchorPoint = Vector2.new(0.5, 0)

local hint = label(gui, "1-4 material na barra    ·    clica para acender    ·    B  pedir ao arbitro    ·    T  tifo    ·    espaco  saltar", 12, MUTED)
hint.Font = Enum.Font.Gotham
hint.Size = UDim2.new(1, 0, 0, 16)
hint.Position = UDim2.new(0, 0, 1, -118)

--[[
	Cada um ve so o que e seu. O material, as teclas da bancada e a barra da
	propria bancada sao de quem e de claque; em campo as teclas sao outras, e
	quem as mostra e o Football.client; quem apita tem o seu aviso e o botao.
]]
local function refreshHint()
	local role = myRole()
	local claque = role ~= nil and Config.Teams[role] ~= nil
	hint.Visible = claque
	gearLabel.Visible = claque
	ownTrack.Visible = claque
end
player:GetAttributeChangedSignal("Team"):Connect(refreshHint)
refreshHint()

local stock = {
	tocha = Config.Gear.tocha.perMatch,
	fumo = Config.Gear.fumo.perMatch,
	tambor = 0,
}

-- -1 quer dizer sem limite (Config.GearStock.unlimited, nos testes).
local function updateGearLabel()
	local pieces = {}
	if stock.tocha < 0 then
		table.insert(pieces, "tochas e fumo sem limite")
	else
		if stock.tocha > 0 then
			table.insert(pieces, stock.tocha .. " tochas")
		end
		if stock.fumo > 0 then
			table.insert(pieces, stock.fumo .. " fumos")
		end
	end
	if stock.tambor > 0 then
		table.insert(pieces, "tambor")
	end

	if #pieces == 0 then
		gearLabel.Text = "sem tochas nem fumo ate ao proximo jogo"
		gearLabel.TextColor3 = MUTED
	else
		gearLabel.Text = table.concat(pieces, "   ·   ")
		gearLabel.TextColor3 = BRASS
	end
end

updateGearLabel()

Remotes.GearCount.OnClientEvent:Connect(function(counts)
	for kind, value in counts do
		stock[kind] = value
	end
	updateGearLabel()
end)

--------------------------------------------------------------------------------
-- O arbitro
--------------------------------------------------------------------------------

-- Visivel a toda a gente: quem apita e o quanto ja cheira mal. Sem a barra a
-- vista, ceder nao teria custo nenhum.
local refBadge = label(gui, "", 13, MUTED)
refBadge.Font = Enum.Font.Gotham
refBadge.Size = UDim2.new(0, 300, 0, 18)
refBadge.Position = UDim2.new(0.5, -150, 0, 116)

local suspTrack = Instance.new("Frame")
suspTrack.Size = UDim2.fromOffset(180, 5)
suspTrack.Position = UDim2.new(0.5, -90, 0, 136)
suspTrack.BackgroundColor3 = Color3.fromRGB(43, 51, 61)
suspTrack.BackgroundTransparency = 0.3
suspTrack.BorderSizePixel = 0
suspTrack.Visible = false
suspTrack.Parent = gui

local suspFill = Instance.new("Frame")
suspFill.Size = UDim2.fromScale(0, 1)
suspFill.BackgroundColor3 = Color3.fromRGB(224, 84, 78)
suspFill.BorderSizePixel = 0
suspFill.Parent = suspTrack

--[[
	O painel de decisao, so para quem apita: o que aconteceu, quem, onde, e as
	opcoes. Poucos segundos — se nao decidir, sai a decisao natural.
]]
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(560, 150)
panel.Position = UDim2.new(0.5, -280, 0.5, -75)
panel.BackgroundColor3 = INK
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelTitle = label(panel, "", 19, TEXT)
panelTitle.Size = UDim2.new(1, -24, 0, 24)
panelTitle.Position = UDim2.new(0, 12, 0, 12)

local panelDetail = label(panel, "", 13, MUTED)
panelDetail.Font = Enum.Font.Gotham
panelDetail.Size = UDim2.new(1, -24, 0, 18)
panelDetail.Position = UDim2.new(0, 12, 0, 38)

local panelPressure = label(panel, "", 13, BRASS)
panelPressure.Font = Enum.Font.Gotham
panelPressure.Size = UDim2.new(1, -24, 0, 18)
panelPressure.Position = UDim2.new(0, 12, 0, 58)

local panelClock = label(panel, "", 13, MUTED)
panelClock.Font = Enum.Font.GothamBold
panelClock.Size = UDim2.new(0, 40, 0, 18)
panelClock.Position = UDim2.new(1, -52, 0, 14)

local function optionColour(id: string): Color3
	if id == "nada" then
		return Color3.fromRGB(70, 76, 88)
	elseif string.find(id, "vermelho") then
		return Color3.fromRGB(196, 52, 48)
	elseif string.find(id, "amarelo") then
		return Color3.fromRGB(214, 170, 40)
	end
	return Color3.fromRGB(58, 132, 92)
end

local current: { id: number, options: { { id: string, label: string } } }? = nil
local closesAt = 0

local choiceButtons: { TextButton } = {}
for i = 1, 4 do
	local b = Instance.new("TextButton")
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = TEXT
	b.TextWrapped = true
	b.Text = ""
	b.Visible = false
	b.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b

	b.Activated:Connect(function()
		local incident = current
		if not incident then
			return
		end
		local option = incident.options[i]
		if option then
			Remotes.Decide:FireServer(option.id)
			current = nil
			panel.Visible = false
		end
	end)
	table.insert(choiceButtons, b)
end

Remotes.Incident.OnClientEvent:Connect(function(incident, pressureByTeam)
	if not incident then
		current = nil
		panel.Visible = false
		return
	end

	panelTitle.Text = incident.title
	panelDetail.Text = incident.detail

	local parts = {}
	for teamId, count in pressureByTeam do
		if count > 0 then
			table.insert(parts, Config.Teams[teamId].short .. ": " .. count)
		end
	end
	panelPressure.Text = #parts > 0 and ("a bancada pede  —  " .. table.concat(parts, "   ")) or ""

	-- O mesmo lance chega outra vez a cada grito das bancadas: nao se mexe nos
	-- botoes nem no relogio, so na pressao.
	if current and current.id == incident.id then
		return
	end
	current = incident
	closesAt = os.clock() + incident.seconds

	local count = #incident.options
	local gap = 8
	local width = (536 - gap * (count - 1)) / count
	for i, b in choiceButtons do
		local option = incident.options[i]
		b.Visible = option ~= nil
		if option then
			b.Text = string.upper(option.label)
			b.BackgroundColor3 = optionColour(option.id)
			b.Size = UDim2.new(0, width, 0, 46)
			b.Position = UDim2.new(0, 12 + (i - 1) * (width + gap), 1, -58)
		end
	end
	panel.Visible = true
end)

RunService.RenderStepped:Connect(function()
	if panel.Visible then
		panelClock.Text = string.format("%.0fs", math.max(closesAt - os.clock(), 0))
	end
end)

--[[
	A janela de uma entrada: dois segundos em que o arbitro pode apitar, com o
	jogo a correr. Toda a gente ve o aviso e a barra a esvaziar; quem apita ve o
	botao APITAR (ou carrega em E); as claques podem pedir (B). Nao apitar e
	deixar seguir — nao ha botao para isso.
]]
local entry = Instance.new("Frame")
entry.AnchorPoint = Vector2.new(0.5, 0)
entry.Size = UDim2.fromOffset(420, 64)
entry.Position = UDim2.new(0.5, 0, 0, 180)
entry.BackgroundColor3 = INK
entry.BackgroundTransparency = 0.15
entry.BorderSizePixel = 0
entry.Visible = false
entry.Parent = gui

local entryCorner = Instance.new("UICorner")
entryCorner.CornerRadius = UDim.new(0, 10)
entryCorner.Parent = entry

local entryTitle = label(entry, "", 16, TEXT)
entryTitle.Size = UDim2.new(1, -24, 0, 20)
entryTitle.Position = UDim2.fromOffset(12, 8)

local entryDetail = label(entry, "", 12, MUTED)
entryDetail.Font = Enum.Font.Gotham
entryDetail.Size = UDim2.new(1, -24, 0, 16)
entryDetail.Position = UDim2.fromOffset(12, 28)

local entryTrack = Instance.new("Frame")
entryTrack.Size = UDim2.new(1, -24, 0, 5)
entryTrack.Position = UDim2.new(0, 12, 1, -12)
entryTrack.BackgroundColor3 = Color3.fromRGB(43, 51, 61)
entryTrack.BorderSizePixel = 0
entryTrack.Parent = entry

local entryFill = Instance.new("Frame")
entryFill.Size = UDim2.fromScale(1, 1)
entryFill.BackgroundColor3 = BRASS
entryFill.BorderSizePixel = 0
entryFill.Parent = entryTrack

local whistleButton = Instance.new("TextButton")
whistleButton.AnchorPoint = Vector2.new(0.5, 0)
whistleButton.Size = UDim2.fromOffset(240, 58)
whistleButton.Position = UDim2.new(0.5, 0, 0, 252)
whistleButton.BackgroundColor3 = Color3.fromRGB(214, 170, 40)
whistleButton.BorderSizePixel = 0
whistleButton.Font = Enum.Font.GothamBlack
whistleButton.TextSize = 24
whistleButton.TextColor3 = INK
whistleButton.Text = "E   APITAR"
whistleButton.Visible = false
whistleButton.Parent = gui

local whistleCorner = Instance.new("UICorner")
whistleCorner.CornerRadius = UDim.new(0, 10)
whistleCorner.Parent = whistleButton

local entryEndsAt = 0
local entrySeconds = 2

local function blowWhistle()
	if entry.Visible and myRole() == "arbitro" then
		Remotes.Decide:FireServer("apitar")
		entry.Visible = false
		whistleButton.Visible = false
	end
end

whistleButton.Activated:Connect(blowWhistle)

ContextActionService:BindAction("Apitar", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		blowWhistle()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.E)

local function showEntry(w: any)
	if not w then
		entry.Visible = false
		whistleButton.Visible = false
		return
	end
	entryTitle.Text = string.upper(w.title)
	local role = myRole()
	if role == "arbitro" then
		entryDetail.Text = w.detail .. "   ·   apitas?"
	elseif myTeam then
		entryDetail.Text = w.detail .. "   ·   B  pede falta"
	else
		entryDetail.Text = w.detail .. "   ·   o arbitro apita?"
	end
	entryEndsAt = w.endsAt
	entrySeconds = w.seconds
	entry.Visible = true
	whistleButton.Visible = role == "arbitro"
end

RunService.RenderStepped:Connect(function()
	if not entry.Visible then
		return
	end
	local left = entryEndsAt - workspace:GetServerTimeNow()
	if left <= 0 then
		entry.Visible = false
		whistleButton.Visible = false
		return
	end
	entryFill.Size = UDim2.fromScale(math.clamp(left / entrySeconds, 0, 1), 1)
end)

Remotes.RefState.OnClientEvent:Connect(function(payload)
	showEntry(payload.window)
	local state = payload.state
	if state and state.name then
		refBadge.Text = "arbitro: " .. state.name
		suspTrack.Visible = true
		suspFill.Size = UDim2.fromScale(math.clamp(state.suspicion / state.max, 0, 1), 1)
	else
		refBadge.Text = "sem arbitro"
		suspTrack.Visible = false
	end

	-- Sem lance aberto, o painel fecha (decidido, ou o tempo acabou).
	if not payload.pending and not payload.resolved and panel.Visible then
		current = nil
		panel.Visible = false
	end

	-- A decisao, para toda a gente.
	local resolved = payload.resolved
	if resolved then
		if current then
			current = nil
			panel.Visible = false
		end
		local text = resolved.text
		if resolved.caught then
			text = "ARBITRO APANHADO" .. (if text then "   ·   " .. text else "")
		end
		if text then
			goalLabel.Text = text
			goalLabel.TextColor3 = if resolved.caught then Color3.fromRGB(224, 84, 78) else TEXT
			local shown = text
			task.delay(3, function()
				if goalLabel.Text == shown then
					goalLabel.Text = ""
				end
			end)
		end
	end
end)

-- B: pedir ao arbitro. Nao e dinheiro, e a bancada a gritar — vale pelo numero
-- de vozes e por serem recentes.
ContextActionService:BindAction("Pedir", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and myTeam then
		Remotes.Pressure:FireServer()
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.B)

ContextActionService:SetTitle("Pedir", "PEDIR")

--------------------------------------------------------------------------------
-- Ligacao ao servidor
--------------------------------------------------------------------------------

Remotes.Atmosphere.OnClientEvent:Connect(function(levels)
	for teamId, fill in bars do
		local fraction = (levels[teamId] or 0) / Config.Atmosphere.max
		fill.Size = UDim2.fromScale(1, math.clamp(fraction, 0, 1))
	end

	if myTeam then
		local mine = (levels[myTeam] or 0) / Config.Atmosphere.max
		ownFill.Size = UDim2.fromScale(math.clamp(mine, 0, 1), 1)
	end
end)

local PHASE_TEXT = {
	clubhouse = { "NA SEDE", "material, lider e a tua claque" },
	corteo = { "CORTEO", "o lider guia, a claque vai atras da faixa" },
	espera = { "A ESPERA DAS BANCADAS", "" },
	entrada = { "ENTRADA EM CAMPO", "" },
	first = { "1a PARTE", "" },
	halftime = { "INTERVALO", "" },
	second = { "2a PARTE", "" },
	fulltime = { "FIM DO JOGO", "a seguir, novo dia na sede" },
}

local function scoreLine(score: { [string]: number }): string
	local home, away = Config.Teams[Config.TeamOrder[1]], Config.Teams[Config.TeamOrder[2]]
	return string.format("%s  %d - %d  %s", home.short, score[home.id], score[away.id], away.short)
end

local lastGoalStamp = 0
local bigUntil = 0 -- o golo em grande some-se a esta hora (os.clock)
local shownPhase = ""

local function showBig(title: string, colour: Color3, score: string, note: string, seconds: number)
	bigTitle.Text = title
	bigTitle.TextColor3 = colour
	bigScore.Text = score
	bigNote.Text = note
	bigTitle.Visible = true
	bigScore.Visible = true
	bigNote.Visible = note ~= ""
	bigUntil = os.clock() + seconds
end

Remotes.MatchState.OnClientEvent:Connect(function(snapshot)
	scoreLabel.Text = scoreLine(snapshot.score)

	local text = PHASE_TEXT[snapshot.phase] or { "", "" }
	phaseLabel.Text = text[1]
	phaseNote.Text = text[2]
	if snapshot.phase == "espera" then
		local ready, total = workspace:GetAttribute("StandsReady"), workspace:GetAttribute("StandsTotal")
		if type(ready) == "number" and type(total) == "number" and total > 0 then
			phaseNote.Text = string.format("%d/%d na bancada", ready, total)
		end
	end
	phaseClock.Text = string.format("%d:%02d", snapshot.clock // 60, snapshot.clock % 60)

	if snapshot.lastGoal and snapshot.goalStamp > lastGoalStamp then
		local fresh = lastGoalStamp > 0 or workspace:GetServerTimeNow() - snapshot.goalStamp < 3
		lastGoalStamp = snapshot.goalStamp
		if fresh then
			local team = Config.Teams[snapshot.lastGoal]
			-- A quem tem tocha ou fumo e e da claque que marcou: e agora.
			local lightUp = myTeam == snapshot.lastGoal and (stock.tocha ~= 0 or stock.fumo ~= 0)
			showBig("GOLO", team.color, team.name .. "    " .. scoreLine(snapshot.score), if lightUp then "ACENDE AS TOCHAS" else "", 6)
		end
	end

	-- O apito final: o resultado em grande durante o rescaldo.
	if snapshot.phase ~= shownPhase then
		shownPhase = snapshot.phase
		if snapshot.phase == "fulltime" then
			local home, away = snapshot.score.home, snapshot.score.away
			local winner = if home > away then Config.Teams.home elseif away > home then Config.Teams.away else nil
			showBig(
				"FIM DO JOGO",
				if winner then winner.color else TEXT,
				scoreLine(snapshot.score),
				if winner then "vitoria do " .. winner.name else "empate",
				snapshot.clock
			)
		elseif bigTitle.Text == "FIM DO JOGO" then
			bigUntil = 0
		end
	end
end)

RunService.RenderStepped:Connect(function()
	if (bigTitle.Visible or bigNote.Visible) and os.clock() >= bigUntil then
		bigTitle.Visible = false
		bigScore.Visible = false
		bigNote.Visible = false
	end
end)

--[[
	A fila parada a frente da bancada principal: e o momento das tochas. A quem
	e de claque e ainda tem material, diz-se-lhe que e agora.
]]
local function refreshLineHint()
	local line = workspace:GetAttribute("EntranceLine") == true
	if line and myTeam and (stock.tocha ~= 0 or stock.fumo ~= 0) then
		showBig("", TEXT, "", "ACENDE AS TOCHAS", Config.Entrance.lineSeconds)
		bigTitle.Visible = false
		bigScore.Visible = false
	elseif not line and bigNote.Text == "ACENDE AS TOCHAS" and bigTitle.Text == "" then
		bigUntil = 0
	end
end
workspace:GetAttributeChangedSignal("EntranceLine"):Connect(refreshLineHint)

--------------------------------------------------------------------------------
-- O que dizem os NPCs da sede
--------------------------------------------------------------------------------

--[[
	Uma janela ao meio do ecra com o que o NPC da mesa disse: as instrucoes da
	inscricao, a loja, ou o que o lider pode fazer. Fecha-se no OK, ou sozinha
	ao afastar-se da mesa.
]]
local talk = Instance.new("Frame")
talk.AnchorPoint = Vector2.new(0.5, 0.5)
talk.Size = UDim2.fromOffset(460, 230)
talk.Position = UDim2.fromScale(0.5, 0.5)
talk.BackgroundColor3 = INK
talk.BackgroundTransparency = 0.08
talk.BorderSizePixel = 0
talk.Visible = false
talk.ZIndex = 20
talk.Parent = gui

local talkCorner = Instance.new("UICorner")
talkCorner.CornerRadius = UDim.new(0, 10)
talkCorner.Parent = talk

local talkTitle = label(talk, "", 20, BRASS)
talkTitle.Font = Enum.Font.GothamBlack
talkTitle.Size = UDim2.new(1, -32, 0, 28)
talkTitle.Position = UDim2.fromOffset(16, 14)
talkTitle.TextXAlignment = Enum.TextXAlignment.Left
talkTitle.ZIndex = 21

local talkBody = label(talk, "", 14, TEXT)
talkBody.Font = Enum.Font.Gotham
talkBody.Size = UDim2.new(1, -32, 1, -100)
talkBody.Position = UDim2.fromOffset(16, 48)
talkBody.TextXAlignment = Enum.TextXAlignment.Left
talkBody.TextYAlignment = Enum.TextYAlignment.Top
talkBody.TextWrapped = true
talkBody.ZIndex = 21

local talkOk = Instance.new("TextButton")
talkOk.AnchorPoint = Vector2.new(0.5, 1)
talkOk.Size = UDim2.fromOffset(120, 34)
talkOk.Position = UDim2.new(0.5, 0, 1, -12)
talkOk.BackgroundColor3 = BRASS:Lerp(INK, 0.3)
talkOk.BorderSizePixel = 0
talkOk.Font = Enum.Font.GothamBold
talkOk.TextSize = 14
talkOk.TextColor3 = TEXT
talkOk.Text = "OK"
talkOk.ZIndex = 21
talkOk.Parent = talk

local talkOkCorner = Instance.new("UICorner")
talkOkCorner.CornerRadius = UDim.new(0, 6)
talkOkCorner.Parent = talkOk

local talkedAt: Vector3? = nil

talkOk.Activated:Connect(function()
	talk.Visible = false
end)

Remotes.Npc.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or type(message.title) ~= "string" or type(message.lines) ~= "table" then
		return
	end
	talkTitle.Text = message.title
	local lines = {}
	for _, line in message.lines do
		if type(line) == "string" then
			table.insert(lines, "•  " .. line)
		end
	end
	talkBody.Text = table.concat(lines, "\n\n")
	talk.Visible = true
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	talkedAt = root and root.Position or nil
end)

-- Afastar-se da mesa fecha a janela.
RunService.Heartbeat:Connect(function()
	if not talk.Visible or not talkedAt then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and (root.Position - talkedAt).Magnitude > 16 then
		talk.Visible = false
	end
end)

--------------------------------------------------------------------------------
-- Saltar de fase (so admins)
--------------------------------------------------------------------------------

--[[
	Para testar e para mostrar o jogo sem esperar. O botao so aparece a quem
	esta em Config.Admins; quem decide se o salto conta e o servidor, pela mesma
	lista — esconder o botao nao chega para impedir ninguem.
]]
if table.find(Config.Admins, player.UserId) then
	local skip = Instance.new("TextButton")
	skip.Size = UDim2.fromOffset(120, 28)
	skip.Position = UDim2.fromOffset(108, 136)
	skip.BackgroundColor3 = Color3.fromRGB(58, 62, 72)
	skip.BackgroundTransparency = 0.15
	skip.BorderSizePixel = 0
	skip.Font = Enum.Font.GothamBold
	skip.TextSize = 12
	skip.TextColor3 = TEXT
	skip.Text = "]  SALTAR FASE"
	skip.Parent = gui

	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 6)
	skipCorner.Parent = skip

	skip.Activated:Connect(function()
		Remotes.Admin:FireServer("skip")
	end)

	ContextActionService:BindAction("SaltarFase", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Remotes.Admin:FireServer("skip")
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.RightBracket)
end

--------------------------------------------------------------------------------
-- Tifos
--------------------------------------------------------------------------------

--[[
	O lider ve um botao com os tifos que restam e se agora e o momento certo;
	carrega, escolhe o desenho, e sai. Quem esta no bloco recebe a cor do seu
	lugar e carrega em T para levantar.

	O aviso de "momento certo" esta ali para o lider decidir com a informacao
	toda: o tifo vale o dobro no apito inicial e depois de um golo nosso.
]]

local TIFO = Config.Tifo
local lastSnapshot: any = nil
local tifoLeft: { [string]: number } = {}
local tifoActive: { [string]: any } = {}
local myCard: any = nil
local pickerOpen = false

Remotes.MatchState.OnClientEvent:Connect(function(snapshot)
	lastSnapshot = snapshot
end)

local function isPlaying(): boolean
	return lastSnapshot ~= nil and (lastSnapshot.phase == "first" or lastSnapshot.phase == "second")
end

-- A mesma conta que o servidor faz, para o lider saber antes de carregar.
local function isMoment(): boolean
	local snap = lastSnapshot
	if not snap or not myTeam then
		return false
	end
	if snap.phase == "first" and Config.Match.halfLength - snap.clock <= TIFO.momentWindow then
		return true
	end
	return snap.lastGoal == myTeam and workspace:GetServerTimeNow() - snap.goalStamp <= TIFO.momentWindow
end

local function isLeader(): boolean
	return player:GetAttribute("Leader") == true
end

-- O botao do lider, no canto de baixo a direita.
local tifoButton = Instance.new("TextButton")
tifoButton.AnchorPoint = Vector2.new(1, 1)
tifoButton.Size = UDim2.fromOffset(210, 54)
tifoButton.Position = UDim2.new(1, -20, 1, -20)
tifoButton.BackgroundColor3 = INK
tifoButton.BackgroundTransparency = 0.15
tifoButton.BorderSizePixel = 0
tifoButton.Text = ""
tifoButton.Visible = false
tifoButton.Parent = gui

local tifoButtonCorner = Instance.new("UICorner")
tifoButtonCorner.CornerRadius = UDim.new(0, 10)
tifoButtonCorner.Parent = tifoButton

local tifoButtonTitle = label(tifoButton, "", 16, TEXT)
tifoButtonTitle.Size = UDim2.new(1, 0, 0, 22)
tifoButtonTitle.Position = UDim2.new(0, 0, 0, 7)

local tifoButtonNote = label(tifoButton, "", 12, MUTED)
tifoButtonNote.Font = Enum.Font.Gotham
tifoButtonNote.Size = UDim2.new(1, 0, 0, 16)
tifoButtonNote.Position = UDim2.new(0, 0, 0, 31)

-- O seletor: um cartao por desenho, com o desenho em ponto pequeno.
local picker = Instance.new("Frame")
picker.AnchorPoint = Vector2.new(1, 1)
picker.Size = UDim2.fromOffset(#TIFO.designs * 150 + 10, 150)
picker.Position = UDim2.new(1, -20, 1, -84)
picker.BackgroundColor3 = INK
picker.BackgroundTransparency = 0.1
picker.BorderSizePixel = 0
picker.Visible = false
picker.Parent = gui

local pickerCorner = Instance.new("UICorner")
pickerCorner.CornerRadius = UDim.new(0, 12)
pickerCorner.Parent = picker

local previews: { { cells: { Frame }, design: any } } = {}

for i, design in TIFO.designs do
	local card = Instance.new("TextButton")
	card.Size = UDim2.fromOffset(140, 130)
	card.Position = UDim2.fromOffset(10 + (i - 1) * 150, 10)
	card.BackgroundColor3 = Color3.fromRGB(30, 35, 43)
	card.BorderSizePixel = 0
	card.Text = ""
	card.Parent = picker

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	-- Cada quadrado do desenho, pintado quando se sabe a equipa.
	local cell = 8
	local grid = Instance.new("Frame")
	grid.Size = UDim2.fromOffset(TIFO.columns * cell, TIFO.rows * cell)
	grid.Position = UDim2.new(0.5, -TIFO.columns * cell / 2, 0, 12)
	grid.BackgroundTransparency = 1
	grid.Parent = card

	local cells = {}
	for r = 1, TIFO.rows do
		for c = 1, TIFO.columns do
			local square = Instance.new("Frame")
			square.Size = UDim2.fromOffset(cell - 1, cell - 1)
			square.Position = UDim2.fromOffset((c - 1) * cell, (r - 1) * cell)
			square.BorderSizePixel = 0
			square.Parent = grid
			cells[(r - 1) * TIFO.columns + c] = square
		end
	end
	table.insert(previews, { cells = cells, design = design })

	local name = label(card, design.name, 15, TEXT)
	name.Size = UDim2.new(1, 0, 0, 20)
	name.Position = UDim2.new(0, 0, 1, -34)

	card.Activated:Connect(function()
		Remotes.Tifo:FireServer("launch", design.id)
		pickerOpen = false
		picker.Visible = false
	end)
end

local function paintPreviews()
	if not myTeam then
		return
	end
	for _, preview in previews do
		local rows = TifoDesigns.rows(preview.design, myTeam)
		for r = 1, TIFO.rows do
			for c = 1, TIFO.columns do
				preview.cells[(r - 1) * TIFO.columns + c].BackgroundColor3 =
					TifoDesigns.colour(string.sub(rows[r] or "", c, c), myTeam)
			end
		end
	end
end

player:GetAttributeChangedSignal("Team"):Connect(paintPreviews)
paintPreviews()

local function canLaunch(): boolean
	return myTeam ~= nil and isLeader() and isPlaying() and not tifoActive[myTeam] and (tifoLeft[myTeam] or TIFO.perMatch) > 0
end

local function togglePicker()
	pickerOpen = not pickerOpen and canLaunch()
	picker.Visible = pickerOpen
end

tifoButton.Activated:Connect(togglePicker)

-- O aviso a meio do ecra: o que vai subir, quando, e se o momento e bom.
local tifoBanner = label(gui, "", 30, TEXT)
tifoBanner.Font = Enum.Font.GothamBlack
tifoBanner.Size = UDim2.new(1, 0, 0, 38)
tifoBanner.Position = UDim2.new(0, 0, 0.26, 0)

local tifoBannerNote = label(gui, "", 14, MUTED)
tifoBannerNote.Font = Enum.Font.Gotham
tifoBannerNote.Size = UDim2.new(1, 0, 0, 20)
tifoBannerNote.Position = UDim2.new(0, 0, 0.26, 40)

-- A cartolina de cada um, por cima da barra do rodape.
local cardPrompt = Instance.new("Frame")
cardPrompt.AnchorPoint = Vector2.new(0.5, 1)
cardPrompt.Size = UDim2.fromOffset(300, 44)
cardPrompt.Position = UDim2.new(0.5, 0, 1, -104)
cardPrompt.BackgroundColor3 = INK
cardPrompt.BackgroundTransparency = 0.15
cardPrompt.BorderSizePixel = 0
cardPrompt.Visible = false
cardPrompt.Parent = gui

local cardPromptCorner = Instance.new("UICorner")
cardPromptCorner.CornerRadius = UDim.new(0, 10)
cardPromptCorner.Parent = cardPrompt

local swatch = Instance.new("Frame")
swatch.Size = UDim2.fromOffset(30, 30)
swatch.Position = UDim2.fromOffset(7, 7)
swatch.BorderSizePixel = 0
swatch.Parent = cardPrompt

local swatchStroke = Instance.new("UIStroke")
swatchStroke.Color = TEXT
swatchStroke.Thickness = 1
swatchStroke.Parent = swatch

local cardText = label(cardPrompt, "", 15, TEXT)
cardText.Size = UDim2.new(1, -48, 1, 0)
cardText.Position = UDim2.fromOffset(44, 0)
cardText.TextXAlignment = Enum.TextXAlignment.Left

local function lift()
	if myCard and not myCard.lifted then
		myCard.lifted = true
		Remotes.Tifo:FireServer("lift")
	end
end

-- T: levantar a cartolina se houver uma na mao; senao, o lider abre o seletor.
ContextActionService:BindAction("Tifo", function(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if myCard and not myCard.lifted and workspace:GetServerTimeNow() < myCard.lowerAt then
		lift()
	elseif isLeader() then
		togglePicker()
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.T)

ContextActionService:SetTitle("Tifo", "TIFO")

Remotes.TifoState.OnClientEvent:Connect(function(payload)
	if payload.kind == "card" then
		myCard = { colour = payload.colour, raiseAt = payload.raiseAt, lowerAt = payload.lowerAt, lifted = false }
		swatch.BackgroundColor3 = payload.colour
		return
	end

	tifoLeft[payload.teamId] = payload.left
	tifoActive[payload.teamId] = payload.active and payload or nil
	if payload.teamId == myTeam and not payload.active then
		myCard = nil
	end
end)

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()

	-- O botao do lider.
	local leaderHere = myTeam ~= nil and isLeader() and isPlaying()
	tifoButton.Visible = leaderHere
	if leaderHere and myTeam then
		local left = tifoLeft[myTeam] or TIFO.perMatch
		tifoButtonTitle.Text = string.format("T  TIFO  (%d)", left)
		if tifoActive[myTeam] then
			tifoButtonNote.Text = "no ar"
			tifoButtonNote.TextColor3 = MUTED
		elseif left <= 0 then
			tifoButtonNote.Text = "acabaram-se neste jogo"
			tifoButtonNote.TextColor3 = MUTED
		elseif isMoment() then
			tifoButtonNote.Text = "MOMENTO CERTO  ·  vale o dobro"
			tifoButtonNote.TextColor3 = BRASS
		else
			tifoButtonNote.Text = "fora de tempo  ·  vale metade"
			tifoButtonNote.TextColor3 = MUTED
		end
	end
	if pickerOpen and not canLaunch() then
		pickerOpen = false
		picker.Visible = false
	end

	-- O aviso: o tifo de qualquer claque le-se no ecra de toda a gente.
	local shown = (myTeam and tifoActive[myTeam]) or nil
	if not shown then
		for _, teamId in Config.TeamOrder do
			shown = shown or tifoActive[teamId]
		end
	end

	if shown and t < shown.lowerAt then
		local team = Config.Teams[shown.teamId]
		tifoBanner.TextColor3 = team.color
		if t < shown.raiseAt then
			tifoBanner.Text = string.format("TIFO %s  ·  %d", string.upper(shown.name), math.ceil(shown.raiseAt - t))
		else
			tifoBanner.Text = "TIFO " .. string.upper(shown.name)
		end
		tifoBannerNote.Text = team.name .. (shown.strong and "  ·  no momento certo" or "  ·  fora de tempo")
	else
		tifoBanner.Text = ""
		tifoBannerNote.Text = ""
	end

	-- A cartolina na mao.
	if myCard and t < myCard.lowerAt then
		cardPrompt.Visible = true
		if myCard.lifted then
			cardText.Text = "cartolina no ar"
		elseif t < myCard.raiseAt then
			cardText.Text = "a tua cor  ·  T para levantar"
		else
			cardText.Text = "T  LEVANTA A CARTOLINA"
		end
	else
		cardPrompt.Visible = false
	end
end)
