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

--[[
	Sons. Poe aqui os ids dos teus audios (rbxassetid://NUMERO) e passa a haver
	som sem mexer em mais nada. Vazios, o jogo funciona igual — so em silencio.

	Comeca pelo `drum`: e o som que manda na bancada.
]]
local SOUNDS = {
	drum = "",
	goal = "",
}

local function play(id: string, volume: number?)
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.PlayOnRemove = true
	sound.Parent = workspace
	sound:Destroy()
end

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
title.Position = UDim2.new(0, 20, 0.5, -150)

local subtitle = label(menu, "Sais da sede, vais com o corteo, e entras no estadio", 16, MUTED)
subtitle.Font = Enum.Font.Gotham
subtitle.Size = UDim2.new(1, -40, 0, 22)
subtitle.Position = UDim2.new(0, 20, 0.5, -108)

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
	choice(team.name, "claque  ·  tochas, fumo, corteo", team.color, (index == 1) and -232 or 12, 220, -56, teamId)
end

choice("Apitar o jogo", "arbitro  ·  decides, e podes ceder", Color3.fromRGB(46, 50, 58), -232, 452, 36, "arbitro")

--------------------------------------------------------------------------------
-- Quem sou
--------------------------------------------------------------------------------

local function myRole(): string?
	return player:GetAttribute("Team")
end

local roleLabel = label(gui, "", 14, MUTED)
roleLabel.Font = Enum.Font.Gotham
roleLabel.Size = UDim2.new(1, 0, 0, 20)
roleLabel.Position = UDim2.new(0, 0, 1, -100)

local function refreshRole()
	local role = myRole()
	if role == "arbitro" then
		myTeam = nil
		roleLabel.Text = "apitas este jogo"
		roleLabel.TextColor3 = TEXT
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

local scoreLabel = label(gui, "0 - 0", 40, TEXT)
scoreLabel.Size = UDim2.new(1, 0, 0, 46)
scoreLabel.Position = UDim2.new(0, 0, 0, 16)

local phaseLabel = label(gui, "", 14, MUTED)
phaseLabel.Font = Enum.Font.Gotham
phaseLabel.Size = UDim2.new(1, 0, 0, 20)
phaseLabel.Position = UDim2.new(0, 0, 0, 62)

local goalLabel = label(gui, "", 30, TEXT)
goalLabel.Size = UDim2.new(1, 0, 0, 36)
goalLabel.Position = UDim2.new(0, 0, 0, 88)

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
ownTrack.Position = UDim2.new(0.5, 0, 1, -48)
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
gearLabel.Position = UDim2.new(0.5, 0, 1, -78)
gearLabel.AnchorPoint = Vector2.new(0.5, 0)

local hint = label(gui, "material na sede    ·    B  pedir ao arbitro    ·    T  tifo    ·    espaco  saltar", 12, MUTED)
hint.Font = Enum.Font.Gotham
hint.Size = UDim2.new(1, 0, 0, 16)
hint.Position = UDim2.new(0, 0, 1, -26)

local stock = {
	tocha = Config.Gear.tocha.perMatch,
	fumo = Config.Gear.fumo.perMatch,
	tambor = Config.Gear.tambor.perMatch,
}

local function updateGearLabel()
	local pieces = {}
	if stock.tocha > 0 then
		table.insert(pieces, stock.tocha .. " tochas")
	end
	if stock.fumo > 0 then
		table.insert(pieces, stock.fumo .. " fumos")
	end
	if stock.tambor > 0 then
		table.insert(pieces, "tambor")
	end

	if #pieces == 0 then
		gearLabel.Text = "mochila vazia"
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

-- O painel de decisao, so para quem apita.
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(420, 132)
panel.Position = UDim2.new(0.5, -210, 0.5, -66)
panel.BackgroundColor3 = INK
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelTitle = label(panel, "", 20, TEXT)
panelTitle.Size = UDim2.new(1, -24, 0, 26)
panelTitle.Position = UDim2.new(0, 12, 0, 14)

local panelPressure = label(panel, "", 13, BRASS)
panelPressure.Font = Enum.Font.Gotham
panelPressure.Size = UDim2.new(1, -24, 0, 18)
panelPressure.Position = UDim2.new(0, 12, 0, 42)

local choiceButtons: { TextButton } = {}
for i = 1, 2 do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 186, 0, 42)
	b.Position = UDim2.new(0, i == 1 and 12 or 222, 1, -54)
	b.BackgroundColor3 = i == 1 and Color3.fromRGB(79, 180, 119) or Color3.fromRGB(224, 84, 78)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = TEXT
	b.Text = ""
	b.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b

	table.insert(choiceButtons, b)
end

Remotes.Incident.OnClientEvent:Connect(function(incident, pressureByTeam)
	if not incident then
		panel.Visible = false
		return
	end

	local team = Config.Teams[incident.teamId]
	panelTitle.Text = incident.kind == "golo"
		and ("Golo do " .. team.name .. " — conta?")
		or ("Penalti para o " .. team.name .. "?")

	local parts = {}
	for teamId, count in pressureByTeam do
		if count > 0 then
			table.insert(parts, Config.Teams[teamId].short .. ": " .. count)
		end
	end
	panelPressure.Text = #parts > 0 and ("a bancada pede  —  " .. table.concat(parts, "   ")) or ""

	for i, b in choiceButtons do
		b.Text = string.upper(incident.options[i])
		b.Activated:Once(function()
			Remotes.Decide:FireServer(incident.options[i])
			panel.Visible = false
		end)
	end

	panel.Visible = true
end)

Remotes.RefState.OnClientEvent:Connect(function(payload)
	local state = payload.state
	if state and state.name then
		refBadge.Text = "arbitro: " .. state.name
		suspTrack.Visible = true
		suspFill.Size = UDim2.fromScale(math.clamp(state.suspicion / state.max, 0, 1), 1)
	else
		refBadge.Text = "sem arbitro"
		suspTrack.Visible = false
	end

	local resolved = payload.resolved
	if resolved then
		local team = Config.Teams[resolved.team]
		if resolved.caught then
			goalLabel.Text = "ARBITRO APANHADO"
			goalLabel.TextColor3 = Color3.fromRGB(224, 84, 78)
		elseif resolved.kind == "golo" and resolved.choice == "anular" then
			goalLabel.Text = "GOLO ANULADO  " .. team.short
			goalLabel.TextColor3 = Color3.fromRGB(224, 84, 78)
		end
		task.delay(4, function()
			if goalLabel.Text ~= "" then
				goalLabel.Text = ""
			end
		end)
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
	warmup = "CORTEO  —  segue a faixa ate ao estadio",
	first = "1a PARTE",
	halftime = "INTERVALO",
	second = "2a PARTE",
	fulltime = "FINAL",
}

local lastGoalStamp = 0

Remotes.MatchState.OnClientEvent:Connect(function(snapshot)
	scoreLabel.Text = string.format("%d - %d", snapshot.score.home, snapshot.score.away)
	phaseLabel.Text = string.format("%s  ·  %d", PHASE_TEXT[snapshot.phase] or "", snapshot.clock)

	if snapshot.lastGoal and snapshot.goalStamp > lastGoalStamp then
		lastGoalStamp = snapshot.goalStamp
		local team = Config.Teams[snapshot.lastGoal]
		goalLabel.Text = "GOLO  " .. team.short
		goalLabel.TextColor3 = team.color
		play(SOUNDS.goal, 0.7)
		task.delay(4, function()
			if lastGoalStamp == snapshot.goalStamp then
				goalLabel.Text = ""
			end
		end)
	end
end)

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
