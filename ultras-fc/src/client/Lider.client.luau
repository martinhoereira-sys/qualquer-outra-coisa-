--!strict
--[[
	O lider, neste ecra.

	- Se sou o lider: o botao ORDENS abre o painel com as oito ordens.
	- Se sou da claque: os avisos do lider ("O lider mandou saltar — carrega E
	  para entrar"). Carregar E (ou no botao, no telemovel) entra; ignorar nao
	  faz nada. O lider nunca obriga ninguem.
	- Toda a gente: o cantico que o lider pos a tocar, a sair da claque (ou da
	  faixa, no corteo), como som no mundo.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local TXT = Config.Text.liderHud
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StadiumPlan"))
local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"))
local Schedule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Schedule"))

local L = Config.Lider
local me = Players.LocalPlayer

local BG = Color3.fromRGB(22, 24, 32)
local CARD = Color3.fromRGB(34, 38, 50)
local TEXT = Color3.fromRGB(245, 245, 245)
local MUTED = Color3.fromRGB(170, 176, 190)
local GOLD = Color3.fromRGB(255, 196, 60)

local gui = Instance.new("ScreenGui")
gui.Name = "Lider"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = me:WaitForChild("PlayerGui")
UI.scale(gui, true)

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function label(parent: Instance, text: string, size: number, colour: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = size
	t.TextColor3 = colour
	t.Text = text
	t.TextWrapped = true
	t.Parent = parent
	return t
end

local function button(parent: Instance, text: string, colour: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = colour
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 15
	b.TextColor3 = TEXT
	b.TextWrapped = true
	b.Text = text
	b.Parent = parent
	corner(b, 10)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.6
	stroke.Thickness = 2
	stroke.Parent = b
	return b
end

local function teamColour(): Color3
	local team = Config.Teams[me:GetAttribute("Team") or ""]
	return if team then team.color else GOLD
end

--------------------------------------------------------------------------------
-- Avisos pequenos (respostas do servidor, "o lider deu-te uma tocha")
--------------------------------------------------------------------------------

local toast = Instance.new("TextLabel")
toast.Name = "Aviso"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 132)
toast.Size = UDim2.fromOffset(460, 38)
toast.BackgroundColor3 = BG
toast.BackgroundTransparency = 0.1
toast.Font = Enum.Font.GothamBold
toast.TextSize = 16
toast.TextColor3 = TEXT
toast.TextWrapped = true
toast.Visible = false
toast.Parent = gui
corner(toast, 10)
local toastSeq = 0

local function say(text: string)
	if text == "" then
		return
	end
	toastSeq += 1
	local mine = toastSeq
	toast.Text = text
	toast.Visible = true
	task.delay(4, function()
		if toastSeq == mine then
			toast.Visible = false
		end
	end)
end

--------------------------------------------------------------------------------
-- O aviso do lider: carrega E para entrar
--------------------------------------------------------------------------------

local card = Instance.new("Frame")
card.Name = "Convite"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 176)
card.Size = UDim2.fromOffset(480, 96)
card.BackgroundColor3 = BG
card.Visible = false
card.Parent = gui
corner(card, 14)
local cardStroke = Instance.new("UIStroke")
cardStroke.Thickness = 3
cardStroke.Parent = card

local cardTitle = label(card, "", 34, TEXT) -- the order, big
cardTitle.Font = Enum.Font.GothamBlack
cardTitle.Position = UDim2.fromOffset(16, 10)
cardTitle.Size = UDim2.new(1, -170, 0, 48)
cardTitle.TextXAlignment = Enum.TextXAlignment.Left

local cardHint = label(card, TXT.pressEToJoinIn, 13, MUTED)
cardHint.Position = UDim2.fromOffset(16, 60)
cardHint.Size = UDim2.new(1, -170, 0, 20)
cardHint.TextXAlignment = Enum.TextXAlignment.Left

local join = button(card, TXT.joinInE, Color3.fromRGB(40, 170, 90))
join.AnchorPoint = Vector2.new(1, 0.5)
join.Position = UDim2.new(1, -14, 0.5, 0)
join.Size = UDim2.fromOffset(140, 60)
join.TextSize = 17

local timerBar = Instance.new("Frame")
timerBar.BorderSizePixel = 0
timerBar.BackgroundColor3 = GOLD
timerBar.Position = UDim2.new(0, 0, 1, -5)
timerBar.Size = UDim2.new(1, 0, 0, 5)
timerBar.Parent = card

local current: { id: number, order: string, untilAt: number }? = nil
local ACTION = "EntrarOrdemLider"

local function closeInvite()
	current = nil
	card.Visible = false
	ContextActionService:UnbindAction(ACTION)
end

local function acceptInvite()
	local invite = current
	if not invite then
		return
	end
	Remotes.Lider:FireServer("aceitar", invite.id)
	closeInvite()
	say(TXT.youReIn)
end

join.Activated:Connect(acceptInvite)

local function openInvite(id: number, order: string, text: string)
	current = { id = id, order = order, untilAt = os.clock() + L.inviteSeconds }
	cardTitle.Text = text
	cardStroke.Color = teamColour()
	card.Visible = true
	-- O E so e deste aviso enquanto ele esta no ecra: por cima dos prompts do mapa.
	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			acceptInvite()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
end

RunService.RenderStepped:Connect(function()
	local invite = current
	if invite then
		local leftTime = invite.untilAt - os.clock()
		if leftTime <= 0 then
			closeInvite()
		else
			timerBar.Size = UDim2.new(leftTime / L.inviteSeconds, 0, 0, 5)
		end
	end
end)

--------------------------------------------------------------------------------
-- The capo's panel
--------------------------------------------------------------------------------

--[[
	One button on the right edge, under the clock, opens it. Inside, three
	sections, ONE at a time:

	  SING     the chants of my club
	  GIVE     gear to someone in the curva
	  ORDERS   the seven orders, by the moment they are for:
	             BEFORE THE MATCH   form up · march · uniform
	             DURING THE MATCH   jump · arms · crouch · light up
	           The moment it is now comes first.
]]
local U = Config.UI
local HALF = U.gap / 2
local PANEL_W = 460
local TOGGLE_W = 200

local toggle = UI.button(gui, TXT.orders)
toggle.Name = "Abrir"
toggle.AnchorPoint = Vector2.new(1, 0)
toggle.Position = UDim2.new(1, -U.gap, 0, HALF + U.button + HALF)
toggle.Size = UDim2.fromOffset(TOGGLE_W, U.button)
toggle.Visible = false
local toggleLine = UI.outline(toggle, U.text)

local panel = Instance.new("Frame")
panel.Name = "Ordens"
panel.BackgroundColor3 = U.ground
panel.BackgroundTransparency = U.groundTransparency
panel.BorderSizePixel = 0
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -(U.gap + TOGGLE_W + HALF), 0, HALF + U.button + HALF)
panel.Size = UDim2.fromOffset(PANEL_W + U.gap * 2, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.Visible = false
panel.Parent = gui
UI.corner(panel)
local panelPad = Instance.new("UIPadding")
panelPad.PaddingLeft = UDim.new(0, U.gap)
panelPad.PaddingRight = UDim.new(0, U.gap)
panelPad.PaddingTop = UDim.new(0, U.gap)
panelPad.PaddingBottom = UDim.new(0, U.gap)
panelPad.Parent = panel

local SECTIONS = { "sing", "give", "command" }
local tabs: { [string]: TextButton } = {}
local tabLines: { [string]: UIStroke } = {}
local body = Instance.new("Frame")
body.Name = "Seccao"
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(0, U.button + U.gap)
body.Size = UDim2.fromOffset(PANEL_W, 0)
body.AutomaticSize = Enum.AutomaticSize.Y
body.Parent = panel

local section = "command"
local budgetText = "?"
local giveInfo: TextLabel? = nil
local chosenTarget: Player? = nil

local function small(parent: Instance, text: string, y: number, lines: number): TextLabel
	local l = UI.label(parent, text, "small", true)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.Position = UDim2.fromOffset(0, y)
	l.Size = UDim2.new(1, 0, 0, lines * (U.small + 6))
	return l
end

-- SING: the chants of my club, and only those.
local function drawSing()
	local myTeam = Config.Teams[me:GetAttribute("Team") or ""]
	local songs = Config.chantsOf(myTeam and myTeam.club)
	local y = 0
	if #songs == 0 then
		small(body, TXT.noChants, 0, 1).Name = "SemCanticos"
		y = U.small + 6 + HALF
	end
	for i, song in songs do
		local b = UI.button(body, song.name, "♪")
		b.Name = "Cantico_" .. i
		b.AutoLocalize = false
		b.Position = UDim2.fromOffset(0, y)
		local word = b:FindFirstChild("Palavra") :: TextLabel?
		if word then
			word.TextXAlignment = Enum.TextXAlignment.Left
		end
		b.Activated:Connect(function()
			Remotes.Lider:FireServer("musica", i)
		end)
		y += U.button + HALF
	end
	local stop = UI.button(body, TXT.stop)
	stop.Name = "Parar"
	stop.Position = UDim2.fromOffset(0, y)
	stop.Activated:Connect(function()
		Remotes.Lider:FireServer("musica", 0)
	end)
end

-- GIVE: who, then what.
local ITEM_LABEL = { tocha = TXT.flare, fumo = TXT.smoke, bandeira = TXT.flag, faixa = TXT.banner, mastro = TXT.poleFlagOnly1 }
local function drawGive()
	Remotes.Lider:FireServer("pedir")
	local info = small(body, TXT.youCanGive .. budgetText .. TXT.thisMatchPickThePerson, 0, 2)
	giveInfo = info
	local y = (U.small + 6) * 2 + HALF

	local people = Instance.new("ScrollingFrame")
	people.Name = "Pessoas"
	people.BackgroundTransparency = 1
	people.BorderSizePixel = 0
	people.Position = UDim2.fromOffset(0, y)
	people.Size = UDim2.new(1, 0, 0, U.row * 2 + HALF + U.line * 2)
	people.CanvasSize = UDim2.new()
	people.AutomaticCanvasSize = Enum.AutomaticSize.Y
	people.ScrollBarThickness = U.line
	people.Parent = body
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, U.line)
	pad.PaddingLeft = UDim.new(0, U.line)
	pad.PaddingRight = UDim.new(0, U.line + 4)
	pad.Parent = people
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, HALF)
	list.Parent = people
	y += U.row * 2 + HALF + U.line * 2 + U.gap

	local lines: { [Player]: UIStroke } = {}
	local function paint()
		for player, line in lines do
			line.Enabled = player == chosenTarget
		end
	end
	local anyone = false
	for _, player in Players:GetPlayers() do
		-- The capo is in the list too: the pole flag can stay with him.
		if player:GetAttribute("Team") == me:GetAttribute("Team") then
			anyone = true
			local row = UI.button(people, if player == me then TXT.meCapo else player.DisplayName)
			row.AutoLocalize = player == me
			row.Size = UDim2.new(1, 0, 0, U.row)
			lines[player] = UI.outline(row, teamColour())
			row.Activated:Connect(function()
				chosenTarget = player
				paint()
			end)
		end
	end
	if not anyone then
		small(people, TXT.nobodyElseInTheUltras, 0, 1)
	end
	paint()

	for i, kind in L.giveKinds do
		local b = UI.button(body, ITEM_LABEL[kind] or kind)
		b.Name = "Dar_" .. kind
		local column, line = (i - 1) % 2, (i - 1) // 2
		b.Position = UDim2.new(column * 0.5, column * HALF / 2, 0, y + line * (U.button + HALF))
		b.Size = UDim2.new(0.5, -HALF / 2, 0, U.button)
		b.Activated:Connect(function()
			local target = chosenTarget
			if not target or not target.Parent then
				say(TXT.pickThePersonFirst)
				return
			end
			Remotes.Lider:FireServer("dar", target.UserId, kind)
		end)
	end
end

-- ORDERS: by the moment they are for; the moment it is now comes first.
local MOMENTS = {
	{ id = "before", title = TXT.before, orders = { { "formar", TXT.formUp }, { "marchar", TXT.march }, { "farda", TXT.uniform } } },
	{ id = "during", title = TXT.during, orders = { { "saltar", TXT.jump }, { "palmas", TXT.clap }, { "bracos", TXT.arms }, { "agachar", TXT.crouch }, { "acender", TXT.lightUp } } },
}
local function momentNow(): string
	local moment = Schedule.at(Schedule.gameTime())
	return if moment.night or moment.phase == "clubhouse" or moment.phase == "corteo" then "before" else "during"
end
local function drawCommand()
	local now = momentNow()
	local order = if now == "before" then { MOMENTS[1], MOMENTS[2] } else { MOMENTS[2], MOMENTS[1] }
	local y = 0
	for _, moment in order do
		local head = UI.label(body, moment.title, "small", moment.id ~= now)
		head.TextXAlignment = Enum.TextXAlignment.Left
		head.Position = UDim2.fromOffset(0, y)
		y += U.small + 6 + HALF
		for i, entry in moment.orders do
			local b = UI.button(body, entry[2] :: string)
			b.Name = "Ordem_" .. entry[1]
			local column, line = (i - 1) % 2, (i - 1) // 2
			b.Position = UDim2.new(column * 0.5, column * HALF / 2, 0, y + line * (U.button + HALF))
			b.Size = UDim2.new(0.5, -HALF / 2, 0, U.button)
			if moment.id == now then
				UI.outline(b, teamColour())
			end
			b.Activated:Connect(function()
				Remotes.Lider:FireServer(entry[1])
			end)
		end
		y += math.ceil(#moment.orders / 2) * (U.button + HALF) + HALF
	end
end

local DRAW = { sing = drawSing, give = drawGive, command = drawCommand }

local function show()
	body:ClearAllChildren()
	giveInfo = nil
	for name, line in tabLines do
		line.Enabled = name == section
		line.Color = teamColour()
	end
	DRAW[section]()
end

local TAB_TEXT = { sing = TXT.sing, give = TXT.give, command = TXT.command }
for i, name in SECTIONS do
	local b = UI.button(panel, TAB_TEXT[name])
	b.Name = "Tab_" .. name
	local width = (PANEL_W - HALF * (#SECTIONS - 1)) / #SECTIONS
	b.Position = UDim2.fromOffset((i - 1) * (width + HALF), 0)
	b.Size = UDim2.fromOffset(width, U.button)
	tabs[name] = b
	tabLines[name] = UI.outline(b, U.text)
	b.Activated:Connect(function()
		section = name
		show()
	end)
end

toggle.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		show()
		Remotes.Lider:FireServer("pedir")
	end
end)

local function refreshLeader()
	local leader = me:GetAttribute("Leader") == true
	toggle.Visible = leader
	if not leader then
		panel.Visible = false
	end
	toggleLine.Color = teamColour()
end
me:GetAttributeChangedSignal("Leader"):Connect(refreshLeader)
me:GetAttributeChangedSignal("Team"):Connect(refreshLeader)
refreshLeader()

--------------------------------------------------------------------------------
-- O que o servidor manda
--------------------------------------------------------------------------------

local walking: RBXScriptConnection? = nil

Remotes.Lider.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	local kind = data.kind
	if kind == "convite" and type(data.id) == "number" then
		openInvite(data.id, tostring(data.order), tostring(data.text))
	elseif kind == "aviso" or kind == "resposta" or kind == "estado" then
		if type(data.left) == "number" and type(data.budget) == "number" then
			budgetText = data.left .. TXT.of .. data.budget
			local info = giveInfo
			if info and info.Parent then
				info.Text = TXT.youCanGive .. budgetText .. TXT.thisMatchPickThePerson
			end
		end
		if type(data.text) == "string" then
			say(data.text)
		end
	elseif kind == "ir" and typeof(data.at) == "Vector3" then
		-- O lugar na formatura: anda-se para la; mexer-se cancela.
		local humanoid = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:MoveTo(data.at)
			say(TXT.onTheWayToYour)
			if walking then
				walking:Disconnect()
			end
			walking = humanoid.MoveToFinished:Connect(function()
				if walking then
					walking:Disconnect()
					walking = nil
				end
			end)
		end
	end
end)

--------------------------------------------------------------------------------
-- A musica do lider, a sair da claque (ou da faixa, no corteo)
--------------------------------------------------------------------------------

local C = Config.Chants
type Playing = { key: string, sound: Sound, anchor: Part, startedAt: number, total: number }
local playing: { [string]: Playing } = {}

local function anchorFor(teamId: string): (Vector3, BasePart?)
	local stadium = workspace:FindFirstChild("Stadium")
	local march = stadium and stadium:FindFirstChild("March")
	local banner = march and march:FindFirstChild("Banner_" .. teamId)
	if banner and banner:IsA("BasePart") and banner:GetAttribute("Stage") ~= "chegou" then
		return banner.Position, banner
	end
	return Plan.claqueSeat(teamId, 4, 0.5) + Vector3.new(0, 4, 0), nil
end

local function stop(teamId: string)
	local p = playing[teamId]
	if p then
		p.anchor:Destroy()
		playing[teamId] = nil
	end
end

local function update(teamId: string)
	local stadium = workspace:FindFirstChild("Stadium")
	local value = stadium and stadium:GetAttribute("Musica_" .. teamId)
	if type(value) ~= "string" then
		stop(teamId)
		return
	end
	local clubId, index, started = string.match(value, "^(%w+):(%d+):([%d%.]+)$")
	local song = clubId and Config.chantsOf(clubId)[tonumber(index) :: number]
	local startedAt = tonumber(started)
	if not song or not startedAt then
		stop(teamId)
		return
	end
	local seconds, repeats, total = Config.chantTiming(song)
	if workspace:GetServerTimeNow() - startedAt > total then
		stop(teamId)
		return
	end
	local existing = playing[teamId]
	if existing and existing.key == value then
		return
	end
	stop(teamId)
	local anchor = Instance.new("Part")
	anchor.Name = "Cantico_" .. teamId
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = anchorFor(teamId)
	anchor.Parent = workspace
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. song.id
	sound.Looped = false
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = C.minDistance
	sound.RollOffMaxDistance = C.maxDistance
	sound.Parent = anchor
	local entry: Playing = { key = value, sound = sound, anchor = anchor, startedAt = startedAt, total = total }
	playing[teamId] = entry
	-- Sung `repeats` times, with a short silence between two: never glued.
	task.spawn(function()
		local cycle = seconds + C.pause
		while playing[teamId] == entry do
			local elapsed = workspace:GetServerTimeNow() - startedAt
			local turn = math.floor(elapsed / cycle)
			if turn >= repeats then
				stop(teamId)
				break
			end
			local into = elapsed - turn * cycle
			if into < seconds - 0.5 then
				-- Loud for the claque that sings it, lower for everyone else.
				sound.Volume = if me:GetAttribute("Team") == teamId then C.volume else C.farVolume
				sound.TimePosition = if into > 0.3 then into else 0
				sound:Play()
			end
			task.wait(cycle - into)
		end
	end)
end

local function watchStadium(stadium: Instance)
	for _, teamId in Config.TeamOrder do
		stadium:GetAttributeChangedSignal("Musica_" .. teamId):Connect(function()
			update(teamId)
		end)
		update(teamId)
	end
end

local stadiumFolder = workspace:WaitForChild("Stadium")
watchStadium(stadiumFolder)

-- A musica segue a faixa no corteo, e acaba sozinha ao fim do tempo.
task.spawn(function()
	while true do
		task.wait(0.5)
		for teamId, p in playing do
			if workspace:GetServerTimeNow() - p.startedAt > p.total then
				stop(teamId)
			else
				p.anchor.Position = anchorFor(teamId)
			end
		end
	end
end)
