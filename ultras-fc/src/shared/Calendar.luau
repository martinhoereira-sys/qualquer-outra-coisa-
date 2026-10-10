--!strict
--[[
	THE COMPETITIONS, as a calendar. Pure functions of the time, of the clubs
	in Config and of the results so far: the server uses them to know what is
	due, and every screen uses the same ones to draw the tables and the
	timetable. Nothing here assumes a number of clubs.

	THE WEEK (shared/Schedule: it starts on Monday at 09:00)
	  Monday to Saturday   LEAGUE and CUP side by side
	  Sunday               SUPERCUP at Config.Competitions.superHour

	Every hour has three slots, and each has its competition
	(Config.Competitions.slots): :00 LEAGUE, :20 LEAGUE, :40 CUP. A cup slot
	with no cup match left to play goes to the league (and a league slot with
	no league match left, to the cup); with neither, the stadium has an
	official friendly: claque and corteo, counting for no table.

	  LEAGUE  every club against every other, home and away, and then all of
	          it again (Config.Competitions.voltasDaLiga). How it is played
	          is one word, Config.Competitions.modoDaLiga:
	            "jornadas"   rounds: every club plays once a round, a round
	                         opens when the one before has had its slots;
	                         what is left of a round stays due until played.
	            "tudoConta"  no rounds: each server plays the match that
	                         brings most people together, everything played
	                         counts, and the table goes by points per match.
	                         A club is only ranked after
	                         Config.Competitions.minimoDeJogos matches.
	  CUP     two groups drawn on Monday morning; in each, everyone against
	          everyone, home and away, a round opening when the one before
	          has had its slots. The top two of each group go through:
	          semi-finals on Saturday (1st A v 2nd B, 1st B v 2nd A), final
	          on Saturday night. A draw there goes to penalties.
	  SUPERCUP  league champion against cup winner (if the same club won
	          both: against the league runner-up).

	A FIXTURE is { id, kind, home, away, round?, group?, stage? }:
	  kind   "liga" | "taca" | "supertaca" | "amigavel"
	  id     "L:home:away" (second time round: "L2:home:away") · "X:slot:home:away" (tudoConta) · "T:home:away" · "SF1" · "SF2" · "F" · "S"
	A RESULT is { h, a, p? }: goals, and on penalties the club that went through.
	The STATE of a season is { week, reset, results, open?, semis?, super? }
	(`open`: in "tudoConta", the league table itself, club by club).
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
	open: boolean?, -- "tudoConta": a league match of no round
}
export type Result = { h: number, a: number, p: string? }
export type State = {
	week: number,
	reset: number,
	results: { [string]: Result },
	open: { [string]: any }?,
	semis: { { string } }?,
	super: { string }?,
}
export type Row = { club: string, p: number, w: number, d: number, l: number, gf: number, ga: number, pts: number, missing: number? }

local DAY = 24 * 3600
local slotsPerDay = math.floor(DAY / Schedule.SLOT)

-- What a slot is for, by its place in the hour (Config.Competitions.slots).
local function kindOf(slot: number): string
	local place = math.floor(Schedule.slotStart(slot) % 3600 / Schedule.SLOT)
	return C.slots[place % #C.slots + 1]
end

-- How many slots of each kind a day of official matches has.
local perDay: { [string]: number } = {}
for k = 0, slotsPerDay - 1 do
	if Schedule.isOfficial(k) then
		perDay[kindOf(k)] = (perDay[kindOf(k)] or 0) + 1
	end
end

local function openLeague(): boolean
	return C.modoDaLiga == "tudoConta"
end

-- Two clubs of the same city: a derby.
function Calendar.isDerby(a: string, b: string): boolean
	local x, y = (Config.Clubs :: any)[a], (Config.Clubs :: any)[b]
	return x ~= nil and y ~= nil and x.city ~= nil and x.city == y.city
end

--------------------------------------------------------------------------------
-- The league
--------------------------------------------------------------------------------

local leagueRounds: { { Fixture } } = {}
do
	local once = 0 -- the rounds of one time round
	for _, match in Config.Derbies do
		once = math.max(once, (match :: any).round or 1)
	end
	for turn = 1, math.max(1, C.voltasDaLiga) do
		for _, match in Config.Derbies do
			local round = (turn - 1) * once + ((match :: any).round or 1)
			leagueRounds[round] = leagueRounds[round] or {}
			table.insert(leagueRounds[round], {
				id = (if turn == 1 then "L:" else "L" .. turn .. ":") .. match.home .. ":" .. match.away,
				kind = "liga",
				home = match.home,
				away = match.away,
				round = round,
			})
		end
	end
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

-- One result into the lines of its two clubs.
function Calendar.add(home: any, away: any, result: Result)
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

function Calendar.emptyRow(clubId: string): Row
	return { club = clubId, p = 0, w = 0, d = 0, l = 0, gf = 0, ga = 0, pts = 0 }
end

-- The table of `clubs` over `fixtures`: points, then goal difference, then goals scored.
function Calendar.table(clubs: { string }, fixtures: { Fixture }, results: { [string]: Result }): { Row }
	local rows: { [string]: Row } = {}
	for _, clubId in clubs do
		rows[clubId] = Calendar.emptyRow(clubId)
	end
	for _, fixture in fixtures do
		local result = results[fixture.id]
		local home, away = rows[fixture.home], rows[fixture.away]
		if result and home and away then
			Calendar.add(home, away, result)
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

--[[
	"tudoConta": the table is kept club by club (state.open), and goes by
	points per match played. A club with fewer than
	Config.Competitions.minimoDeJogos matches is not ranked yet: it goes to
	the end, with how many it still needs (`missing`).
]]
local function openTable(state: State): { Row }
	local saved: any = state.open or {}
	local list: { Row } = {}
	for _, clubId in Config.ClubOrder do
		local row = Calendar.emptyRow(clubId)
		local s = saved[clubId]
		if type(s) == "table" then
			for _, key in { "p", "w", "d", "l", "gf", "ga", "pts" } do
				if type(s[key]) == "number" then
					(row :: any)[key] = s[key]
				end
			end
		end
		if row.p < C.minimoDeJogos then
			row.missing = C.minimoDeJogos - row.p
		end
		table.insert(list, row)
	end
	local function rate(row: Row, value: number): number
		return if row.p > 0 then value / row.p else 0
	end
	table.sort(list, function(x, y)
		if (x.missing == nil) ~= (y.missing == nil) then
			return x.missing == nil
		end
		if x.missing and y.missing and x.p ~= y.p then
			return x.p > y.p
		end
		if rate(x, x.pts) ~= rate(y, y.pts) then
			return rate(x, x.pts) > rate(y, y.pts)
		end
		if rate(x, x.gf - x.ga) ~= rate(y, y.gf - y.ga) then
			return rate(x, x.gf - x.ga) > rate(y, y.gf - y.ga)
		end
		return (table.find(Config.ClubOrder, x.club) or 0) < (table.find(Config.ClubOrder, y.club) or 0)
	end)
	return list
end

-- Has any league match of this season been played?
function Calendar.leaguePlayed(state: State): boolean
	if openLeague() then
		for _, row in openTable(state) do
			if row.p > 0 then
				return true
			end
		end
		return false
	end
	for _, list in leagueRounds do
		for _, fixture in list do
			if state.results[fixture.id] then
				return true
			end
		end
	end
	return false
end

-- Is the league all played? (Never, in "tudoConta": it ends with the week.)
function Calendar.leagueOver(state: State): boolean
	if openLeague() then
		return false
	end
	for _, list in leagueRounds do
		for _, fixture in list do
			if not state.results[fixture.id] then
				return false
			end
		end
	end
	return true
end

function Calendar.leagueTable(state: State): { Row }
	if openLeague() then
		return openTable(state)
	end
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
	index: number, -- 0 in the hours of official matches, -1 at night
	kind: string, -- what this slot is for: "liga" or "taca"
	leagueSlot: number, -- how many league slots the week has had before this one
	leagueRound: number, -- the round of the league that is open now, by the clock (Config.Competitions.duracaoDaJornada)
	cupSlot: number, -- the same for the cup
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
		kind = kindOf(slot),
		leagueSlot = 0,
		leagueRound = 1,
		cupSlot = 0,
		semis = false,
		final = false,
		supercup = false,
	}
	if not n then
		return w
	end
	w.index = 0
	-- THE ROUND OF THE LEAGUE GOES BY THE CLOCK: one more every Config.Competitions.duracaoDaJornada
	-- minutes of real time since the week started, whatever has been played.
	w.leagueRound = math.floor((day * DAY + game % DAY) / 60 / math.max(1, C.duracaoDaJornada or 240)) + 1
	local hour = math.floor(game % DAY / 3600)
	local minute = math.floor(game % 3600 / 60)
	if day >= 6 then
		w.supercup = hour == C.superHour and minute == 0
		return w
	end
	-- The slots of each kind the week has had before this one.
	local before: { [string]: number } = {}
	for k = slot - n, slot - 1 do
		before[kindOf(k)] = (before[kindOf(k)] or 0) + 1
	end
	w.leagueSlot = day * (perDay.liga or 0) + (before.liga or 0)
	w.cupSlot = day * (perDay.taca or 0) + (before.taca or 0)
	if day >= 5 then
		-- Saturday: the semi-finals, and the final from Config.Competitions.finalHour on.
		w.semis = true
		w.final = hour >= C.finalHour or hour < Config.Schedule.firstHour
	end
	return w
end

-- The rounds open after `slots` slots: one more each time the one before has had its slots.
local function openRounds(rounds: { { Fixture } }, slots: number): number
	local size = if rounds[1] then math.max(1, #rounds[1]) else 1
	return math.min(#rounds, slots // size + 1)
end

-- What is left to play of `rounds`, up to round `top`, the oldest first.
local function left(rounds: { { Fixture } }, top: number, state: State, list: { Fixture })
	for round = 1, top do
		for _, fixture in rounds[round] or {} do
			if not state.results[fixture.id] then
				table.insert(list, fixture)
			end
		end
	end
end

-- The cup matches due at this slot (the knockout matches first: they have their day).
local function cupDue(w: Window, state: State): { Fixture }
	local list: { Fixture } = {}
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
	local rounds = Calendar.cupRounds(state)
	left(rounds, if w.day >= 5 then #rounds else openRounds(rounds, w.cupSlot), state, list)
	return list
end

local function leagueDue(w: Window, state: State): { Fixture }
	local list: { Fixture } = {}
	if not openLeague() then
		left(leagueRounds, math.min(#leagueRounds, w.leagueRound), state, list)
	end
	return list
end

-- Is `slot` the last official one of Saturday? When its match ends, the league closes.
function Calendar.closesLeague(slot: number): boolean
	return Schedule.isOfficial(slot) and not Schedule.isOfficial(slot + 1) and Schedule.weekday(Schedule.slotStart(slot)) == 5
end

--[[
	Is `slot` a league slot of "tudoConta"? (There the league has no list of
	matches: the server plays whoever brings most people.) A cup slot with
	nothing of the cup left is one too.
]]
function Calendar.isOpenLeague(slot: number, state: State): boolean
	if not openLeague() then
		return false
	end
	local w = Calendar.window(slot)
	if w.index < 0 or w.week ~= state.week or w.day >= 6 then
		return false
	end
	return w.kind ~= "taca" or #cupDue(w, state) == 0
end

--[[
	Everything due at `slot` and not yet played, the oldest first. The slot's
	own competition; if it has nothing left, the other one; nothing at all
	means an official friendly.
]]
function Calendar.due(slot: number, state: State): { Fixture }
	local w = Calendar.window(slot)
	if w.index < 0 or w.week ~= state.week then
		return {}
	end
	if w.supercup then
		local fixture = Calendar.supercup(state)
		return if fixture and not state.results[fixture.id] then { fixture } else {}
	end
	if w.day >= 6 then
		return {}
	end
	local cup, league = cupDue(w, state), leagueDue(w, state)
	if w.kind == "taca" then
		return if #cup > 0 then cup else league
	end
	if #league > 0 or openLeague() then
		return league
	end
	return cup
end

--[[
	THE PLAN of the slot, for the timetable on the screens: the match that is
	played at `slot` if nobody is online to change the order (the server takes
	the due match with most real people; this is the order with none). `taken`
	are the matches already given to earlier slots of the same look-ahead.
	Returns nil when nothing is due: a friendly at the stadium.
]]
function Calendar.planned(slot: number, state: State, taken: { [string]: boolean }): Fixture?
	if Calendar.isOpenLeague(slot, state) then
		-- "tudoConta": a league match, between whoever is there.
		return { id = "X:" .. slot, kind = "liga", home = "", away = "", open = true }
	end
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
		if not fixture.round then
			return "leagueOpen", nil
		end
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
