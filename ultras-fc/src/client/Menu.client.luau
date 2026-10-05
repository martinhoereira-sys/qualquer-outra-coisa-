--!strict
--[[
	THE MENU of the competitions (the COMPETITIONS button), with tabs:

	  SCHEDULE   the next 24 hours, slot by slot, starting at the hour it is
	  LEAGUE     the table of all the clubs
	  CUP        the two groups and the knockout matches
	  SUPERCUP   who is in it and how long until Sunday
	  HONOUR     the board of the month: titles by competition

	In every tab my club is highlighted, and on top there is always when my
	club plays next and in which competition.

	Everything shown comes from the server (workspace attributes "Epoca" and
	"Jogo", written by server/Competition) through shared/Calendar: nothing is
	counted on this side. Club names are proper names and are never translated.
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
local T = Config.Text.menu
local COMP = Config.Text.comp

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

-- Small screens: everything shrinks together.
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function rescale()
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	uiScale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.5, 1)
end
rescale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, value: string, size: number, colour: Color3, font: Enum.Font?, proper: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = colour
	l.Text = value
	l.TextTruncate = Enum.TextTruncate.AtEnd
	if proper then
		l.AutoLocalize = false
	end
	l.Parent = parent
	return l
end

local function frame(parent: Instance, colour: Color3, size: UDim2, position: UDim2, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = position
	f.Parent = parent
	return f
end

local function button(parent: Instance, value: string, size: UDim2, position: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = Color3.fromRGB(58, 62, 72)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = TEXT
	b.Text = value
	b.Parent = parent
	corner(b, 6)
	return b
end

local open = button(gui, T.open, UDim2.fromOffset(150, 28), UDim2.fromOffset(16, 246))
open.Name = "Abrir"
open.BackgroundTransparency = 0.15

local WIDTH, HEIGHT = 780, 520
local panel = frame(gui, PANEL, UDim2.fromOffset(WIDTH, HEIGHT), UDim2.fromScale(0.5, 0.5), 0.03)
panel.Name = "Painel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Visible = false
corner(panel, 12)

local close = button(panel, "X", UDim2.fromOffset(32, 28), UDim2.fromOffset(WIDTH - 44, 10))
close.AutoLocalize = false

-- Always on top: when my club plays next, and in which competition.
local mine = text(panel, "", 15, GOLD, Enum.Font.GothamBlack, true)
mine.Size = UDim2.fromOffset(WIDTH - 80, 26)
mine.Position = UDim2.fromOffset(16, 10)
mine.TextXAlignment = Enum.TextXAlignment.Left

local TABS = { "schedule", "league", "cup", "supercup", "honour" }
local tabButtons: { [string]: TextButton } = {}
local page = Instance.new("ScrollingFrame")
page.Name = "Pagina"
page.BackgroundTransparency = 1
page.BorderSizePixel = 0
page.Size = UDim2.fromOffset(WIDTH - 24, HEIGHT - 96)
page.Position = UDim2.fromOffset(12, 84)
page.ScrollBarThickness = 6
page.CanvasSize = UDim2.fromOffset(0, 0)
page.AutomaticCanvasSize = Enum.AutomaticSize.Y
page.Parent = panel

local current = "schedule"

--------------------------------------------------------------------------------
-- What the server says
--------------------------------------------------------------------------------

local function season(): Calendar.State?
	local raw = workspace:GetAttribute("Epoca")
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw :: string)
	end)
	if not ok or type(data) ~= "table" or type(data.results) ~= "table" then
		return nil
	end
	return data
end

local function matchNow(): any
	local raw = workspace:GetAttribute("Jogo")
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw :: string)
	end)
	return if ok and type(data) == "table" then data else nil
end

local function compText(fixture: any): string
	local key, value = Calendar.label(fixture)
	local words = (COMP :: any)[key]
	return if value ~= nil then string.format(words, value) else words
end

