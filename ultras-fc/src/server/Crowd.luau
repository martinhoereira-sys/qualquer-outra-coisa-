--!strict
--[[
	A claque na bancada.

	Sao bonecos, e sao a coisa mais importante que ha no estadio. Uma bancada
	vazia nao apoia ninguem por mais botoes que se carregue — o apoio e a massa
	la estar, e e por isso que isto existe antes de qualquer mecanica.

	Saltam em sincronia. E isso que se ve de uma claque a serio do outro lado do
	relvado: nao pessoas paradas, um bloco inteiro a mexer ao mesmo tempo. Cada
	um leva um desfasamento minimo para nao parecer uma maquina.

	Nada usa fisica nem Humanoid: e tudo posto a mao, frame a frame — e nao aqui.
	O servidor so constroi os bonecos e diz o compasso de cada claque; quem os
	poe a saltar e cada ecra (Crowd.client). Mexer 80 bonecos no servidor era
	mandar centenas de pecas pela rede a todos, sessenta vezes por segundo, e
	num telemovel isso pesa mais do que o estadio inteiro.

	O compasso e o mesmo para toda a gente: o servidor acumula-o e publica-o com
	o relogio dele, e cada ecra anda com ele a partir dai. Todos veem a claque a
	saltar ao mesmo tempo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Budget = require(script.Parent:WaitForChild("Budget"))
local Stadium = require(script.Parent:WaitForChild("Stadium"))

local Crowd = {}

local C = Config.Crowd
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StadiumPlan"))
local Ultra = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ultra"))

-- Cada boneco tira a sorte o seu aspeto (Ultra) a partir deste numero.
local nextSeed = 0

type Supporter = {
	model: Model,
	teamId: string,
}

local people: { Supporter } = {}
local root: Folder? = nil

-- Onde vai o salto de cada claque, em saltos. So interessa a parte decimal.
local beat: { [string]: number } = {}
local moods: { [string]: string } = {}

-- Quantas vezes por segundo o compasso vai para os ecras. Entre envios, cada
-- ecra adianta-o sozinho.
local SEND_EVERY = 0.1
local sinceSend = math.huge

local function makePart(name: string, size: Vector3, colour: Color3, parent: Instance): Part
	Budget.take("Adeptos")
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildSupporter(teamId: string, at: Vector3, withFlag: boolean, parent: Instance): Supporter
	local team = Config.Teams[teamId]

	local model = Instance.new("Model")
	model.Name = "Ultra"
	model.Parent = parent

	local facing = CFrame.lookAt(at, Vector3.new(0, at.Y - 4, 0))

	--[[
		O aspeto: parece gente (Ultra), bracos no ar. Tudo relativo ao tronco,
		com a frente virada para o campo.
	]]
	nextSeed += 1
	local seed = nextSeed * 104729 + math.random(1, 100000)
	local torso: BasePart? = nil
	for _, p in Ultra.pieces(seed, team.color, "up") do
		local part = makePart(p.name, p.size, p.colour, model)
		if p.material then
			part.Material = p.material
		end
		part.CFrame = facing * p.offset
		if p.name == "Torso" then
			torso = part
		end
	end
	local body = torso :: BasePart
	model.PrimaryPart = body
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		Ultra.nameTag(head, seed)
	end

	local function attach(name: string, size: Vector3, colour: Color3, offset: CFrame)
		local piece = makePart(name, size, colour, model)
		piece.CFrame = body.CFrame * offset
	end

	if withFlag then
		attach("Pole", Vector3.new(0.2, 9, 0.2), Color3.fromRGB(70, 60, 48), CFrame.new(0.9, 5, 0))
		attach("Flag", Vector3.new(0.15, 3.4, 5), team.color, CFrame.new(0.9, 8, 2.6))
	end

	-- O que o ecra precisa para o por a saltar: de que claque e, o desfasamento
	-- dele, e quantas pecas tem, para saber quando ja chegaram todas.
	model:SetAttribute("Team", teamId)
	model:SetAttribute("Phase", math.random() * 0.22) -- em saltos: cada um com o seu atraso, nao uma maquina
	model:SetAttribute("Parts", #model:GetChildren())

	return { model = model, teamId = teamId }
end

function Crowd.build(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Crowd"
	folder.Parent = parent
	root = folder

	table.clear(people)

	--[[
		Enchem-se as filas baixas da curva de cada claque (StadiumPlan), de ponta
		a ponta da curva, menos o buraco do vomitorio. E a mancha compacta que se
		le como claque; gente espalhada le-se como publico.
	]]
	local rows = { 2, 3, 4, 5, 6, 7 }
	local perRow = math.ceil(C.perStand / #rows)

	for _, teamId in Config.TeamOrder do
		local made = 0

		for _, row in rows do
			local hole = if row > Plan.exitRow then Plan.vomitoryHalfT(Plan.rowRadius(row)) + 0.02 else 0
			for i = 1, perRow do
				if made >= C.perStand then
					break
				end
				local t = 0.07 + (i - 1) * (0.86 / (perRow - 1))
				if math.abs(t - 0.5) < hole then
					continue
				end
				made += 1

				local jitter = (math.random() - 0.5) * 0.01
				local at = Plan.claqueSeat(teamId, row, t + jitter) + Vector3.new(0, 2.6, 0)
				table.insert(people, buildSupporter(teamId, at, made % C.flagEvery == 0, folder))
			end
		end
	end
end

--[[
	Os bonecos dao lugar a gente a serio: por cada pessoa na claque saem
	Config.Crowd.botsPerPlayer bonecos dessa bancada, os mais perto do meio,
	que e onde as pessoas aparecem. Voltam quando as pessoas saem. Quem sai
	vai para o ServerStorage, que nao chega aos ecras: la desaparecem, e
	voltam a aparecer quando o boneco volta a bancada.
]]
local benched: Folder? = nil
local order: { [string]: { Supporter } } = {}

function Crowd.makeRoom(members: { [string]: number })
	local folder = root
	if not folder then
		return
	end
	if not benched then
		local made = Instance.new("Folder")
		made.Name = "AdeptosForaDaBancada"
		made.Parent = ServerStorage
		benched = made
	end
	if next(order) == nil then
		-- Por equipa, do meio do bloco para as pontas.
		for _, person in people do
			order[person.teamId] = order[person.teamId] or {}
			table.insert(order[person.teamId], person)
		end
		for teamId, list in order do
			local middle = Stadium.spawnPoint(teamId) or Vector3.zero
			table.sort(list, function(a, b)
				return (a.model:GetPivot().Position - middle).Magnitude < (b.model:GetPivot().Position - middle).Magnitude
			end)
		end
	end
	for teamId, list in order do
		local out = math.min((members[teamId] or 0) * C.botsPerPlayer, #list)
		for i, person in list do
			local target = if i <= out then benched else folder
			if person.model.Parent ~= target then
				person.model.Parent = target
			end
		end
	end
end

--[[
	`intensity` e 0 a 1: e a forca do tambor. Com ele parado a claque mexe-se
	devagar; a bater, salta a serio.

	O compasso acumula-se em vez de se tirar do relogio: assim, quando o tambor
	acelera, a claque acelera a partir de onde esta, sem dar um salto no ar.
	Vai para os ecras como atributos da pasta Crowd, com a hora do servidor a
	que foi tirado.
]]
function Crowd.step(dt: number, intensityByTeam: { [string]: number })
	local folder = root
	if not folder then
		return
	end

	local rates: { [string]: number } = {}
	local heights: { [string]: number } = {}
	for _, teamId in Config.TeamOrder do
		local intensity = intensityByTeam[teamId] or 0
		local mood = moods[teamId]
		if mood == "festa" then
			-- Golo nosso, ou jogo ganho: tudo no ar, com o tambor ou sem ele.
			rates[teamId] = C.drumRate
			heights[teamId] = C.bounceHeight * C.partyHeight
		elseif mood == "calada" then
			rates[teamId] = C.baseRate
			heights[teamId] = 0
		else
			rates[teamId] = C.baseRate + (C.drumRate - C.baseRate) * intensity
			heights[teamId] = C.bounceHeight * (0.45 + intensity * 0.55)
		end
		beat[teamId] = ((beat[teamId] or 0) + rates[teamId] * dt) % 1
	end

	sinceSend += dt
	if sinceSend < SEND_EVERY then
		return
	end
	sinceSend = 0

	folder:SetAttribute("Stamp", workspace:GetServerTimeNow())
	for _, teamId in Config.TeamOrder do
		folder:SetAttribute("Beat_" .. teamId, beat[teamId])
		folder:SetAttribute("Rate_" .. teamId, rates[teamId])
		folder:SetAttribute("Height_" .. teamId, heights[teamId])
		folder:SetAttribute("Sit_" .. teamId, moods[teamId] == "calada")
		-- Em festa cada um faz o seu: o compasso fica, mas os ecras deixam de o seguir.
		folder:SetAttribute("Party_" .. teamId, moods[teamId] == "festa")
	end
end

--[[
	O estado de espirito de uma claque, por cima do tambor:

		"festa"   golo nosso, ou jogo ganho — salta tudo, com forca
		"calada"  golo deles, ou jogo perdido — senta-se e cala-se
		nil       o normal: salta ao ritmo do tambor
]]
function Crowd.setMood(teamId: string, mood: string?)
	moods[teamId] = mood
end

function Crowd.mood(teamId: string): string?
	return moods[teamId]
end

--[[
	Tifo no ar: a claque para de saltar e recolhe as bandeiras. Quem segura uma
	cartolina nao salta, e um mastro de nove studs furava o desenho.
]]
function Crowd.setTifo(teamId: string, on: boolean)
	if root then
		root:SetAttribute("Hold_" .. teamId, on)
	end
	for _, person in people do
		if person.teamId == teamId then
			for _, name in { "Pole", "Flag" } do
				local piece = person.model:FindFirstChild(name) :: BasePart?
				if piece then
					piece.Transparency = on and 1 or 0
				end
			end
		end
	end
end

return Crowd
