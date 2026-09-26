--!strict
--[[
	As faixas das claques atadas a vedacao da curva, viradas para o campo.

	Como nas bancadas a serio: varias faixas lado a lado, letras grossas, cada
	uma com a sua cor, e de pano (Pano, tiras que baloicam) — nao uma placa.
	Os textos estao em Config.Teams[...].faixas.

	Vivem no mapa (Workspace.Estadio.Faixas_<equipa>), para se verem no
	preview do Studio. `build` so faz as que faltam, e tira a tarja antiga
	(uma placa lisa) se ainda la estiver.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Pano = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pano"))
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StadiumPlan"))

local Faixas = {}

local HEIGHT = 3.2
local TOP = 5.8 -- a beira de cima, presa ao topo da vedacao (a 6)
local GAP = 0.05 -- o espaco entre duas faixas, em t

-- Uma faixa escura, uma da cor da claque, e assim alternado.
local KINDS = { "faixa", "faixa_cor", "faixa" }

function Faixas.build(estadio: Instance)
	for _, teamId in Config.TeamOrder do
		local team = Config.Teams[teamId]
		local curve = estadio:FindFirstChild("Curva_" .. teamId)
		if curve then
			-- A tarja antiga era uma placa lisa: sai.
			for _, old in curve:GetChildren() do
				if old.Name == "Tarja" then
					old:Destroy()
				end
			end
		end
		if estadio:FindFirstChild("Faixas_" .. teamId) then
			continue
		end

		local folder = Instance.new("Folder")
		folder.Name = "Faixas_" .. teamId
		local cx, cz = Plan.claqueCorner(teamId)
		local radius = Plan.cornerRadius - 2
		local texts = team.faixas or { team.claque }
		local count = #texts
		local span = (1 - GAP * (count + 1)) / count
		for i, text in texts do
			-- Vistas do campo, t cresce da direita para a esquerda: a primeira fica a esquerda.
			local t0 = GAP + (count - i) * (span + GAP)
			local t1 = t0 + span
			local a = Plan.curvePoint(cx, cz, t0, radius, TOP)
			local b = Plan.curvePoint(cx, cz, t1, radius, TOP)
			local width = (b - a).Magnitude
			local design = Pano.designFor(KINDS[(i - 1) % #KINDS + 1], teamId, text)
			local cloth = Pano.new(folder, width, HEIGHT, math.max(6, math.round(width / 1.1)), design, {
				mode = "hang",
				name = "Faixa",
				pixels = 40,
				seed = i * 31 + #teamId,
			})
			Pano.fix(cloth, Pano.between(a, b, Vector3.yAxis), 0.35)
		end
		folder.Parent = estadio
	end
end

return Faixas
