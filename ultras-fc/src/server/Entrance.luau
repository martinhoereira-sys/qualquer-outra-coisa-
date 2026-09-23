--!strict
--[[
	A entrada em campo.

	Do corteo ate ao apito, quem joga espera no balneario, por baixo da
	bancada principal, com a grade do tunel fechada. Quando as bancadas estao
	prontas abre-se o tunel: sai primeiro o arbitro — a pessoa que apita, ou um
	boneco de arbitro so para isto —, atras dele as duas equipas, uma fila de
	cada lado, e param lado a lado a frente do circulo central, virados para a
	bancada principal. Ficam ali presos vinte segundos, que e o momento de
	olhar para as bancadas; depois cada um vai para o seu lugar, e ha apito.

	Acontece uma vez por jogo. Quem chega depois nao espera por nada.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Budget = require(script.Parent:WaitForChild("Budget"))
local Stadium = require(script.Parent:WaitForChild("Stadium"))
local Squad = require(script.Parent:WaitForChild("Squad"))
local Bots = require(script.Parent:WaitForChild("Bots"))
local Crowd = require(script.Parent:WaitForChild("Crowd"))
local Referee = require(script.Parent:WaitForChild("Referee"))

type Footballer = Squad.Footballer

local Entrance = {}

local E = Config.Entrance

-- Um que sai do tunel: um jogador, o arbitro que e pessoa, ou o boneco de arbitro.
type Walker = {
	f: Footballer?,
	player: Player?, -- se for uma pessoa, e o ecra dela que a faz andar
	humanoid: Humanoid,
	root: BasePart,
	points: { Vector3 },
	index: number,
	startAt: number,
	nextMove: number,
}

local walkers: { Walker } = {}
local startedAt: number? = nil
local lined = false
local released = false
local refBot: Model? = nil

-- Para onde olha a fila: para a bancada principal.
local function facing(): Vector3
	return Vector3.new(0, 0, Stadium.mainSide())
end

local function lineSpot(teamId: string?, order: number): Vector3
	local z = Stadium.mainSide() * E.lineZ
	if not teamId then
		return Vector3.new(0, 0, z)
	end
	local side = Config.Teams[teamId].side
	return Vector3.new(side * (3 + (order - 1) * E.spacing), 0, z)
end

local function refereeCharacter(): (Player?, Humanoid?, BasePart?)
	local player = Referee.current()
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return player, humanoid, root
end

--[[
	O boneco de arbitro: de preto, so para a entrada. Sem pessoa a apitar, a
	fila sairia sem ninguem a frente, e a entrada em campo abre sempre com o
	arbitro.
]]
local function spawnRefBot(): (Humanoid?, BasePart?)
	local description = Instance.new("HumanoidDescription")
	local black = Color3.fromRGB(22, 22, 26)
	description.HeadColor = Color3.fromRGB(198, 152, 112)
	description.TorsoColor = black
	description.LeftArmColor = black
	description.RightArmColor = black
	description.LeftLegColor = black
	description.RightLegColor = black

	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Entrance] o boneco de arbitro nao nasceu:", result)
		return nil, nil
	end
	local model = result :: Model
	if not Budget.try("Jogadores", Budget.partsIn(model)) then
		model:Destroy()
		return nil, nil
	end

	model.Name = "Arbitro"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = Config.Football.walkSpeed
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Footballers"
		end
	end
	local at = Stadium.lockerSpot(nil, 0)
	model:PivotTo(CFrame.lookAt(at + Vector3.new(0, 3, 0), at + Vector3.new(0, 3, 0) + facing()))
	model.Parent = workspace:FindFirstChild("Stadium") or workspace
	root:SetNetworkOwner(nil)
	refBot = model
	return humanoid, root
end

local function removeRefBot()
	local bot = refBot
	refBot = nil
	if bot then
		Budget.give("Jogadores", Budget.partsIn(bot))
		bot:Destroy()
	end
end

-- Por no sitio e virar para a bancada principal: pessoa ou boneco.
local function settle(w: Walker, at: Vector3)
	local f = w.f
	if f then
		Squad.place(f, at, facing())
		return
	end
	local height = w.humanoid.HipHeight + w.root.Size.Y / 2 + 0.1
	local here = Vector3.new(at.X, height, at.Z)
	local model = w.root.Parent :: Model
	model:PivotTo(CFrame.lookAt(here, here + facing()))
end

--------------------------------------------------------------------------------

--[[
	Comeca o corteo: toda a gente que joga vai para o balneario e espera, com a
	grade do tunel fechada. Os bonecos ficam quietos la dentro.
]]
function Entrance.prepare()
	Squad.setLocker(true)
	Bots.setPaused(true)
	Stadium.setTunnelOpen(false)
	Squad.sendAllToLocker()

	local _, _, root = refereeCharacter()
	if root then
		local at = Stadium.lockerSpot(nil, 0) + Vector3.new(0, 3, 0)
		root.CFrame = CFrame.lookAt(at, at + facing())
	end
end

-- O arbitro que e pessoa, quando o balneario esta em uso, espera la dentro.
function Entrance.refereeSpot(): Vector3?
	if Squad.inLocker() then
		return Stadium.lockerSpot(nil, 0)
	end
	return nil
end

--[[
	As bancadas estao prontas: abre-se o tunel e sai a fila. O arbitro a
	frente, pelo meio; cada equipa pela sua faixa, um atras do outro.
]]
function Entrance.start()
	table.clear(walkers)
	startedAt = os.clock()
	lined = false
	released = false
	Stadium.setTunnelOpen(true)

	-- As duas claques no maximo, sem ser preciso fazer nada.
	for _, teamId in Config.TeamOrder do
		Crowd.setMood(teamId, "festa")
	end

	local now = os.clock()
	local player, humanoid, root = refereeCharacter()
	if not (humanoid and root) then
		player = nil
		humanoid, root = spawnRefBot()
	end
	if humanoid and root then
		local points = Stadium.tunnelPath(0)
		table.insert(points, lineSpot(nil, 0))
		table.insert(walkers, {
			player = player,
			humanoid = humanoid,
			root = root,
			points = points,
			index = 1,
			startAt = now,
			nextMove = 0,
		})
	end

	for _, teamId in Config.TeamOrder do
		local side = Config.Teams[teamId].side
		local order = 0
		for _, f in Squad.team(teamId) do
			local fHumanoid, fRoot = f.humanoid, f.root
			if fHumanoid and fRoot and not f.sentOff then
				order += 1
				f.wantSprint = false
				local points = Stadium.tunnelPath(side * 2.2)
				table.insert(points, lineSpot(teamId, order))
				table.insert(walkers, {
					f = f,
					player = f.player,
					humanoid = fHumanoid,
					root = fRoot,
					points = points,
					index = 1,
					startAt = now + E.stagger * order,
					nextMove = 0,
				})
			end
		end
	end

	-- As pessoas andam pelo seu ecra: e la que o boneco delas se mexe.
	for _, w in walkers do
		local who = w.player
		if who then
			task.delay(math.max(w.startAt - now, 0), function()
				if startedAt ~= nil and not lined then
					Remotes.Escort:FireClient(who, w.points, facing())
				end
			end)
		end
	end
end

-- Presos na fila: ninguem anda nem salta, pessoas incluidas.
local function holdReferee(hold: boolean)
	local _, humanoid = refereeCharacter()
	if humanoid then
		humanoid.WalkSpeed = if hold then 0 else Config.Football.walkSpeed
		humanoid.JumpHeight = if hold then 0 else 7.2
	end
end

function Entrance.step()
	local started = startedAt
	if not started or released then
		return
	end
	local now = os.clock()
	local t = now - started

	if not lined then
		for _, w in walkers do
			-- Os bonecos: ponto a ponto pelo tunel ate ao seu lugar na fila.
			if not w.player and now >= w.startAt and w.index <= #w.points and w.humanoid.Parent then
				local target = w.points[w.index]
				local here = w.root.Position
				if Vector3.new(target.X - here.X, 0, target.Z - here.Z).Magnitude < 1.5 then
					w.index += 1
				elseif now >= w.nextMove then
					w.nextMove = now + 0.3
					w.humanoid:MoveTo(Vector3.new(target.X, here.Y, target.Z))
				end
			end
		end

		if t >= E.lineAt then
			--[[
				A fila: quem ainda nao chegou e posto no seu lugar, para a fila
				sair direita, e toda a gente fica presa a olhar para a bancada.
			]]
			lined = true
			for _, w in walkers do
				if w.humanoid.Parent then
					settle(w, w.points[#w.points])
				end
			end
			Squad.setFrozen(true)
			holdReferee(true)
			workspace:SetAttribute("EntranceLine", true)
		end
		return
	end

	if t >= E.lineAt + E.lineSeconds then
		-- Quebram a fila: cada um para o seu lugar, e o apito ja vem.
		released = true
		workspace:SetAttribute("EntranceLine", nil)
		Squad.setFrozen(false)
		holdReferee(false)
		Squad.setLocker(false)
		Bots.setPaused(false)
		for _, teamId in Config.TeamOrder do
			Crowd.setMood(teamId, nil)
		end
		for _, w in walkers do
			if w.player == nil and w.f == nil then
				-- O boneco de arbitro sai para a linha lateral e desaparece no apito.
				w.humanoid:MoveTo(Vector3.new(0, w.root.Position.Y, Stadium.mainSide() * (Config.Stadium.pitchWidth / 2 - 2)))
			end
		end
	end
end

--[[
	O fim da entrada, venha ela ao fim do tempo ou por salto de fase: tudo como
	se tivesse acabado bem. Pode ser chamado mais do que uma vez.
]]
function Entrance.finish()
	local wasRunning = startedAt ~= nil
	startedAt = nil
	table.clear(walkers)
	removeRefBot()
	workspace:SetAttribute("EntranceLine", nil)
	Stadium.setTunnelOpen(true)
	Squad.setLocker(false)
	Bots.setPaused(false)
	if wasRunning and not released then
		Squad.setFrozen(false)
		holdReferee(false)
		for _, teamId in Config.TeamOrder do
			Crowd.setMood(teamId, nil)
		end
	end
	released = false
	lined = false
end

return Entrance
