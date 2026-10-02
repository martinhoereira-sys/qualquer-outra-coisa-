--!strict
--[[
	The way to the stadium, for whoever goes in the corteo.

	- A line of arrows on the ground along the corteo's route (the same route
	  the banner follows: server/March publishes it on the banner, attribute
	  "Rota"). Only for the people of that claque, only on their own screen;
	  it can be turned off (ARROWS button) and it goes away on arrival.
	- GO STRAIGHT TO THE STADIUM: if the match has already started and I am
	  still out in the city, one button takes me to my stand. Whoever wants to
	  walk the whole way, walks. Nobody is stuck in a corteo that left late.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local T = Config.Text.rota

local SPACING = 14 -- studs between two arrows
local TEXT = Color3.fromRGB(236, 238, 242)

local gui = Instance.new("ScreenGui")
gui.Name = "UltrasRota"
gui.ResetOnSpawn = false
gui.DisplayOrder = 12
gui.Parent = player:WaitForChild("PlayerGui")

local function button(text: string, size: UDim2, position: UDim2, colour: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = colour
	b.BackgroundTransparency = 0.1
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = TEXT
	b.Text = text
	b.Visible = false
	b.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	return b
end

local toggle = button(T.arrowsOn, UDim2.fromOffset(130, 30), UDim2.new(0, 16, 1, -84), Color3.fromRGB(58, 62, 72))
local straight = button(T.straight, UDim2.fromOffset(300, 44), UDim2.new(0.5, -150, 1, -150), Color3.fromRGB(40, 150, 90))
straight.TextSize = 15
straight.Font = Enum.Font.GothamBlack

local wanted = true
local folder: Folder? = nil
local drawnFor: string? = nil

local function clear()
	if folder then
		folder:Destroy()
		folder = nil
	end
	drawnFor = nil
end

-- One arrow: two thin bars meeting at the tip, flat on the ground, pointing along `dir`.
local function arrow(at: Vector3, dir: Vector3, colour: Color3, parent: Instance)
	local base = CFrame.lookAt(at, at + dir)
	for _, side in { -1, 1 } do
		local p = Instance.new("Part")
		p.Name = "Seta"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = colour
		p.Transparency = 0.25
		p.Size = Vector3.new(0.7, 0.12, 3.2)
		p.CFrame = base * CFrame.new(side * 0.95, 0, 0.9) * CFrame.Angles(0, math.rad(side * 38), 0)
		p.Parent = parent
	end
end

local function draw(route: string, colour: Color3)
	clear()
	local points: { Vector3 } = {}
	for x, z in string.gmatch(route, "(-?%d+),(-?%d+)") do
		table.insert(points, Vector3.new(tonumber(x) :: number, 0, tonumber(z) :: number))
	end
	if #points < 2 then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "SetasCortejo"
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { f }
	local carried = SPACING / 2
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local step = b - a
		local length = step.Magnitude
		if length > 0.5 then
			local dir = step.Unit
			local s = carried
			while s < length do
				local spot = a + dir * s
				-- On the ground, wherever it is.
				local hit = workspace:Raycast(Vector3.new(spot.X, 40, spot.Z), Vector3.new(0, -80, 0), params)
				local y = if hit then hit.Position.Y else 0.5
				arrow(Vector3.new(spot.X, y + 0.1, spot.Z), dir, colour, f)
				s += SPACING
			end
			carried = s - length
		end
	end
	f.Parent = workspace
	folder = f
	drawnFor = route
end

local phase = ""
Remotes.MatchState.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) == "table" and type(snapshot.phase) == "string" then
		phase = snapshot.phase
	end
end)

toggle.Activated:Connect(function()
	wanted = not wanted
	toggle.Text = if wanted then T.arrowsOn else T.arrowsOff
	if not wanted then
		clear()
	end
end)

straight.Activated:Connect(function()
	Remotes.Home:FireServer("estadio")
end)

local function myBanner(): BasePart?
	local teamId = player:GetAttribute("Team")
	if type(teamId) ~= "string" or not Config.Teams[teamId] then
		return nil
	end
	local found = workspace:FindFirstChild("Banner_" .. teamId, true)
	return if found and found:IsA("BasePart") then found else nil
end

task.spawn(function()
	while true do
		task.wait(0.5)
		local banner = myBanner()
		local stage = banner and banner:GetAttribute("Stage")
		local route = banner and banner:GetAttribute("Rota")
		local onTheWay = stage == "formatura" or stage == "marcha" or stage == "corrida"
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- Arrived: inside the ground of the stadium.
		local far = root ~= nil and Vector3.new(root.Position.X, 0, root.Position.Z).Magnitude > Config.Rota.arrivedWithin
		toggle.Visible = banner ~= nil and onTheWay and far
		if banner and onTheWay and far and wanted and type(route) == "string" then
			if drawnFor ~= route then
				local teamId = player:GetAttribute("Team") :: string
				draw(route, Config.Teams[teamId].color:Lerp(Color3.new(1, 1, 1), 0.55))
			end
		else
			clear()
		end
		-- The match is on and I am still out in the city.
		local teamId = player:GetAttribute("Team")
		local supporter = type(teamId) == "string" and Config.Teams[teamId] ~= nil
		local matchOn = phase == "espera" or phase == "entrada" or phase == "first" or phase == "halftime" or phase == "second"
		straight.Visible = supporter and matchOn and far
	end
end)
