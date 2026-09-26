--!strict
--[[
	A claque a saltar, feita neste ecra.

	O servidor constroi os bonecos e diz o compasso de cada claque (atributos da
	pasta Stadium.Crowd, com a hora do servidor a que foi tirado). Aqui adianta-se
	esse compasso com o relogio do servidor, que e o mesmo em todos os ecras, e
	poe-se cada boneco no sitio. Toda a gente ve a claque a saltar ao mesmo tempo
	sem o servidor mandar uma unica peca pela rede.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Pyro = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pyro"))
local Pano = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pano"))

-- As bandeiras dos bonecos sao de pano (Pano), feitas neste ecra.
local clothFolder = Instance.new("Folder")
clothFolder.Name = "BandeirasBancada"
clothFolder.Parent = workspace
-- Onde o pano prende ao mastro, relativo ao tronco (o mastro e o do servidor).
local POLE_BOTTOM = Vector3.new(0.9, 0.5, 0) -- o fundo do mastro (na mao), relativo ao tronco
local POLE_LENGTH = 9

--[[
	Como o boneco agita a bandeira, relativo ao tronco: devolve o eixo do mastro
	e para onde voa o pano. Metade roda o pulso (o mastro as voltas, o pano a
	dar a volta toda atras da ponta); a outra metade balanca de lado a lado.
]]
local function waveOf(phase: number, now: number): (Vector3, Vector3)
	local twirl = (phase * 7.13) % 1 < 0.5
	if twirl then
		local a = now * (5 + (phase * 31) % 2) + phase * 20
		local axis = (Vector3.yAxis + (Vector3.xAxis * math.cos(a) + Vector3.zAxis * math.sin(a)) * 0.45).Unit
		local tangent = -Vector3.xAxis * math.sin(a) + Vector3.zAxis * math.cos(a)
		local fly = -tangent + Vector3.xAxis * 0.3
		return axis, fly
	end
	local w = now * 2.2 + phase * 20
	local axis = (Vector3.yAxis + Vector3.xAxis * math.sin(w) * 0.5).Unit
	return axis, -Vector3.xAxis * math.cos(w) + Vector3.zAxis * 0.35
end

type Person = {
	model: Model,
	teamId: string,
	phase: number,
	base: CFrame,
	parts: { BasePart },
	offsets: { CFrame },
	cloth: Pano.Cloth?,
	pole: number?, -- o indice do mastro nas pecas (mexe-se a parte)
}

local people: { [Model]: Person } = {}

-- Um boneco so entra quando ja chegaram as pecas todas: sem isso, uma que
-- chegasse depois ficava parada enquanto o resto saltava.
local function track(model: Instance)
	if not model:IsA("Model") or people[model] then
		return
	end
	local teamId = model:GetAttribute("Team")
	local phase = model:GetAttribute("Phase")
	local count = model:GetAttribute("Parts")
	local torso = model:FindFirstChild("Torso")
	if type(teamId) ~= "string" or type(phase) ~= "number" or type(count) ~= "number" then
		return
	end
	if not torso or not torso:IsA("BasePart") then
		return
	end

	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
			table.insert(offsets, torso.CFrame:ToObjectSpace(child.CFrame))
		end
	end
	if #parts < count then
		return
	end

	local pole: number? = nil
	for i, part in parts do
		if part.Name == "Pole" then
			pole = i
		end
	end
	-- Com bandeira: o pano a ondular do mastro para o lado, virado para o campo.
	local cloth: Pano.Cloth? = nil
	if model:FindFirstChild("Flag") then
		cloth = Pano.new(clothFolder, 5, 3.4, 7, Pano.designFor("bandeira", teamId), {
			mode = "flag",
			pixels = 16,
			maxDistance = 260,
			seed = math.floor(phase * 1e6),
		})
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) and cloth then
				cloth.model:Destroy()
			end
		end)
	end

	people[model] = {
		model = model,
		teamId = teamId,
		phase = phase,
		base = torso.CFrame,
		parts = parts,
		offsets = offsets,
		cloth = cloth,
		pole = pole,
	}
end

