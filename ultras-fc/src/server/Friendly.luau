--!strict
--[[
	THE TRAINING PITCHES AND THE FRIENDLIES.

	Every club ground (Workspace.Recintos.Recinto_<club>, made by SedeBuilder)
	has a training pitch. On each one there is always a ball: whoever is there
	can kick it about (walk or run into it and it goes where you are facing).
	That is the training.

	A FRIENDLY is a small match on that pitch:
	  - anyone standing on the pitch starts one (the button at the centre spot);
	  - the people on the pitch are split in two teams, by the half they are in;
	  - it is short (Config.Friendly.minutes), with a board showing the score;
	  - no referee, no corteo, no claque, no gear; it does not count for the
	    league table nor for the calendar;
	  - several friendlies can be on at the same time, on different pitches;
	  - it gives less XP than an official match.
	When the BIG MATCH is about to start (the stands are waited for), every
	friendly ends and everyone is told: the official match is the only one that
	stops the whole city.

	Everything is counted here, on the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Friendly = {}

local F = Config.Friendly
local TXT = Config.Text.friendly

type Pitch = {
	club: any,
	frame: CFrame, -- centre of the grass, on top of it
	half: Vector3, -- half length (x) and half width (z)
	ball: BasePart,
	board: TextLabel,
	prompt: ProximityPrompt,
	endsAt: number?, -- a friendly is on until then
	score: { number }, -- goals of the team of the -x half, and of the +x half
	players: { [Player]: number }, -- who plays, and for which side (1 or 2)
	lastKick: { [Player]: number },
}

local pitches: { Pitch } = {}
local allowed = true -- friendlies are for the breaks: not while the big match is on
local giveXP: ((Player, number) -> ())? = nil

-- Who gives the XP at the end (server/Progress, linked from Main).
function Friendly.onXP(fn: (Player, number) -> ())
	giveXP = fn
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Where a point is on the pitch (x along it, z across), or nil if outside.
local function onPitch(pitch: Pitch, at: Vector3, margin: number): Vector3?
	local p = pitch.frame:PointToObjectSpace(at)
	if math.abs(p.X) <= pitch.half.X + margin and math.abs(p.Z) <= pitch.half.Z + margin and p.Y > -3 and p.Y < 30 then
		return p
	end
	return nil
end

local function resetBall(pitch: Pitch)
	pitch.ball.AssemblyLinearVelocity = Vector3.zero
	pitch.ball.AssemblyAngularVelocity = Vector3.zero
	pitch.ball.CFrame = pitch.frame * CFrame.new(0, 1.4, 0)
end

local function show(pitch: Pitch)
	local endsAt = pitch.endsAt
	if endsAt then
		local left = math.max(0, math.ceil(endsAt - os.clock()))
		pitch.board.Text = string.format("%d - %d    %d:%02d", pitch.score[1], pitch.score[2], left // 60, left % 60)
	else
		pitch.board.Text = TXT.training
	end
	pitch.prompt.Enabled = endsAt == nil and allowed
end

local function tell(pitch: Pitch, title: string, line: string)
	for player in pitch.players do
		if player.Parent then
			Remotes.Npc:FireClient(player, { title = title, lines = { line } })
		end
	end
end

local function finish(pitch: Pitch, reason: string?)
	if not pitch.endsAt then
		return
	end
	pitch.endsAt = nil
	local a, b = pitch.score[1], pitch.score[2]
	for player, side in pitch.players do
		if player.Parent then
			local mine, theirs = if side == 1 then a else b, if side == 1 then b else a
			local result = if mine > theirs then TXT.won elseif mine == theirs then TXT.drew else TXT.lost
			Remotes.Npc:FireClient(player, {
				title = string.format(TXT.over, a, b),
				lines = { reason or result, string.format(TXT.xp, F.xp) },
			})
			if giveXP then
				giveXP(player, F.xp)
			end
		end
	end
	table.clear(pitch.players)
	resetBall(pitch)
	show(pitch)
end

local function start(pitch: Pitch, by: Player)
	if pitch.endsAt or not Friendly.allowed() then
		return
	end
	-- Everyone on the pitch plays: one team per half.
	table.clear(pitch.players)
	local count = 0
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local at = root and onPitch(pitch, root.Position, 2)
		if at then
			pitch.players[player] = if at.X < 0 then 1 else 2
			count += 1
		end
	end
	if count == 0 then
		return
	end
	pitch.score = { 0, 0 }
	pitch.endsAt = os.clock() + F.minutes * 60
	resetBall(pitch)
	show(pitch)
	tell(pitch, TXT.started, string.format(TXT.startedLine, F.minutes))
end

function Friendly.allowed(): boolean
	return allowed
end

-- The big match is about to start (or is on): every friendly ends.
function Friendly.setAllowed(on: boolean)
	allowed = on
	for _, pitch in pitches do
		if not on then
			finish(pitch, TXT.bigMatch)
		end
		show(pitch)
	end
end

local function setup(ground: Instance, club: any)
	local grass = ground:FindFirstChild("Relva", true)
	if not grass or not grass:IsA("BasePart") then
		return
	end
	local frame = grass.CFrame * CFrame.new(0, grass.Size.Y / 2, 0)

	local ball = Instance.new("Part")
	ball.Name = "BolaTreino"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2.2, 2.2, 2.2)
	ball.Color = Color3.fromRGB(248, 248, 248)
	ball.Material = Enum.Material.SmoothPlastic
	ball.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.5, 0.5, 1, 1)
	ball.Parent = ground

	-- The centre spot: where a friendly is started, and the board over it.
	local spot = Instance.new("Part")
	spot.Name = "Centro"
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.Transparency = 1
	spot.Size = Vector3.new(2, 2, 2)
	spot.CFrame = frame * CFrame.new(0, 2, 0)
	spot.Parent = ground
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = TXT.start
	prompt.ObjectText = TXT.friendly
	prompt.MaxActivationDistance = 16
	prompt.HoldDuration = 0.6
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot

	local gui = Instance.new("BillboardGui")
	gui.Name = "Marcador"
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffset = Vector3.new(0, 12, 0)
	gui.MaxDistance = 180
	gui.AlwaysOnTop = false
	gui.Parent = spot
	local board = Instance.new("TextLabel")
	board.Size = UDim2.fromScale(1, 1)
	board.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	board.BackgroundTransparency = 0.25
	board.Font = Enum.Font.GothamBlack
	board.TextScaled = true
	board.TextColor3 = Color3.fromRGB(240, 240, 240)
	board.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = board

	local pitch: Pitch = {
		club = club,
		frame = frame,
		half = Vector3.new(grass.Size.X / 2, 0, grass.Size.Z / 2),
		ball = ball,
		board = board,
		prompt = prompt,
		endsAt = nil,
		score = { 0, 0 },
		players = {},
		lastKick = {},
	}
	table.insert(pitches, pitch)
	resetBall(pitch)
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)
	show(pitch)

	prompt.Triggered:Connect(function(player)
		start(pitch, player)
	end)

	-- Walking or running into the ball kicks it the way one is facing.
	ball.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local root = player and rootOf(player)
		if not player or not root then
			return
		end
		local now = os.clock()
		if (pitch.lastKick[player] or 0) + F.kickCooldown > now then
			return
		end
		pitch.lastKick[player] = now
		local speed = root.AssemblyLinearVelocity.Magnitude
		local look = root.CFrame.LookVector
		local dir = Vector3.new(look.X, 0, look.Z)
		if dir.Magnitude < 0.1 then
			return
		end
		local power = F.kick + math.min(speed, 30) * F.kickRun
		ball.AssemblyLinearVelocity = dir.Unit * power + Vector3.new(0, F.kickLift, 0)
	end)
