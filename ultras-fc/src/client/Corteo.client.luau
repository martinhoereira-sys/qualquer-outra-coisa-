--!strict
--[[
	Os bonecos do corteo.

	Sozinho numa rua nao se ve corteo nenhum. Atras de cada faixa vai um grupo
	de bonecos da claque, desalinhados como gente a andar — nao em fila.

	Vivem so neste ecra: o servidor move a faixa (uma peca so) e cada ecra poe
	os seus bonecos atras dela, pelo caminho que ela fez. Nao passa nada pela
	rede, e com a mesma faixa toda a gente ve o corteo no mesmo sitio.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Pano = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pano"))

local M = Config.March

local SKIN = {
	Color3.fromRGB(226, 190, 152),
	Color3.fromRGB(198, 152, 112),
	Color3.fromRGB(150, 106, 74),
	Color3.fromRGB(102, 72, 52),
}

type Walker = {
	parts: { BasePart },
	offsets: { CFrame },
	back: number, -- quantos studs atras da faixa
	side: number, -- quanto para o lado
	gather: Vector3, -- onde fica a espera, antes de sair
	holder: number?, -- -1 ou 1: segura a faixa por esta ponta
	drum: boolean, -- o boneco do tambor: sai quando e o lider a guiar
	phase: number, -- para o passo nao ser igual em todos
	at: Vector3, -- onde esta agora (no chao)
	facing: Vector3,
	ground: number,
	nextGround: number,
}

type Group = {
	banner: BasePart,
	folder: Folder,
	walkers: { Walker },
	cloth: Pano.Cloth, -- a faixa de pano, pendurada da peca do servidor
	trail: { Vector3 }, -- o caminho da faixa, do mais recente para o mais antigo
	arrivedAt: number?,
}

local groups: { [BasePart]: Group } = {}

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

-- Um boneco como os da bancada: tronco, cabeca, pernas e os bracos no ar.
-- O do meio leva o tambor a frente da barriga.
local function makeWalker(colour: Color3, parent: Instance, drum: boolean?): ({ BasePart }, { CFrame })
	local model = Instance.new("Model")
	model.Name = "Marcha"
	model.Parent = parent
	local parts: { BasePart } = {
		piece("Torso", Vector3.new(1.7, 2, 0.9), colour, model),
		piece("Head", Vector3.new(1, 1, 1), SKIN[math.random(1, #SKIN)], model),
		piece("Legs", Vector3.new(1.5, 1.7, 0.8), Color3.fromRGB(24, 26, 32), model),
		piece("ArmL", Vector3.new(0.5, 1.8, 0.5), colour, model),
		piece("ArmR", Vector3.new(0.5, 1.8, 0.5), colour, model),
	}
	local offsets = {
		CFrame.identity,
		CFrame.new(0, 1.5, 0),
		CFrame.new(0, -1.85, 0),
		CFrame.new(-1.1, 1, 0) * CFrame.Angles(0, 0, math.rad(18)),
		CFrame.new(1.1, 1, 0) * CFrame.Angles(0, 0, math.rad(-18)),
	}
	if drum then
		local body = piece("Drum", Vector3.new(1.6, 2.2, 2.2), Color3.fromRGB(196, 186, 168), model)
		body.Shape = Enum.PartType.Cylinder
		table.insert(parts, body)
		table.insert(offsets, CFrame.new(0, -0.4, -1.5) * CFrame.Angles(0, math.rad(90), 0))
	end
	return parts, offsets
end

local function track(banner: Instance)
	if not banner:IsA("BasePart") or groups[banner] then
		return
	end
	local teamId = banner:GetAttribute("Team")
	local team = type(teamId) == "string" and Config.Teams[teamId]
	if not team then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Corteo_" .. tostring(teamId)
	folder.Parent = workspace

	local walkers: { Walker } = {}
	local function add(back: number, side: number, holder: number?, drum: boolean?)
		local parts, offsets = makeWalker(team.color, folder, drum)
		-- A espera ficam do lado da rua, a frente da faixa, nunca dentro da sede.
		local angle = math.random() * math.pi
		local radius = 4 + math.random() * 10
		local gather = Vector3.new(math.cos(angle) * radius, 0, 2 + math.sin(angle) * radius)
		local start = banner.Position + gather
		table.insert(walkers, {
			parts = parts,
			offsets = offsets,
			back = back,
			side = side,
			gather = gather,
			holder = holder,
			drum = drum == true,
			phase = math.random() * math.pi * 2,
			at = Vector3.new(start.X, 0, start.Z),
			facing = Vector3.new(0, 0, -1),
			ground = banner.Position.Y - 3,
			nextGround = 0,
		})
	end

	-- Dois seguram a faixa, um em cada ponta, e ela vai esticada entre eles.
	add(0, 0, -1)
	add(0, 0, 1)

	--[[
		O grupo logo atras da faixa, colado e de parede a parede: filas da
		largura dela, apertadas, com um pouco de desalinho para parecer gente e
		nao soldados. O lider com o tambor vai no meio da primeira fila.
	]]
	local columns = M.columns
	local spacing = banner.Size.X / columns
	for i = 0, M.bots - 1 do
		local row = i // columns
		local column = i % columns
		local side = (column - (columns - 1) / 2) * spacing + (math.random() - 0.5) * 0.8
		local back = 3 + row * 2.6 + (math.random() - 0.5) * 0.8
		local drum = row == 0 and column == columns // 2
		add(back, if drum then 0 else side, nil, drum)
	end

	-- A faixa de pano (a peca do servidor e so o sitio dela).
	local cloth = Pano.new(folder, banner.Size.X, banner.Size.Y, 20, Pano.designFor("faixa", teamId :: string), {
		mode = "hang",
		name = "Faixa",
		pixels = 30,
	})

	groups[banner] = {
		banner = banner,
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
	A altura do chao por baixo de um ponto. Procura-se a partir de pouco acima
	da rua: de mais alto, o raio batia num telhado e o boneco ia la para cima.
	Poucas vezes por segundo chega.
]]
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(at: Vector3, fallback: number): number
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
	rayParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(Vector3.new(at.X, fallback + 6, at.Z), Vector3.new(0, -40, 0), rayParams)
	return if hit then hit.Position.Y else fallback
end

local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

RunService.RenderStepped:Connect(function(dt)
	table.clear(moveParts)
	table.clear(moveFrames)
	local now = os.clock()

	for banner, group in groups do
		local here = banner.Position
		local moving = banner:GetAttribute("Moving") == true
		local arrived = banner:GetAttribute("Arrived") == true

		-- O caminho da faixa: um ponto novo a cada dois studs.
		local trail = group.trail
		if (trail[1] - here).Magnitude >= 2 then
			table.insert(trail, 1, here)
			if #trail > 120 then
				table.remove(trail)
			end
		end

		-- Chegados a porta, entram no estadio: vao ate a faixa e desaparecem.
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
		Pano.pose(group.cloth, banner.CFrame * CFrame.new(-size.X / 2, size.Y / 2, 0), now, if moving then 0.55 else 0.3, moveParts, moveFrames)

		-- Com o lider a guiar, e ele que leva o tambor: o boneco do tambor sai.
		local led = banner:GetAttribute("Led") == true

		for _, w in group.walkers do
			if w.drum and led then
				for _, part in w.parts do
					table.insert(moveParts, part)
					table.insert(moveFrames, CFrame.new(0, -500, 0))
				end
				continue
			end
			local target: Vector3
			if w.holder and not arrived then
				-- Na ponta da faixa, a segura-la: vai onde ela vai, virado para a frente.
				local grip = banner.CFrame * CFrame.new(w.holder * (banner.Size.X / 2 + 0.6), 0, 0.9)
				target = grip.Position
			elseif moving and not arrived then
				local point, direction = alongTrail(trail, w.back)
				local right = direction:Cross(Vector3.yAxis)
				target = point + right * w.side
			elseif arrived then
				target = here
			else
				target = here + w.gather
			end
			target = Vector3.new(target.X, 0, target.Z)

			-- Anda para la ao passo de uma pessoa, sem saltar de sitio.
			local delta = target - w.at
			local stepLength = math.min(delta.Magnitude, (M.speed + 4) * dt)
			local walking = delta.Magnitude > 0.5
			if walking then
				w.facing = delta.Unit
				w.at += delta.Unit * stepLength
			end
			-- Quem segura a faixa olha sempre para onde ela olha.
			if w.holder and moving then
				local look = banner.CFrame.LookVector
				w.facing = Vector3.new(look.X, 0, look.Z).Unit
			end

			if now >= w.nextGround then
				w.nextGround = now + 0.4 + math.random() * 0.2
				w.ground = groundAt(w.at, w.ground)
			end

			-- O passo sobe e desce; parados, saltam no sitio como na bancada.
			local bob = if walking
				then math.abs(math.sin(now * 5.5 + w.phase)) * 0.3
				else math.abs(math.sin(now * 5 + w.phase)) * 0.8
			local body = Vector3.new(w.at.X, w.ground + 2.6 + bob, w.at.Z)
			local cf = CFrame.lookAt(body, body + w.facing)
			for i, part in w.parts do
				table.insert(moveParts, part)
				table.insert(moveFrames, cf * w.offsets[i])
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
