--!strict
--[[
	LIGHT ON THE ULTRAS. A few lights with nothing to see (no lamp, no beam)
	hang over each claque's corner of the stadium, so the block of ultras is
	read from the other end of the ground, by day and by night.

	They are made on each screen (they cost nothing to the server), they cast
	no shadows, and how many and how strong is Config.ClaqueLights.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Plan = require(Shared:WaitForChild("StadiumPlan"))

local C = Config.ClaqueLights

local folder = Instance.new("Folder")
folder.Name = "LuzesDasClaques"
folder.Parent = workspace

for _, teamId in Config.TeamOrder do
	for i = 1, C.count do
		-- Spread along the curve, over the middle rows.
		local t = if C.count == 1 then 0.5 else 0.12 + 0.76 * (i - 1) / (C.count - 1)
		local at = Plan.claqueSeat(teamId, C.row, t) + Vector3.new(0, C.height, 0)
		local part = Instance.new("Part")
		part.Name = "Luz_" .. teamId .. "_" .. i
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.one
		part.Position = at
		part.Parent = folder
		local light = Instance.new("PointLight")
		light.Color = C.colour
		light.Brightness = C.brightness
		light.Range = C.range
		light.Shadows = false
		light.Parent = part
	end
end
