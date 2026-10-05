--!strict
--[[
	THE TROPHIES. At the end of the League, of the Cup and of the Supercup:
	  - the trophy appears on the pitch, on a plinth at the centre spot;
	  - the captain of the winning club walks up, and lifts it over the head;
	  - confetti in the colours of the champion club.

	Each competition has its own trophy, made of simple shapes like the
	emblems (no images):
	  liga       a tall gold cup with two handles, on a dark base
	  taca       a wide silver bowl with a lid and a knob
	  supertaca  a round gold shield on a stand, with the club's colour in it

	Trophy.present(kind, club, captain?) does the whole ceremony and cleans up
	after itself. `captain` is the character that lifts it (nil when the
	champion is not on this pitch: the trophy and the confetti are shown all
	the same).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Trophy = {}

local T = Config.Trophy

local GOLD = Color3.fromRGB(232, 184, 60)
local SILVER = Color3.fromRGB(208, 212, 220)
local DARK = Color3.fromRGB(30, 30, 36)

local function piece(parent: Instance, shape: Enum.PartType, size: Vector3, offset: CFrame, colour: Color3, root: BasePart?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.Metal
	p.Reflectance = 0.15
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = root == nil
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if root then
		p.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	else
		p.CFrame = offset
	end
	p.Parent = parent
	return p
end

-- A cylinder standing up (Roblox cylinders lie along X).
local UP = CFrame.Angles(0, 0, math.rad(90))

--[[
	Builds the trophy of `kind` at `at` (the point it stands on). Returns the
	model; its PrimaryPart is the base, and everything is welded to it.
]]
function Trophy.build(kind: string, club: any, at: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Trofeu_" .. kind
	local base = piece(model, Enum.PartType.Cylinder, Vector3.new(0.5, 1.6, 1.6), at * CFrame.new(0, 0.25, 0) * UP, DARK)
	base.Name = "Base"
	base.Material = Enum.Material.SmoothPlastic
	base.Reflectance = 0
	model.PrimaryPart = base
	-- Offsets below are from the base, which lies on its side: undo that first.
	local function add(shape: Enum.PartType, size: Vector3, offset: CFrame, colour: Color3): Part
		return piece(model, shape, size, UP:Inverse() * offset, colour, base)
	end
	local clubColour: Color3 = club.color
	if kind == "liga" then
		-- A tall cup: stem, bowl, rim, two handles.
		add(Enum.PartType.Cylinder, Vector3.new(1.3, 0.5, 0.5), CFrame.new(0, 0.9, 0) * UP, GOLD)
		add(Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 2.1, 0), GOLD)
		add(Enum.PartType.Cylinder, Vector3.new(1.2, 1.7, 1.7), CFrame.new(0, 2.8, 0) * UP, GOLD)
		add(Enum.PartType.Cylinder, Vector3.new(0.16, 1.9, 1.9), CFrame.new(0, 3.45, 0) * UP, clubColour)
		for _, side in { -1, 1 } do
			add(Enum.PartType.Block, Vector3.new(0.18, 1.1, 0.18), CFrame.new(side * 1.15, 2.7, 0), GOLD)
			add(Enum.PartType.Block, Vector3.new(0.5, 0.18, 0.18), CFrame.new(side * 0.95, 3.2, 0), GOLD)
			add(Enum.PartType.Block, Vector3.new(0.5, 0.18, 0.18), CFrame.new(side * 0.95, 2.2, 0), GOLD)
		end
	elseif kind == "taca" then
		-- A wide bowl with a lid and a knob.
		add(Enum.PartType.Cylinder, Vector3.new(0.8, 0.6, 0.6), CFrame.new(0, 0.7, 0) * UP, SILVER)
		add(Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, 2, 0), SILVER)
		add(Enum.PartType.Cylinder, Vector3.new(0.2, 2.6, 2.6), CFrame.new(0, 2.5, 0) * UP, clubColour)
		add(Enum.PartType.Ball, Vector3.new(1.9, 1.3, 1.9), CFrame.new(0, 2.9, 0), SILVER)
		add(Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 3.7, 0), SILVER)
	else
		-- A round shield on a stand, the club's colour in the middle.
		add(Enum.PartType.Block, Vector3.new(0.5, 1.2, 0.4), CFrame.new(0, 0.9, 0), GOLD)
		add(Enum.PartType.Cylinder, Vector3.new(0.3, 3, 3), CFrame.new(0, 2.9, 0) * CFrame.Angles(0, math.rad(90), 0), GOLD)
		add(Enum.PartType.Cylinder, Vector3.new(0.34, 2, 2), CFrame.new(0, 2.9, 0) * CFrame.Angles(0, math.rad(90), 0), clubColour)
		add(Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 2.9, 0), GOLD)
	end
	model.Parent = parent
	return model
end

