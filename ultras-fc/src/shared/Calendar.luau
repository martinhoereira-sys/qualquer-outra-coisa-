--!strict
--[[
	THE COMPETITIONS, as a calendar. Pure functions of the time, of the clubs
	in Config and of the results so far: the server uses them to know what is
	due, and every screen uses the same ones to draw the tables and the
	timetable. Nothing here assumes a number of clubs.

	THE WEEK (shared/Schedule: it starts on Monday at 09:00)
	  Monday to Saturday   LEAGUE and CUP side by side
	  Sunday               SUPERCUP at Config.Competitions.superHour

	The six days are cut in WINDOWS (Config.Competitions.windowsPerDay a day).
	  LEAGUE  every club against every other, home and away (Config.Derbies).
	          One round opens with each window. A round only closes when all
	          its matches are played: what is left stays due until it is.
	  CUP     two groups drawn on Monday morning; in each, everyone against
	          everyone, home and away. Its rounds open in the first windows of
	          each day from Monday to Friday. The top two of each group go
	          through: semi-finals on Saturday (1st A v 2nd B, 1st B v 2nd A),
	          final on Saturday night. A draw there goes to penalties.
	  SUPERCUP  league champion against cup winner (if the same club won
	          both: against the league runner-up).

	A FIXTURE is { id, kind, home, away, round?, group?, stage? }:
	  kind   "liga" | "taca" | "supertaca" | "amigavel"
	  id     "L:home:away" · "T:home:away" · "SF1" · "SF2" · "F" · "S"
	A RESULT is { h, a, p? }: goals, and on penalties the club that went through.
	The STATE of a season is { week, reset, results, semis?, super? }.
]]

local Config = require(script.Parent:WaitForChild("Config"))
local Schedule = require(script.Parent:WaitForChild("Schedule"))

local Calendar = {}

local C = Config.Competitions

export type Fixture = {
	id: string,
	kind: string,
	home: string,
	away: string,
	round: number?,
	group: string?,
	stage: string?,
}
export type Result = { h: number, a: number, p: string? }
export type State = {
	week: number,
	reset: number,
	results: { [string]: Result },
	semis: { { string } }?,
	super: { string }?,
}
export type Row = { club: string, p: number, w: number, d: number, l: number, gf: number, ga: number, pts: number }

local DAY = 24 * 3600
local slotsPerDay = math.floor(DAY / Schedule.SLOT)

-- How many slots with an official match a day has, and so how long a window is.
local officialPerDay = 0
for k = 0, slotsPerDay - 1 do
	if Schedule.isOfficial(k) then
		officialPerDay += 1
	end
