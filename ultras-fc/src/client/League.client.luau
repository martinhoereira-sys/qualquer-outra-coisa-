--!strict
--[[
	The league table, on the screen at any time (the TABLE button).

	  position · flag · club · played · W · D · L · goals · points

	My club is highlighted; the second club I follow has a discreet mark. A
	small star by the name for each title a club has won. The top of the panel
	says how long the season still has ("2 DAYS LEFT").

	The numbers come from the server (workspace attribute "Liga", written by
	server/League): nothing here is counted on this side.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Emblem = require(Shared:WaitForChild("Emblem"))
local Calendar = require(Shared:WaitForChild("Calendar"))
local Schedule = require(Shared:WaitForChild("Schedule"))

local player = Players.LocalPlayer
local T = Config.Text.league

local PANEL = Color3.fromRGB(18, 22, 32)
local ROW = Color3.fromRGB(30, 34, 46)
local TEXT = Color3.fromRGB(236, 238, 242)
local MUTED = Color3.fromRGB(141, 150, 163)
local GOLD = Color3.fromRGB(255, 200, 60)

local gui = Instance.new("ScreenGui")
gui.Name = "UltrasLiga"
gui.ResetOnSpawn = false
gui.DisplayOrder = 15
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, value: string, size: number, colour: Color3, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = colour
	l.Text = value
	l.Parent = parent
	return l
end

local open = Instance.new("TextButton")
open.Size = UDim2.fromOffset(114, 28)
open.Position = UDim2.fromOffset(16, 246)
open.BackgroundColor3 = Color3.fromRGB(58, 62, 72)
open.BackgroundTransparency = 0.15
open.BorderSizePixel = 0
open.Font = Enum.Font.GothamBold
open.TextSize = 12
open.TextColor3 = TEXT
open.Text = T.open
open.Parent = gui
corner(open, 6)

local WIDTH = 620
local LINE = 34
local panel = Instance.new("Frame")
panel.Visible = false
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(WIDTH, 96 + #Config.ClubOrder * LINE + 12)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Parent = gui
corner(panel, 12)

local title = text(panel, T.title, 20, GOLD, Enum.Font.GothamBlack)
title.Size = UDim2.fromOffset(300, 28)
title.Position = UDim2.fromOffset(18, 12)
title.TextXAlignment = Enum.TextXAlignment.Left

local left = text(panel, "", 13, TEXT, Enum.Font.GothamBlack)
left.Size = UDim2.fromOffset(200, 28)
left.Position = UDim2.fromOffset(WIDTH - 266, 12)
left.TextXAlignment = Enum.TextXAlignment.Right

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(32, 28)
close.Position = UDim2.fromOffset(WIDTH - 48, 12)
close.BackgroundColor3 = Color3.fromRGB(58, 62, 72)
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBlack
close.TextSize = 14
close.TextColor3 = TEXT
close.Text = "X"
close.AutoLocalize = false
close.Parent = panel
corner(close, 6)

-- The columns: where each number goes.
local COLUMNS = { { T.played, 330 }, { T.won, 372 }, { T.drawn, 408 }, { T.lost, 444 }, { T.goals, 494 }, { T.points, 560 } }
for _, column in COLUMNS do
	local head = text(panel, column[1], 11, MUTED, Enum.Font.GothamBlack)
	head.Size = UDim2.fromOffset(50, 20)
	head.Position = UDim2.fromOffset(column[2] - 25, 56)
end

local list = Instance.new("Frame")
list.BackgroundTransparency = 1
list.Size = UDim2.fromOffset(WIDTH - 24, #Config.ClubOrder * LINE)
list.Position = UDim2.fromOffset(12, 82)
list.Parent = panel

local function draw()
	list:ClearAllChildren()
	local raw = workspace:GetAttribute("Epoca")
	local ok, season = pcall(function()
		return HttpService:JSONDecode(raw :: string)
	end)
	if not ok or type(season) ~= "table" or type(season.results) ~= "table" then
		return
	end
	local won = if type(season.titles) == "table" and type(season.titles.liga) == "table" then season.titles.liga else {}
	local data = { rows = {}, ends = Schedule.weekStart(season.week) + 6 * 24 * 3600 }
	for position, row in Calendar.leagueTable(season) do
		table.insert(data.rows, { club = row.club, pos = position, p = row.p, w = row.w, d = row.d, l = row.l, gf = row.gf, ga = row.ga, pts = row.pts, titles = won[row.club] or 0 })
	end
	local mine = player:GetAttribute("Clube")
	local second = player:GetAttribute("Clube2")
	for i, entry in data.rows do
		local club = (Config.Clubs :: any)[entry.club]
		if not club then
			continue
		end
		local row = Instance.new("Frame")
		row.BackgroundColor3 = ROW
		row.BackgroundTransparency = if entry.club == mine then 0 else 0.45
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, LINE - 4)
		row.Position = UDim2.fromOffset(0, (i - 1) * LINE)
		row.Parent = list
		corner(row, 6)
		if entry.club == mine then
			local edge = Instance.new("UIStroke")
			edge.Color = GOLD
			edge.Thickness = 1.5
			edge.Parent = row
		end

		local position = text(row, tostring(entry.pos), 13, if entry.club == mine then GOLD else TEXT, Enum.Font.GothamBlack)
		position.Size = UDim2.fromOffset(26, LINE - 4)
		position.Position = UDim2.fromOffset(4, 0)

		local flag = Instance.new("Frame")
		flag.BackgroundTransparency = 1
		flag.Size = UDim2.fromOffset(21, 14)
		flag.Position = UDim2.fromOffset(34, (LINE - 4 - 14) / 2)
		flag.Parent = row
		Emblem.flag(flag, club.country)

		local crest = Instance.new("Frame")
		crest.BackgroundTransparency = 1
		crest.Size = UDim2.fromOffset(24, 24)
		crest.Position = UDim2.fromOffset(62, (LINE - 4 - 24) / 2)
		crest.Parent = row
		Emblem.draw(crest, club, { year = false })

		-- The name is a proper name: never translated. A star for each title.
		local stars = string.rep("★", math.min(entry.titles or 0, 5))
		local name = text(row, club.name .. (if stars ~= "" then "  " .. stars else ""), 13, TEXT, Enum.Font.GothamBold)
		name.AutoLocalize = false
		name.Size = UDim2.fromOffset(200, LINE - 4)
		name.Position = UDim2.fromOffset(94, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		if entry.club == second then
			-- The club I follow: a discreet mark.
			local mark = Instance.new("Frame")
			mark.BackgroundColor3 = MUTED
			mark.BorderSizePixel = 0
			mark.Size = UDim2.fromOffset(3, LINE - 14)
			mark.Position = UDim2.fromOffset(0, 5)
			mark.Parent = row
		end

		local values = { entry.p, entry.w, entry.d, entry.l, entry.gf .. ":" .. entry.ga, entry.pts }
		for k, column in COLUMNS do
			local v = text(row, tostring(values[k]), 13, if k == #COLUMNS then GOLD else TEXT, if k == #COLUMNS then Enum.Font.GothamBlack else Enum.Font.Gotham)
			v.AutoLocalize = false
			v.Size = UDim2.fromOffset(50, LINE - 4)
			v.Position = UDim2.fromOffset(column[2] - 25 - 12, 0)
		end
	end

	-- How long the season still has.
	local seconds = (if type(data.ends) == "number" then data.ends else 0) - Schedule.gameTime()
	local days = math.ceil(seconds / 86400)
	left.Text = if days > 1 then string.format(T.daysLeft, days) elseif days == 1 then T.lastDay else T.over
end

open.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		draw()
	end
end)
close.Activated:Connect(function()
	panel.Visible = false
end)
workspace:GetAttributeChangedSignal("Epoca"):Connect(function()
	if panel.Visible then
		draw()
	end
end)
