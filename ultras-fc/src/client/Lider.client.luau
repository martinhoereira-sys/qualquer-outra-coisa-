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
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StadiumPlan"))

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

local cardTitle = label(card, "", 20, TEXT)
cardTitle.Font = Enum.Font.GothamBlack
cardTitle.Position = UDim2.fromOffset(16, 10)
cardTitle.Size = UDim2.new(1, -170, 0, 48)
cardTitle.TextXAlignment = Enum.TextXAlignment.Left

local cardHint = label(card, "Carrega E para entrar  ·  ignora se não quiseres", 13, MUTED)
cardHint.Position = UDim2.fromOffset(16, 60)
cardHint.Size = UDim2.new(1, -170, 0, 20)
cardHint.TextXAlignment = Enum.TextXAlignment.Left

local join = button(card, "ENTRAR  (E)", Color3.fromRGB(40, 170, 90))
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
	say("Entraste!")
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
-- O painel do lider
--------------------------------------------------------------------------------

local toggle = button(gui, "📣 ORDENS", Color3.fromRGB(200, 60, 50))
toggle.AnchorPoint = Vector2.new(1, 0.5)
toggle.Position = UDim2.new(1, -14, 0.5, -170)
toggle.Size = UDim2.fromOffset(150, 44)
toggle.TextSize = 16
toggle.Visible = false

local panel = Instance.new("Frame")
panel.Name = "Ordens"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -14, 0.5, 30)
panel.Size = UDim2.fromOffset(300, 340)
panel.BackgroundColor3 = BG
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = gui
corner(panel, 14)

local header = label(panel, "LÍDER · as tuas ordens", 16, GOLD)
header.Font = Enum.Font.GothamBlack
header.Position = UDim2.fromOffset(14, 8)
header.Size = UDim2.new(1, -28, 0, 22)
header.TextXAlignment = Enum.TextXAlignment.Left

local sub = label(panel, "Ninguém é obrigado: a claque recebe um aviso e decide.", 12, MUTED)
sub.Position = UDim2.fromOffset(14, 30)
sub.Size = UDim2.new(1, -28, 0, 30)
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.TextYAlignment = Enum.TextYAlignment.Top