local function watch(model: Instance)
	track(model)
	if model:IsA("Model") then
		model.ChildAdded:Connect(function()
			track(model)
		end)
		model.AttributeChanged:Connect(function()
			track(model)
		end)
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then
				people[model] = nil
			end
		end)
	end
end

local stadium = workspace:WaitForChild("Stadium")
local crowd = stadium:WaitForChild("Crowd")

for _, model in crowd:GetChildren() do
	watch(model)
end
crowd.ChildAdded:Connect(watch)

-- Reutilizadas a cada frame, para nao criar tabelas novas sessenta vezes por
-- segundo num telemovel.
local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

-- Um numero entre 0 e 1 que so depende de `x`: o mesmo em todos os ecras.
local function hash(x: number): number
	return (math.sin(x * 12.9898) * 43758.5453) % 1
end

--[[
	O golo. Normalmente a claque salta toda ao mesmo tempo, mas no golo
	ninguem esta organizado: cada um faz o seu, e o contraste e o que faz o
	golo parecer grande.

	Cada boneco muda de gesto a cada par de segundos: saltos a destempo e mais
	altos, rodar sobre si, encostar-se ao do lado a abracar, ou balancar com
	os bracos no ar. Tudo tirado do relogio do servidor e do desfasamento de
	cada um, por isso todos os ecras veem o mesmo caos.
]]
local function chaos(person: Person, now: number): CFrame
	local seed = person.phase * 97.13
	local slot = math.floor(now / 2.5 + hash(seed) * 4)
	local gesture = math.floor(hash(seed + slot * 0.61) * 4)
	local rate = 1.3 + hash(seed + 1.7) * 2.6
	local height = Config.Crowd.bounceHeight * (1 + hash(seed + slot * 0.37) * 1.8)
	local lift = math.abs(math.sin((now * rate + hash(seed + 3.1)) * math.pi)) * height

	local yaw, roll, side = 0, 0, 0
	if gesture == 1 then
		-- A rodar sobre si.
		yaw = now * (3 + hash(seed + 5.3) * 4) % (math.pi * 2)
	elseif gesture == 2 then
		-- Encostado ao do lado, num abraco: salta menos e inclina-se para ele.
		local towards = if hash(seed + slot) < 0.5 then -1 else 1
		roll = towards * 0.45
		side = towards * 0.7
		lift *= 0.35
	elseif gesture == 3 then
		-- A balancar de um lado para o outro.
		roll = math.sin(now * 7 + seed) * 0.4
	end
	return person.base * CFrame.new(side, lift, 0) * CFrame.Angles(0, yaw, roll)
end

