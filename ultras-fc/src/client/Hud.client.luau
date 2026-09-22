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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

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
-- Escolher lado
--------------------------------------------------------------------------------

local picker = Instance.new("Frame")
picker.Size = UDim2.fromScale(1, 1)
picker.BackgroundColor3 = INK
picker.BackgroundTransparency = 0.08
picker.Parent = gui

local pickTitle = label(picker, "Escolhe o teu lado", 34, TEXT)
pickTitle.Size = UDim2.new(1, -40, 0, 44)
pickTitle.Position = UDim2.new(0, 20, 0.5, -140)

local pickHint = label(picker, "Sais da sede e vais com o corteo ate ao estadio", 16, MUTED)
pickHint.Font = Enum.Font.Gotham
pickHint.Size = UDim2.new(1, -40, 0, 22)
pickHint.Position = UDim2.new(0, 20, 0.5, -98)

for index, teamId in Config.TeamOrder do
	local team = Config.Teams[teamId]

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 220, 0, 74)
	button.Position = UDim2.new(0.5, (index == 1) and -232 or 12, 0.5, -40)
	button.BackgroundColor3 = team.color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = team.name
	button.TextSize = 19
	button.TextColor3 = TEXT
	button.Parent = picker

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	button.Activated:Connect(function()
		myTeam = teamId
		Remotes.PickTeam:FireServer(teamId)
		picker.Visible = false
	end)
end

-- O apito e um papel como os outros, e e o unico que decide jogos.
local refButton = Instance.new("TextButton")
refButton.Size = UDim2.new(0, 452, 0, 46)
refButton.Position = UDim2.new(0.5, -226, 0.5, 46)
refButton.BackgroundColor3 = Color3.fromRGB(38, 42, 50)
refButton.BorderSizePixel = 0
refButton.Font = Enum.Font.GothamBold
refButton.Text = "Apitar o jogo"
refButton.TextSize = 16
refButton.TextColor3 = MUTED
refButton.Parent = picker

local refCorner = Instance.new("UICorner")
refCorner.CornerRadius = UDim.new(0, 10)
refCorner.Parent = refButton

local amReferee = false

refButton.Activated:Connect(function()
	amReferee = true
	Remotes.PickTeam:FireServer("arbitro")
	picker.Visible = false
end)

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

local hint = label(gui, "F  tocha    G  fumo    T  tambor    B  pedir ao arbitro    espaco  saltar", 12, MUTED)
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

--[[
	As teclas so pedem o material; ele vai para a mochila. Usa-se depois, ao
	pegar nele e clicar — o gesto de o levantar e metade da coisa, e no tambor e
	cada clique que e uma pancada.
]]
for kind, key in { tocha = Enum.KeyCode.F, fumo = Enum.KeyCode.G, tambor = Enum.KeyCode.T } do
	local action = "Pedir_" .. kind
	ContextActionService:BindAction(action, function(_, inputState)
		if inputState == Enum.UserInputState.Begin and myTeam then
			Remotes.Gear:FireServer(kind)
		end
		return Enum.ContextActionResult.Pass
	end, true, key)

	ContextActionService:SetTitle(action, string.upper(kind))
end

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