end
Calendar.WINDOW = math.max(1, officialPerDay // C.windowsPerDay)

-- Two clubs of the same city: a derby.
function Calendar.isDerby(a: string, b: string): boolean
	local x, y = (Config.Clubs :: any)[a], (Config.Clubs :: any)[b]
	return x ~= nil and y ~= nil and x.city ~= nil and x.city == y.city
end

--------------------------------------------------------------------------------
-- The league
--------------------------------------------------------------------------------

local leagueRounds: { { Fixture } } = {}
for _, match in Config.Derbies do
	local round = (match :: any).round or 1
	leagueRounds[round] = leagueRounds[round] or {}
	table.insert(leagueRounds[round], {
		id = "L:" .. match.home .. ":" .. match.away,
		kind = "liga",
		home = match.home,
		away = match.away,
		round = round,
	})
end
-- Derbies first: they are the big match of the round.
for _, list in leagueRounds do
	table.sort(list, function(a, b)
		local da, db = Calendar.isDerby(a.home, a.away), Calendar.isDerby(b.home, b.away)
		if da ~= db then
			return da
		end
		return a.id < b.id
	end)
end

function Calendar.leagueRounds(): { { Fixture } }
	return leagueRounds
end

--------------------------------------------------------------------------------
-- The cup
--------------------------------------------------------------------------------

-- The draw of the week: the same for every server (it comes from the week and
-- from how many times the season was started again).
function Calendar.groups(state: State): { [string]: { string } }
	local order = table.clone(Config.ClubOrder)
	local rng = Random.new(state.week * 1009 + state.reset * 7919 + 17)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local half = math.ceil(#order / 2)
	local a, b = {}, {}
	for i, clubId in order do
		table.insert(if i <= half then a else b, clubId)
	end
	return { A = a, B = b }
end

-- The rounds of one group: everyone against everyone, home and away.
local function groupRounds(name: string, clubs: { string }): { { Fixture } }
	local seats = table.clone(clubs)
	if #seats % 2 == 1 then
		table.insert(seats, "") -- one rests each round
	end
	local n = #seats
	local rounds: { { Fixture } } = {}
	for leg = 1, 2 do
		local wheel = table.clone(seats)
		for round = 1, n - 1 do
			local list: { Fixture } = {}
			for i = 1, n / 2 do
				local x, y = wheel[i], wheel[n + 1 - i]
				if x ~= "" and y ~= "" then
					local swap = (round % 2 == 0) ~= (leg == 2)
					local home, away = if swap then y else x, if swap then x else y
					table.insert(list, {
						id = "T:" .. home .. ":" .. away,
						kind = "taca",
						home = home,
						away = away,
						group = name,
						round = (leg - 1) * (n - 1) + round,
						stage = "grupos",
					})
				end
			end
			table.insert(rounds, list)
			table.insert(wheel, 2, table.remove(wheel) :: string)
		end
	end
	return rounds
end

-- The rounds of the group stage: round k of every group together.
function Calendar.cupRounds(state: State): { { Fixture } }
	local groups = Calendar.groups(state)
	local rounds: { { Fixture } } = {}
	for _, name in { "A", "B" } do
		for k, list in groupRounds(name, groups[name]) do
			rounds[k] = rounds[k] or {}
			for _, fixture in list do
				table.insert(rounds[k], fixture)
			end
		end
	end
	return rounds
end

--------------------------------------------------------------------------------
-- Tables
--------------------------------------------------------------------------------

-- Who went through in a knockout match (nil if it is not decided).
function Calendar.winner(fixture: Fixture, result: Result?): string?
	if not result then
		return nil
	end
	if result.h > result.a then
		return fixture.home
	elseif result.a > result.h then
		return fixture.away
	end
	return result.p
end

-- The table of `clubs` over `fixtures`: points, then goal difference, then goals scored.
function Calendar.table(clubs: { string }, fixtures: { Fixture }, results: { [string]: Result }): { Row }
	local rows: { [string]: Row } = {}
	for _, clubId in clubs do
		rows[clubId] = { club = clubId, p = 0, w = 0, d = 0, l = 0, gf = 0, ga = 0, pts = 0 }
	end
	for _, fixture in fixtures do
		local result = results[fixture.id]
		local home, away = rows[fixture.home], rows[fixture.away]
		if result and home and away then
			home.p += 1
			away.p += 1
			home.gf += result.h
			home.ga += result.a
			away.gf += result.a
			away.ga += result.h
			if result.h > result.a then
				home.w += 1
				away.l += 1
				home.pts += C.win
			elseif result.h < result.a then
				away.w += 1
				home.l += 1
				away.pts += C.win
			else
				home.d += 1
				away.d += 1
				home.pts += C.draw
				away.pts += C.draw
			end
		end
	end
	local list: { Row } = {}
	for _, clubId in clubs do
		table.insert(list, rows[clubId])
	end
	table.sort(list, function(x, y)
		if x.pts ~= y.pts then
			return x.pts > y.pts
		end
		if x.gf - x.ga ~= y.gf - y.ga then
			return x.gf - x.ga > y.gf - y.ga
		end
		if x.gf ~= y.gf then
			return x.gf > y.gf
		end
		return (table.find(Config.ClubOrder, x.club) or 0) < (table.find(Config.ClubOrder, y.club) or 0)
	end)
	return list
end

function Calendar.leagueTable(state: State): { Row }
	local all: { Fixture } = {}
	for _, list in leagueRounds do
		for _, fixture in list do
			table.insert(all, fixture)
		end
	end
	return Calendar.table(Config.ClubOrder, all, state.results)
end

function Calendar.groupTables(state: State): { [string]: { Row } }
	local groups = Calendar.groups(state)
	local out: { [string]: { Row } } = {}
	for name, clubs in groups do
		local fixtures: { Fixture } = {}
		for _, list in groupRounds(name, clubs) do
			for _, fixture in list do
				table.insert(fixtures, fixture)
			end
		end
		out[name] = Calendar.table(clubs, fixtures, state.results)
	end
	return out
end

--------------------------------------------------------------------------------
-- The knockout matches and the supercup
--------------------------------------------------------------------------------

-- The semi-finals: the ones saved in the state, or as the groups stand now.
function Calendar.semis(state: State): { Fixture }
	local pairs_ = state.semis
	if not pairs_ then
		local tables = Calendar.groupTables(state)
		local a, b = tables.A, tables.B
		if #a < 2 or #b < 2 then
			return {}
		end
		pairs_ = { { a[1].club, b[2].club }, { b[1].club, a[2].club } }
	end
	local list: { Fixture } = {}
	for i, pair in pairs_ :: { { string } } do
		table.insert(list, { id = "SF" .. i, kind = "taca", home = pair[1], away = pair[2], stage = "meias" })
	end
	return list
end

function Calendar.final(state: State): Fixture?
	local semis = Calendar.semis(state)
	if #semis < 2 then
		return nil
	end
	local one = Calendar.winner(semis[1], state.results.SF1)
	local two = Calendar.winner(semis[2], state.results.SF2)
	if not one or not two then
		return nil
	end
	return { id = "F", kind = "taca", home = one, away = two, stage = "final" }
end

function Calendar.cupWinner(state: State): string?
	local final = Calendar.final(state)
	return if final then Calendar.winner(final, state.results.F) else nil
end

-- League champion against cup winner; the same club in both: against the league runner-up.
function Calendar.supercup(state: State): Fixture?
	local pair = state.super
	if not pair then
		local league = Calendar.leagueTable(state)
		if #league < 2 then
			return nil
		end
		local champion = league[1].club
		local cup = Calendar.cupWinner(state)
		local other = if cup and cup ~= champion then cup else league[2].club
		pair = { champion, other }
	end
	return { id = "S", kind = "supertaca", home = (pair :: { string })[1], away = (pair :: { string })[2], stage = "supertaca" }
end

--------------------------------------------------------------------------------
-- What is due, and when
--------------------------------------------------------------------------------

export type Window = {
	week: number,
	day: number, -- 0 Monday ... 6 Sunday
	index: number, -- which window of the day (0, 1, 2 ...), or -1 at night
	pos: number, -- which slot of the window (0 ...)
	league: number, -- the league round open now (0: none)
	cup: number, -- the cup group round open now (0: none)
	semis: boolean, -- the semi-finals are due
	final: boolean, -- the final is due
	supercup: boolean, -- this is the slot of the supercup
}

-- The slot of the day (0 = the first official one of the morning), or nil at night.
local function slotOfDay(slot: number): number?
	if not Schedule.isOfficial(slot) then
		return nil
	end
	local n = -1
	local k = slot
	-- back to the first official slot of this run
	while Schedule.isOfficial(k) and slot - k < slotsPerDay do
		n += 1
		k -= 1
	end
	return n
end

function Calendar.window(slot: number): Window
	local game = Schedule.slotStart(slot)
	local day = Schedule.weekday(game)
	local n = slotOfDay(slot)
	local w: Window = {
		week = Schedule.week(game),
		day = day,
		index = -1,
		pos = 0,
		league = 0,
		cup = 0,
		semis = false,
		final = false,
		supercup = false,
	}
	if not n then
		return w
	end
	w.index = math.min(n // Calendar.WINDOW, C.windowsPerDay - 1)
	w.pos = n - w.index * Calendar.WINDOW
	local hour = math.floor(game % DAY / 3600)
	local minute = math.floor(game % 3600 / 60)
	if day >= 6 then
		w.supercup = hour == C.superHour and minute == 0
		return w
	end
	-- League: one more round with each window; in the last window, all that is left.
	local windows = 6 * C.windowsPerDay
	local number = day * C.windowsPerDay + w.index + 1
	w.league = if number >= windows then #leagueRounds else math.min(number, #leagueRounds)
	-- Cup groups: Monday to Friday, the first windows of the day (all but the last).
	local perDay = math.max(1, C.windowsPerDay - 1)
	if day <= 4 then
		w.cup = day * perDay + math.min(w.index, perDay - 1) + 1
	else
		w.cup = math.huge -- Saturday: whatever is left of the groups
		w.semis = w.index >= 1 or C.windowsPerDay == 1
		-- The final on Saturday night, from Config.Competitions.finalHour on.
		local night = hour >= C.finalHour or hour < Config.Schedule.firstHour
		w.final = w.index >= C.windowsPerDay - 1 and night
	end
	return w
end

-- Everything due at `slot` and not yet played, the oldest first.
function Calendar.due(slot: number, state: State): { Fixture }
	local w = Calendar.window(slot)
	local list: { Fixture } = {}
	if w.index < 0 or w.week ~= state.week then
		return list
	end
	if w.supercup then
		local fixture = Calendar.supercup(state)
		if fixture and not state.results[fixture.id] then
			table.insert(list, fixture)
		end
		return list
	end
	if w.day >= 6 then
		return list
	end
	-- The knockout matches first: they have their hour.
	if w.final then
		local fixture = Calendar.final(state)
		if fixture and not state.results[fixture.id] then
			table.insert(list, fixture)
		end
	end
	if w.semis then
		for _, fixture in Calendar.semis(state) do
			if not state.results[fixture.id] then
				table.insert(list, fixture)
			end
		end
	end
	local cupRounds = Calendar.cupRounds(state)
	local top = math.max(w.league, if w.cup == math.huge then #cupRounds else w.cup)
	for round = 1, top do
		if round <= w.league and leagueRounds[round] then
			for _, fixture in leagueRounds[round] do
				if not state.results[fixture.id] then
					table.insert(list, fixture)
				end
			end
		end
		if round <= w.cup and cupRounds[round] then
			for _, fixture in cupRounds[round] do
				if not state.results[fixture.id] then
					table.insert(list, fixture)
				end
			end
		end
	end
	return list
end

--[[
	THE PLAN of the slot, for the timetable on the screens: the match that is
	played at `slot` if nobody is online to change the order (the server takes
	the due match with most real people; this is the order with none). `taken`
	are the matches already given to earlier slots of the same look-ahead.
	Returns nil when nothing is due: a friendly at the stadium.
]]
function Calendar.planned(slot: number, state: State, taken: { [string]: boolean }): Fixture?
	for _, fixture in Calendar.due(slot, state) do
		if not taken[fixture.id] then
			return fixture
		end
	end
	return nil
end

-- The competition and the round of a fixture, for the screens: a key of Config.Text.comp and a number.
function Calendar.label(fixture: Fixture): (string, any)
	if fixture.kind == "liga" then
		return "league", fixture.round
	elseif fixture.kind == "supertaca" then
		return "supercup", nil
	elseif fixture.kind == "amigavel" then
		return "friendly", nil
	elseif fixture.stage == "meias" then
		return "semi", nil
	elseif fixture.stage == "final" then
		return "final", nil
	end
	return "group", fixture.group
end

return Calendar
