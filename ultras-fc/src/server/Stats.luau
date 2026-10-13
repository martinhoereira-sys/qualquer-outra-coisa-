--!strict
--[[
	THE NUMBERS OF EACH PLAYER, for the rankings: goals, assists and wins in
	OFFICIAL matches, by season (a week), the same in every server.

	  - Only real people: a figure is never in a ranking.
	  - Whoever played on loan counts all the same: the numbers are the
	    person's, whatever shirt they wore.
	  - BEST PLAYER is a sum of points, Config.Stats.points:
	        goals x 3  +  assists x 2  +  wins x 1
	  - Each ranking is kept for everyone and club by club (the club of the
	    heart of each person).

	One document a season in the DataStore ("s_<week>"): { [userId] = { n = name,
	c = club, g = goals, a = assists, w = wins } }. A server keeps what happened
	in it and writes it every Config.Stats.flushSeconds, adding to what is there
	(UpdateAsync), and reads the whole table back: the tops are worked out here
	and published in the workspace attribute "Estatisticas" (JSON) for the menu
	(client/Menu) and the boards in the city.

	Everything here is decided on the server.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Schedule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Schedule"))

local Stats = {}

local S = Config.Stats

type Line = { n: string, c: string?, g: number, a: number, w: number }

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(S.store .. (if RunService:IsStudio() then "_Studio" else ""))
	end)
	if ok then
		store = result
	end
end

local pending: { [string]: Line } = {} -- what happened here and is not written yet
local table_: { [string]: Line } = {} -- the whole season, as last read
local tableWeek = 0
local clubOf: ((Player) -> string?)? = nil
local onPublished: (() -> ())? = nil

function Stats.setClubOf(fn: (Player) -> string?)
	clubOf = fn
end

-- Called each time the tops were worked out again (the boards redraw).
function Stats.onPublished(fn: () -> ())
	onPublished = fn
end

local function week(): number
	return Schedule.week(Schedule.gameTime())
end

local function lineOf(player: Player): Line
	local key = tostring(player.UserId)
	local line = pending[key]
	if not line then
		line = { n = player.DisplayName, c = nil, g = 0, a = 0, w = 0 }
		pending[key] = line
	end
	line.n = player.DisplayName
	line.c = if clubOf then clubOf(player) else nil
	return line
end

function Stats.goal(player: Player)
	lineOf(player).g += 1
end

function Stats.assist(player: Player)
	lineOf(player).a += 1
end

function Stats.win(player: Player)
	lineOf(player).w += 1
end

local function score(line: Line): number
	return line.g * S.points.goal + line.a * S.points.assist + line.w * S.points.win
end

local KINDS: { [string]: (Line) -> number } = {
	goals = function(line)
		return line.g
	end,
	assists = function(line)
		return line.a
	end,
	best = score,
}

-- The first `count` of `kind`, of everyone or of one club: { { n = name, c = club, v = value } }.
local function top(kind: string, club: string?, count: number): { any }
	local value = KINDS[kind]
	local list = {}
	for _, line in table_ do
		if (club == nil or line.c == club) and value(line) > 0 then
			table.insert(list, { n = line.n, c = line.c, v = value(line), g = line.g })
		end
	end
	table.sort(list, function(a, b)
		if a.v ~= b.v then
			return a.v > b.v
		end
		if a.g ~= b.g then
			return a.g > b.g
		end
		return a.n < b.n
	end)
	local first = {}
	for i = 1, math.min(count, #list) do
		first[i] = { n = list[i].n, c = list[i].c, v = list[i].v }
	end
	return first
end

function Stats.top(kind: string, club: string?, count: number): { any }
	return top(kind, club, count)
end

-- The awards of the season, as it stands: best scorer, most assists, best player, and the team of the season.
function Stats.awards(): any
	local scorer = top("goals", nil, 1)[1]
	local assists = top("assists", nil, 1)[1]
	return {
		scorer = scorer,
		assists = assists,
		best = top("best", nil, 1)[1],
		team = top("best", nil, S.teamOfTheSeason),
	}
end

local lastAwards: any = nil

local function publish()
	local all = { week = tableWeek, geral = {}, clubes = {}, premios = lastAwards }
	for kind in KINDS do
		(all.geral :: any)[kind] = top(kind, nil, S.showOverall)
	end
	for _, clubId in Config.ClubOrder do
		local club = {}
		for kind in KINDS do
			(club :: any)[kind] = top(kind, clubId, S.showClub)
		end
		(all.clubes :: any)[clubId] = club
	end
	workspace:SetAttribute("Estatisticas", HttpService:JSONEncode(all))
	if onPublished then
		task.spawn(onPublished)
	end
end

local function clean(value: any): { [string]: Line }
	local out: { [string]: Line } = {}
	if type(value) == "table" then
		for key, line in value do
			if type(key) == "string" and type(line) == "table" then
				out[key] = {
					n = if type(line.n) == "string" then line.n else "?",
					c = if type(line.c) == "string" and (Config.Clubs :: any)[line.c] then line.c else nil,
					g = if type(line.g) == "number" then line.g else 0,
					a = if type(line.a) == "number" then line.a else 0,
					w = if type(line.w) == "number" then line.w else 0,
				}
			end
		end
	end
	return out
end

--[[
	THE SEASON ENDS (Saturday night, with the league): what happened here is
	written, the awards are worked out and kept in the board of honour (the
	key "awards": the last seasons), and they are given back for the ceremony.
]]
function Stats.lastAwards(): any
	return lastAwards
end

function Stats.close(): any
	Stats.flush()
	local awards = Stats.awards()
	awards.week = tableWeek
	lastAwards = awards
	local s = store
	if s then
		pcall(function()
			s:UpdateAsync("awards", function(old)
				local all = if type(old) == "table" then old else {}
				all[tostring(tableWeek)] = awards
				-- (The last seasons only.)
				local weeks = {}
				for key in all do
					table.insert(weeks, tonumber(key) or 0)
				end
				table.sort(weeks)
				while #weeks > 12 do
					all[tostring(table.remove(weeks, 1))] = nil
				end
				return all
			end)
		end)
	end
	return awards
end

-- Writes what happened here and reads the season back.
function Stats.flush()
	local now = week()
	local mine = pending
	pending = {}
	local merged: { [string]: Line }? = nil
	local s = store
	if s then
		local ok = pcall(function()
			s:UpdateAsync("s_" .. now, function(old)
				local all = clean(old)
				for key, line in mine do
					local there = all[key]
					if there then
						there.n = line.n
						there.c = line.c or there.c
						there.g += line.g
						there.a += line.a
						there.w += line.w
					else
						all[key] = line
					end
				end
				merged = all
				return all
			end)
		end)
		if not ok then
			merged = nil
		end
	end
	if not merged then
		-- No DataStore (Studio with the services off, or it failed): kept in this server only.
		local all = if tableWeek == now then table_ else {}
		for key, line in mine do
			local there = all[key]
			if there then
				there.n = line.n
				there.c = line.c or there.c
				there.g += line.g
				there.a += line.a
				there.w += line.w
			else
				all[key] = line
			end
		end
		merged = all
	end
	table_ = merged :: { [string]: Line }
	tableWeek = now
	publish()
end

function Stats.start()
	task.spawn(function()
		-- The awards of the last season that had any, for the board of honour.
		local s = store
		if s then
			pcall(function()
				local all = s:GetAsync("awards")
				if type(all) == "table" then
					local newest = -1
					for key, value in all do
						local n = tonumber(key) or -1
						if n > newest and type(value) == "table" then
							newest = n
							lastAwards = value
						end
					end
				end
			end)
		end
		Stats.flush()
		while true do
			task.wait(S.flushSeconds)
			Stats.flush()
		end
	end)
	game:BindToClose(function()
		if next(pending) ~= nil then
			Stats.flush()
		end
	end)
	Players.PlayerRemoving:Connect(function() end)
end

return Stats
