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

local UI = require(Shared:WaitForChild("UI"))

local player = Players.LocalPlayer
local T = Config.Text.menu
local COMP = Config.Text.comp
local U = Config.UI

local H = U.canvas.Y
local W = U.canvas.X
local EDGE = U.gap * 1.5
local HALF = U.gap / 2
local MINE = Color3.fromRGB(52, 56, 68) -- my club's line: a lighter ground

-- The button that opens it lives with the rest of the HUD.
local gui = Instance.new("ScreenGui")
gui.Name = "UltrasLiga"
gui.ResetOnSpawn = false
gui.DisplayOrder = 15
gui.Parent = player:WaitForChild("PlayerGui")
local hudScale = Instance.new("UIScale")
hudScale.Parent = gui
local function rescale()
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else U.canvas
	hudScale.Scale = math.clamp(math.min(size.X / U.canvas.X, size.Y / U.canvas.Y), U.minScale, 1)
end
rescale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end
local open = Instance.new("TextButton")
open.Name = "Abrir"
open.Size = UDim2.fromOffset(150, 28)
open.Position = UDim2.fromOffset(16, 246)
open.BackgroundColor3 = Color3.fromRGB(58, 62, 72)
open.BackgroundTransparency = 0.15
open.BorderSizePixel = 0
open.Font = Enum.Font.GothamBold
open.TextSize = 12
open.TextColor3 = U.text
open.Text = T.open
open.Parent = gui
local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 6)
openCorner.Parent = open

-- The menu itself: its own screen, over everything, filling the screen.
local screen = Instance.new("ScreenGui")
screen.Name = "UltrasMenu"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 90
screen.Enabled = false
screen.Parent = player:WaitForChild("PlayerGui")
local scale = UI.scale(screen, false, true)

local ground = Instance.new("Frame")
ground.AnchorPoint = Vector2.new(0.5, 0.5)
ground.Position = UDim2.fromScale(0.5, 0.5)
ground.Size = UDim2.fromOffset(W, H)
ground.BackgroundColor3 = U.ground
ground.BackgroundTransparency = U.groundTransparency
ground.BorderSizePixel = 0
ground.Active = true
ground.Parent = screen
UI.corner(ground)

local panel = Instance.new("Frame")
panel.Name = "Painel"
panel.BackgroundTransparency = 1
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(W, H)
panel.Visible = false
panel.Parent = ground

-- A piece of text at a place. `size` is one of the three; `dim` is secondary text.
local function text(parent: Instance, value: string, size: UI.Size, dim: boolean, x: number, y: number, width: number, height: number, align: Enum.TextXAlignment?, proper: boolean?): TextLabel
	local l = UI.label(parent, value, size, dim, true)
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(width, height)
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	if proper then
		l.AutoLocalize = false
	end
	return l
end

local function row(parent: Instance, x: number, y: number, width: number, height: number, mine: boolean, club: any?): Frame
	local f = UI.panel(parent)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(width, height)
	if mine then
		-- My club: a lighter ground, and its colour as a line round it.
		f.BackgroundColor3 = MINE
		f.BackgroundTransparency = 0
		if club then
			UI.outline(f, club.color)
		end
	end
	return f
end

-- Always on top, big: when my club plays next, and in which competition.
local answer = Instance.new("Frame")
answer.Name = "MeuClube"
answer.BackgroundTransparency = 1
answer.Position = UDim2.fromOffset(EDGE, 20)
answer.Size = UDim2.fromOffset(W - EDGE * 2 - U.button - U.gap, U.button)
answer.Parent = panel
local answerCrest = Instance.new("Frame")
answerCrest.BackgroundTransparency = 1
answerCrest.Size = UDim2.fromOffset(U.button, U.button)
answerCrest.Parent = answer
local answerWords = UI.label(answer, "", "title", false, true)
answerWords.AutoLocalize = false
answerWords.TextXAlignment = Enum.TextXAlignment.Left
answerWords.AnchorPoint = Vector2.new(0, 0.5)
answerWords.Position = UDim2.new(0, U.button + U.gap, 0.5, 0)
answerWords.Size = UDim2.new(1, -(U.button + U.gap), 0, U.title + 6)

local close = UI.button(panel, "X")
close.Name = "Fechar"
close.AutoLocalize = false
close.Size = UDim2.fromOffset(U.button, U.button)

