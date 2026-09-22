--!strict
--[[
	O que o adepto ve e faz.

	Duas coisas: escolher equipa a entrada, e depois cantar ao compasso.

	O compasso nao vem pela rede — o cliente le o mesmo relogio do servidor e
	calcula-o sozinho, por isso o ritmo mantem-se suave mesmo com ping.

	Regra do ecra: ESPACO E PARA SALTAR. Cantar e no E. Um jogo onde se esta numa
	bancada tem de deixar saltar, e a barra de espaco e onde a mao ja esta.
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

	Comeca pelo `drum`: e ele que marca o compasso. Sem som, o ritmo tem de se
	ler no ecra, que e bem mais dificil do que ouvi-lo.
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
local BRASS = Color3.fromRGB(217, 164, 65)
local GOOD = Color3.fromRGB(79, 180, 119)
local BAD = Color3.fromRGB(224, 84, 78)

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

local phaseLabel = label(gui, "AQUECIMENTO", 14, MUTED)
phaseLabel.Font = Enum.Font.Gotham
phaseLabel.Size = UDim2.new(1, 0, 0, 20)
phaseLabel.Position = UDim2.new(0, 0, 0, 62)

local goalLabel = label(gui, "", 30, TEXT)
goalLabel.Size = UDim2.new(1, 0, 0, 36)
goalLabel.Position = UDim2.new(0, 0, 0, 88)

--------------------------------------------------------------------------------
-- As bancadas, uma barra de cada lado
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

--------------------------------------------------------------------------------
-- O compasso, discreto, em baixo
--------------------------------------------------------------------------------

-- Uma barra fina que enche entre batidas e estala no momento certo. Chega para
-- se ler o ritmo sem tapar meio ecra com um botao.
local beatTrack = Instance.new("Frame")
beatTrack.AnchorPoint = Vector2.new(0.5, 1)
beatTrack.Size = UDim2.fromOffset(200, 5)
beatTrack.Position = UDim2.new(0.5, 0, 1, -56)
beatTrack.BackgroundColor3 = Color3.fromRGB(43, 51, 61)
beatTrack.BackgroundTransparency = 0.3
beatTrack.BorderSizePixel = 0
beatTrack.Parent = gui

local beatFill = Instance.new("Frame")
beatFill.AnchorPoint = Vector2.new(0.5, 0.5)
beatFill.Position = UDim2.fromScale(0.5, 0.5)
beatFill.Size = UDim2.fromScale(0, 1)
beatFill.BackgroundColor3 = BRASS
beatFill.BorderSizePixel = 0
beatFill.Parent = beatTrack

-- A barra da propria bancada, junto ao compasso: a das bordas fica longe do
-- sitio para onde se esta a olhar.
local ownTrack = Instance.new("Frame")
ownTrack.AnchorPoint = Vector2.new(0.5, 1)
ownTrack.Size = UDim2.fromOffset(200, 5)
ownTrack.Position = UDim2.new(0.5, 0, 1, -44)
ownTrack.BackgroundColor3 = Color3.fromRGB(43, 51, 61)
ownTrack.BackgroundTransparency = 0.3
ownTrack.BorderSizePixel = 0
ownTrack.Parent = gui

local ownFill = Instance.new("Frame")
ownFill.Size = UDim2.fromScale(0, 1)
ownFill.BackgroundColor3 = TEXT
ownFill.BorderSizePixel = 0
ownFill.Parent = ownTrack

-- Tochas restantes, ao lado do compasso.
local flareLabel = label(gui, "", 13, BRASS)
flareLabel.Size = UDim2.new(1, 0, 0, 18)
flareLabel.Position = UDim2.new(0.5, 0, 1, -76)
flareLabel.AnchorPoint = Vector2.new(0.5, 0)

local hint = label(gui, "E  cantar     F  pegar tocha  ·  clicar para acender     espaco  saltar", 12, MUTED)
hint.Font = Enum.Font.Gotham
hint.Size = UDim2.new(1, 0, 0, 16)
hint.Position = UDim2.new(0, 0, 1, -26)

local feedback = label(gui, "", 24, TEXT)
feedback.Size = UDim2.new(1, 0, 0, 30)
feedback.Position = UDim2.new(0.5, 0, 1, -104)
feedback.AnchorPoint = Vector2.new(0.5, 0)
feedback.TextTransparency = 1

local comboLabel = label(gui, "", 14, BRASS)
comboLabel.Size = UDim2.new(1, 0, 0, 18)
comboLabel.Position = UDim2.new(0.5, 0, 1, -80)
comboLabel.AnchorPoint = Vector2.new(0.5, 0)
comboLabel.TextTransparency = 1

--------------------------------------------------------------------------------
-- Cantar
--------------------------------------------------------------------------------

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

-- O cliente julga o proprio acerto pelo mesmo relogio que o servidor usa. Ir e
-- voltar ao servidor so para mostrar "PERFEITO" fazia o ritmo sentir-se pastoso,
-- que e precisamente o que este jogo nao pode ser. A barra continua a ser
-- decidida pelo servidor: isto muda o que se ve, nao o que conta.
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
		showFeedback("PERFEITO", BRASS)
		play(SOUNDS.perfect, 0.6)
	elseif offset <= Config.Beat.window then
		combo = 0
		showFeedback("BOA", GOOD)
		play(SOUNDS.hit, 0.5)
	else
		combo = 0
		showFeedback("FORA DE TEMPO", BAD)
		play(SOUNDS.miss, 0.4)
	end
end

--[[
	E para cantar, e nada mais. O terceiro argumento pede um botao tactil, que
	o Roblox so cria em telemovel — no computador o ecra fica limpo, e a barra
	de espaco continua a fazer o que toda a gente espera: saltar.
]]
ContextActionService:BindAction("Cantar", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		chant()
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.E)

ContextActionService:SetTitle("Cantar", "CANTA")

--------------------------------------------------------------------------------
-- Tochas
--------------------------------------------------------------------------------

local flaresLeft = Config.Flares.perMatch

local function updateFlareLabel()
	if flaresLeft > 0 then
		flareLabel.Text = string.format("%d tochas", flaresLeft)
		flareLabel.TextColor3 = BRASS
	else
		flareLabel.Text = "sem tochas"
		flareLabel.TextColor3 = MUTED
	end
end

updateFlareLabel()

Remotes.FlareCount.OnClientEvent:Connect(function(count)
	flaresLeft = count
	updateFlareLabel()
end)

-- O F so pede a tocha; ela vai para a mochila. Acende-se depois, ao pegar nela
-- e clicar — o gesto de a levantar e metade da coisa.
ContextActionService:BindAction("Tocha", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and myTeam then
		Remotes.Flare:FireServer()
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.F)

ContextActionService:SetTitle("Tocha", "TOCHA")

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
-- O compasso a correr
--------------------------------------------------------------------------------

local lastDrumBeat = -1

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local interval = Config.Beat.interval

	local beat = math.floor(now / interval + 0.5)
	local offset = now - beat * interval

	if beat ~= lastDrumBeat and math.abs(offset) < 0.05 then
		lastDrumBeat = beat
		play(SOUNDS.drum, 0.35)
	end

	-- Cheia na batida, vazia entre batidas: o pico e o momento de carregar.
	local closeness = math.clamp(1 - math.abs(offset) / (interval / 2), 0, 1)
	beatFill.Size = UDim2.fromScale(closeness, 1)
	beatFill.BackgroundTransparency = 0.55 - closeness * 0.55
end)
