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

type Person = {
	model: Model,
	teamId: string,
	phase: number,
	base: CFrame,
	parts: { BasePart },
	offsets: { CFrame },
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

	people[model] = {
		model = model,
		teamId = teamId,
		phase = phase,
		base = torso.CFrame,
		parts = parts,
		offsets = offsets,
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
	for _, name in Config.TeamOrder do
		local beat = crowd:GetAttribute("Beat_" .. name)
		local rate = crowd:GetAttribute("Rate_" .. name)
		local height = crowd:GetAttribute("Height_" .. name)
		if type(beat) == "number" and type(rate) == "number" and type(height) == "number" then
			beats[name] = beat + rate * elapsed
			-- Tifo no ar: seguram a cartolina, nao saltam.
			heights[name] = crowd:GetAttribute("Hold_" .. name) == true and 0 or height
			-- Calados: sentam-se, que e o que se ve de uma bancada que sofreu.
			drops[name] = crowd:GetAttribute("Sit_" .. name) == true and Config.Crowd.sitDrop or 0
		end
	end

	table.clear(moveParts)
	table.clear(moveFrames)
	for _, person in people do
		local beat = beats[person.teamId]
		if beat then
			local lift = math.abs(math.sin((beat + person.phase) * math.pi)) * heights[person.teamId]
			local at = person.base + Vector3.new(0, lift - drops[person.teamId], 0)
			for i, part in person.parts do
				table.insert(moveParts, part)
				table.insert(moveFrames, at * person.offsets[i])
			end
		end
	end

	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

--[[
	A entrada em campo: com a fila parada, alguns bonecos de cada claque acendem
	tochas. So neste ecra, e so um por claque com luz propria: uma bancada
	inteira de luzes deitava abaixo um telemovel, e a chama e o fumo chegam para
	se ver de longe. Os escolhidos sao os mesmos em todos os ecras, porque o
	desfasamento de cada boneco vem do servidor.
]]
local flares: { Instance } = {}

local function lightFlares()
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
				local fire = Instance.new("Fire")
				fire.Heat = 9
				fire.Size = 4
				fire.Color = team.color
				fire.SecondaryColor = Color3.fromRGB(255, 238, 196)
				fire.Parent = arm
				table.insert(flares, fire)

				local smoke = Instance.new("Smoke")
				smoke.Color = team.color:Lerp(Color3.new(1, 1, 1), 0.5)
				smoke.Opacity = 0.3
				smoke.RiseVelocity = 8
				smoke.Size = 8
				smoke.Parent = arm
				table.insert(flares, smoke)

				if i <= Config.Entrance.flareLights then
					local light = Instance.new("PointLight")
					light.Color = team.color
					light.Brightness = 5
					light.Range = 30
					light.Shadows = false
					light.Parent = arm
					table.insert(flares, light)
				end
			end
		end
	end
end

local function putOutFlares()
	for _, effect in flares do
		effect:Destroy()
	end
	table.clear(flares)
end

workspace:GetAttributeChangedSignal("EntranceLine"):Connect(function()
	if workspace:GetAttribute("EntranceLine") == true then
		putOutFlares()
		lightFlares()
	else
		putOutFlares()
	end
end)