local TABS = { "schedule", "league", "cup", "supercup", "honour" }
local tabButtons: { [string]: TextButton } = {}
local tabLines: { [string]: UIStroke } = {}
local TOP = 20 + (U.button + U.gap) * 2
local page = Instance.new("ScrollingFrame")
page.Name = "Pagina"
page.BackgroundTransparency = 1
page.BorderSizePixel = 0
page.ScrollBarThickness = 6
page.CanvasSize = UDim2.fromOffset(0, 0)
page.AutomaticCanvasSize = Enum.AutomaticSize.Y
page.Parent = panel
local inset = Instance.new("UIPadding")
inset.PaddingLeft = UDim.new(0, U.line)
inset.PaddingRight = UDim.new(0, U.line)
inset.PaddingTop = UDim.new(0, U.line)
inset.PaddingBottom = UDim.new(0, U.line)
inset.Parent = page

-- The width there is to draw in (inside the page).
local PAGE = W - EDGE * 2 - U.line * 2 - 6

-- A wide screen (most phones): the menu uses the width there is.
local function measure()
	local camera = workspace.CurrentCamera
	local wide = if camera then camera.ViewportSize.X / scale.Scale else U.canvas.X
	W = math.clamp(math.floor(wide), U.canvas.X, U.canvas.X * 1.25)
	W = U.canvas.X -- a panel in the middle, on every screen
	PAGE = W - EDGE * 2 - U.line * 2 - 6
	panel.Size = UDim2.fromOffset(W, H)
	ground.Size = UDim2.fromOffset(W, H)
	answer.Size = UDim2.fromOffset(W - EDGE * 2 - U.button - U.gap, U.button)
	close.Position = UDim2.fromOffset(W - EDGE - U.button, 20)
	local tabW = (W - EDGE * 2 - HALF * (#TABS - 1)) / #TABS
	for i, name in TABS do
		local b = tabButtons[name]
		if b then
			b.Position = UDim2.fromOffset(EDGE + (i - 1) * (tabW + HALF), 20 + U.button + U.gap)
			b.Size = UDim2.fromOffset(tabW, U.button)
		end
	end
	page.Position = UDim2.fromOffset(EDGE - U.line, TOP - U.line)
	page.Size = UDim2.fromOffset(W - EDGE * 2 + U.line * 2, H - TOP - 20 + U.line)
end

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

local ROW = U.row
local STEP = U.row + HALF
local CREST = U.row - HALF * 2

local function crestAt(parent: Instance, club: any, x: number, height: number)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(CREST, CREST)
	holder.Position = UDim2.fromOffset(x, (height - CREST) / 2)
	holder.Parent = parent
	Emblem.draw(holder, club, { year = false })
end

-- emblem + name of a club, starting at x (to the right) or ending at x (to the left).
local function clubCell(parent: Instance, clubId: string, x: number, height: number, toLeft: boolean, width: number)
	local club = (Config.Clubs :: any)[clubId]
	if not club then
		return
	end
	crestAt(parent, club, if toLeft then x - CREST else x, height)
	local name = text(parent, club.name, "normal", false, if toLeft then x - width else x + CREST + HALF, 0, width - CREST - HALF, height, if toLeft then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left, true)
	if clubId == myClub() then
		name.Font = Enum.Font.GothamBlack
	end
end

local function section(y: number, words: string): number
	text(page, words, "small", true, 0, y, PAGE, U.small + 6, Enum.TextXAlignment.Left)
	return y + U.small + 6 + HALF
end

--[[
	A table of clubs (league or a cup group) at (x, y), `width` wide. Tall
	lines, few columns: when it is narrow, columns go (never the letter).
	Returns the height used.
]]
local function drawTable(rows: { Calendar.Row }, x: number, y: number, width: number, stars: { [string]: number }?, through: number?): number
	local COLUMN = 84
	local names = if width > 900
		then { "played", "won", "drawn", "lost", "goals", "points" }
		else { "played", "points" }
	local left = width - #names * COLUMN - HALF
	for k, name in names do
		text(page, (T :: any)[name], "small", true, x + left + (k - 1) * COLUMN, y, COLUMN, U.small + 6)
	end
	y += U.small + 6 + HALF
	for i, entry in rows do
		local club = (Config.Clubs :: any)[entry.club]
		local line = row(page, x, y + (i - 1) * STEP, width, ROW, entry.club == myClub(), club)
		-- The ones that go through (cup groups) have a mark.
		if through and i <= through then
			local mark = Instance.new("Frame")
			mark.BackgroundColor3 = U.text
			mark.BorderSizePixel = 0
			mark.Size = UDim2.fromOffset(U.line, ROW - U.gap * 2)
			mark.Position = UDim2.fromOffset(HALF / 2, U.gap)
			mark.Parent = line
		end
		text(line, if entry.missing then "-" else tostring(i), "normal", true, HALF, 0, 44, ROW).AutoLocalize = false
		crestAt(line, club, 44 + HALF * 2, ROW)
		local won = if stars then stars[entry.club] or 0 else 0
		local nameX = 44 + HALF * 3 + CREST
		local name = text(line, club.name .. (if won > 0 then "  " .. string.rep("★", math.min(won, 5)) else ""), "normal", false, nameX, 0, left - nameX - HALF, ROW, Enum.TextXAlignment.Left, true)
		name.Font = Enum.Font.GothamBlack
		local values: { [string]: any } = { played = entry.p, won = entry.w, drawn = entry.d, lost = entry.l, goals = entry.gf .. ":" .. entry.ga, points = entry.pts }
		if entry.missing then
			-- Not ranked yet: how many matches it still needs, in place of the numbers.
			text(line, string.format(T.matchesToGo, entry.missing), "small", true, left, 0, #names * COLUMN, ROW, Enum.TextXAlignment.Right)
			continue
		end
		for k, key in names do
			local v = text(line, tostring(values[key]), "normal", key ~= "points", left + (k - 1) * COLUMN, 0, COLUMN, ROW)
			v.AutoLocalize = false
			if key == "points" then
				v.Font = Enum.Font.GothamBlack
			end
		end
	end
	return U.small + 6 + HALF + #rows * STEP
end

-- One match on a line: (what it is)  home  score  away.
local function matchLine(y: number, fixture: any, result: any, head: string?): number
	local mine = fixture.home == myClub() or fixture.away == myClub()
	local line = row(page, 0, y, PAGE, ROW, mine, (Config.Clubs :: any)[myClub() or ""])
	local headWidth = if head then 240 else 0
	if head then
		text(line, head, "small", true, U.gap, 0, headWidth - U.gap, ROW, Enum.TextXAlignment.Left)
	end
	local centre = headWidth + (PAGE - headWidth) / 2
	local side = (PAGE - headWidth) / 2 - 60 - HALF
	clubCell(line, fixture.home, centre - 60, ROW, true, side)
	clubCell(line, fixture.away, centre + 60, ROW, false, side)
	local score = if result then result.h .. " - " .. result.a else "v"
	local s = text(line, score, "normal", result == nil, centre - 50, 0, 100, ROW)
	s.Font = Enum.Font.GothamBlack
	s.AutoLocalize = false
	return y + STEP
end

--------------------------------------------------------------------------------
-- The tabs
--------------------------------------------------------------------------------

-- The next 24 hours, slot by slot. (When MY club plays is on top of the menu, big.)
local function drawSchedule(state: Calendar.State)
	-- From the match on now (or, in the break, the one about to start).
	local first = Schedule.at(Schedule.gameTime()).slot
	if Schedule.at(Schedule.gameTime()).night then
		first = Schedule.slotOf(Schedule.gameTime())
	end
	local y = 0
	local nightOpen = false
	local TIME, KIND = 120, 280
	for _, entry in plan(state, first, math.floor(24 * 3600 / Schedule.SLOT)) do
		local start = Schedule.slotStart(entry.slot)
		if entry.night then
			-- The whole night is one line.
			if not nightOpen then
				nightOpen = true
				local line = row(page, 0, y, PAGE, ROW, false)
				text(line, string.format(T.night, Schedule.clock(start), string.format("%02d:00", Config.Schedule.firstHour)), "small", true, U.gap, 0, PAGE - U.gap * 2, ROW)
				y += STEP
			end
			continue
		end
		nightOpen = false
		local fixture = entry.fixture
		local involved = fixture ~= nil and (fixture.home == myClub() or fixture.away == myClub() or (fixture.open == true and myClub() ~= nil))
		local line = row(page, 0, y, PAGE, ROW, involved, (Config.Clubs :: any)[myClub() or ""])
		local time = text(line, Schedule.clock(start), "normal", false, U.gap, 0, TIME - U.gap, ROW, Enum.TextXAlignment.Left)
		time.Font = Enum.Font.GothamBlack
		time.AutoLocalize = false
		if not fixture then
			text(line, T.openSlot, "small", true, TIME, 0, PAGE - TIME - U.gap, ROW)
		elseif fixture.open then
			-- A league of no rounds: whoever is there plays.
			text(line, T.openLeague, "small", true, TIME, 0, PAGE - TIME - KIND - U.gap, ROW)
			text(line, compText(fixture), "small", true, PAGE - KIND - U.gap, 0, KIND, ROW, Enum.TextXAlignment.Right)
		else
			local derby = Calendar.isDerby(fixture.home, fixture.away)
			text(line, compText(fixture) .. (if derby then "  ·  " .. T.derby else ""), "small", not derby, PAGE - KIND - U.gap, 0, KIND, ROW, Enum.TextXAlignment.Right)
			local centre = TIME + (PAGE - TIME - KIND - U.gap) / 2
			local side = (PAGE - TIME - KIND - U.gap) / 2 - 30 - HALF
			clubCell(line, fixture.home, centre - 30, ROW, true, side)
			clubCell(line, fixture.away, centre + 30, ROW, false, side)
			text(line, "v", "small", true, centre - 20, 0, 40, ROW).AutoLocalize = false
		end
		y += STEP
	end
end

local function drawLeague(state: Calendar.State)
	local data: any = state
	local won = if type(data.titles) == "table" and type(data.titles.liga) == "table" then data.titles.liga else {}
	local ends = Schedule.weekStart(state.week) + 6 * 24 * 3600
	local days = math.ceil((ends - Schedule.gameTime()) / 86400)
	local y = section(0, if days > 1 then string.format(T.daysLeft, days) elseif days == 1 then T.lastDay else T.over)
	drawTable(Calendar.leagueTable(state), 0, y, PAGE, won)
end

local function drawCup(state: Calendar.State)
	local tables = Calendar.groupTables(state)
	local half = (PAGE - U.gap) / 2
	local y = 0
	local used = 0
	for i, name in { "A", "B" } do
		local x = (i - 1) * (half + U.gap)
		text(page, string.format(T.group, name), "small", true, x, y, half, U.small + 6, Enum.TextXAlignment.Left)
		used = math.max(used, drawTable(tables[name], x, y + U.small + 6, half, nil, 2))
	end
	y = y + U.small + 6 + used + U.gap
	y = section(y, T.knockout)
	local semis = Calendar.semis(state)
	for i, fixture in semis do
		y = matchLine(y, fixture, state.results[fixture.id], string.format(T.semi, i))
	end
	local final = Calendar.final(state)
	if final then
		y = matchLine(y, final, state.results.F, T.final)
	else
		text(page, T.finalWait, "small", true, 0, y, PAGE, ROW)
	end
end

local function drawSupercup(state: Calendar.State)
	local at = Schedule.weekStart(state.week) + 6 * 24 * 3600 + (Config.Competitions.superHour - Config.Schedule.firstHour) * 3600
	local left = at - Schedule.gameTime()
	local head = text(page, if left > 0 then string.format(T.superIn, Schedule.countdown(left)) else T.superPlayed, "title", false, 0, 0, PAGE, U.title + 6, Enum.TextXAlignment.Left)
	head.AutoLocalize = false
	local y = U.title + 6 + U.gap
	local fixture = Calendar.supercup(state)
	if fixture then
		y = matchLine(y, fixture, state.results.S, if state.super then T.superSet else T.superAsItStands)
	end
	local note = text(page, T.superNote, "small", true, 0, y + HALF, PAGE, (U.small + 6) * 2, Enum.TextXAlignment.Left)
	note.TextScaled = false
	note.TextWrapped = true
end

local function drawHonour(state: Calendar.State)
	local data: any = state
	local month = tostring(Schedule.month(Schedule.gameTime()))
	local byCompetition = if type(data.months) == "table" and type(data.months[month]) == "table" then data.months[month] else {}
	local y = section(0, T.honourMonth)
	local total: { [string]: number } = {}
	local third = (PAGE - U.gap * 2) / 3
	local lists = { { "liga", T.honourLeague }, { "taca", T.honourCup }, { "supertaca", T.honourSuper } }
	local tallest = 0
	local function list(x: number, top: number, head: string, counts: { [string]: number }, width: number): number
		text(page, head, "small", false, x, top, width, U.small + 6, Enum.TextXAlignment.Left)
		local order = {}
		for clubId, n in counts do
			if (Config.Clubs :: any)[clubId] then
				table.insert(order, { clubId, n })
			end
		end
		table.sort(order, function(a, b)
			return a[2] > b[2]
		end)
		local line = top + U.small + 6 + HALF
		if #order == 0 then
			text(page, T.honourNone, "small", true, x, line, width, U.small + 6, Enum.TextXAlignment.Left)
			return (U.small + 6) * 2 + HALF
		end
		for i, entry in order do
			local r = row(page, x, line, width, ROW, entry[1] == myClub(), (Config.Clubs :: any)[entry[1]])
			clubCell(r, entry[1], HALF, ROW, false, width - 70)
			local n = text(r, tostring(entry[2]), "normal", false, width - 60, 0, 50, ROW)
			n.Font = Enum.Font.GothamBlack
			n.AutoLocalize = false
			line += STEP
			if i >= 5 then
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
		tallest = math.max(tallest, list((i - 1) * (third + U.gap), y, entry[2] :: string, counts, third))
	end
	y += tallest + U.gap
	list(0, y, T.honourOverall, total, PAGE)
end

local DRAW: { [string]: (Calendar.State) -> () } = {
	schedule = drawSchedule,
	league = drawLeague,
	cup = drawCup,
	supercup = drawSupercup,
	honour = drawHonour,
}

local function draw()
	measure()
	for _, child in page:GetChildren() do
		if not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	page.CanvasPosition = Vector2.zero
	local clubId = myClub()
	local club = clubId and (Config.Clubs :: any)[clubId]
	-- The tab that is open: a line round it (in my club's colour, if I have one).
	for name, line in tabLines do
		line.Enabled = name == current
		line.Color = if club then club.color else U.text
		tabButtons[name].BackgroundColor3 = if name == current then MINE else U.panel
	end
	local state = season()
	if not state then
		return
	end
	-- When my club plays next (from the plan of the next 24 hours).
	answerCrest:ClearAllChildren()
	answerWords.Text = ""
	if club then
		Emblem.draw(answerCrest, club, { year = false })
		answerWords.Text = string.format(T.noMatch, club.nameUpper)
		local game = Schedule.gameTime()
		local first = if Schedule.at(game).night then Schedule.slotOf(game) else Schedule.at(game).slot
		for _, entry in plan(state, first, math.floor(24 * 3600 / Schedule.SLOT)) do
			local fixture = entry.fixture
			local over = Schedule.slotStart(entry.slot) + Schedule.MATCH < game
			if fixture and not over and (fixture.home == clubId or fixture.away == clubId or fixture.open) then
				answerWords.Text = string.format(T.yourClub, Schedule.clock(Schedule.slotStart(entry.slot)), compText(fixture))
				break
			end
		end
	end
	DRAW[current](state)
end

for _, name in TABS do
	local b = UI.button(panel, (T :: any)[name])
	b.Name = "Tab_" .. name
	tabButtons[name] = b
	tabLines[name] = UI.outline(b, U.text)
	b.Activated:Connect(function()
		current = name
		draw()
	end)
end

open.Activated:Connect(function()
	screen.Enabled = not screen.Enabled
	panel.Visible = screen.Enabled
	if screen.Enabled then
		draw()
	end
end)
close.Activated:Connect(function()
	screen.Enabled = false
	panel.Visible = false
end)
workspace:GetAttributeChangedSignal("Epoca"):Connect(function()
	if screen.Enabled then
		draw()
	end
end)
workspace:GetAttributeChangedSignal("Jogo"):Connect(function()
	if screen.Enabled and current == "schedule" then
		draw()
	end
end)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if screen.Enabled then
			task.defer(draw)
		end
	end)
end