local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Position = UDim2.fromOffset(12, 64)
grid.Size = UDim2.new(1, -24, 0, 264)
grid.Parent = panel
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.new(0.5, -5, 0, 58)
layout.CellPadding = UDim2.fromOffset(10, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

-- As duas listas que se abrem (musica e dar material), no lugar das ordens.
local subPanel = Instance.new("Frame")
subPanel.BackgroundTransparency = 1
subPanel.Position = UDim2.fromOffset(12, 64)
subPanel.Size = UDim2.new(1, -24, 1, -76)
subPanel.Visible = false
subPanel.Parent = panel

local function clearSub()
	for _, child in subPanel:GetChildren() do
		child:Destroy()
	end
end

local function showOrders()
	subPanel.Visible = false
	grid.Visible = true
	clearSub()
end

local function backButton()
	local back = button(subPanel, "◀ voltar", CARD)
	back.Size = UDim2.new(1, 0, 0, 30)
	back.TextSize = 13
	back.Activated:Connect(showOrders)
end

local function showMusic()
	grid.Visible = false
	clearSub()
	subPanel.Visible = true
	backButton()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.Parent = subPanel
	for i, song in L.canticos do
		local b = button(subPanel, "♪ " .. song.name, Color3.fromRGB(120, 70, 200))
		b.Size = UDim2.new(1, 0, 0, 36)
		b.LayoutOrder = i
		b.Activated:Connect(function()
			Remotes.Lider:FireServer("musica", i)
		end)
	end
	local stop = button(subPanel, "■ PARAR", Color3.fromRGB(90, 90, 100))
	stop.Size = UDim2.new(1, 0, 0, 32)
	stop.LayoutOrder = 99
	stop.Activated:Connect(function()
		Remotes.Lider:FireServer("musica", 0)
	end)
end

local budgetText = "?"
local giveInfo: TextLabel? = nil
local chosenTarget: Player? = nil

local ITEM_LABEL = { tocha = "🔥 Tocha", fumo = "💨 Fumo", bandeira = "🚩 Bandeira", faixa = "🎌 Faixa" }

local function showGive()
	grid.Visible = false
	clearSub()
	subPanel.Visible = true
	backButton()

	local info = label(subPanel, "Podes dar " .. budgetText .. " neste jogo. Escolhe a pessoa, depois o quê.", 12, MUTED)
	giveInfo = info
	info.Position = UDim2.fromOffset(0, 34)
	info.Size = UDim2.new(1, 0, 0, 30)
	info.TextXAlignment = Enum.TextXAlignment.Left

	local people = Instance.new("ScrollingFrame")
	people.BackgroundColor3 = CARD
	people.BorderSizePixel = 0
	people.Position = UDim2.fromOffset(0, 66)
	people.Size = UDim2.new(1, 0, 0, 116)
	people.CanvasSize = UDim2.new()
	people.AutomaticCanvasSize = Enum.AutomaticSize.Y
	people.ScrollBarThickness = 6
	people.Parent = subPanel
	corner(people, 8)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.Parent = people

	local rows: { [Player]: TextButton } = {}
	local function paint()
		for player, row in rows do
			row.BackgroundColor3 = if player == chosenTarget then teamColour() else Color3.fromRGB(48, 52, 66)
		end
	end
	local anyone = false
	for _, player in Players:GetPlayers() do
		if player ~= me and player:GetAttribute("Team") == me:GetAttribute("Team") then
			anyone = true
			local row = button(people, player.DisplayName, Color3.fromRGB(48, 52, 66))
			row.Size = UDim2.new(1, -8, 0, 28)
			row.TextSize = 13
			rows[player] = row
			row.Activated:Connect(function()
				chosenTarget = player
				paint()
			end)
		end
	end
	if not anyone then
		local none = label(people, "Ainda não há mais ninguém na claque.", 13, MUTED)
		none.Size = UDim2.new(1, 0, 0, 40)
	end
	paint()

	local items = Instance.new("Frame")
	items.BackgroundTransparency = 1
	items.Position = UDim2.fromOffset(0, 188)
	items.Size = UDim2.new(1, 0, 0, 76)
	items.Parent = subPanel
	local itemGrid = Instance.new("UIGridLayout")
	itemGrid.CellSize = UDim2.new(0.5, -4, 0, 34)
	itemGrid.CellPadding = UDim2.fromOffset(8, 6)
	itemGrid.Parent = items
	for _, kind in L.giveKinds do
		local b = button(items, ITEM_LABEL[kind] or kind, Color3.fromRGB(210, 120, 40))
		b.TextSize = 14
		b.Activated:Connect(function()
			local target = chosenTarget
			if not target or not target.Parent then
				say("Escolhe primeiro a pessoa.")
				return
			end
			Remotes.Lider:FireServer("dar", target.UserId, kind)
		end)
	end
end

local ORDERS = {
	{ id = "formar", text = "FORMAR", colour = Color3.fromRGB(60, 110, 200) },
	{ id = "marchar", text = "MARCHAR", colour = Color3.fromRGB(40, 150, 90) },
	{ id = "saltar", text = "SALTAR", colour = Color3.fromRGB(230, 140, 30) },
	{ id = "acender", text = "ACENDER", colour = Color3.fromRGB(210, 50, 40) },
	{ id = "bandeirao", text = "BANDEIRÃO", colour = Color3.fromRGB(150, 60, 190) },
	{ id = "musica", text = "MÚSICA ▸", colour = Color3.fromRGB(120, 70, 200) },
	{ id = "dar", text = "DAR MATERIAL ▸", colour = Color3.fromRGB(210, 120, 40) },
	{ id = "farda", text = "FARDA", colour = Color3.fromRGB(50, 50, 60) },
}

for i, order in ORDERS do
	local b = button(grid, order.text, order.colour)
	b.LayoutOrder = i
	b.Activated:Connect(function()
		if order.id == "musica" then
			showMusic()
		elseif order.id == "dar" then
			Remotes.Lider:FireServer("pedir")
			showGive()
		else
			Remotes.Lider:FireServer(order.id)
		end
	end)
end

toggle.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		showOrders()
		Remotes.Lider:FireServer("pedir")
	end
end)

local function refreshLeader()
	local leader = me:GetAttribute("Leader") == true
	toggle.Visible = leader
	if not leader then
		panel.Visible = false
	end
	toggle.BackgroundColor3 = teamColour()
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
			budgetText = data.left .. " de " .. data.budget
			local info = giveInfo
			if info and info.Parent then
				info.Text = "Podes dar " .. budgetText .. " neste jogo. Escolhe a pessoa, depois o que."
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
			say("A caminho do teu lugar na formatura (mexe-te para cancelar).")
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

type Playing = { key: string, sound: Sound, anchor: Part, startedAt: number }
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
	local index, started = string.match(value, "^(%d+):([%d%.]+)$")
	local song = index and L.canticos[tonumber(index) :: number]
	local startedAt = tonumber(started)
	if not song or not startedAt or workspace:GetServerTimeNow() - startedAt > L.musicSeconds then
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
	sound.Looped = true
	sound.Volume = 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 40
	sound.RollOffMaxDistance = 420
	sound.Parent = anchor
	sound:Play()
	playing[teamId] = { key = value, sound = sound, anchor = anchor, startedAt = startedAt }
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
			if workspace:GetServerTimeNow() - p.startedAt > L.musicSeconds then
				stop(teamId)
			else
				p.anchor.Position = anchorFor(teamId)
			end
		end
	end
end)