end

function Friendly.start()
	local root = workspace:FindFirstChild("Recintos")
	if root then
		for _, clubId in Config.ClubOrder do
			local ground = root:FindFirstChild("Recinto_" .. clubId)
			if ground then
				setup(ground, (Config.Clubs :: any)[clubId])
			end
		end
	end

	local lastShow = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, pitch in pitches do
			local p = pitch.frame:PointToObjectSpace(pitch.ball.Position)
			local out = math.abs(p.X) > pitch.half.X or math.abs(p.Z) > pitch.half.Z + 1 or p.Y < -4
			if out then
				-- Between the posts and under the bar it is a goal; anywhere else, back to the centre.
				local goal = math.abs(p.X) > pitch.half.X - 1.5 and math.abs(p.Z) < F.goalHalfWidth and p.Y < F.goalHeight
				if goal and pitch.endsAt then
					-- The +x goal is defended by team 2: team 1 scores there.
					local side = if p.X > 0 then 1 else 2
					pitch.score[side] += 1
					tell(pitch, TXT.goal, string.format("%d - %d", pitch.score[1], pitch.score[2]))
				end
				resetBall(pitch)
			end
			if pitch.endsAt and now >= pitch.endsAt then
				finish(pitch, nil)
			end
		end
		if now - lastShow > 1 then
			lastShow = now
			for _, pitch in pitches do
				if pitch.endsAt then
					show(pitch)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, pitch in pitches do
			pitch.players[player] = nil
			pitch.lastKick[player] = nil
		end
	end)
end

return Friendly
