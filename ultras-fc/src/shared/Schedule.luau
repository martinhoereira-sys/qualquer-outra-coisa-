--!strict
--[[
	THE CLOCK OF THE GAME. One clock only, taken from the REAL time of the
	world (never from when a server opened), so every server and every screen
	agree on what is on now.

	The day (game time = UTC + Config.Schedule.utcOffset hours):
	  09:00 to 01:00   official matches
	  01:00 to 09:00   night: only friendlies at the training pitches

	Between 09:00 and 01:00 every hour is the same, in SLOTS of 20 minutes:
	  :00 - :15  OFFICIAL MATCH     :15 - :20  break (friendlies)
	  :20 - :35  OFFICIAL MATCH     :35 - :40  break
	  :40 - :55  OFFICIAL MATCH     :55 - :00  break

	The phases of the match day are laid over that. The 15 minutes of a match
	are: waiting for the stands, the teams coming out, first half, half-time,
	second half, full time. The 5 minutes of break BEFORE a match belong to it:
	the clubhouse and then the corteo to the stadium. At night there is one
	long "clubhouse" (flagged `night`), until five minutes before 09:00.

	Everything here is a pure function of the time: nothing is counted or
	remembered. (For tests, an admin can push the clock forward: the push is in
	the workspace attribute "RelogioSalto", in seconds, the same for everyone
	in that server.)
]]

local Config = require(script.Parent:WaitForChild("Config"))

local Schedule = {}

local S = Config.Schedule
local M = Config.Match

Schedule.SLOT = S.slotMinutes * 60
Schedule.MATCH = S.matchMinutes * 60
local DAY = 24 * 3600
local WEEK = 7 * DAY
-- 1 January 1970 was a Thursday: the first Monday was four days later.
local FIRST_MONDAY = 4 * DAY

-- The phases of the 15 minutes of a match, in order, and of the break before it.
local MATCH_PHASES = {
	{ "espera", M.waitLength },
	{ "entrada", M.entranceLength },
	{ "first", M.halfLength },
	{ "halftime", M.halfTimeLength },
	{ "second", M.halfLength },
	{ "fulltime", M.fullTimeLength },
}
local BREAK_PHASES = {
	{ "clubhouse", M.clubhouseLength },
	{ "corteo", M.corteoLength },
}

-- The real time now (seconds since 1970), the same on the server and on every screen.
function Schedule.now(): number
	local push = workspace:GetAttribute("RelogioSalto")
	return workspace:GetServerTimeNow() + (if type(push) == "number" then push else 0)
end

-- Game time: seconds since 1970 in the game's own time zone.
function Schedule.gameTime(now: number?): number
	return (now or Schedule.now()) + S.utcOffset * 3600
end

function Schedule.slotOf(game: number): number
	return math.floor(game / Schedule.SLOT)
end

-- When (game time) the match of slot `k` kicks off its 15 minutes.
function Schedule.slotStart(k: number): number
	return k * Schedule.SLOT
end

-- Has slot `k` an official match? (Not between 01:00 and 09:00.)
function Schedule.isOfficial(k: number): boolean
	local hour = math.floor((k * Schedule.SLOT) % DAY / 3600)
	if S.firstHour <= S.lastHour then
		return hour >= S.firstHour and hour < S.lastHour
	end
	return hour >= S.firstHour or hour < S.lastHour
end

-- The first slot with an official match from slot `k` on.
function Schedule.nextOfficial(k: number): number
	for j = k, k + DAY / Schedule.SLOT do
		if Schedule.isOfficial(j) then
			return j
		end
	end
	return k
end

export type Moment = {
	phase: string,
	remaining: number, -- seconds left of this phase
	length: number, -- how long this phase lasts
	slot: number, -- the slot of the match this moment belongs to
	night: boolean, -- 01:00 to 09:00: no official match on
}

-- What is on at game time `game`.
function Schedule.at(game: number): Moment
	local k = Schedule.slotOf(game)
	local u = game - k * Schedule.SLOT
	local breakLength = Schedule.SLOT - Schedule.MATCH
	if u < Schedule.MATCH and Schedule.isOfficial(k) then
		local passed = 0
		for _, entry in MATCH_PHASES do
			local length = entry[2] :: number
			if u < passed + length then
				return { phase = entry[1] :: string, remaining = passed + length - u, length = length, slot = k, night = false }
			end
			passed += length
		end
	elseif u >= Schedule.MATCH and Schedule.isOfficial(k + 1) then
		local passed = Schedule.MATCH
		for _, entry in BREAK_PHASES do
			local length = entry[2] :: number
			if u < passed + length then
				return { phase = entry[1] :: string, remaining = passed + length - u, length = length, slot = k + 1, night = false }
			end
			passed += length
		end
	end
	-- Night: one long clubhouse until the break before the first match of the morning.
	local first = Schedule.nextOfficial(k + 1)
	local untilAt = first * Schedule.SLOT - breakLength
	local remaining = math.max(untilAt - game, 1)
	return { phase = "clubhouse", remaining = remaining, length = remaining, slot = first, night = true }
end

-- When (game time) the next official match kicks off, strictly after `game`.
function Schedule.nextKickOff(game: number): number
	return Schedule.nextOfficial(Schedule.slotOf(game) + 1) * Schedule.SLOT
end

-- "21:40"
function Schedule.clock(game: number): string
	local seconds = game % DAY
	return string.format("%02d:%02d", seconds // 3600, seconds % 3600 // 60)
end

-- "04:12" (or "1:04:12" above an hour)
function Schedule.countdown(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, s % 3600 // 60, s % 60)
	end
	return string.format("%02d:%02d", s // 60, s % 60)
end

--[[
	The football week. A competition DAY runs from 09:00 to 09:00 (so the
	matches after midnight belong to the day that started in the morning), and
	the WEEK starts on Monday at 09:00.
	  Schedule.week(game)      the number of the week (the season)
	  Schedule.weekday(game)   0 Monday ... 5 Saturday, 6 Sunday
	  Schedule.weekStart(w)    game time of Monday 09:00 of week `w`
]]
local function shifted(game: number): number
	return game - FIRST_MONDAY - S.firstHour * 3600
end

function Schedule.week(game: number): number
	return math.floor(shifted(game) / WEEK)
end

function Schedule.weekday(game: number): number
	return math.floor(shifted(game) % WEEK / DAY)
end

function Schedule.weekStart(week: number): number
	return week * WEEK + FIRST_MONDAY + S.firstHour * 3600
end

-- The month of a game time, as year * 12 + month (for the honour board).
function Schedule.month(game: number): number
	local date = os.date("!*t", math.floor(game))
	return date.year * 12 + (date.month - 1)
end

return Schedule
