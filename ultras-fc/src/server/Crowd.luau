--!strict
--[[
	A claque na bancada.

	Sao bonecos, e sao a coisa mais importante que ha no estadio. Uma bancada
	vazia nao apoia ninguem por mais botoes que se carregue — o apoio e a massa
	la estar, e e por isso que isto existe antes de qualquer mecanica.

	Saltam em sincronia. E isso que se ve de uma claque a serio do outro lado do
	relvado: nao pessoas paradas, um bloco inteiro a mexer ao mesmo tempo. Cada
	um leva um desfasamento minimo para nao parecer uma maquina.

	Nada usa fisica nem Humanoid: e tudo posto a mao, frame a frame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Crowd = {}

local C = Config.Crowd
local S = Config.Stadium

type Supporter = {
	model: Model,
	base: Vector3,
	phase: number,
	teamId: string,
}

local people: { Supporter } = {}

local SKIN = {
	Color3.fromRGB(226, 190, 152),
	Color3.fromRGB(198, 152, 112),
	Color3.fromRGB(150, 106, 74),
	Color3.fromRGB(102, 72, 52),
}

local function makePart(name: string, size: Vector3, colour: Color3, parent: Instance): Part
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
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = piece
		weld.Parent = torso
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

	return { model = model, base = at, phase = math.random() * 0.9, teamId = teamId }
end

function Crowd.build(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Crowd"
	folder.Parent = parent

	table.clear(people)

	--[[
		Enche-se so o miolo das filas baixas de cada lado comprido. A claque
		ocupa um bloco, nao a bancada toda: e a mancha compacta que se le como
		claque, gente espalhada le-se como publico.
	]]
	local rows = { 2, 3, 4, 5, 6, 7 }
	local perRow = math.ceil(C.perStand / #rows)

	for _, teamId in Config.TeamOrder do
		local side = Config.Teams[teamId].side
		local made = 0

		for _, row in rows do
			local topY = row * S.rowHeight
			local z = (S.pitchWidth / 2 + S.standGap + (row - 0.5) * S.rowDepth) * side
			-- Ocupam o miolo da bancada, nao a largura toda: a claque e um bloco
			-- compacto, e gente espalhada le-se como publico.
			local spread = S.pitchLength * 0.3

			for i = 1, perRow do
				if made >= C.perStand then
					break
				end
				made += 1

				local x = (i - (perRow + 1) / 2) * (spread * 2 / perRow)
				local at = Vector3.new(x + math.random() * 0.5 - 0.25, topY + 2.6, z)
				table.insert(people, buildSupporter(teamId, at, made % C.flagEvery == 0, folder))
			end
		end
	end
end

--[[
	`intensity` e 0 a 1: e a forca do tambor. Com ele parado a claque mexe-se
	devagar; a bater, salta a serio.
]]
function Crowd.step(now: number, intensityByTeam: { [string]: number })
	for _, person in people do
		local intensity = intensityByTeam[person.teamId] or 0
		local rate = C.baseRate + (C.drumRate - C.baseRate) * intensity
		local height = C.bounceHeight * (0.45 + intensity * 0.55)

		local lift = math.abs(math.sin((now + person.phase) * rate * math.pi)) * height
		local root = person.model.PrimaryPart
		if root then
			root.CFrame = CFrame.lookAt(
				person.base + Vector3.new(0, lift, 0),
				Vector3.new(0, person.base.Y - 4, 0)
			)
		end
	end
end

return Crowd
