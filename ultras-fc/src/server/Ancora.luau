--!strict
--[[
	Os edificios presos ao chao.

	Muito do que se poe no mapa vem da Toolbox com as pecas soltas (Anchored
	falso), so soldadas umas as outras. Parece firme, mas o primeiro toque (um
	autocarro, uma bola) deita as paredes abaixo: foi o que aconteceu a uma
	sede.

	Aqui prende-se tudo o que e cenario. Ficam soltas so as coisas feitas para
	se mexer: pecas com dobradicas, cordas, molas ou calhas (portas, baloicos),
	o que tem Humanoid, e os nossos veiculos e o jogo (autocarros, bicicletas,
	a bola, os bonecos).

	Corre a cada arranque, por isso o que se acrescentar ao mapa depois fica
	preso sozinho.
]]

local Ancora = {}

-- As pastas do jogo que tem pecas soltas de proposito.
local SKIP_TOP: { [string]: boolean } = {
	Transportes = true, -- os autocarros andam pela fisica
	Stadium = true, -- o jogo (bola, bonecos, material)
	BicicletasParadas = true, -- as bicicletas estacionadas
}

-- Coisas do mapa que sao feitas para se mexer.
local KEEP_LOOSE: { [string]: boolean } = {
	Ball = true,
	["Skate Board"] = true,
	["Swing Set"] = true,
	["McDonalds Food bag"] = true,
	["Ball pit"] = true, -- as bolas da piscina de bolas
}

local MOVING = {
	"HingeConstraint",
	"RopeConstraint",
	"SpringConstraint",
	"PrismaticConstraint",
	"BallSocketConstraint",
	"CylindricalConstraint",
	"RodConstraint",
	"VehicleSeat",
}

-- As pecas presas a um constraint que as deixa mexer (portas, baloicos...).
-- Uma passagem so pelo mapa: com milhares de pecas, procurar peca a peca era lento.
local function movingParts(): { [BasePart]: boolean }
	local set: { [BasePart]: boolean } = {}
	for _, c in workspace:GetDescendants() do
		if c:IsA("VehicleSeat") then
			set[c] = true
		else
			for _, className in MOVING do
				if c:IsA(className) then
					for _, key in { "Attachment0", "Attachment1" } do
						local attachment = (c :: any)[key]
						local part = attachment and attachment.Parent
						if part and part:IsA("BasePart") then
							set[part] = true
						end
					end
				end
			end
		end
	end
	return set
end

local function looseAncestor(part: Instance): boolean
	local node = part.Parent
	while node and node ~= workspace do
		if KEEP_LOOSE[node.Name] or node:FindFirstChildOfClass("Humanoid") then
			return true
		end
		node = node.Parent
	end
	return false
end

--[[
	Prende o cenario. Devolve quantas pecas prendeu.
]]
function Ancora.run(): number
	local count = 0
	local moving = movingParts()
	for _, top in workspace:GetChildren() do
		if SKIP_TOP[top.Name] or KEEP_LOOSE[top.Name] or top:IsA("Terrain") or top:IsA("Camera") then
			continue
		end
		if top:FindFirstChildOfClass("Humanoid") then
			continue
		end
		local parts: { BasePart } = {}
		if top:IsA("BasePart") then
			table.insert(parts, top)
		end
		for _, d in top:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		for _, part in parts do
			if not part.Anchored and not looseAncestor(part) and not moving[part] then
				part.Anchored = true
				count += 1
			end
		end
	end
	return count
end

return Ancora