RunService.RenderStepped:Connect(function()
	local stamp = crowd:GetAttribute("Stamp")
	if type(stamp) ~= "number" then
		return
	end
	local elapsed = workspace:GetServerTimeNow() - stamp

	-- O compasso de cada claque, agora, e quanto salta.
	local beats: { [string]: number } = {}
	local heights: { [string]: number } = {}
	local drops: { [string]: number } = {}
	local parties: { [string]: boolean } = {}
	local covered: { [string]: boolean } = {} -- bandeirao em baixo: as bandeiras recolhem
	local sways: { [string]: boolean } = {} -- a balancar os bracos, todos ao mesmo tempo
	local together: { [string]: boolean } = {} -- SALTAR: todos exatamente ao mesmo tempo
	local now = workspace:GetServerTimeNow()
	for _, name in Config.TeamOrder do
		-- Em festa, e sem tifo no ar (quem segura a cartolina nao larga).
		parties[name] = crowd:GetAttribute("Party_" .. name) == true and crowd:GetAttribute("Hold_" .. name) ~= true
		local beat = crowd:GetAttribute("Beat_" .. name)
		local rate = crowd:GetAttribute("Rate_" .. name)
		local height = crowd:GetAttribute("Height_" .. name)
		if type(beat) == "number" and type(rate) == "number" and type(height) == "number" then
			beats[name] = beat + rate * elapsed
			-- Tifo no ar: seguram a cartolina, nao saltam.
			heights[name] = crowd:GetAttribute("Hold_" .. name) == true and 0 or height
			local banner = stadium:GetAttribute("Bandeirao_" .. name)
			local B = Config.Lider.bandeirao
			covered[name] = type(banner) == "number" and now >= banner and now - banner < B.unroll + B.hold + B.rollup
			-- O lider mandou SALTAR: a bancada inteira salta muito mais alto.
			local jumpUntil = stadium:GetAttribute("Saltar_" .. name)
			if type(jumpUntil) == "number" and now < jumpUntil then
				heights[name] *= 1.9
				together[name] = true
			end
			-- Calados: sentam-se, que e o que se ve de uma bancada que sofreu.
			drops[name] = crowd:GetAttribute("Sit_" .. name) == true and Config.Crowd.sitDrop or 0
			-- As coreografias do lider: todos agachados, ou todos a balancar os bracos.
			local crouchUntil = stadium:GetAttribute("Agachar_" .. name)
			if type(crouchUntil) == "number" and now < crouchUntil then
				heights[name] = 0
				drops[name] = 1.5
			end
			local swayUntil = stadium:GetAttribute("Bracos_" .. name)
			sways[name] = type(swayUntil) == "number" and now < swayUntil
		end
	end

	table.clear(moveParts)
	table.clear(moveFrames)
	for _, person in people do
		local beat = beats[person.teamId]
		if beat then
			local at: CFrame
			if parties[person.teamId] then
				at = chaos(person, now)
			else
				local phase = if together[person.teamId] then 0 else person.phase
				local lift = math.abs(math.sin((beat + phase) * math.pi)) * heights[person.teamId]
				at = person.base + Vector3.new(0, lift - drops[person.teamId], 0)
				if sways[person.teamId] then
					-- De um lado para o outro, ao compasso, a bancada inteira junta.
					at *= CFrame.Angles(0, 0, math.sin(beat * math.pi) * 0.3)
				end
			end
			-- A bandeira: o mastro a rodar ou a balancar, e o pano atras da ponta.
			local cloth = person.cloth
			local poleCF: CFrame? = nil
			if cloth then
				-- Tifo no ar ou bandeirao em baixo: as bandeiras recolhem-se.
				local down = crowd:GetAttribute("Hold_" .. person.teamId) == true or covered[person.teamId] == true
				Pano.show(cloth, not down)
				if not down then
					local axis, fly = waveOf(person.phase, now)
					fly -= axis * fly:Dot(axis)
					fly = if fly.Magnitude > 1e-3 then fly.Unit else Vector3.xAxis
					local side = axis:Cross(fly)
					poleCF = at * CFrame.fromMatrix(POLE_BOTTOM + axis * (POLE_LENGTH / 2), side, axis)
					local top = POLE_BOTTOM + axis * (POLE_LENGTH - 0.3)
					Pano.pose(cloth, at * CFrame.fromMatrix(top, fly, axis), now + person.phase * 40, 1, moveParts, moveFrames)
				end
			end
			for i, part in person.parts do
				table.insert(moveParts, part)
				table.insert(moveFrames, if i == person.pole and poleCF then poleCF else at * person.offsets[i])
			end
		end
	end

	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

--[[
	A entrada em campo: com a fila parada, alguns bonecos de cada claque acendem
	tochas (as da Pyro, iguais as das pessoas). So neste ecra; os escolhidos
	sao os mesmos em todos os ecras, porque o desfasamento de cada boneco vem
	do servidor. Apagam-se a morrer, e o fumo fica no ar.
]]
local flares: { Instance } = {}

local function lightFlares()
	local lit = 0
	local byTeam: { [string]: { Person } } = {}
	for _, person in people do
		byTeam[person.teamId] = byTeam[person.teamId] or {}
		table.insert(byTeam[person.teamId], person)
	end
	for teamId, list in byTeam do
		table.sort(list, function(a, b)
			return a.phase > b.phase
		end)
		local team = Config.Teams[teamId]
		for i = 1, math.min(Config.Entrance.flares, #list) do
			local arm = list[i].model:FindFirstChild("ArmR")
			if arm and arm:IsA("BasePart") then
				-- A tocha a serio (a mesma das pessoas), na ponta do braco no ar.
				local tip = Instance.new("Attachment")
				tip.Name = "Tocha"
				tip.Position = Vector3.new(0, arm.Size.Y / 2 + 0.4, 0)
				tip.Parent = arm
				Pyro.flare(tip, team.color)
				Pyro.light(tip, team.color, 5, 28, lit)
				lit += 1
				table.insert(flares, tip)
			end
		end
	end
end

local function putOutFlares()
	for _, effect in flares do
		Pyro.fade(effect, 3)
		task.delay(Pyro.LINGER, function()
			effect:Destroy()
		end)
	end
	table.clear(flares)
end

--[[
	As ordens do lider (atributos na pasta Stadium): os bonecos obedecem sempre.
	- ACENDER: uns quantos bonecos da claque acendem tocha durante um bocado.
	- FARDA: casaco e calcas escuras, iguais, em todos.
]]
local ordered: { [string]: { Instance } } = {}

local function fadeSet(set: { Instance })
	for _, tip in set do
		if tip.Parent and not tip:GetAttribute("Apagada") then
			tip:SetAttribute("Apagada", true)
			Pyro.fade(tip, 4)
			task.delay(Pyro.LINGER, function()
				tip:Destroy()
			end)
		end
	end
end

local function lightTeam(teamId: string, count: number, seconds: number)
	-- Uma ordem nova: as tochas da anterior apagam-se (nao ficam duas na mesma mao).
	local previous = ordered[teamId]
	if previous then
		fadeSet(previous)
	end
	local list: { Person } = {}
	for _, person in people do
		if person.teamId == teamId then
			table.insert(list, person)
		end
	end
	-- Os mesmos em todos os ecras: pelo desfasamento de cada um.
	table.sort(list, function(a, b)
		return hash(a.phase * 31.7) < hash(b.phase * 31.7)
	end)
	local team = Config.Teams[teamId]
	local made: { Instance } = {}
	for i = 1, math.min(count, #list) do
		local arm = list[i].model:FindFirstChild("ArmR")
		if arm and arm:IsA("BasePart") then
			local tip = Instance.new("Attachment")
			tip.Name = "Tocha"
			tip.Position = Vector3.new(0, arm.Size.Y / 2 + 0.4, 0)
			tip.Parent = arm
			if i % 6 == 0 then
				Pyro.smoke(tip, team.color)
				task.delay(3, function()
					Pyro.settle(tip)
				end)
			else
				Pyro.flare(tip, team.color)
			end
			Pyro.light(tip, team.color, 5, 28, i - 1)
			table.insert(made, tip)
		end
	end
	ordered[teamId] = made
	-- Cada tocha apaga-se sempre ao fim do tempo, mesmo que o lider volte a
	-- mandar acender entretanto (antes ficavam acesas para sempre).
	task.delay(seconds, function()
		if ordered[teamId] == made then
			ordered[teamId] = nil
		end
		fadeSet(made)
	end)
end

local FARDA_PARTS = { Torso = true, ArmL = true, ArmR = true, Legs = true }
local original: { [BasePart]: Color3 } = {}

local function dressTeam(teamId: string, on: boolean)
	for _, person in people do
		if person.teamId == teamId then
			for _, part in person.parts do
				if FARDA_PARTS[part.Name] then
					if on then
						original[part] = original[part] or part.Color
						part.Color = Config.Lider.farda
					elseif original[part] then
						part.Color = original[part]
						original[part] = nil
					end
				end
			end
		end
	end
end

for _, teamId in Config.TeamOrder do
	stadium:GetAttributeChangedSignal("Acender_" .. teamId):Connect(function()
		local untilAt = stadium:GetAttribute("Acender_" .. teamId)
		if type(untilAt) == "number" and untilAt > workspace:GetServerTimeNow() then
			lightTeam(teamId, Config.Lider.lightBots, untilAt - workspace:GetServerTimeNow())
		end
	end)
	stadium:GetAttributeChangedSignal("Farda_" .. teamId):Connect(function()
		dressTeam(teamId, stadium:GetAttribute("Farda_" .. teamId) == true)
	end)
end

workspace:GetAttributeChangedSignal("EntranceLine"):Connect(function()
	if workspace:GetAttribute("EntranceLine") == true then
		putOutFlares()
		lightFlares()
	else
		putOutFlares()
	end
end)