-- The plan of the next `count` slots from `from`: { slot, fixture? , night }.
local function plan(state: Calendar.State, from: number, count: number): { any }
	local list = {}
	local taken: { [string]: boolean } = {}
	local now = matchNow()
	for k = from, from + count - 1 do
		if not Schedule.isOfficial(k) then
			table.insert(list, { slot = k, night = true })
		else
			local fixture: any = nil
			if now and now.slot == k then
				fixture = now
			else
				fixture = Calendar.planned(k, state, taken)
			end
			if fixture then
				taken[fixture.id] = true
			end
			table.insert(list, { slot = k, fixture = fixture, night = false })
		end
	end
	return list
end

--------------------------------------------------------------------------------
-- Pieces
--------------------------------------------------------------------------------

local function myClub(): string?
	local club = player:GetAttribute("Clube")
	return if type(club) == "string" then club else nil
end

-- flag + emblem + name of a club, starting at x (to the right) or ending at x (to the left).
local function clubCell(parent: Instance, clubId: string, x: number, height: number, toLeft: boolean, width: number)
	local club = (Config.Clubs :: any)[clubId]
	if not club then
		return
	end
	local flag = frame(parent, PANEL, UDim2.fromOffset(18, 12), UDim2.fromOffset(if toLeft then x - 18 else x, (height - 12) / 2), 1)
	Emblem.flag(flag, club.country)
	local crest = frame(parent, PANEL, UDim2.fromOffset(22, 22), UDim2.fromOffset(if toLeft then x - 44 else x + 22, (height - 22) / 2), 1)
	Emblem.draw(crest, club, { year = false })
	local name = text(parent, club.name, 13, if clubId == myClub() then GOLD else TEXT, Enum.Font.GothamBold, true)
	name.Size = UDim2.fromOffset(width - 50, height)
	name.Position = UDim2.fromOffset(if toLeft then x - width else x + 50, 0)
	name.TextXAlignment = if toLeft then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
end

local function section(y: number, words: string): number
	local l = text(page, words, 12, MUTED, Enum.Font.GothamBlack)
	l.Size = UDim2.fromOffset(WIDTH - 40, 20)
	l.Position = UDim2.fromOffset(4, y)
	l.TextXAlignment = Enum.TextXAlignment.Left
	return y + 24
end

