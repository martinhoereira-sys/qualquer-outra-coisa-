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

local hint = label(gui, "F  tocha      G  fumo      T  tambor      espaco  saltar", 12, MUTED)
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
