--!strict
--[[
	O que o adepto ve e faz.

	Duas coisas: escolher equipa a entrada, e depois cantar ao compasso. O
	compasso nao vem pela rede — o cliente le o mesmo relogio do servidor e
	calcula-o sozinho, por isso o pulso e suave mesmo com ping.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local myTeam: string? = nil

--[[
	Sons. Poe aqui os ids dos teus audios (rbxassetid://NUMERO) e passa a haver
	som sem mexer em mais nada. Vazios, o jogo funciona igual — so em silencio.

	O `drum` toca em cada batida e e o mais importante: e ele que da o compasso.
	Sem som, a pessoa tem de o ler no circulo, o que e bem mais dificil.
]]
local SOUNDS = {
	drum = "",
	perfect = "",
	hit = "",
	miss = "",
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
-- Escolher equipa
--------------------------------------------------------------------------------

local picker = Instance.new("Frame")
picker.Size = UDim2.fromScale(1, 1)
picker.BackgroundColor3 = INK
picker.BackgroundTransparency = 0.08
picker.Parent = gui

local pickTitle = label(picker, "Escolhe o teu lado", 34, TEXT)
pickTitle.Size = UDim2.new(1, -40, 0, 44)
pickTitle.Position = UDim2.new(0, 20, 0.5, -140)

local pickHint = label(picker, "Canta ao ritmo para encher a bancada", 16, MUTED)
pickHint.Font = Enum.Font.Gotham
pickHint.Size = UDim2.new(1, -40, 0, 22)
pickHint.Position = UDim2.new(0, 20, 0.5, -98)

local function showPicker(visible: boolean)
	picker.Visible = visible
end

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
		showPicker(false)
	end)
end

--------------------------------------------------------------------------------
-- Marcador e barras
--------------------------------------------------------------------------------

local hud = Instance.new("Frame")
hud.Size = UDim2.new(1, 0, 0, 132)
hud.BackgroundTransparency = 1
hud.Parent = gui

local scoreLabel = label(hud, "0 - 0", 40, TEXT)
scoreLabel.Size = UDim2.new(1, 0, 0, 46)
scoreLabel.Position = UDim2.new(0, 0, 0, 16)

local phaseLabel = label(hud, "AQUECIMENTO", 14, MUTED)
phaseLabel.Font = Enum.Font.Gotham
phaseLabel.Size = UDim2.new(1, 0, 0, 20)
phaseLabel.Position = UDim2.new(0, 0, 0, 62)

local goalLabel = label(hud, "", 30, TEXT)
goalLabel.Size = UDim2.new(1, 0, 0, 36)
goalLabel.Position = UDim2.new(0, 0, 0, 86)

-- Uma barra por bancada, encostada a cada lado do ecra.
local bars: { [string]: Frame } = {}

for index, teamId in Config.TeamOrder do
	local team = Config.Teams[teamId]
	local onLeft = index == 1

	local track = Instance.new("Frame")
	track.Size = UDim2.new(0, 26, 0, 240)
	track.Position = UDim2.new(onLeft and 0 or 1, onLeft and 24 or -50, 0.5, -120)
	track.BackgroundColor3 = Color3.fromRGB(43, 51, 61)
	track.BorderSizePixel = 0
	track.Parent = gui

	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = team.color
	fill.BorderSizePixel = 0
	fill.Parent = track

	local tag = label(track, team.short, 13, MUTED)
	tag.Font = Enum.Font.Gotham
	tag.Size = UDim2.new(1, 20, 0, 18)
	tag.Position = UDim2.new(0, -10, 1, 6)

	bars[teamId] = fill
end

--------------------------------------------------------------------------------
-- O compasso
--------------------------------------------------------------------------------

local pulse = Instance.new("Frame")
pulse.AnchorPoint = Vector2.new(0.5, 0.5)
pulse.Size = UDim2.fromOffset(96, 96)
pulse.Position = UDim2.new(0.5, 0, 1, -120)
pulse.BackgroundColor3 = Color3.fromRGB(217, 164, 65)
pulse.BorderSizePixel = 0
pulse.Parent = gui

local pulseCorner = Instance.new("UICorner")
pulseCorner.CornerRadius = UDim.new(1, 0)
pulseCorner.Parent = pulse

local pulseText = label(pulse, "CANTA", 15, INK)
pulseText.Size = UDim2.fromScale(1, 1)

-- O veredicto aparece imediatamente por cima do circulo. A barra continua a ser
-- decidida pelo servidor; isto e o que a pessoa ve, e tem de ser instantaneo.
local feedback = label(gui, "", 26, TEXT)
feedback.Size = UDim2.new(1, 0, 0, 32)
feedback.Position = UDim2.new(0, 0, 1, -196)
feedback.TextTransparency = 1

local comboLabel = label(gui, "", 15, Color3.fromRGB(217, 164, 65))
comboLabel.Font = Enum.Font.GothamBold
comboLabel.Size = UDim2.new(1, 0, 0, 20)
comboLabel.Position = UDim2.new(0, 0, 1, -168)
comboLabel.TextTransparency = 1

-- A barra da propria bancada, junto ao circulo: a das bordas fica longe demais
-- do sitio para onde se esta a olhar.
local ownTrack = Instance.new("Frame")
ownTrack.AnchorPoint = Vector2.new(0.5, 0)
ownTrack.Size = UDim2.fromOffset(160, 8)
ownTrack.Position = UDim2.new(0.5, 0, 1, -38)
ownTrack.BackgroundColor3 = Color3.fromRGB(43, 51, 61)
ownTrack.BorderSizePixel = 0
ownTrack.Parent = gui

local ownFill = Instance.new("Frame")
ownFill.Size = UDim2.fromScale(0, 1)
ownFill.BackgroundColor3 = Color3.fromRGB(217, 164, 65)
ownFill.BorderSizePixel = 0
ownFill.Parent = ownTrack

local chantHint = label(gui, "espaco  ou  toca no circulo", 13, MUTED)
chantHint.Font = Enum.Font.Gotham
chantHint.Size = UDim2.new(1, 0, 0, 18)
chantHint.Position = UDim2.new(0, 0, 1, -56)

local combo = 0
local feedbackToken = 0

local function showFeedback(text: string, colour: Color3)
	feedbackToken += 1
	local token = feedbackToken

	feedback.Text = text
	feedback.TextColor3 = colour
	feedback.TextTransparency = 0

	comboLabel.Text = combo >= 2 and (combo .. " seguidos") or ""
	comboLabel.TextTransparency = combo >= 2 and 0 or 1

	task.delay(0.55, function()
		if feedbackToken == token then
			feedback.TextTransparency = 1
			comboLabel.TextTransparency = 1
		end
	end)
end

-- O cliente le o mesmo relogio do servidor, por isso julga o proprio acerto sem
-- esperar resposta. Ir e voltar ao servidor para mostrar "PERFEITO" fazia o
-- ritmo sentir-se pastoso, que e precisamente o que este jogo nao pode ser.
local function beatOffset(): number
	local now = workspace:GetServerTimeNow()
	local index = math.floor(now / Config.Beat.interval + 0.5)
	return math.abs(now - index * Config.Beat.interval)
end

local function chant()
	if not myTeam then
		return
	end

	Remotes.Chant:FireServer()

	local offset = beatOffset()
	if offset <= Config.Beat.perfectWindow then
		combo += 1
		showFeedback("PERFEITO", Color3.fromRGB(217, 164, 65))
		play(SOUNDS.perfect, 0.6)
	elseif offset <= Config.Beat.window then
		combo = 0
		showFeedback("BOA", Color3.fromRGB(79, 180, 119))
		play(SOUNDS.hit, 0.5)
	else
		combo = 0
		showFeedback("FORA DE TEMPO", Color3.fromRGB(224, 84, 78))
		play(SOUNDS.miss, 0.4)
	end
end

local pulseButton = Instance.new("TextButton")
pulseButton.Size = UDim2.fromScale(1, 1)
pulseButton.BackgroundTransparency = 1
pulseButton.Text = ""
pulseButton.Parent = pulse
pulseButton.Activated:Connect(chant)

ContextActionService:BindAction("UltrasChant", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		chant()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Space)

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
	warmup = "AQUECIMENTO",
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

-- O tambor e o compasso. Sem som e preciso ler o circulo, o que e bem mais
-- dificil — por isso o `drum` e o primeiro som a valer a pena por.
local lastDrumBeat = -1

-- O pulso respira ao compasso: grande na batida, pequeno entre batidas.
RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()

	local beat = math.floor(now / Config.Beat.interval + 0.5)
	if beat ~= lastDrumBeat and math.abs(now - beat * Config.Beat.interval) < 0.05 then
		lastDrumBeat = beat
		play(SOUNDS.drum, 0.35)
	end

	local phase = (now % Config.Beat.interval) / Config.Beat.interval
	local closeness = 1 - math.abs(phase - 0.5) * 2 -- 1 na batida, 0 a meio
	local scale = 0.82 + closeness * 0.30

	pulse.Size = UDim2.fromOffset(96 * scale, 96 * scale)
	pulse.BackgroundTransparency = 0.45 - closeness * 0.45
end)

showPicker(true)