-- A table of clubs (league or a cup group) at (x, y), `width` wide. Returns the height used.
local function drawTable(rows: { Calendar.Row }, x: number, y: number, width: number, stars: { [string]: number }?, through: number?): number
	local LINE = 30
	local columns = { { T.played, 0.52 }, { T.won, 0.6 }, { T.drawn, 0.67 }, { T.lost, 0.74 }, { T.goals, 0.84 }, { T.points, 0.95 } }
	for _, column in columns do
		local head = text(page, column[1], 10, MUTED, Enum.Font.GothamBlack)
		head.Size = UDim2.fromOffset(44, 16)
		head.Position = UDim2.fromOffset(x + width * column[2] - 22, y)
	end
	y += 18
	for i, entry in rows do
		local club = (Config.Clubs :: any)[entry.club]
		local isMine = entry.club == myClub()
		local row = frame(page, ROW, UDim2.fromOffset(width, LINE - 4), UDim2.fromOffset(x, y + (i - 1) * LINE), if isMine then 0 else 0.45)
		corner(row, 6)
		if isMine then
			local edge = Instance.new("UIStroke")
			edge.Color = GOLD
			edge.Thickness = 1.5
			edge.Parent = row
		end
		-- The ones that go through (cup groups) have a mark.
		if through and i <= through then
			frame(row, GOLD, UDim2.fromOffset(3, LINE - 12), UDim2.fromOffset(0, 4))
		end
		local position = text(row, tostring(i), 12, if isMine then GOLD else TEXT, Enum.Font.GothamBlack)
		position.AutoLocalize = false
		position.Size = UDim2.fromOffset(22, LINE - 4)
		position.Position = UDim2.fromOffset(5, 0)
		local flag = frame(row, PANEL, UDim2.fromOffset(18, 12), UDim2.fromOffset(28, (LINE - 16) / 2), 1)
		Emblem.flag(flag, club.country)
		local crest = frame(row, PANEL, UDim2.fromOffset(22, 22), UDim2.fromOffset(50, (LINE - 26) / 2), 1)
		Emblem.draw(crest, club, { year = false })
		local won = if stars then stars[entry.club] or 0 else 0
		local name = text(row, club.name .. (if won > 0 then "  " .. string.rep("★", math.min(won, 5)) else ""), 12, TEXT, Enum.Font.GothamBold, true)
		name.Size = UDim2.fromOffset(width * 0.5 - 84, LINE - 4)
		name.Position = UDim2.fromOffset(78, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local values = { entry.p, entry.w, entry.d, entry.l, entry.gf .. ":" .. entry.ga, entry.pts }
		for k, column in columns do
			local v = text(row, tostring(values[k]), 12, if k == #columns then GOLD else TEXT, if k == #columns then Enum.Font.GothamBlack else Enum.Font.Gotham)
			v.AutoLocalize = false
			v.Size = UDim2.fromOffset(44, LINE - 4)
			v.Position = UDim2.fromOffset(width * column[2] - 22, 0)
		end
	end
	return 18 + #rows * LINE
end

-- One match on a line: home  score  away.
local function matchLine(y: number, fixture: any, result: any, head: string?, width: number?, x: number?): number
	local w = width or (WIDTH - 40)
	local left = x or 4
	local row = frame(page, ROW, UDim2.fromOffset(w, 30), UDim2.fromOffset(left, y), 0.45)
	corner(row, 6)
	if fixture.home == myClub() or fixture.away == myClub() then
		local edge = Instance.new("UIStroke")
		edge.Color = GOLD
		edge.Thickness = 1.5
		edge.Parent = row
		row.BackgroundTransparency = 0
	end
	local headWidth = if head then 150 else 0
	if head then
		local h = text(row, head, 11, MUTED, Enum.Font.GothamBlack)
		h.Size = UDim2.fromOffset(headWidth - 10, 30)
		h.Position = UDim2.fromOffset(8, 0)
		h.TextXAlignment = Enum.TextXAlignment.Left
	end
	local centre = headWidth + (w - headWidth) / 2
	local side = (w - headWidth) / 2 - 34
	clubCell(row, fixture.home, centre - 34, 30, true, side)
	clubCell(row, fixture.away, centre + 34, 30, false, side)
	local score = if result then result.h .. " - " .. result.a else "v"
	local s = text(row, score, 13, if result then GOLD else MUTED, Enum.Font.GothamBlack)
	s.AutoLocalize = false
	s.Size = UDim2.fromOffset(60, 30)
	s.Position = UDim2.fromOffset(centre - 30, 0)
	return y + 34
end

--------------------------------------------------------------------------------
-- The tabs
--------------------------------------------------------------------------------

local function drawSchedule(state: Calendar.State)
	-- From the match on now (or, in the break, the one about to start).
	local first = Schedule.at(Schedule.gameTime()).slot
	if Schedule.at(Schedule.gameTime()).night then
		first = Schedule.slotOf(Schedule.gameTime())
	end
	local y = section(0, T.scheduleNote)
	local nightOpen = false
	for _, entry in plan(state, first, math.floor(24 * 3600 / Schedule.SLOT)) do
		local start = Schedule.slotStart(entry.slot)
		if entry.night then
			-- The whole night is one line.
			if not nightOpen then
				nightOpen = true
				local row = frame(page, Color3.fromRGB(12, 14, 22), UDim2.fromOffset(WIDTH - 40, 30), UDim2.fromOffset(4, y), 0.2)
				corner(row, 6)
				local l = text(row, string.format(T.night, Schedule.clock(start), string.format("%02d:00", Config.Schedule.firstHour)), 12, MUTED, Enum.Font.GothamBold)
				l.Size = UDim2.fromScale(1, 1)
				y += 34
			end
			continue
		end
		nightOpen = false
		local fixture = entry.fixture
		local isNow = entry.slot == first
		local row = frame(page, ROW, UDim2.fromOffset(WIDTH - 40, 30), UDim2.fromOffset(4, y), 0.45)
		corner(row, 6)
		local involved = fixture ~= nil and (fixture.home == myClub() or fixture.away == myClub())
		if involved then
			local edge = Instance.new("UIStroke")
			edge.Color = GOLD
			edge.Thickness = 1.5
			edge.Parent = row
			row.BackgroundTransparency = 0
		end
		local time = text(row, Schedule.clock(start), 13, if isNow then GOLD else TEXT, Enum.Font.GothamBlack)
		time.AutoLocalize = false
		time.Size = UDim2.fromOffset(50, 30)
		time.Position = UDim2.fromOffset(6, 0)
		if not fixture then
			local l = text(row, T.openSlot, 12, MUTED, Enum.Font.Gotham)
			l.Size = UDim2.fromOffset(WIDTH - 120, 30)
			l.Position = UDim2.fromOffset(60, 0)
		else
			local derby = Calendar.isDerby(fixture.home, fixture.away)
			local comp = text(row, compText(fixture) .. (if derby then "  ·  " .. T.derby else ""), 10, if derby then GOLD else MUTED, Enum.Font.GothamBlack)
			comp.Size = UDim2.fromOffset(170, 30)
			comp.Position = UDim2.fromOffset(58, 0)
			comp.TextXAlignment = Enum.TextXAlignment.Left
			local centre = 230 + (WIDTH - 40 - 230) / 2
			clubCell(row, fixture.home, centre - 20, 30, true, 220)
			clubCell(row, fixture.away, centre + 20, 30, false, 220)
			local v = text(row, "v", 12, MUTED, Enum.Font.GothamBlack)
			v.AutoLocalize = false
			v.Size = UDim2.fromOffset(20, 30)
			v.Position = UDim2.fromOffset(centre - 10, 0)
		end
		y += 34
	end
end

local function drawLeague(state: Calendar.State)
	local data: any = state
	local won = if type(data.titles) == "table" and type(data.titles.liga) == "table" then data.titles.liga else {}
	local ends = Schedule.weekStart(state.week) + 6 * 24 * 3600
	local days = math.ceil((ends - Schedule.gameTime()) / 86400)
	local y = section(0, if days > 1 then string.format(T.daysLeft, days) elseif days == 1 then T.lastDay else T.over)
	drawTable(Calendar.leagueTable(state), 4, y, WIDTH - 40, won)
end

local function drawCup(state: Calendar.State)
	local tables = Calendar.groupTables(state)
	local half = (WIDTH - 52) / 2
	local y = 0
	local used = 0
	for i, name in { "A", "B" } do
		local x = 4 + (i - 1) * (half + 12)
		local head = text(page, string.format(T.group, name), 12, MUTED, Enum.Font.GothamBlack)
		head.Size = UDim2.fromOffset(half, 20)
		head.Position = UDim2.fromOffset(x, y)
		head.TextXAlignment = Enum.TextXAlignment.Left
		used = math.max(used, drawTable(tables[name], x, y + 22, half, nil, 2))
	end
	y = y + 22 + used + 10
	y = section(y, T.knockout)
	local semis = Calendar.semis(state)
	for i, fixture in semis do
		y = matchLine(y, fixture, state.results[fixture.id], string.format(T.semi, i))
	end
	local final = Calendar.final(state)
	if final then
		y = matchLine(y, final, state.results.F, T.final)
	else
		local l = text(page, T.finalWait, 12, MUTED, Enum.Font.Gotham)
		l.Size = UDim2.fromOffset(WIDTH - 40, 26)
		l.Position = UDim2.fromOffset(4, y)
	end
end

local function drawSupercup(state: Calendar.State)
	local at = Schedule.weekStart(state.week) + 6 * 24 * 3600 + (Config.Competitions.superHour - Config.Schedule.firstHour) * 3600
	local left = at - Schedule.gameTime()
	local y = section(0, if left > 0 then string.format(T.superIn, Schedule.countdown(left)) else T.superPlayed)
	local fixture = Calendar.supercup(state)
	if fixture then
		y = matchLine(y, fixture, state.results.S, if state.super then T.superSet else T.superAsItStands)
	end
	local note = text(page, T.superNote, 12, MUTED, Enum.Font.Gotham)
	note.Size = UDim2.fromOffset(WIDTH - 40, 40)
	note.Position = UDim2.fromOffset(4, y + 6)
	note.TextWrapped = true
end

local function drawHonour(state: Calendar.State)
	local data: any = state
	local month = tostring(Schedule.month(Schedule.gameTime()))
	local byCompetition = if type(data.months) == "table" and type(data.months[month]) == "table" then data.months[month] else {}
	local y = section(0, T.honourMonth)
	local total: { [string]: number } = {}
	local third = (WIDTH - 64) / 3
	local lists = { { "liga", T.honourLeague }, { "taca", T.honourCup }, { "supertaca", T.honourSuper } }
	local tallest = 0
	local function list(x: number, top: number, head: string, counts: { [string]: number }): number
		local h = text(page, head, 11, GOLD, Enum.Font.GothamBlack)
		h.Size = UDim2.fromOffset(third, 20)
		h.Position = UDim2.fromOffset(x, top)
		h.TextXAlignment = Enum.TextXAlignment.Left
		local order = {}
		for clubId, n in counts do
			if (Config.Clubs :: any)[clubId] then
				table.insert(order, { clubId, n })
			end
		end
		table.sort(order, function(a, b)
			return a[2] > b[2]
		end)
		local line = top + 22
		if #order == 0 then
			local none = text(page, T.honourNone, 11, MUTED, Enum.Font.Gotham)
			none.Size = UDim2.fromOffset(third, 20)
			none.Position = UDim2.fromOffset(x, line)
			none.TextXAlignment = Enum.TextXAlignment.Left
			return 44
		end
		for i, entry in order do
			local row = frame(page, ROW, UDim2.fromOffset(third, 26), UDim2.fromOffset(x, line), if entry[1] == myClub() then 0 else 0.45)
			corner(row, 6)
			clubCell(row, entry[1], 4, 26, false, third - 40)
			local n = text(row, tostring(entry[2]), 13, GOLD, Enum.Font.GothamBlack)
			n.AutoLocalize = false
			n.Size = UDim2.fromOffset(30, 26)
			n.Position = UDim2.fromOffset(third - 34, 0)
			line += 30
			if i >= 6 then
				break
			end
		end
		return line - top
	end
	for i, entry in lists do
		local counts = if type(byCompetition[entry[1]]) == "table" then byCompetition[entry[1]] else {}
		for clubId, n in counts do
			total[clubId] = (total[clubId] or 0) + n
		end
		tallest = math.max(tallest, list(4 + (i - 1) * (third + 12), y, entry[2] :: string, counts))
	end
	y += tallest + 12
	list(4, y, T.honourOverall, total)
end

local DRAW: { [string]: (Calendar.State) -> () } = {
	schedule = drawSchedule,
	league = drawLeague,
	cup = drawCup,
	supercup = drawSupercup,
	honour = drawHonour,
}

local function draw()
	for _, child in page:GetChildren() do
		child:Destroy()
	end
	page.CanvasPosition = Vector2.zero
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == current then GOLD else Color3.fromRGB(58, 62, 72)
		b.TextColor3 = if name == current then PANEL else TEXT
	end
	local state = season()
	if not state then
		return
	end
	-- When my club plays next (from the plan of the next 24 hours).
	local clubId = myClub()
	local club = clubId and (Config.Clubs :: any)[clubId]
	mine.Text = ""
	if club then
		mine.Text = string.format(T.noMatch, club.nameUpper)
		local game = Schedule.gameTime()
		local first = if Schedule.at(game).night then Schedule.slotOf(game) else Schedule.at(game).slot
		for _, entry in plan(state, first, math.floor(24 * 3600 / Schedule.SLOT)) do
			local fixture = entry.fixture
			local over = Schedule.slotStart(entry.slot) + Schedule.MATCH < game
			if fixture and not over and (fixture.home == clubId or fixture.away == clubId) then
				mine.Text = string.format(T.yourClub, Schedule.clock(Schedule.slotStart(entry.slot)), compText(fixture))
				break
			end
		end
	end
	DRAW[current](state)
end

for i, name in TABS do
	local b = button(panel, (T :: any)[name], UDim2.fromOffset(144, 30), UDim2.fromOffset(12 + (i - 1) * 150, 44))
	b.Name = "Tab_" .. name
	tabButtons[name] = b
	b.Activated:Connect(function()
		current = name
		draw()
	end)
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
workspace:GetAttributeChangedSignal("Jogo"):Connect(function()
	if panel.Visible and current == "schedule" then
		draw()
	end
end)
