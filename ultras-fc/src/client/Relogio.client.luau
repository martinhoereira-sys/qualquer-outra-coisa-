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

local box = Instance.new("Frame")
box.Name = "Relogio"
box.AnchorPoint = Vector2.new(0, 0)
box.Position = UDim2.fromOffset(326, 60)
box.Size = UDim2.fromOffset(236, 52)
box.BackgroundColor3 = PANEL
box.BackgroundTransparency = 0.2
box.BorderSizePixel = 0
box.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = box

local function label(parent: Instance, size: number, colour: Color3, y: number, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -16, 0, size + 6)
	l.Position = UDim2.fromOffset(8, y)
	l.Font = font
	l.TextSize = size
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

local timeLine = label(box, 13, MUTED, 4, Enum.Font.GothamBold)
local nextLine = label(box, 15, GOLD, 24, Enum.Font.GothamBlack)

-- The notice two minutes before a match, and the button for the two clubs.
local notice = Instance.new("TextLabel")
notice.Visible = false
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, 120)
notice.Size = UDim2.fromOffset(420, 40)
notice.BackgroundColor3 = PANEL
notice.BackgroundTransparency = 0.15
notice.BorderSizePixel = 0
notice.Font = Enum.Font.GothamBlack
notice.TextSize = 18
notice.TextColor3 = GOLD
notice.Text = T.notice
notice.Parent = gui
local noticeCorner = Instance.new("UICorner")
noticeCorner.CornerRadius = UDim.new(0, 8)
noticeCorner.Parent = notice

local go = Instance.new("TextButton")
go.Visible = false
go.AnchorPoint = Vector2.new(0.5, 0)
go.Position = UDim2.new(0.5, 0, 0, 168)
go.Size = UDim2.fromOffset(300, 48)
go.BackgroundColor3 = Color3.fromRGB(40, 150, 90)
go.BorderSizePixel = 0
go.Font = Enum.Font.GothamBlack
go.TextSize = 17
go.TextColor3 = TEXT
go.Text = T.go
go.Parent = gui
local goCorner = Instance.new("UICorner")
goCorner.CornerRadius = UDim.new(0, 8)
goCorner.Parent = go

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

		-- Two minutes before the match of this slot.
		local toKickOff = Schedule.slotStart(moment.slot) - game
		local soon = not moment.night and toKickOff > 0 and toKickOff <= Config.Schedule.noticeSeconds
		notice.Visible = soon and toKickOff > Config.Schedule.noticeSeconds - 12
		local teamId = player:GetAttribute("Team")
		local mine = type(teamId) == "string" and Config.Teams[teamId] ~= nil
		go.Visible = soon and mine and usedFor ~= moment.slot
		task.wait(0.5)
	end
end)
