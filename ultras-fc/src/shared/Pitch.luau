--!strict
--[[
	THE PITCH the football is played on: where its middle is, and how long and
	wide it is. The football (server/Football, Bots, Squad) does not know where
	the stadium is: it asks here. Everything it works out about the lines, the
	goals and the boxes is worked out in the PITCH'S OWN COORDINATES (the middle
	of the grass is 0, 0, 0; X runs from goal to goal, Z from touchline to
	touchline, Y is up from the grass), and turned into places of the world
	only when a thing is put somewhere.

	Today there is one pitch: the stadium's. (Step 1 of "one football for the
	training grounds too": with this in place the same football can later be
	told to play on another pitch.)
]]

local Config = require(script.Parent:WaitForChild("Config"))

local Pitch = {}

-- The middle of the grass, in the world (Y is the top of the grass).
Pitch.centre = Vector3.new(0, 0, 0)
Pitch.length = Config.Stadium.pitchLength
Pitch.width = Config.Stadium.pitchWidth

-- A place of the world, as the pitch sees it.
function Pitch.toLocal(p: Vector3): Vector3
	return p - Pitch.centre
end

-- A place of the pitch, in the world.
function Pitch.toWorld(p: Vector3): Vector3
	return p + Pitch.centre
end

return Pitch
