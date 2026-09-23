--!strict
--[[
	Quem esta em campo.

	Cinco lugares por equipa. Cada lugar sem pessoa leva um boneco; quando chega
	alguem, o boneco desse lugar sai, e volta quando a pessoa se vai embora.
	Sozinho joga-se com e contra nove; com dez pessoas nao ha boneco nenhum.

	Os bonecos sao personagens do Roblox a serio, com Humanoid e animacao de
	corrida — de longe tem de se ler como jogadores, nao como pecas a deslizar.
	Levam a camisola e o numero, e as pessoas recebem o mesmo equipamento.

	Este modulo trata dos corpos: por no sitio, vestir, correr, cair. Quem tem
	a bola e o que se faz com ela e do Football; o que os bonecos decidem e do
	Bots.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Squad = {}

local F = Config.Football
local S = Config.Stadium
local HALF = S.pitchLength / 2

export type Footballer = {
	teamId: string,
	slot: number,
	number: number,
	player: Player?, -- nil: e um boneco
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	stamina: number,
	wantSprint: boolean,
	dribbling: boolean, -- boneco com a bola nos pes
	exhausted: boolean,
	downUntil: number,
	immuneUntil: number,
	run: AnimationTrack?,
	idle: AnimationTrack?,
}

local slots: { [string]: { Footballer } } = {}
local folder: Folder? = nil
local frozen = false

--[[
	Grupos de colisao. Os jogadores nao chocam uns com os outros nem com a
	bola: a posse e o roubo sao por proximidade, e corpos a empurrar a bola
	faziam-na saltar ao calhas. As paredes invisiveis a volta do relvado so
	existem para a bola.
]]
PhysicsService:RegisterCollisionGroup("Footballers")
PhysicsService:RegisterCollisionGroup("Ball")
PhysicsService:RegisterCollisionGroup("BallWall")
PhysicsService:CollisionGroupSetCollidable("Footballers", "Footballers", false)
PhysicsService:CollisionGroupSetCollidable("Footballers", "Ball", false)
PhysicsService:CollisionGroupSetCollidable("Footballers", "BallWall", false)
PhysicsService:CollisionGroupSetCollidable("BallWall", "Default", false)

local SKIN = {
	Color3.fromRGB(226, 190, 152),
	Color3.fromRGB(198, 152, 112),
	Color3.fromRGB(150, 106, 74),
	Color3.fromRGB(102, 72, 52),
}
local SHORTS = Color3.fromRGB(28, 30, 36)

-- As animacoes de base do R15.
local RUN_ANIM = "rbxassetid://507767714"
local IDLE_ANIM = "rbxassetid://507766388"

--------------------------------------------------------------------------------
-- Onde fica cada um
--------------------------------------------------------------------------------

-- Cada equipa ataca a baliza a frente da sua claque, e defende a outra.
function Squad.attackSign(teamId: string): number
	return Config.Teams[teamId].side
end

function Squad.homeSpot(f: Footballer): Vector3
	local spot = F.formation[f.slot]
	local sign = Squad.attackSign(f.teamId)
	return Vector3.new(-sign * HALF * spot.x, 0, spot.z * S.pitchWidth)
end

local function groundCFrame(at: Vector3, facing: Vector3, height: number): CFrame
	local here = Vector3.new(at.X, height, at.Z)
	return CFrame.lookAt(here, here + Vector3.new(facing.X, 0, facing.Z))
end

local function hipHeight(f: Footballer): number
	local humanoid = f.humanoid
	local root = f.root
	if humanoid and root then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return 3
end

function Squad.place(f: Footballer, at: Vector3)
	local model = f.model
	if not model then
		return
	end
	local facing = Vector3.new(Squad.attackSign(f.teamId), 0, 0)
	model:PivotTo(groundCFrame(at, facing, hipHeight(f) + 0.1))
	local root = f.root
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	local humanoid = f.humanoid
	if humanoid and not f.player then
		humanoid:MoveTo(Vector3.new(at.X, 0, at.Z))
	end
end

--[[
	Todos ao seu lugar para o pontape de saida. Quem sai fica encostado a bola,
	o avancado do outro lado fica fora do circulo.
]]
function Squad.placeForKickoff(kickingTeam: string)
	local radius = S.pitchLength * 9.15 / 105
	for teamId, list in slots do
		local sign = Squad.attackSign(teamId)
		for _, f in list do
			local at = Squad.homeSpot(f)
			if f.slot == 1 then
				at = if teamId == kickingTeam then Vector3.new(-sign * 2.6, 0, 0) else Vector3.new(-sign * (radius + 2), 0, 0)
			end
			Squad.place(f, at)
		end
	end
end

--------------------------------------------------------------------------------
-- Equipamento
--------------------------------------------------------------------------------

local function numberOn(torso: BasePart, number: number, face: Enum.NormalId)
	local existing = torso:FindFirstChild("Number" .. face.Name)
	if existing then
		existing:Destroy()
	end

	local sign = Instance.new("SurfaceGui")
	sign.Name = "Number" .. face.Name
	sign.Face = face
	sign.CanvasSize = Vector2.new(100, 100)
	sign.LightInfluence = 0.6
	sign.Parent = torso

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(0.8, 0.8)
	text.Position = UDim2.fromScale(0.1, 0.12)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.Text = tostring(number)
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(248, 248, 248)
	text.Parent = sign
end

local function setGroup(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Footballers"
		end
	end
end

--[[
	A camisola. Numa pessoa, a roupa do avatar sai (camisa, calcas, roupa em
	camadas) e o corpo fica com as cores da equipa; o cabelo e o resto ficam.
]]
local function dress(f: Footballer)
	local model = f.model
	if not model then
		return
	end
	local team = Config.Teams[f.teamId]

	for _, child in model:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:FindFirstChildOfClass("WrapLayer") then
				child:Destroy()
			end
		end
	end

	local colours = model:FindFirstChildOfClass("BodyColors")
	if not colours then
		colours = Instance.new("BodyColors")
		colours.Parent = model
	end
	local bc = colours :: BodyColors
	bc.TorsoColor3 = team.color
	bc.LeftArmColor3 = team.color
	bc.RightArmColor3 = team.color
	bc.LeftLegColor3 = SHORTS
	bc.RightLegColor3 = SHORTS

	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		numberOn(torso, f.number, Enum.NormalId.Back)
		numberOn(torso, f.number, Enum.NormalId.Front)
	end
end

--------------------------------------------------------------------------------
-- Bonecos
--------------------------------------------------------------------------------

local function spawnBot(f: Footballer)
	local team = Config.Teams[f.teamId]
	local skin = SKIN[math.random(1, #SKIN)]

	local description = Instance.new("HumanoidDescription")
	description.HeadColor = skin
	description.TorsoColor = team.color
	description.LeftArmColor = team.color
	description.RightArmColor = team.color
	description.LeftLegColor = SHORTS
	description.RightLegColor = SHORTS

	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Squad] boneco nao nasceu:", result)
		return
	end
	-- Entretanto pode ter chegado uma pessoa para este lugar.
	if f.player or f.model then
		result:Destroy()
		return
	end

	local model = result :: Model
	model.Name = team.short .. " " .. f.number

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.WalkSpeed = F.botSpeed

	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end

	f.model = model
	f.humanoid = humanoid
	f.root = root
	dress(f)
	setGroup(model)

	model.Parent = folder
	root:SetNetworkOwner(nil)
	Squad.place(f, Squad.homeSpot(f))

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	local run = Instance.new("Animation")
	run.AnimationId = RUN_ANIM
	local idle = Instance.new("Animation")
	idle.AnimationId = IDLE_ANIM
	local a = animator :: Animator
	f.run = a:LoadAnimation(run)
	f.idle = a:LoadAnimation(idle)
	local idleTrack = f.idle :: AnimationTrack
	idleTrack.Looped = true
	idleTrack:Play()
end

local function removeBot(f: Footballer)
	if f.player then
		return
	end
	if f.model then
		f.model:Destroy()
	end
	f.model = nil
	f.humanoid = nil
	f.root = nil
	f.run = nil
	f.idle = nil
end

--------------------------------------------------------------------------------
-- Pessoas
--------------------------------------------------------------------------------

local function bindCharacter(f: Footballer, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	-- Deixa o Roblox acabar de montar a roupa, senao a camisola fica por baixo.
	task.wait(0.3)
	if f.player == nil or f.player.Character ~= character then
		return
	end

	f.model = character
	f.humanoid = humanoid
	f.root = root
	f.stamina = F.staminaMax
	f.downUntil = 0
	dress(f)
	setGroup(character)
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Footballers"
		elseif d:IsA("Shirt") or d:IsA("Pants") then
			task.defer(function()
				d:Destroy()
			end)
		end
	end)

	humanoid.WalkSpeed = F.walkSpeed
	Squad.place(f, Squad.homeSpot(f))
end

local connections: { [Player]: RBXScriptConnection } = {}

--[[
	Uma pessoa entra em campo, no primeiro lugar livre da equipa — de frente
	para tras, que e onde quem chega quer jogar. Equipa cheia, nao entra.
]]
function Squad.join(player: Player, teamId: string): boolean
	local list = slots[teamId]
	if not list then
		return false
	end
	local current = Squad.byPlayer(player)
	if current and current.teamId == teamId then
		return true
	end

	local free: Footballer? = nil
	for _, f in list do
		if not f.player then
			free = f
			break
		end
	end
	if not free then
		return false
	end

	Squad.leave(player)
	local f = free :: Footballer
	removeBot(f)
	f.player = player
	f.wantSprint = false
	-- Shift e sprint; com o shift-lock na mesma tecla, cada sprint trancava a camara.
	player.DevEnableMouseLock = false
	player:SetAttribute("Team", "jogador")
	player:SetAttribute("PitchTeam", teamId)
	player:SetAttribute("Number", f.number)

	connections[player] = player.CharacterAdded:Connect(function(character)
		bindCharacter(f, character)
	end)
	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		bindCharacter(f, character)
	end)
	return true
end

-- Sai do campo, e o boneco volta ao lugar.
function Squad.leave(player: Player)
	local f = Squad.byPlayer(player)
	if not f then
		return
	end
	if connections[player] then
		connections[player]:Disconnect()
		connections[player] = nil
	end
	local humanoid = f.humanoid
	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = 16
		humanoid.PlatformStand = false
	end
	if player.Parent then
		player.DevEnableMouseLock = true
		player:SetAttribute("PitchTeam", nil)
		player:SetAttribute("Number", nil)
		player:SetAttribute("Stamina", nil)
		if player:GetAttribute("Team") == "jogador" then
			player:SetAttribute("Team", nil)
		end
	end
	f.player = nil
	f.model = nil
	f.humanoid = nil
	f.root = nil
	task.spawn(spawnBot, f)
end

function Squad.byPlayer(player: Player): Footballer?
	for _, list in slots do
		for _, f in list do
			if f.player == player then
				return f
			end
		end
	end
	return nil
end

function Squad.isHuman(f: Footballer): boolean
	return f.player ~= nil
end

function Squad.setSprint(player: Player, on: boolean)
	local f = Squad.byPlayer(player)
	if f then
		f.wantSprint = on
	end
end

--------------------------------------------------------------------------------
-- Estado do corpo
--------------------------------------------------------------------------------

-- Quem esta de pe e pronto a jogar, com corpo no mundo.
function Squad.active(): { Footballer }
	local out = {}
	for _, list in slots do
		for _, f in list do
			local humanoid = f.humanoid
			if f.root and humanoid and humanoid.Parent and humanoid.Health > 0 then
				table.insert(out, f)
			end
		end
	end
	return out
end

function Squad.team(teamId: string): { Footballer }
	return slots[teamId] or {}
end

function Squad.isDown(f: Footballer, now: number): boolean
	return now < f.downUntil
end

function Squad.isFrozen(): boolean
	return frozen
end

function Squad.setFrozen(on: boolean)
	frozen = on
end

--[[
	Cair. Quem perde a bola num roubo vai ao chao e demora um segundo a
	levantar-se: e o que faz roubar valer a pena, e o que se ve de longe.
]]
function Squad.fall(f: Footballer, now: number)
	local humanoid = f.humanoid
	local root = f.root
	if not humanoid or not root then
		return
	end
	f.downUntil = now + F.fallTime

	local look = root.CFrame.LookVector
	local here = root.Position
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = groundCFrame(here, look, 1.2) * CFrame.Angles(math.rad(80), 0, 0)

	local model = f.model
	task.delay(F.fallTime, function()
		if f.model ~= model or not root.Parent then
			return
		end
		humanoid.PlatformStand = false
		root.CFrame = groundCFrame(root.Position, look, hipHeight(f) + 0.2)
		root.AssemblyLinearVelocity = Vector3.zero
		if not f.player then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

--[[
	O folego e a velocidade. Sprint gasta, sem sprint recupera; esgotado, so se
	volta a sprintar depois de recuperar um bocado — senao ficava-se a piscar
	entre correr e andar.
]]
function Squad.step(dt: number, now: number)
	for _, list in slots do
		for _, f in list do
			local humanoid = f.humanoid
			local root = f.root
			if humanoid and root then
				local moving = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
				local sprinting = f.wantSprint and not f.exhausted and moving > 2

				if sprinting then
					f.stamina = math.max(f.stamina - F.staminaDrain * dt, 0)
					if f.stamina <= 0 then
						f.exhausted = true
					end
				else
					f.stamina = math.min(f.stamina + F.staminaRegen * dt, F.staminaMax)
					if f.exhausted and f.stamina >= F.staminaRecover then
						f.exhausted = false
					end
				end

				local speed
				if frozen or Squad.isDown(f, now) then
					speed = 0
				elseif f.player then
					speed = if f.wantSprint and not f.exhausted then F.sprintSpeed else F.walkSpeed
				elseif f.wantSprint and not f.exhausted then
					speed = if f.dribbling then F.botDribbleSpeed else F.botSprintSpeed
				else
					speed = F.botSpeed
				end
				if humanoid.WalkSpeed ~= speed then
					humanoid.WalkSpeed = speed
				end
				humanoid.JumpHeight = if frozen then 0 else 7.2

				local player = f.player
				if player then
					player:SetAttribute("Stamina", math.floor(f.stamina / F.staminaMax * 100 + 0.5) / 100)
					player:SetAttribute("Exhausted", f.exhausted)
				else
					-- A corrida acompanha a velocidade, para os pes nao patinarem.
					local run = f.run
					local idle = f.idle
					if run and idle then
						if moving > 1.5 then
							if not run.IsPlaying then
								run:Play(0.15)
								idle:Stop(0.15)
							end
							run:AdjustSpeed(moving / 16)
						elseif run.IsPlaying then
							run:Stop(0.2)
							idle:Play(0.2)
						end
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------

function Squad.build(parent: Instance)
	local made = Instance.new("Folder")
	made.Name = "Footballers"
	made.Parent = parent
	folder = made

	for _, teamId in Config.TeamOrder do
		local list = {}
		for index, spot in F.formation do
			table.insert(list, {
				teamId = teamId,
				slot = index,
				number = spot.number,
				player = nil,
				model = nil,
				humanoid = nil,
				root = nil,
				stamina = F.staminaMax,
				wantSprint = false,
				dribbling = false,
				exhausted = false,
				downUntil = 0,
				immuneUntil = 0,
				run = nil,
				idle = nil,
			} :: Footballer)
		end
		slots[teamId] = list
	end

	for _, list in slots do
		for _, f in list do
			task.spawn(spawnBot, f)
		end
	end
end

return Squad
