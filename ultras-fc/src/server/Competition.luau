--!strict
--[[
	THE COMPETITIONS, on the server: which match this server plays in each
	slot, the results, the titles.

	WHERE IT IS KEPT. Nothing of this lives in a server's memory: the results
	of the week, the semi-finals, the supercup pairing, the titles and the
	honour board are in the game's DataStore (Config.Competitions.store), so a
	server closing wipes nothing and every server sees the same tables.
	  "w_<week>"   the season: results, claims, semis, supercup, reset
	  "titles"     titles of every club (all time and by month), what was awarded
	Every change is an UpdateAsync on what is there (never a blind write), so
	two servers never overwrite each other. Without DataStore access (Studio
	with the API services off) the same thing is kept in this server only, so
	the game can still be tested.

	WHICH MATCH THIS SERVER PLAYS. When a slot comes, the server looks at who
	is inside and takes, among the matches STILL DUE (shared/Calendar: the
	open league round, the open cup round, the knockout matches), the one that
	brings most real people together; between equals, derbies first, then the
	oldest. It CLAIMS it in the DataStore, so another server does not play the
	same one; an unfinished claim lapses by itself. With nobody of either club
	it is played between bots, marked NO FANS: the round has to close all the
	same. With nothing due, the stadium has a friendly (it does not count).

	Points, goals, champions: everything is decided here. Nothing comes from a
	player's side.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Schedule = require(Shared:WaitForChild("Schedule"))
local Calendar = require(Shared:WaitForChild("Calendar"))

local Competition = {}

local C = Config.Competitions

export type Playing = {
	fixture: Calendar.Fixture,
	counts: boolean, -- its result goes to the tables
	noFans: boolean,
	slot: number,
}

local SERVER = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

local store: DataStore? = nil
-- In Studio the tests have a store of their own: they never touch the season of the live game.
local STORE = C.store .. (if game:GetService("RunService"):IsStudio() then "_Studio" else "")
pcall(function()
	store = DataStoreService:GetDataStore(STORE)
end)
local offline = store == nil -- the DataStore cannot be used: keep everything here

-- What this server knows now (a copy of what is in the DataStore).
local season: any = { week = 0, reset = 0, results = {}, claims = {} }
local titles: any = { all = {}, months = {}, awarded = {}, boards = {} }
local playing: Playing? = nil
local listeners: { () -> () } = {}

local function gameNow(): number
	return Schedule.gameTime()
end

local function cleanSeason(saved: any, week: number): any
	local s = if type(saved) == "table" then saved else {}
	return {
		week = week,
		reset = if type(s.reset) == "number" then s.reset else 0,
		results = if type(s.results) == "table" then s.results else {},
		claims = if type(s.claims) == "table" then s.claims else {},
		semis = if type(s.semis) == "table" then s.semis else nil,
		super = if type(s.super) == "table" then s.super else nil,
	}
end

local function cleanTitles(saved: any): any
	local t = if type(saved) == "table" then saved else {}
	return {
		all = if type(t.all) == "table" then t.all else {}, -- competition -> club -> titles ever
		months = if type(t.months) == "table" then t.months else {}, -- month -> competition -> club -> titles
		awarded = if type(t.awarded) == "table" then t.awarded else {}, -- "liga:<week>" -> club
		boards = if type(t.boards) == "table" then t.boards else {}, -- month -> the honour board as it closed
	}
end

-- One read of a key (nil on failure).
local function get(key: string): (boolean, any)
	local s = store
	if offline or not s then
		return false, nil
	end
	local ok, value = pcall(function()
		return s:GetAsync(key)
	end)
	if not ok then
		warn("[Ultras FC] Competition: read failed: " .. tostring(value))
		-- In Studio without API access every call fails: stop trying.
		if game:GetService("RunService"):IsStudio() then
			offline = true
		end
	end
	return ok, value
end

-- One change of a key: `change(old)` returns the new value, or nil to leave it.
local function update(key: string, change: (any) -> any): boolean
	local s = store
	if offline or not s then
		return false
	end
	local ok, err = pcall(function()
		s:UpdateAsync(key, change)
	end)
	if not ok then
		warn("[Ultras FC] Competition: write failed: " .. tostring(err))
	end
	return ok
end

local function weekKey(week: number): string
	return "w_" .. week
end

local function state(): Calendar.State
	return season
end

local function publish()
	local now = playing
	workspace:SetAttribute("Epoca", HttpService:JSONEncode({
		week = season.week,
		reset = season.reset,
		results = season.results,
		semis = season.semis,
		super = season.super,
		titles = titles.all,
		months = titles.months,
		boards = titles.boards,
	}))
	workspace:SetAttribute("Jogo", if now
		then HttpService:JSONEncode({
			id = now.fixture.id,
			kind = now.fixture.kind,
			home = now.fixture.home,
			away = now.fixture.away,
			round = now.fixture.round,
			group = now.fixture.group,
			stage = now.fixture.stage,
			counts = now.counts,
			noFans = now.noFans,
			slot = now.slot,
		})
		else nil)
	for _, fn in listeners do
		task.spawn(fn)
	end
end

function Competition.onChanged(fn: () -> ())
	table.insert(listeners, fn)
end

--------------------------------------------------------------------------------
-- Titles
--------------------------------------------------------------------------------

-- A title for `club` in `competition` ("liga", "taca", "supertaca"), once per week.
local function award(competition: string, week: number, club: string)
	local mark = competition .. ":" .. week
	local month = tostring(Schedule.month(Schedule.weekStart(week) + 6 * 24 * 3600))
	local function apply(t: any): any
		if t.awarded[mark] then
			return nil
		end
		t.awarded[mark] = club
		t.all[competition] = t.all[competition] or {}
		t.all[competition][club] = (t.all[competition][club] or 0) + 1
		t.months[month] = t.months[month] or {}
		t.months[month][competition] = t.months[month][competition] or {}
		t.months[month][competition][club] = (t.months[month][competition][club] or 0) + 1
		return t
	end
	if offline then
		apply(titles)
	else
		update("titles", function(old)
			local t = cleanTitles(old)
			local changed = apply(t)
			if changed then
				titles = changed
			end
			return changed
		end)
	end
end

-- The week is over (Saturday night has passed): the league champion and the cup winner get their titles.
local function settle(finished: any)
	local played = false
	for id in finished.results do
		if string.sub(id, 1, 2) == "L:" then
			played = true
			break
		end
	end
	if played then
		award("liga", finished.week, Calendar.leagueTable(finished)[1].club)
	end
	local cup = Calendar.cupWinner(finished)
	if cup then
		award("taca", finished.week, cup)
	end
	local supercup = Calendar.supercup(finished)
	local winner = if supercup then Calendar.winner(supercup, finished.results.S) else nil
	if winner then
		award("supertaca", finished.week, winner)
	end
end

--[[
	The honour board of a month that has ended is kept as it closed: who led
	each list (league, cup, supercup, and all added up).
]]
local function closeMonths()
	local current = Schedule.month(gameNow())
	for month, byCompetition in titles.months do
		if tonumber(month) and (tonumber(month) :: number) < current and not titles.boards[month] then
			local function apply(t: any): any
				if t.boards[month] then
					return nil
				end
				t.boards[month] = byCompetition
				return t
			end
			if offline then
				apply(titles)
			else
				update("titles", function(old)
					local t = cleanTitles(old)
					local changed = apply(t)
					if changed then
						titles = changed
					end
					return changed
				end)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------

local function refresh()
	local week = Schedule.week(gameNow())
	if week ~= season.week then
		-- A new week: the one that ended is settled, and everything starts at zero.
		local finished = season
		if finished.week > 0 then
			settle(finished)
		end
		season = cleanSeason(nil, week)
		playing = nil
	end
	if not offline then
		local ok, saved = get(weekKey(week))
		if ok then
			season = cleanSeason(saved, week)
		end
		local okTitles, savedTitles = get("titles")
		if okTitles then
			titles = cleanTitles(savedTitles)
		end
		-- The week before, if nobody was there to settle it.
		if not titles.awarded["fechada:" .. (week - 1)] then
			local okOld, old = get(weekKey(week - 1))
			if okOld then
				settle(cleanSeason(old, week - 1))
				update("titles", function(current)
					local t = cleanTitles(current)
					t.awarded["fechada:" .. (week - 1)] = "sim"
					titles = t
					return t
				end)
			end
		end
	end
	-- On Sunday the league and the cup are over: their titles are given.
	if Schedule.weekday(gameNow()) >= 6 then
		settle(season)
	end
	closeMonths()
	publish()
end

--------------------------------------------------------------------------------
-- Choosing the match of a slot
--------------------------------------------------------------------------------

-- A claim that is still good and is not ours.
local function claimedByOther(s: any, id: string): boolean
	local claim = s.claims[id]
	return type(claim) == "table" and claim.server ~= SERVER and (claim.untilAt or 0) > os.time()
end

-- Tries to take `fixture` for this server. False if another server has it (or it is played).
local function claim(fixture: Calendar.Fixture): boolean
	local untilAt = os.time() + Schedule.SLOT
	if offline then
		season.claims[fixture.id] = { server = SERVER, untilAt = untilAt }
		return true
	end
	local got = false
	local week = season.week
	update(weekKey(week), function(old)
		local s = cleanSeason(old, week)
		if s.results[fixture.id] or claimedByOther(s, fixture.id) then
			got = false
			season = s
			return nil
		end
		-- Lapsed claims go.
		for id, other in s.claims do
			if type(other) ~= "table" or (other.untilAt or 0) <= os.time() then
				s.claims[id] = nil
			end
		end
		s.claims[fixture.id] = { server = SERVER, untilAt = untilAt }
		-- The knockout pairings are fixed the first time they are needed.
		if fixture.stage == "meias" and not s.semis then
			local semis = Calendar.semis(s)
			if #semis == 2 then
				s.semis = { { semis[1].home, semis[1].away }, { semis[2].home, semis[2].away } }
			end
		end
		if fixture.kind == "supertaca" and not s.super then
			s.super = { fixture.home, fixture.away }
		end
		got = true
		season = s
		return s
	end)
	return got
end

--[[
	The match of `slot` for this server. `people[club]` is how many real
	people of each club are in it. `late` is true when the server opened with
	the match already going: it is then a friendly (half a match does not
	count).
]]
function Competition.pick(slot: number, people: { [string]: number }, late: boolean): Playing
	local week = Schedule.week(Schedule.slotStart(slot))
	if week ~= season.week then
		refresh()
	end
	local window = Calendar.window(slot)
	local function crowd(fixture: Calendar.Fixture): number
		return (people[fixture.home] or 0) + (people[fixture.away] or 0)
	end

	if not late then
		local due = Calendar.due(slot, state())
		local order: { [string]: number } = {}
		for i, fixture in due do
			order[fixture.id] = i
		end
		table.sort(due, function(a, b)
			if crowd(a) ~= crowd(b) then
				return crowd(a) > crowd(b)
			end
			local da, db = Calendar.isDerby(a.home, a.away), Calendar.isDerby(b.home, b.away)
			if da ~= db then
				return da
			end
			return order[a.id] < order[b.id]
		end)
		for _, fixture in due do
			if not claimedByOther(season, fixture.id) then
				if claim(fixture) then
					playing = { fixture = fixture, counts = true, noFans = crowd(fixture) == 0, slot = slot }
					publish()
					return playing :: Playing
				elseif fixture.kind == "supertaca" then
					-- Another server has the supercup: here it is shown all the same, without counting.
					playing = { fixture = fixture, counts = false, noFans = crowd(fixture) == 0, slot = slot }
					publish()
					return playing :: Playing
				end
			end
		end
		if window.supercup then
			-- Nothing else official at the hour of the supercup.
			local fixture = Calendar.supercup(state())
			if fixture then
				playing = { fixture = fixture, counts = false, noFans = crowd(fixture) == 0, slot = slot }
				publish()
				return playing :: Playing
			end
		end
	end

	-- Nothing due: a friendly at the stadium, between the two clubs with most people here.
	local clubs = table.clone(Config.ClubOrder)
	table.sort(clubs, function(a, b)
		if (people[a] or 0) ~= (people[b] or 0) then
			return (people[a] or 0) > (people[b] or 0)
		end
		return (table.find(Config.ClubOrder, a) or 0) < (table.find(Config.ClubOrder, b) or 0)
	end)
	-- With one club only, its derby rival if it has one.
	local home, away = clubs[1], clubs[2]
	if (people[away] or 0) == 0 then
		for _, clubId in Config.ClubOrder do
			if clubId ~= home and Calendar.isDerby(home, clubId) then
				away = clubId
				break
			end
		end
	end
	local friendly: Calendar.Fixture = { id = "A:" .. slot, kind = "amigavel", home = home, away = away }
	playing = { fixture = friendly, counts = false, noFans = crowd(friendly) == 0, slot = slot }
	publish()
	return playing :: Playing
end

function Competition.playing(): Playing?
	return playing
end

--[[
	Full time. The result of the match this server claimed goes to the tables.
	`penalties` is the club that went through when a knockout match ended level.
]]
function Competition.record(homeGoals: number, awayGoals: number, penalties: string?)
	local now = playing
	if not now or not now.counts then
		return
	end
	now.counts = false -- once
	local fixture = now.fixture
	local result = { h = homeGoals, a = awayGoals, p = penalties }
	local week = season.week
	season.results[fixture.id] = result
	season.claims[fixture.id] = nil
	if not offline then
		update(weekKey(week), function(old)
			local s = cleanSeason(old, week)
			if s.results[fixture.id] then
				return nil
			end
			s.results[fixture.id] = result
			s.claims[fixture.id] = nil
			season = s
			return s
		end)
	end
	if fixture.id == "F" then
		local winner = Calendar.winner(fixture, result)
		if winner then
			award("taca", week, winner)
		end
	elseif fixture.id == "S" then
		local winner = Calendar.winner(fixture, result)
		if winner then
			award("supertaca", week, winner)
		end
	end
	publish()
end

-- Is the match on now one that cannot end level (semi-final, final, supercup)?
function Competition.knockout(): boolean
	local now = playing
	return now ~= nil and now.counts and (now.fixture.stage == "meias" or now.fixture.stage == "final" or now.fixture.kind == "supertaca")
end

function Competition.state(): Calendar.State
	return season
end

function Competition.titles(): any
	return titles
end

--[[
	START AGAIN (the admin only; who may call this is Main's business). Wipes
	the results, points, goals and tables of the season and starts a new one
	from zero, with a new cup draw. The titles already won stay; people's
	clubs, levels and gear are not here and are not touched.
]]
function Competition.reset()
	local week = Schedule.week(gameNow())
	local fresh = cleanSeason(nil, week)
	fresh.reset = (season.reset or 0) + 1
	if offline then
		season = fresh
	else
		update(weekKey(week), function(old)
			local s = cleanSeason(old, week)
			fresh.reset = s.reset + 1
			season = fresh
			return fresh
		end)
	end
	playing = nil
	publish()
end

function Competition.start()
	season = cleanSeason(nil, Schedule.week(gameNow()))
	refresh()
	task.spawn(function()
		while true do
			task.wait(C.refreshSeconds)
			refresh()
		end
	end)
end

return Competition
