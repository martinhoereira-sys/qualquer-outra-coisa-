--!strict
--[[
	The clock on the screen, always in sight (in the stadium and in the city):

	  21:37  ·  your time 22:37          the game's time and, beside it, mine
	  NEXT MATCH IN 04:12                or, at night:
	  NIGHT · FIRST MATCH AT 09:00

	Two minutes before each match everyone is told, and whoever is of one of
	the two clubs gets a button: GO TO THE MATCH.

	The times come from shared/Schedule (the real time of the world); nothing
	is counted on this side.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Schedule = require(Shared:WaitForChild("Schedule"))
local Calendar = require(Shared:WaitForChild("Calendar"))
local UI = require(Shared:WaitForChild("UI"))
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local T = Config.Text.clock

local TEXT = Color3.fromRGB(236, 238, 242)
local MUTED = Color3.fromRGB(170, 176, 188)
local GOLD = Color3.fromRGB(255, 200, 60)
local PANEL = Color3.fromRGB(18, 22, 32)

local gui = Instance.new("ScreenGui")
gui.Name = "UltrasRelogio"
gui.ResetOnSpawn = false
gui.DisplayOrder = 11
gui.Parent = player:WaitForChild("PlayerGui")
UI.scale(gui, true)
local U = Config.UI

local box = Instance.new("Frame")
box.Name = "Relogio"
-- In the top right corner: how long until the next match.
box.AnchorPoint = Vector2.new(1, 0)
box.Position = UDim2.new(1, -U.gap, 0, U.gap / 2)
box.Size = UDim2.fromOffset(380, U.button)
box.BackgroundColor3 = U.panel
box.BackgroundTransparency = U.panelTransparency
box.BorderSizePixel = 0
box.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, U.corner)
corner.Parent = box

local function label(parent: Instance, size: number, colour: Color3, y: number, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -U.gap * 2, 0, size + 4)
	l.Position = UDim2.fromOffset(U.gap, y)
	l.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.MinTextSize = 10
	limit.Parent = l
	l.Font = font
	l.TextSize = size
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

local nextLine = label(box, U.normal, U.text, 2, Enum.Font.GothamBlack)
local timeLine = label(box, U.small - 4, U.text, 34, Enum.Font.GothamMedium)
timeLine.TextTransparency = U.dim
-- Which competition the match on now is of (and NO FANS when it is played between bots).
local compLine = label(box, U.small - 4, U.text, 58, Enum.Font.GothamMedium)

-- The notice two minutes before a match, and the button for the two clubs.
local notice = Instance.new("TextLabel")
notice.Visible = false
-- Under the clock, on the same edge: the middle of the screen stays free.
notice.AnchorPoint = Vector2.new(1, 0)
notice.Position = UDim2.new(1, -U.gap, 0, U.gap / 2 + (U.button + U.gap / 2) * 3)
notice.Size = UDim2.fromOffset(380, U.small + 16)
notice.BackgroundColor3 = U.panel
notice.BackgroundTransparency = U.panelTransparency
notice.BorderSizePixel = 0
notice.Font = Enum.Font.GothamBlack
notice.TextSize = U.small
notice.TextColor3 = U.text
notice.Text = T.notice
notice.Parent = gui
local noticeCorner = Instance.new("UICorner")
noticeCorner.CornerRadius = UDim.new(0, U.corner)
noticeCorner.Parent = notice

local go = Instance.new("TextButton")
go.Visible = false
go.AnchorPoint = Vector2.new(1, 0)
go.Position = UDim2.new(1, -U.gap, 0, U.gap / 2 + (U.button + U.gap / 2) * 2) -- (under the capo's button)
go.Size = UDim2.fromOffset(380, U.button)
go.BackgroundColor3 = U.panel
go.BackgroundTransparency = 0
go.BorderSizePixel = 0
go.Font = Enum.Font.GothamBlack
go.TextSize = U.normal
go.TextColor3 = U.text
go.Text = T.go
go.Parent = gui
local goCorner = Instance.new("UICorner")
goCorner.CornerRadius = UDim.new(0, U.corner)
goCorner.Parent = go
UI.outline(go, U.text)

local usedFor = -1 -- the slot the button was already used for
go.Activated:Connect(function()
	usedFor = Schedule.at(Schedule.gameTime()).slot
	go.Visible = false
	Remotes.Home:FireServer("jogo")
end)

-- My own time: the game's time moved by the difference between my clock and UTC.
local function localClock(now: number): string
	local date = os.date("*t", math.floor(now))
	return string.format("%02d:%02d", date.hour, date.min)
end

task.spawn(function()
	while true do
		local now = Schedule.now()
		local game = Schedule.gameTime(now)
		local moment = Schedule.at(game)
		timeLine.Text = Schedule.clock(game) .. "  ·  " .. string.format(T.local_, localClock(now))
		local kickOff = Schedule.nextKickOff(game)
		-- In the break before a match, the "next match" is the one about to start.
		if not moment.night and (moment.phase == "clubhouse" or moment.phase == "corteo") then
			kickOff = Schedule.slotStart(moment.slot)
		end
		if moment.night then
			nextLine.Text = string.format(T.night, Schedule.clock(Schedule.slotStart(moment.slot)))
		else
			nextLine.Text = string.format(T.nextIn, Schedule.countdown(kickOff - game))
		end

		-- The competition of the match of this slot.
		local raw = workspace:GetAttribute("Jogo")
		local okMatch, match = pcall(function()
			return HttpService:JSONDecode(raw :: string)
		end)
		local supercup = false
		if okMatch and type(match) == "table" and match.slot == moment.slot and not moment.night then
			local key, value = Calendar.label(match)
			local text = (Config.Text.comp :: any)[key]
			compLine.Text = (if value ~= nil then string.format(text, value) else text) .. (if match.noFans then "  ·  " .. Config.Text.comp.noFans else "")
			supercup = match.kind == "supertaca"
		else
			compLine.Text = ""
		end
		go.Text = if supercup then Config.Text.comp.goSuper else T.go

		-- Two minutes before the match of this slot.
		local toKickOff = Schedule.slotStart(moment.slot) - game
		local soon = not moment.night and toKickOff > 0 and toKickOff <= Config.Schedule.noticeSeconds
		notice.Visible = soon and toKickOff > Config.Schedule.noticeSeconds - 12
		local teamId = player:GetAttribute("Team")
		local mine = type(teamId) == "string" and Config.Teams[teamId] ~= nil
		-- (The supercup is for everyone: whoever is of neither club goes in as a neutral.)
		go.Visible = soon and (mine or supercup) and usedFor ~= moment.slot
		task.wait(0.5)
	end
end)
