--!strict
--[[
	O BANDEIRAO: o momento mais bonito de um jogo de futebol a serio.

	O pano gigante esta enrolado no cimo da curva da claque (o rolo vive no
	mapa, Workspace.Estadio.Bandeirao_<equipa>, para se ver no preview). O
	lider da a ordem e ele desenrola-se de cima para baixo por cima das
	cabecas, tapa o bloco inteiro, fica um bocado e volta a enrolar.

	Aqui so se decide QUANDO: uma vez por parte, e so com o jogo a decorrer (ou
	na entrada das equipas). A hora de inicio vai no atributo
	"Bandeirao_<equipa>" da pasta Workspace.Stadium, e cada ecra desenha o pano
	(Bandeirao.client) — 448 bocados a mexer nao passam pela rede.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BP = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BandeiraoPlan"))

local B = Config.Lider.bandeirao

local Bandeirao = {}

-- Quanto dura tudo: desenrolar, ficar, enrolar.
Bandeirao.SECONDS = B.unroll + B.hold + B.rollup

-- As fases em que se pode, e a que parte contam (uma vez por parte).
local HALF: { [string]: string } = {
	entrada = "1",
	first = "1",
	halftime = "2",
	second = "2",
}

local used: { [string]: boolean } = {}

-- O rolo, no cimo de cada curva de claque. So faz o que falta.
function Bandeirao.build(estadio: Instance)
	for _, teamId in Config.TeamOrder do
		if estadio:FindFirstChild("Bandeirao_" .. teamId) then
			continue
		end
		local folder = Instance.new("Folder")
		folder.Name = "Bandeirao_" .. teamId
		local colour = Config.Teams[teamId].color
		for i, piece in BP.roll(teamId, BP.sTop, BP.ROLL_PIECES) do
			local p = Instance.new("Part")
			p.Name = "Rolo"
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(piece.length, BP.ROLL_THICK, BP.ROLL_THICK)
			p.CFrame = piece.cf
			p.Color = if i % 2 == 0 then colour else Color3.fromRGB(236, 236, 232)
			p.Material = Enum.Material.Fabric
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Parent = folder
		end
		folder.Parent = estadio
	end
end

-- Dia de jogo novo: pode-se outra vez.
function Bandeirao.newMatch()
	table.clear(used)
end

--[[
	O lider mandou. Devolve se desceu, e porque nao (para lhe dizer).
]]
function Bandeirao.trigger(teamId: string, phase: string): (boolean, string?)
	local half = HALF[phase]
	if not half then
		return false, "O bandeirão só desce com o jogo a decorrer."
	end
	local key = teamId .. ":" .. half
	if used[key] then
		return false, "Já usaste o bandeirão nesta parte."
	end
	local stadium = workspace:FindFirstChild("Stadium")
	if not stadium then
		return false, nil
	end
	used[key] = true
	stadium:SetAttribute("Bandeirao_" .. teamId, workspace:GetServerTimeNow())
	return true, nil
end

return Bandeirao
