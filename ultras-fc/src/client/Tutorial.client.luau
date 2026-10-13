--!strict
--[[
	THE FIRST STEPS. For whoever has just chosen their first club: an arrow in
	the world and ONE short sentence at the top of the screen, one at a time
	(five words at most). While the step is not done, the arrow stays there.

	    ULTRA    Go to your claque -> Take a flag -> Join the march ->
	             Press E: follow the capo
	    PLAYER   Go to the academy -> Kick the ball -> Wait for the match

	There is always a small SKIP in the corner. Done or skipped, it never comes
	back: the server keeps that in the profile (the attribute "Tutorial" is only
	there while it is still to be shown; whoever already had a club never has it).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local T = Config.Text.tutorial
local U = Config.UI
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "UltrasTutorial"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local phrase = Instance.new("TextLabel")
phrase.Name = "Frase"
phrase.AnchorPoint = Vector2.new(0.5, 0)
phrase.Position = UDim2.new(0.5, 0, 0, 76)
phrase.Size = UDim2.new(0.7, 0, 0, 62)
phrase.BackgroundColor3 = U.panel
phrase.BackgroundTransparency = 0.1
phrase.BorderSizePixel = 0
phrase.Font = Enum.Font.GothamBlack
phrase.TextScaled = true
phrase.TextColor3 = U.text
phrase.Text = ""
phrase.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(620, 62)
limit.Parent = phrase
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 12)
round.Parent = phrase
local inset = Instance.new("UIPadding")
inset.PaddingLeft = UDim.new(0, 18)
inset.PaddingRight = UDim.new(0, 18)
inset.PaddingTop = UDim.new(0, 10)
inset.PaddingBottom = UDim.new(0, 10)
inset.Parent = phrase

local skip = Instance.new("TextButton")
skip.Name = "Saltar"
skip.AnchorPoint = Vector2.new(0, 1)
skip.Position = UDim2.new(0, 16, 1, -16)
skip.Size = UDim2.fromOffset(88, 34)
skip.BackgroundColor3 = U.panel
skip.BackgroundTransparency = 0.25
skip.BorderSizePixel = 0
skip.Font = Enum.Font.GothamBold
skip.TextSize = 15
skip.TextColor3 = Color3.fromRGB(176, 182, 192)
skip.Text = T.skip
skip.Parent = gui
local skipRound = round:Clone()
skipRound.Parent = skip

-- The arrow in the world: over the place to go to, seen from anywhere.
local marker = Instance.new("Part")
marker.Name = "SetaDosPrimeirosPassos"
marker.Anchored = true
marker.CanCollide = false
marker.CanQuery = false
marker.CanTouch = false
marker.Transparency = 1
marker.Size = Vector3.new(1, 1, 1)
local board = Instance.new("BillboardGui")
board.AlwaysOnTop = true
board.Size = UDim2.fromOffset(84, 84)
board.StudsOffset = Vector3.new(0, 7, 0)
board.MaxDistance = math.huge
board.Parent = marker
local arrow = Instance.new("TextLabel")
arrow.BackgroundTransparency = 1
arrow.Size = UDim2.fromScale(1, 1)
arrow.Font = Enum.Font.GothamBlack
arrow.TextScaled = true
arrow.TextColor3 = Color3.fromRGB(255, 208, 60)
arrow.TextStrokeTransparency = 0.2
arrow.Text = "▼"
arrow.Parent = board

local function rootOf(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function myClub(): string?
	local club = player:GetAttribute("Clube")
	return if type(club) == "string" then club else nil
end

-- The places.
local function sede(): Vector3?
	local folder = workspace:FindFirstChild("SedesInscricao")
	local spot = folder and folder:FindFirstChild("Inscricao_" .. (myClub() or ""))
	return if spot and spot:IsA("BasePart") then spot.Position else nil
end

local function academy(): Vector3?
	local grounds = workspace:FindFirstChild("Recintos")
	local ground = grounds and grounds:FindFirstChild("Recinto_" .. (myClub() or ""))
	local grass = ground and ground:FindFirstChild("Relva", true)
	return if grass and grass:IsA("BasePart") then grass.Position else nil
end

local function trainingBall(): Vector3?
	local grounds = workspace:FindFirstChild("Recintos")
	local ground = grounds and grounds:FindFirstChild("Recinto_" .. (myClub() or ""))
	local ball = ground and ground:FindFirstChild("BolaTreino")
	return if ball and ball:IsA("BasePart") then ball.Position else academy()
end

local function banner(): BasePart?
	local team = player:GetAttribute("Team")
	local stadium = workspace:FindFirstChild("Stadium")
	local march = stadium and stadium:FindFirstChild("March")
	local found = march and type(team) == "string" and march:FindFirstChild("Banner_" .. team)
	return if found and found:IsA("BasePart") then found else nil
end

local function near(at: Vector3?, distance: number): boolean
	local root = rootOf()
	return at ~= nil and root ~= nil and Vector3.new(at.X - root.Position.X, 0, at.Z - root.Position.Z).Magnitude <= distance
end

type Step = { text: string, target: () -> Vector3?, done: (number) -> boolean }

local orderedAt = 0 -- the last time I followed an order of the capo
player:GetAttributeChangedSignal("EmoteUntil"):Connect(function()
	orderedAt = os.clock()
end)

local STEPS: { [string]: { Step } } = {
	adepto = {
		{ text = T.goToClaque, target = sede, done = function()
			return near(sede(), 30)
		end },
		{ text = T.takeFlag, target = sede, done = function()
			local hold = player:GetAttribute("Hold")
			return hold == "bandeirinha" or hold == "mastro" or hold == "gemflag"
		end },
		{ text = T.joinMarch, target = function()
			local b = banner()
			return if b then b.Position else sede()
		end, done = function()
			local b = banner()
			local stage = b and b:GetAttribute("Stage")
			return b ~= nil and (stage == "marcha" or stage == "corrida") and near(b.Position, Config.March.radius)
		end },
		{ text = T.followCapo, target = function()
			local b = banner()
			return if b then b.Position else nil
		end, done = function(since)
			return orderedAt > since
		end },
	},
	jogador = {
		{ text = T.goToAcademy, target = academy, done = function()
			return near(academy(), 34)
		end },
		{ text = T.kickBall, target = trainingBall, done = function()
			return near(trainingBall(), 4.5)
		end },
		{ text = T.waitMatch, target = function()
			return nil
		end, done = function(since)
			return os.clock() - since > 8
		end },
	},
}

local running = false
local skipped = false
skip.Activated:Connect(function()
	skipped = true
end)

local function finish()
	gui.Enabled = false
	marker.Parent = nil
	Remotes.PickTeam:FireServer("tutorial:done")
end

local function run()
	if running then
		return
	end
	running = true
	skipped = false
	-- (Not over the screens of the choice: only once I am in.)
	while player:GetAttribute("Tutorial") == true and player:GetAttribute("Team") == nil and player:GetAttribute("UpNext") == nil do
		task.wait(0.5)
	end
	if player:GetAttribute("Tutorial") ~= true then
		running = false
		return
	end
	local role = if player:GetAttribute("TutorialPapel") == "jogador" or player:GetAttribute("Team") == "jogador" then "jogador" else "adepto"
	gui.Enabled = true
	for _, step in STEPS[role] do
		local since = os.clock()
		phrase.Text = step.text
		while not skipped and not step.done(since) do
			local at = step.target()
			if at then
				marker.CFrame = CFrame.new(at)
				marker.Parent = workspace
			else
				marker.Parent = nil
			end
			RunService.Heartbeat:Wait()
		end
		if skipped then
			break
		end
		task.wait(0.6)
	end
	finish()
	running = false
end

player:GetAttributeChangedSignal("Tutorial"):Connect(function()
	if player:GetAttribute("Tutorial") == true then
		task.spawn(run)
	end
end)
if player:GetAttribute("Tutorial") == true then
	task.spawn(run)
end