-- Confetti in the club's colours, falling over `at` for `seconds`.
local function confetti(club: any, at: Vector3, seconds: number, parent: Instance)
	local source = Instance.new("Part")
	source.Name = "Confetes"
	source.Anchored = true
	source.CanCollide = false
	source.CanQuery = false
	source.Transparency = 1
	source.Size = Vector3.new(T.confettiSpread, 1, T.confettiSpread)
	source.CFrame = CFrame.new(at + Vector3.new(0, T.confettiHeight, 0))
	source.Parent = parent
	local colours: { Color3 } = { club.color, club.accent or club.second, Color3.fromRGB(245, 245, 245) }
	for _, colour in colours do
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(colour)
		e.Size = NumberSequence.new(0.35)
		e.Lifetime = NumberRange.new(5, 7)
		e.Rate = T.confettiRate
		e.Speed = NumberRange.new(2, 6)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -7, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-260, 260)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.LightEmission = 0
		e.LightInfluence = 1
		e.Parent = source
	end
	task.delay(seconds, function()
		for _, e in source:GetChildren() do
			if e:IsA("ParticleEmitter") then
				e.Enabled = false
			end
		end
		task.wait(8)
		source:Destroy()
	end)
end

--[[
	The ceremony. `place(at, facing)` puts the captain somewhere (the caller
	knows how its characters are moved); `arms(up)` raises or lowers the
	captain's arms.
]]
function Trophy.present(kind: string, club: any, captain: Model?, place: ((Vector3, Vector3) -> ())?, arms: ((boolean) -> ())?)
	local folder = Instance.new("Folder")
	folder.Name = "Cerimonia"
	folder.Parent = workspace
	local centre = Vector3.new(0, T.groundY, 0)

	-- The plinth, and the trophy on it.
	local plinth = Instance.new("Part")
	plinth.Name = "Pedestal"
	plinth.Anchored = true
	plinth.CanCollide = false
	plinth.Size = Vector3.new(3, 2.6, 3)
	plinth.Color = club.color
	plinth.Material = Enum.Material.SmoothPlastic
	plinth.CFrame = CFrame.new(centre + Vector3.new(0, 1.3, 0))
	plinth.Parent = folder
	local trophy = Trophy.build(kind, club, CFrame.new(centre + Vector3.new(0, 2.6, 0)), folder)
	confetti(club, centre, T.seconds - 4, folder)

	local raised: { [Motor6D]: CFrame } = {}
	local root = captain and captain:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = captain and captain:FindFirstChild("Head") :: BasePart?
	if captain and root and head and place then
		-- The captain walks up beside the plinth, facing the main stand.
		place(centre + Vector3.new(0, 3, 3.4), Vector3.new(0, 0, 1))
		task.wait(0.6)
		if captain.Parent and trophy.Parent then
			-- The captain stands still for the ceremony (whatever the match wants of them).
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.lookAt(centre + Vector3.new(0, root.Position.Y - centre.Y, 3.4), centre + Vector3.new(0, root.Position.Y - centre.Y, 30))
			root.Anchored = true
			task.wait(0.4)
			-- Lifted: off the plinth, over the head, held there.
			local base = trophy.PrimaryPart :: BasePart
			local over = head.CFrame * CFrame.new(0, 1.0, -0.3)
			local tween = TweenService:Create(base, TweenInfo.new(T.liftSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = over * base.CFrame.Rotation })
			-- (Everything is welded to the base, which is anchored: it moves as one.)
			for _, p in trophy:GetChildren() do
				if p:IsA("BasePart") and p ~= base then
					p.Anchored = false
				end
			end
			if arms then
				arms(true)
			end
			-- Both arms straight up, holding it (whatever the celebration does).
			for _, spec in { { "RightUpperArm", "RightShoulder", 1 }, { "LeftUpperArm", "LeftShoulder", -1 } } do
				local arm = captain:FindFirstChild(spec[1] :: string)
				local joint = arm and arm:FindFirstChild(spec[2] :: string)
				if joint and joint:IsA("Motor6D") then
					raised[joint] = raised[joint] or joint.C0
					joint.C0 = raised[joint] * CFrame.Angles(0, 0, math.rad(165) * (spec[3] :: number))
				end
			end
			tween:Play()
			tween.Completed:Wait()
			-- Up and down a little, like someone showing it to the stands.
			for i = 1, T.pumps do
				if not trophy.Parent then
					break
				end
				local up = TweenService:Create(base, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { CFrame = base.CFrame * CFrame.new(0.9, 0, 0) })
				up:Play()
				up.Completed:Wait()
				local down = TweenService:Create(base, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { CFrame = base.CFrame * CFrame.new(-0.9, 0, 0) })
				down:Play()
				down.Completed:Wait()
			end
		end
	end

	task.delay(T.seconds, function()
		if arms then
			arms(false)
		end
		if root and root.Parent then
			root.Anchored = false
		end
		for joint, rest in raised do
			if joint.Parent then
				joint.C0 = rest
			end
		end
		folder:Destroy()
	end)
end

return Trophy
