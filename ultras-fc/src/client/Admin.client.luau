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

local rows = 5
local panel = Instance.new("Frame")
panel.Name = "Bar"
panel.Visible = false
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
local EXTRA = 3 * 28 -- the match list is four lines tall
panel.Size = UDim2.fromOffset(LABEL + CELL * 4 + 96, 34 + rows * ROW + 8 + EXTRA)
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
		local b = button(panel, T.off, UDim2.fromOffset(80, ROW - 14), UDim2.fromOffset(LABEL + 4 * CELL + 4, y + 4))
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
	for n, derby in Config.Derbies do
		local home = (Config.Clubs :: any)[derby.home]
		local away = (Config.Clubs :: any)[derby.away]
		-- Three to a row: the two matches of a round, round after round.
		local column, line = (n - 1) % 3, math.floor((n - 1) / 3)
		local b = button(panel, home.short .. " v " .. away.short, UDim2.fromOffset(88, 24), UDim2.fromOffset(LABEL + column * 92, y + 4 + line * 28))
		b.TextSize = 11
		b.Activated:Connect(function()
			Remotes.Admin:FireServer("derby", n)
		end)
		buttons[n] = b
	end
	local function light()
		local current = workspace:GetAttribute("Derby")
		for n, b in buttons do
			b.BackgroundColor3 = if n == current then GOLD else BUTTON
			b.TextColor3 = if n == current then PANEL else TEXT
		end
	end
	workspace:GetAttributeChangedSignal("Derby"):Connect(light)
	light()
end
