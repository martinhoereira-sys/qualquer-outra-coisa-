--!strict
--[[
	The league: ten clubs, one trophy.

	  win 3 · draw 1 · defeat 0
	  tie-break: 1st goal difference, 2nd goals scored

	The season lasts a week: it starts on Monday morning with everything at
	zero and ends on Sunday night. Whoever has most points on Sunday is the
	CHAMPION; on Monday the table starts again. What stays from one season to
	the next: how many titles each club has won (a star by its name each).

	Everything here is decided on the server: points, goals and the champion
	never come from a player's side. The table is kept in a DataStore shared by
	every server (results are added with UpdateAsync, so two servers never
	overwrite each other) and published to the screens in the workspace
	attribute "Liga" (JSON). Without DataStore access (Studio), the table lives
	in this server only.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local League = {}

local L = Config.League

type Row = { p: number, w: number, d: number, l: number, gf: number, ga: number }

local WEEK = 7 * 24 * 3600
-- 1 January 1970 was a Thursday: the first Monday was four days later.
local FIRST_MONDAY = 4 * 24 * 3600

local function seasonNow(): number
	return math.floor((os.time() - FIRST_MONDAY) / WEEK)
end

local function seasonEnd(season: number): number
	return FIRST_MONDAY + (season + 1) * WEEK
end

local function getStore(): DataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(L.store)
	end)
	return if ok then result else nil
end

local store = getStore()
local season = seasonNow()
local rows: { [string]: Row } = {}
local titles: { [string]: number } = {}

local function blank(): Row
	return { p = 0, w = 0, d = 0, l = 0, gf = 0, ga = 0 }
end

local function clean(saved: any): { [string]: Row }
	local out: { [string]: Row } = {}
	for _, clubId in Config.ClubOrder do
		local row = blank()
		local old = if type(saved) == "table" then saved[clubId] else nil
		if type(old) == "table" then
			for key in row :: any do
				if type(old[key]) == "number" then
					(row :: any)[key] = math.max(0, math.floor(old[key]))
				end
			end
		end
		out[clubId] = row
	end
	return out
end

local function points(row: Row): number
	return row.w * L.win + row.d * L.draw
end

-- The clubs in table order: points, then goal difference, then goals scored.
function League.standing(from: { [string]: Row }?): { string }
	local t = from or rows
	local order = table.clone(Config.ClubOrder)
	table.sort(order, function(a, b)
		local x, y = t[a], t[b]
		if points(x) ~= points(y) then
			return points(x) > points(y)
		end
		if x.gf - x.ga ~= y.gf - y.ga then
			return x.gf - x.ga > y.gf - y.ga
		end
		if x.gf ~= y.gf then
			return x.gf > y.gf
		end
		return (table.find(Config.ClubOrder, a) or 0) < (table.find(Config.ClubOrder, b) or 0)
	end)
	return order
end

local function publish()
	local list = {}
	for position, clubId in League.standing() do
		local row = rows[clubId]
		table.insert(list, {
			club = clubId,
			pos = position,
			p = row.p,
			w = row.w,
			d = row.d,
			l = row.l,
			gf = row.gf,
			ga = row.ga,
			pts = points(row),
			titles = titles[clubId] or 0,
		})
	end
	workspace:SetAttribute("Liga", HttpService:JSONEncode({ season = season, ends = seasonEnd(season), rows = list }))
end

local function addTo(row: Row, scored: number, conceded: number)
	row.p += 1
	row.gf += scored
	row.ga += conceded
	if scored > conceded then
		row.w += 1
	elseif scored == conceded then
		row.d += 1
	else
		row.l += 1
	end
end

-- A result of an official match (the server calls this at full time).
function League.record(homeClub: string, awayClub: string, homeGoals: number, awayGoals: number)
	if not rows[homeClub] or not rows[awayClub] or homeClub == awayClub then
		return
	end
	addTo(rows[homeClub], homeGoals, awayGoals)
	addTo(rows[awayClub], awayGoals, homeGoals)
	publish()
	local s = store
	if s then
		local key = "s_" .. season
		task.spawn(function()
			local ok, err = pcall(function()
				s:UpdateAsync(key, function(old)
					local saved = clean(old)
					addTo(saved[homeClub], homeGoals, awayGoals)
					addTo(saved[awayClub], awayGoals, homeGoals)
					return saved
				end)
			end)
			if not ok then
				warn("[Ultras FC] League: result not saved: " .. tostring(err))
			end
		end)
	end
end

-- The champion of a finished season gets a title: once, whichever server sees it first.
local function award(finished: number)
	local s = store
	if not s then
		return
	end
	pcall(function()
		local final = clean(s:GetAsync("s_" .. finished))
		local champion = League.standing(final)[1]
		if final[champion].p == 0 then
			return -- nobody played that week
		end
		s:UpdateAsync("titles", function(old)
			local saved = if type(old) == "table" then old else { won = {}, awarded = {} }
			saved.won = if type(saved.won) == "table" then saved.won else {}
			saved.awarded = if type(saved.awarded) == "table" then saved.awarded else {}
			local key = tostring(finished)
			if saved.awarded[key] then
				return nil
			end
			saved.awarded[key] = champion
			saved.won[champion] = (saved.won[champion] or 0) + 1
			return saved
		end)
	end)
end

local function refresh()
	local now = seasonNow()
	if now ~= season then
		award(season)
		season = now
		rows = clean(nil)
	end
	local s = store
	if s then
		pcall(function()
			rows = clean(s:GetAsync("s_" .. season))
			local saved = s:GetAsync("titles")
			titles = {}
			if type(saved) == "table" and type(saved.won) == "table" then
				for clubId, n in saved.won do
					if type(n) == "number" and (Config.Clubs :: any)[clubId] then
						titles[clubId] = n
					end
				end
			end
		end)
	end
	publish()
end

-- The club at the top right now (for the end of the season).
function League.leader(): string
	return League.standing()[1]
end

function League.start()
	rows = clean(nil)
	publish()
	task.spawn(function()
		while true do
			refresh()
			task.wait(L.refreshSeconds)
		end
	end)
end

return League
