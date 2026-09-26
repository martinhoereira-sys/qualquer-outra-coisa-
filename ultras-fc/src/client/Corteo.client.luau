--!strict
--[[
	Os bonecos do corteo.

	Sozinho numa rua nao se ve corteo nenhum. Atras de cada faixa vai um grupo
	de bonecos da claque, com aspeto de gente (Ultra).

	Vivem so neste ecra: o servidor move a faixa (uma peca so) e diz em que
	momento esta (atributo "Stage"); cada ecra poe os seus bonecos. Nao passa
	nada pela rede, e com a mesma faixa toda a gente ve o corteo no mesmo sitio.

	Os tres momentos:
	- FORMATURA: filas direitas atras da faixa, alinhadas e quietas. E curto,
	  mas e o que faz aquilo parecer serio em vez de um grupo a passear.
	- MARCHA: ja nao sao filas, e um bloco colado, de parede a parede (aperta
	  onde a rua e estreita), organizado mas nao alinhado. Devagar, ao passo
	  do tambor da claque; tochas e fumo a acender pelo caminho.
	- CORRIDA: nos ultimos metros acaba a marcha e desatam todos a correr para
	  dentro. Quem la vai a pe tambem ve o aviso e pode correr mais depressa.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Pano = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pano"))
local Pyro = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pyro"))
local Ultra = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ultra"))

local M = Config.March
local me = Players.LocalPlayer

-- As filas: entre duas, e o espaco na marcha (o bloco e mais apertado).
local FORM_ROW = 2.6
local MARCH_ROW = 2.2
-- De quantos em quantos segundos muda quem tem tocha acesa na marcha.
local TORCH_WINDOW = 14
local TORCH_SHARE = 0.14 -- em cada janela, esta parte dos bonecos acende
local SMOKE_SHARE = 0.03

type Walker = {
	index: number,
	parts: { BasePart },
	offsets: { CFrame },
	arm: number?, -- o indice do braco direito e da mao (para levantar a tocha)
	hand: number?,
	formBack: number, -- na formatura: filas direitas
	formSide: number,
	marchBack: number, -- na marcha: o mesmo lugar, desalinhado
	marchSide: number,
	limit: number, -- quanto se pode afastar para o lado sem bater na parede
	gather: Vector3, -- onde fica a espera, antes de formar
	holder: number?, -- -1 ou 1: segura a faixa por esta ponta
	drum: boolean, -- o boneco do tambor: sai quando e o lider a guiar
	phase: number, -- para o passo nao ser igual em todos
	at: Vector3, -- onde esta agora (no chao)
	facing: Vector3,
	ground: number,
	nextCheck: number,
	torch: Attachment?,
	torchWindow: number,
}

type Group = {
	banner: BasePart,
	teamId: string,
	colour: Color3,
	folder: Folder,
	walkers: { Walker },
	cloth: Pano.Cloth, -- a faixa de pano, pendurada da peca do servidor
	trail: { Vector3 }, -- o caminho da faixa, do mais recente para o mais antigo
	arrivedAt: number?,
	lastStage: string?,
	dressed: boolean?, -- de farda (ordem do lider)
}

local groups: { [BasePart]: Group } = {}

-- Um numero entre 0 e 1 que so depende de `x`: o mesmo em todos os ecras.
local function hash(x: number): number
	return (math.sin(x * 12.9898) * 43758.5453) % 1
end

local function piece(name: string, size: Vector3, colour: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- Os bracos no ar (a tocha acesa): o direito e a mao, relativos ao tronco.
local ARM_UP = CFrame.new(1.1, 1, 0) * CFrame.Angles(0, 0, math.rad(-18))
local HAND_UP = ARM_UP * CFrame.new(0, 0.85, 0)

--[[
	Um boneco com aspeto de gente (Ultra), de bracos caidos a andar. O do meio
	da primeira fila leva o tambor a frente da barriga.
]]
local function makeWalker(index: number, colour: Color3, parent: Instance, drum: boolean): Walker
	local model = Instance.new("Model")
	model.Name = "Marcha"
	model.Parent = parent
	local seed = index * 7727 + math.random(1, 100000)
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local arm, hand
	for _, p in Ultra.pieces(seed, colour, "down") do
		local part = piece(p.name, p.size, p.colour, model)
		if p.material then
			part.Material = p.material
		end
		table.insert(parts, part)
		table.insert(offsets, p.offset)
		if p.name == "ArmR" then
			arm = #parts
		elseif p.name == "MaoR" then
			hand = #parts
		elseif p.name == "Head" then
			Ultra.nameTag(part, seed)
		end
	end
	if drum then
		local body = piece("Drum", Vector3.new(1.6, 2.2, 2.2), Color3.fromRGB(196, 186, 168), model)
		body.Shape = Enum.PartType.Cylinder
		table.insert(parts, body)
		table.insert(offsets, CFrame.new(0, -0.4, -1.5) * CFrame.Angles(0, math.rad(90), 0))
	end
	return {
		index = index,
		parts = parts,
		offsets = offsets,
		arm = arm,
		hand = hand,
		formBack = 0,
		formSide = 0,
		marchBack = 0,
		marchSide = 0,
		limit = math.huge,
		gather = Vector3.zero,
		holder = nil,
		drum = drum,
		phase = math.random() * math.pi * 2,
		at = Vector3.zero,
		facing = Vector3.new(0, 0, -1),
		ground = 0,
		nextCheck = 0,
		torch = nil,
		torchWindow = -1,
	}
end

local function track(banner: Instance)
	if not banner:IsA("BasePart") or groups[banner] then
		return
	end
	local teamId = banner:GetAttribute("Team")
	local team = type(teamId) == "string" and Config.Teams[teamId]
	if not team or type(teamId) ~= "string" then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Corteo_" .. teamId
	folder.Parent = workspace

	local walkers: { Walker } = {}
	local function add(back: number, side: number, holder: number?, drum: boolean)
		local w = makeWalker(#walkers + 1, team.color, folder, drum)
		w.formBack = back
		w.formSide = side
		-- Na marcha: o mesmo lugar, mas mais apertado e desalinhado.
		w.marchBack = if back > 0 then 2.4 + (back - 3) / FORM_ROW * MARCH_ROW + (math.random() - 0.5) * 1.4 else 0
		w.marchSide = side * 0.92 + (math.random() - 0.5) * 1.6
		w.holder = holder
		-- A espera ficam do lado da rua, a frente da faixa, nunca dentro da sede.
		local angle = math.random() * math.pi
		local radius = 4 + math.random() * 10
		w.gather = Vector3.new(math.cos(angle) * radius, 0, 2 + math.sin(angle) * radius)
		local start = banner.Position + w.gather
		w.at = Vector3.new(start.X, 0, start.Z)
		w.ground = banner.Position.Y - 3
		table.insert(walkers, w)
	end

	-- Dois seguram a faixa, um em cada ponta, e ela vai esticada entre eles.
	add(0, 0, -1, false)
	add(0, 0, 1, false)

	--[[
		As filas atras da faixa, da largura dela: na formatura direitas, na
		marcha soltas. O do tambor vai no meio da primeira fila (sai quando e
		o lider, uma pessoa, a levar o tambor).
	]]
	local columns = M.columns
	local spacing = banner.Size.X / columns
	for i = 0, M.bots - 1 do
		local row = i // columns
		local column = i % columns
		local side = (column - (columns - 1) / 2) * spacing
		local back = 3 + row * FORM_ROW
		add(back, side, nil, row == 0 and column == columns // 2)
	end

	-- A faixa de pano (a peca do servidor e so o sitio dela).
	local cloth = Pano.new(folder, banner.Size.X, banner.Size.Y, 20, Pano.designFor("faixa", teamId), {
		mode = "hang",
		name = "Faixa",
		pixels = 30,
	})

	groups[banner] = {
		banner = banner,
		teamId = teamId,
		colour = team.color,
		folder = folder,
		walkers = walkers,
		cloth = cloth,
		trail = { banner.Position },
	}

	banner.AncestryChanged:Connect(function()
		if not banner:IsDescendantOf(workspace) then
			local group = groups[banner]
			groups[banner] = nil
			if group then
				group.folder:Destroy()
			end
		end
	end)
end

-- Um ponto do caminho da faixa, `distance` studs atras dela.
local function alongTrail(trail: { Vector3 }, distance: number): (Vector3, Vector3)
	local left = distance
	for i = 1, #trail - 1 do
		local a, b = trail[i], trail[i + 1]
		local segment = (a - b).Magnitude
		if segment >= left and segment > 0 then
			local point = a:Lerp(b, left / segment)
			return point, (a - b).Unit
		end
		left -= segment
	end
	local last = trail[#trail]
	local direction = if #trail >= 2 then (trail[#trail - 1] - last).Unit else Vector3.new(0, 0, -1)
	return last - direction * left, direction
end

--[[
	A altura do chao por baixo de um ponto, e as paredes ao lado. Procura-se a
	partir de pouco acima da rua: de mais alto, o raio batia num telhado e o
	boneco ia la para cima. Poucas vezes por segundo chega.
]]
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function refreshExclude()
	local exclude: { Instance } = {}
	for _, group in groups do
		table.insert(exclude, group.folder)
		table.insert(exclude, group.banner)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local stadium = workspace:FindFirstChild("Stadium")
	if stadium then
		table.insert(exclude, stadium)
	end
	rayParams.FilterDescendantsInstances = exclude
end

local function groundAt(at: Vector3, fallback: number): number
	local hit = workspace:Raycast(Vector3.new(at.X, fallback + 6, at.Z), Vector3.new(0, -40, 0), rayParams)
	return if hit then hit.Position.Y else fallback
end

-- Ate onde se pode ir para o lado `sign` a partir de `from` sem bater numa parede.
local function roomTo(from: Vector3, right: Vector3, sign: number, want: number): number
	local hit = workspace:Raycast(from, right * sign * (want + 1.5), rayParams)
	return if hit then math.max(0.4, hit.Distance - 1.2) else math.huge
end

--[[
	O compasso do tambor da claque (o mesmo que poe a bancada a saltar): o
	servidor publica-o na pasta Stadium.Crowd. Sem ele, um passo de marcha.
]]
local function beatOf(teamId: string, serverNow: number): number
	local stadium = workspace:FindFirstChild("Stadium")
	local crowd = stadium and stadium:FindFirstChild("Crowd")
	if crowd then
		local stamp = crowd:GetAttribute("Stamp")
		local beat = crowd:GetAttribute("Beat_" .. teamId)
		local rate = crowd:GetAttribute("Rate_" .. teamId)
		if type(stamp) == "number" and type(beat) == "number" and type(rate) == "number" then
			return beat + rate * (serverNow - stamp)
		end
	end
	return serverNow * 1.7
end

--------------------------------------------------------------------------------
-- As tochas e o fumo pelo caminho
--------------------------------------------------------------------------------

local lights = 0

local function putOut(w: Walker)
	local torch = w.torch
	if torch then
		w.torch = nil
		if torch:FindFirstChild("Luz") then
			lights -= 1
		end
		Pyro.fade(torch, 3)
		task.delay(Pyro.LINGER, function()
			torch:Destroy()
		end)
	end
end

-- Em cada janela de tempo, alguns bonecos (os mesmos em todos os ecras) acendem.
local function updateTorch(w: Walker, group: Group, marching: boolean, serverNow: number, ordered: boolean)
	-- Com a ordem ACENDER do lider, muitos mais acendem (e a janela muda ja).
	local window = math.floor(serverNow / TORCH_WINDOW) * 2 + (if ordered then 1 else 0)
	if window == w.torchWindow then
		return
	end
	w.torchWindow = window
	putOut(w)
	if not (marching or ordered) or w.holder or not w.hand then
		return
	end
	local roll = hash(window * 7.31 + w.index * 1.93 + #group.teamId)
	if roll >= (if ordered then 0.6 else TORCH_SHARE) then
		return
	end
	local hand = w.parts[w.hand :: number]
	local at = Instance.new("Attachment")
	at.Name = "Tocha"
	at.Position = Vector3.new(0, 0.4, 0)
	at.Parent = hand
	if roll < SMOKE_SHARE then
		Pyro.smoke(at, group.colour)
		task.delay(3, function()
			if at.Parent then
				Pyro.settle(at)
			end
		end)
	else
		Pyro.flare(at, group.colour)
	end
	if Pyro.light(at, group.colour, 4, 24, lights) then
		lights += 1
	end
	w.torch = at
end

--------------------------------------------------------------------------------
-- A corrida: o aviso a quem vai no corteo
--------------------------------------------------------------------------------

local runGui: ScreenGui? = nil

local function runCall(group: Group)
	if me:GetAttribute("Team") ~= group.teamId then
		return
	end
	local character = me.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or (root.Position - group.banner.Position).Magnitude > M.radius * 1.5 then
		return
	end

	if runGui then
		runGui:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Corrida"
	gui.ResetOnSpawn = false
	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.3)
	text.Size = UDim2.fromOffset(620, 70)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.2
	text.Text = "CORRE PARA DENTRO!"
	text.Parent = gui
	gui.Parent = me:WaitForChild("PlayerGui")
	runGui = gui
	task.delay(4, function()
		gui:Destroy()
	end)

	-- Quem quiser corre mais depressa uns segundos; quem nao quiser, anda.
	local before = humanoid.WalkSpeed
	if before > 0 and before < M.runBoost then
		humanoid.WalkSpeed = M.runBoost
		task.delay(7, function()
			if humanoid.Parent and humanoid.WalkSpeed == M.runBoost then
				humanoid.WalkSpeed = before
			end
		end)
	end
end

--------------------------------------------------------------------------------

local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}
local nextExclude = 0

RunService.RenderStepped:Connect(function(dt)
	table.clear(moveParts)
	table.clear(moveFrames)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	if now >= nextExclude then
		nextExclude = now + 1
		refreshExclude()
	end

	for banner, group in groups do
		local here = banner.Position
		local stage = banner:GetAttribute("Stage")
		if type(stage) ~= "string" then
			stage = if banner:GetAttribute("Moving") == true then "marcha" else "espera"
		end
		local arrived = banner:GetAttribute("Arrived") == true
		if stage ~= group.lastStage then
			if stage == "corrida" then
				runCall(group)
			end
			group.lastStage = stage
		end
		local look = banner.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)

		-- O caminho da faixa: um ponto novo a cada dois studs.
		local trail = group.trail
		if (trail[1] - here).Magnitude >= 2 then
			table.insert(trail, 1, here)
			if #trail > 120 then
				table.remove(trail)
			end
		end

		-- Chegados a porta, entram no estadio e desaparecem.
		if arrived and not group.arrivedAt then
			group.arrivedAt = now
		end
		local inside = group.arrivedAt ~= nil and now - group.arrivedAt > 4
		group.folder.Parent = if inside then nil else workspace
		if inside then
			continue
		end

		-- A faixa aberta, a baloicar mais quando anda.
		local size = banner.Size
		local moving = stage == "marcha" or stage == "corrida"
		Pano.pose(group.cloth, banner.CFrame * CFrame.new(-size.X / 2, size.Y / 2, 0), now, if moving then 0.55 else 0.3, moveParts, moveFrames)

		-- Com o lider a guiar, e ele que leva o tambor: o boneco do tambor sai.
		local led = banner:GetAttribute("Led") == true
		local beat = beatOf(group.teamId, serverNow)
		-- As ordens do lider: os bonecos obedecem sempre.
		local orders = workspace:FindFirstChild("Stadium")
		local jumpUntil = orders and orders:GetAttribute("Saltar_" .. group.teamId)
		local lightUntil = orders and orders:GetAttribute("Acender_" .. group.teamId)
		local jumping = type(jumpUntil) == "number" and serverNow < jumpUntil
		local lighting = type(lightUntil) == "number" and serverNow < lightUntil
		local farda = orders ~= nil and orders:GetAttribute("Farda_" .. group.teamId) == true
		if farda ~= group.dressed then
			group.dressed = farda
			for _, w in group.walkers do
				for _, part in w.parts do
					if part.Name == "Torso" or part.Name == "ArmL" or part.Name == "ArmR" or part.Name == "Legs" then
						if farda then
							part:SetAttribute("Cor", part.Color)
							part.Color = Config.Lider.farda
						else
							local before = part:GetAttribute("Cor")
							if typeof(before) == "Color3" then
								part.Color = before
							end
						end
					end
				end
			end
		end

		for _, w in group.walkers do
			if w.drum and led then
				for _, part in w.parts do
					table.insert(moveParts, part)
					table.insert(moveFrames, CFrame.new(0, -500, 0))
				end
				continue
			end

			updateTorch(w, group, stage == "marcha", serverNow, lighting and stage ~= "corrida")

			local target: Vector3
			local speed = M.speed + 5
			local face: Vector3? = nil
			if w.holder and stage ~= "corrida" and not arrived then
				-- Na ponta da faixa, a segura-la: vai onde ela vai, virado para a frente.
				local grip = banner.CFrame * CFrame.new(w.holder * (size.X / 2 + 0.6), 0, 0.9)
				target = grip.Position
				speed = M.runSpeed + 6
				if stage ~= "espera" then
					face = forward
				end
			elseif stage == "formatura" then
				-- Filas direitas atras da faixa, todos virados para a frente.
				target = (banner.CFrame * CFrame.new(w.formSide, 0, w.formBack)).Position
				face = forward
			elseif stage == "marcha" then
				-- O bloco: o seu lugar no caminho da faixa, desalinhado, a
				-- apertar onde a rua e estreita.
				local point, direction = alongTrail(trail, w.marchBack)
				local right = direction:Cross(Vector3.yAxis)
				if now >= w.nextCheck then
					w.nextCheck = now + 0.4 + math.random() * 0.2
					local from = Vector3.new(point.X, w.ground + 3, point.Z)
					w.limit = roomTo(from, right, if w.marchSide >= 0 then 1 else -1, math.abs(w.marchSide))
					w.ground = groundAt(w.at, w.ground)
				end
				local drift = math.sin(now * 0.35 + w.phase) * 0.45
				local side = math.clamp(w.marchSide + drift, -w.limit, w.limit)
				target = point + right * side
			elseif stage == "corrida" and not arrived then
				-- A correr para a porta, atras da faixa, o bloco a esticar-se.
				local point, direction = alongTrail(trail, w.marchBack * 0.7)
				target = point + direction:Cross(Vector3.yAxis) * w.marchSide * 0.6
				speed = M.runSpeed + 6
			elseif arrived then
				-- A porta: entram todos.
				target = here
				speed = M.runSpeed + 6
			else
				target = here + w.gather
			end
			target = Vector3.new(target.X, 0, target.Z)

			-- Anda para la ao passo de uma pessoa, sem saltar de sitio.
			local delta = target - w.at
			local stepLength = math.min(delta.Magnitude, speed * dt)
			local walking = delta.Magnitude > 0.35
			if walking then
				w.facing = delta.Unit
				w.at += delta.Unit * stepLength
			end
			if face and delta.Magnitude < 1.5 then
				w.facing = face
			end

			if stage ~= "marcha" and now >= w.nextCheck then
				w.nextCheck = now + 0.4 + math.random() * 0.2
				w.ground = groundAt(w.at, w.ground)
			end

			-- O passo: na marcha ao compasso do tambor; a correr, depressa; na
			-- formatura quietos; a espera, a saltar como na bancada.
			local bob, roll = 0, 0
			if stage == "corrida" then
				bob = math.abs(math.sin(now * 11 + w.phase)) * 0.55
				roll = math.sin(now * 11 + w.phase) * 0.08
			elseif jumping then
				-- O lider mandou SALTAR: saltam ao compasso do tambor.
				bob = math.abs(math.sin(beat * math.pi)) * 1.1
			elseif stage == "marcha" then
				local step = (beat + w.phase * 0.02) * math.pi
				bob = math.abs(math.sin(step)) * 0.3
				roll = math.sin(step) * 0.05
			elseif stage == "formatura" then
				bob = if walking then math.abs(math.sin(now * 6 + w.phase)) * 0.25 else math.sin(now * 1.5 + w.phase) * 0.03
			else
				bob = math.abs(math.sin(now * 5 + w.phase)) * 0.8
			end
			local body = Vector3.new(w.at.X, w.ground + 2.6 + bob, w.at.Z)
			local cf = CFrame.lookAt(body, body + w.facing) * CFrame.Angles(0, 0, roll)
			local raised = w.torch ~= nil
			for i, part in w.parts do
				local offset = w.offsets[i]
				if raised and i == w.arm then
					offset = ARM_UP
				elseif raised and i == w.hand then
					offset = HAND_UP
				end
				table.insert(moveParts, part)
				table.insert(moveFrames, cf * offset)
			end
		end
	end

	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

-- A pasta do corteo nasce a cada jogo, dentro do estadio.
local stadium = workspace:WaitForChild("Stadium")

local function watchMarch(folder: Instance)
	if folder.Name ~= "March" then
		return
	end
	for _, banner in folder:GetChildren() do
		track(banner)
	end
	folder.ChildAdded:Connect(track)
end

for _, child in stadium:GetChildren() do
	watchMarch(child)
end
stadium.ChildAdded:Connect(watchMarch)
