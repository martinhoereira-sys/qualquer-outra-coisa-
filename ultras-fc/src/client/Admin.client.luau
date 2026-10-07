--!strict
--[[
	The admin bar: only for Config.Admins (the server checks again on every
	order; hiding the bar stops nobody).

	A small ADMIN button at the bottom left opens it. Inside:
	  MY TEAM      the four clubs: I support this one (changes the derby if needed)
	  WEAR KIT     the four clubs' kits, and OFF
	  WEAR FARDA   the four claques' fardas, and OFF
	  KIT          main / alternate (alternate is off until those kits exist)
	  DERBY        which derby is today's
	The words come from Config.Text.admin.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Emblem = require(Shared:WaitForChild("Emblem"))

local player = Players.LocalPlayer
if not table.find(Config.Admins, player.UserId) then
	return
end

local T = Config.Text.admin
local PANEL = Color3.fromRGB(18, 22, 32)
local BUTTON = Color3.fromRGB(58, 62, 72)
local TEXT = Color3.fromRGB(240, 240, 240)
local DIM = Color3.fromRGB(150, 154, 164)
local GOLD = Color3.fromRGB(255, 200, 60)

local ROW = 46
local LABEL = 104
local CELL = 42

local gui = Instance.new("ScreenGui")
gui.Name = "UltrasAdmin"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function button(parent: Instance, text: string, size: UDim2, position: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = BUTTON
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = TEXT
	b.Text = text
	b.Parent = parent
	corner(b, 6)
	return b
end

local open = button(gui, T.open, UDim2.fromOffset(84, 28), UDim2.new(0, 16, 1, -44))
open.BackgroundTransparency = 0.15

local rows = 8
local panel = Instance.new("Frame")
panel.Name = "Bar"
panel.Visible = false
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
local EXTRA = 0
panel.Size = UDim2.fromOffset(LABEL + CELL * #Config.ClubOrder + 96, 34 + rows * ROW + 8 + EXTRA)
panel.Position = UDim2.new(0, 16, 1, -(52 + 34 + rows * ROW + 8 + EXTRA))
panel.Parent = gui
corner(panel, 10)
local edge = Instance.new("UIStroke")
edge.Color = GOLD
edge.Thickness = 1.5
edge.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -24, 0, 30)
title.Position = UDim2.fromOffset(12, 4)
title.Font = Enum.Font.GothamBlack
title.TextSize = 14
title.TextColor3 = GOLD
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = T.title
title.Parent = panel

open.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

local function rowLabel(index: number, text: string): number
	local y = 34 + (index - 1) * ROW
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromOffset(LABEL - 16, ROW - 6)
	l.Position = UDim2.fromOffset(12, y)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 11
	l.TextColor3 = DIM
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = panel
	return y
end

-- A row with the four club emblems as buttons (and OFF, if asked).
local function clubRow(index: number, text: string, action: string, off: boolean)
	local y = rowLabel(index, text)
	for i, clubId in Config.ClubOrder do
		local club = (Config.Clubs :: any)[clubId]
		local b = button(panel, "", UDim2.fromOffset(CELL - 4, ROW - 6), UDim2.fromOffset(LABEL + (i - 1) * CELL, y))
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(32, 32)
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Parent = b
		Emblem.draw(holder, club, { year = false })
		b.Activated:Connect(function()
			Remotes.Admin:FireServer(action, clubId)
		end)
	end
	if off then
		local b = button(panel, T.off, UDim2.fromOffset(80, ROW - 14), UDim2.fromOffset(LABEL + #Config.ClubOrder * CELL + 4, y + 4))
		b.Activated:Connect(function()
			Remotes.Admin:FireServer(action, "")
		end)
	end
end

clubRow(1, T.team, "team", false)
clubRow(2, T.kit, "kit", true)
clubRow(3, T.farda, "farda", true)

-- Main / alternate kit of the club I am wearing (AUTO: what the match decided).
do
	local y = rowLabel(4, T.kitType)
	for i, option in { { T.auto, "" }, { T.home, "home" }, { T.alt, "away" } } do
		local b = button(panel, option[1], UDim2.fromOffset(86, ROW - 14), UDim2.fromOffset(LABEL + (i - 1) * 90, y + 4))
		b.Activated:Connect(function()
			Remotes.Admin:FireServer("kitName", option[2])
		end)
	end
end

-- The derby: the one on today is lit.
do
	local y = rowLabel(5, T.derby)
	local buttons: { TextButton } = {}
	-- The match on now, and one step back or forward in the calendar.
	local back = button(panel, "<", UDim2.fromOffset(34, ROW - 14), UDim2.fromOffset(LABEL, y + 4))
	local name = button(panel, "", UDim2.fromOffset(150, ROW - 14), UDim2.fromOffset(LABEL + 38, y + 4))
	name.AutoButtonColor = false
	local forward = button(panel, ">", UDim2.fromOffset(34, ROW - 14), UDim2.fromOffset(LABEL + 192, y + 4))
	local function step(by: number)
		local current = workspace:GetAttribute("Derby")
		local n = ((if type(current) == "number" then current else 1) - 1 + by) % #Config.Derbies + 1
		Remotes.Admin:FireServer("derby", n)
	end
	back.Activated:Connect(function()
		step(-1)
	end)
	forward.Activated:Connect(function()
		step(1)
	end)
	buttons[1] = name
	local function light()
		local current = workspace:GetAttribute("Derby")
		local match = Config.Derbies[if type(current) == "number" then current else 1]
		if match then
			name.Text = string.format("%d / %d   %s", match.id, #Config.Derbies, match.name)
		end
	end
	workspace:GetAttributeChangedSignal("Derby"):Connect(light)
	light()
end

-- Start the season again (asks first).
do
	local y = rowLabel(6, T.reset)
	local ask = button(panel, T.resetButton, UDim2.fromOffset(190, ROW - 14), UDim2.fromOffset(LABEL, y + 4))
	ask.Name = "Reset"
	ask.BackgroundColor3 = Color3.fromRGB(120, 44, 40)

	local confirm = Instance.new("Frame")
	confirm.Name = "Confirmar"
	confirm.Visible = false
	confirm.AnchorPoint = Vector2.new(0.5, 0.5)
	confirm.Position = UDim2.fromScale(0.5, 0.5)
	confirm.Size = UDim2.fromOffset(520, 150)
	confirm.BackgroundColor3 = PANEL
	confirm.BorderSizePixel = 0
	confirm.Parent = gui
	corner(confirm, 10)
	local line = Instance.new("UIStroke")
	line.Color = Color3.fromRGB(200, 60, 50)
	line.Thickness = 2
	line.Parent = confirm
	local words = Instance.new("TextLabel")
	words.BackgroundTransparency = 1
	words.Size = UDim2.new(1, -30, 0, 60)
	words.Position = UDim2.fromOffset(15, 14)
	words.Font = Enum.Font.GothamBold
	words.TextSize = 16
	words.TextWrapped = true
	words.TextColor3 = TEXT
	words.Text = T.resetAsk
	words.Parent = confirm
	local yes = button(confirm, T.resetYes, UDim2.fromOffset(200, 44), UDim2.fromOffset(40, 90))
	yes.Name = "Sim"
	yes.BackgroundColor3 = Color3.fromRGB(170, 44, 40)
	local no = button(confirm, T.resetNo, UDim2.fromOffset(200, 44), UDim2.fromOffset(280, 90))
	no.Name = "Nao"

	ask.Activated:Connect(function()
		confirm.Visible = true
	end)
	no.Activated:Connect(function()
		confirm.Visible = false
	end)
	yes.Activated:Connect(function()
		confirm.Visible = false
		Remotes.Admin:FireServer("reset")
	end)
end

-- Erase my own profile (asks first): to see the game as someone who has never joined.
do
	local y = rowLabel(7, T.wipe)
	local ask = button(panel, T.wipeButton, UDim2.fromOffset(190, ROW - 14), UDim2.fromOffset(LABEL, y + 4))
	ask.Name = "Apagar"
	ask.BackgroundColor3 = Color3.fromRGB(120, 44, 40)

	local confirm = Instance.new("Frame")
	confirm.Name = "ConfirmarApagar"
	confirm.Visible = false
	confirm.AnchorPoint = Vector2.new(0.5, 0.5)
	confirm.Position = UDim2.fromScale(0.5, 0.5)
	confirm.Size = UDim2.fromOffset(520, 170)
	confirm.BackgroundColor3 = PANEL
	confirm.BorderSizePixel = 0
	confirm.Parent = gui
	corner(confirm, 10)
	local line = Instance.new("UIStroke")
	line.Color = Color3.fromRGB(200, 60, 50)
	line.Thickness = 2
	line.Parent = confirm
	local words = Instance.new("TextLabel")
	words.BackgroundTransparency = 1
	words.Size = UDim2.new(1, -30, 0, 80)
	words.Position = UDim2.fromOffset(15, 14)
	words.Font = Enum.Font.GothamBold
	words.TextSize = 16
	words.TextWrapped = true
	words.TextColor3 = TEXT
	words.Text = T.wipeAsk
	words.Parent = confirm
	local yes = button(confirm, T.wipeYes, UDim2.fromOffset(200, 44), UDim2.fromOffset(40, 110))
	yes.Name = "Sim"
	yes.BackgroundColor3 = Color3.fromRGB(170, 44, 40)
	local no = button(confirm, T.resetNo, UDim2.fromOffset(200, 44), UDim2.fromOffset(280, 110))
	no.Name = "Nao"

	ask.Activated:Connect(function()
		confirm.Visible = true
	end)
	no.Activated:Connect(function()
		confirm.Visible = false
	end)
	yes.Activated:Connect(function()
		confirm.Visible = false
		Remotes.Admin:FireServer("wipe")
	end)
end

--[[
	ANIMATIONS: every animation of Config.Animations that has a number, to try
	on my own character (only on this screen: nobody else sees it). One at a
	time; STOP ends it.
]]
do
	local Animacoes = require(Shared:WaitForChild("Animacoes"))
	local y = rowLabel(8, T.animations)
	local openList = button(panel, T.animations, UDim2.fromOffset(190, ROW - 14), UDim2.fromOffset(LABEL, y + 4))
	openList.Name = "Animacoes"

	local list = Instance.new("ScrollingFrame")
	list.Name = "ListaAnimacoes"
	list.Visible = false
	list.BackgroundColor3 = PANEL
	list.BackgroundTransparency = 0.08
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 16 + panel.Size.X.Offset + 8, 1, -(52 + 34 + rows * ROW + 8))
	list.Size = UDim2.fromOffset(220, 34 + rows * ROW + 8)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.Parent = gui
	corner(list, 10)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = list

	local playing: AnimationTrack? = nil
	local function stop()
		if playing then
			playing:Stop(0.2)
			playing = nil
		end
	end
	local stopButton = button(list, T.animationsStop, UDim2.new(1, 0, 0, 30), UDim2.new())
	stopButton.Name = "Parar"
	stopButton.BackgroundColor3 = Color3.fromRGB(120, 44, 40)
	stopButton.Activated:Connect(stop)

	local names: { string } = {}
	for name in Config.Animations :: any do
		if Animacoes.has(name) then
			table.insert(names, name)
		end
	end
	table.sort(names)
	for _, name in names do
		local b = button(list, name, UDim2.new(1, 0, 0, 30), UDim2.new())
		b.Name = "Anim_" .. name
		b.AutoLocalize = false
		b.Activated:Connect(function()
			stop()
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			local track = if animator then Animacoes.track(animator, name) else nil
			if track then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Action4
				Animacoes.play(track, name, 0.2)
				playing = track
			end
		end)
	end

	openList.Activated:Connect(function()
		list.Visible = not list.Visible
		if not list.Visible then
			stop()
		end
	end)
	open.Activated:Connect(function()
		if not panel.Visible then
			list.Visible = false
			stop()
		end
	end)
end
