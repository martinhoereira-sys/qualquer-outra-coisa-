--!strict
--[[
	The match day, on the server. The phases come from the REAL clock
	(shared/Schedule), never from when this server opened:

		clubhouse -> corteo -> espera -> entrada -> 1st half -> half-time
		-> 2nd half -> full time -> clubhouse ...

	in slots of 20 minutes (15 of match, 5 of break), and one long clubhouse
	at night. Whoever comes in half-way comes into the phase that is on:
	nothing here waits for anybody, and a server that opens at 21:27 opens in
	the first half of the 21:20 match, like every other server.

	This module keeps what the clock does not know: the score of the match on
	now. It tells its listeners when the phase changes (and once a second, for
	the clocks on the screens).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Schedule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Schedule"))

local MatchLoop = {}

export type Phase = "clubhouse" | "corteo" | "espera" | "entrada" | "first" | "halftime" | "second" | "fulltime"

local state = {
	phase = "clubhouse" :: Phase,
	clock = 0, -- seconds left of the phase on now
	length = 0, -- how long the phase lasts, to know how much has gone
	slot = 0, -- the slot of the match this phase belongs to
	night = false,
	score = { home = 0, away = 0 },
	lastGoal = nil :: string?, -- the team that scored last, for the screens to celebrate
	goalStamp = 0,
}

-- Who listens to changes (Main links here to tell the clients).
local listeners: { (any) -> () } = {}

function MatchLoop.onChange(fn: (any) -> ())
	table.insert(listeners, fn)
end

function MatchLoop.snapshot()
	return {
		phase = state.phase,
		clock = math.max(math.ceil(state.clock), 0),
		length = state.length,
		slot = state.slot,
		night = state.night,
		score = { home = state.score.home, away = state.score.away },
		lastGoal = state.lastGoal,
		goalStamp = state.goalStamp,
	}
end

function MatchLoop.phase(): Phase
	return state.phase
end

-- The slot of the match on now (or of the next one, in the break and at night).
function MatchLoop.slot(): number
	return state.slot
end

function MatchLoop.isNight(): boolean
	return state.night
end

-- Seconds since the phase on now started.
function MatchLoop.elapsed(): number
	return state.length - state.clock
end

local function broadcast()
	local snap = MatchLoop.snapshot()
	for _, fn in listeners do
		fn(snap)
	end
end

local function read()
	local moment = Schedule.at(Schedule.gameTime())
	local changed = moment.phase ~= state.phase or moment.slot ~= state.slot or moment.night ~= state.night
	state.clock = moment.remaining
	state.length = moment.length
	if changed then
		local newMatch = moment.slot ~= state.slot
		state.phase = moment.phase :: Phase
		state.slot = moment.slot
		state.night = moment.night
		-- A new match: a clean scoreboard.
		if newMatch or moment.phase == "clubhouse" then
			state.score.home = 0
			state.score.away = 0
			state.lastGoal = nil
		end
		broadcast()
	end
end

--[[
	These used to bend the clock (a half that waited for a celebration, a wait
	that ended early with the stands full). The clock is the world's now and
	bends for nobody; they are kept so the callers need not change.
]]
function MatchLoop.pauseWhile(_fn: () -> boolean) end
function MatchLoop.holdWhile(_fn: () -> boolean) end
function MatchLoop.readyWhen(_fn: () -> boolean) end
function MatchLoop.entranceIn(_seconds: number) end

--[[
	A goal. Who decides there was a goal is the pitch, not this module: the
	ball going into the goal is what counts.
]]
function MatchLoop.scoreGoal(teamId: string)
	if state.phase ~= "first" and state.phase ~= "second" then
		return
	end
	if state.score[teamId] == nil then
		return
	end

	state.score[teamId] += 1
	state.lastGoal = teamId
	state.goalStamp = workspace:GetServerTimeNow()
	broadcast()
end

-- Who won, or nil on a draw.
function MatchLoop.winner(): string?
	local home, away = state.score.home, state.score.away
	if home == away then
		return nil
	end
	return if home > away then "home" else "away"
end

--[[
	For tests (who may call this is Main's business: the admin list): the clock
	of this server jumps to the end of the phase on now. From the corteo on,
	everything that is waiting for the match is jumped at once, straight to the
	first half.
]]
function MatchLoop.skip()
	local now = Schedule.gameTime()
	local moment = Schedule.at(now)
	local jump = moment.remaining
	if moment.phase == "corteo" or moment.phase == "espera" or moment.phase == "entrada" then
		local at = now + jump
		for _ = 1, 3 do
			local nextMoment = Schedule.at(at + 0.5)
			if nextMoment.phase == "first" then
				break
			end
			at += nextMoment.remaining + 0.5
		end
		jump = at - now
	end
	local push = workspace:GetAttribute("RelogioSalto")
	workspace:SetAttribute("RelogioSalto", (if type(push) == "number" then push else 0) + jump + 0.5)
	read()
end

function MatchLoop.start()
	-- So that the first reading is always "a change", whatever is on.
	state.slot = -1
	read()

	task.spawn(function()
		while true do
			task.wait(0.25)
			read()
		end
	end)

	-- The clocks on the screens only need setting once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			broadcast()
		end
	end)
end

return MatchLoop
