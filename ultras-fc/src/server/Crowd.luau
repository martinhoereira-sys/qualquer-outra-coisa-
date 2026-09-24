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

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Budget = require(script.Parent:WaitForChild("Budget"))
local Stadium = require(script.Parent:WaitForChild("Stadium"))

local Crowd = {}

local C = Config.Crowd
local S = Config.Stadium

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

local SKIN = {
	Color3.fromRGB(226, 190, 152),
	Color3.fromRGB(198, 152, 112),
	Color3.fromRGB(150, 106, 74),
	Color3.fromRGB(102, 72, 52),
}

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

	local torso = makePart("Torso", Vector3.new(1.7, 2, 0.9), team.color, model)
	torso.CFrame = facing
	model.PrimaryPart = torso

	local function attach(name: string, size: Vector3, colour: Color3, offset: CFrame)
		local piece = makePart(name, size, colour, model)
		piece.CFrame = torso.CFrame * offset
	end

	attach("Head", Vector3.new(1, 1, 1), SKIN[math.random(1, #SKIN)], CFrame.new(0, 1.5, 0))
	attach("Legs", Vector3.new(1.5, 1.7, 0.8), Color3.fromRGB(24, 26, 32), CFrame.new(0, -1.85, 0))

	-- Bracos no ar. E a postura de uma claque, e le-se de longe.
	attach("ArmL", Vector3.new(0.5, 1.8, 0.5), team.color, CFrame.new(-1.1, 1, 0) * CFrame.Angles(0, 0, math.rad(18)))
	attach("ArmR", Vector3.new(0.5, 1.8, 0.5), team.color, CFrame.new(1.1, 1, 0) * CFrame.Angles(0, 0, math.rad(-18)))

	if withFlag then
		attach("Pole", Vector3.new(0.2, 9, 0.2), Color3.fromRGB(70, 60, 48), CFrame.new(0.9, 5, 0))
		attach("Flag", Vector3.new(0.15, 3.4, 5), team.color, CFrame.new(0.9, 8, 2.6))
	end

	-- O que o ecra precisa para o por a saltar: de que claque e, o desfasamento
	-- dele, e quantas pecas tem, para saber quando ja chegaram todas.
	model:SetAttribute("Team", teamId)
	model:SetAttribute("Phase", math.random() * 0.12) -- em saltos, nao em segundos
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
		Enche-se so o miolo das filas baixas de cada topo, atras da baliza. A
		claque ocupa um bloco, nao a bancada toda: e a mancha compacta que se le
		como claque, gente espalhada le-se como publico.
	]]
	local rows = { 2, 3, 4, 5, 6, 7 }
	local perRow = math.ceil(C.perStand / #rows)

	for _, teamId in Config.TeamOrder do
		local side = Config.Teams[teamId].side
		local made = 0

		for _, row in rows do
			local topY = row * S.rowHeight
			local x = (S.pitchLength / 2 + S.standGap + (row - 0.5) * S.rowDepth) * side
			-- Ocupam o bloco do meio de ponta a ponta, e so ele: e o sector da
			-- claque, entre as duas escadas que lhe servem de entrada.
			local spread = Stadium.claqueHalfWidth() - 1

			for i = 1, perRow do
				if made >= C.perStand then
					break
				end
				made += 1

				local z = -spread + (i - 1) * (spread * 2 / (perRow - 1))
				local at = Vector3.new(x, topY + 2.6, z + math.random() * 0.5 - 0.25)
				table.insert(people, buildSupporter(teamId, at, made % C.flagEvery == 0, folder))
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
