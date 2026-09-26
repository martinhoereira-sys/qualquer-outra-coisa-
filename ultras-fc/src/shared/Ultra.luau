--!strict
--[[
	O aspeto dos bonecos de claque: tem de parecer gente, nao bonecos.

	Como nas claques a serio (e nas fotos do UKFL): quase todos de casaco
	escuro, cachecol da claque a tapar a cara, oculos escuros, bone ou gorro,
	o emblema pequeno ao peito. Iguais o suficiente para se ler um grupo,
	diferentes o suficiente para nao se ler uma fotocopia: cada um tira a sorte
	a pele, o cabelo, o que traz na cabeca e na cara, as calcas e os tenis.

	E so a receita: quem constroi (Crowd no servidor, Corteo no ecra) cria as
	pecas com a sua propria funcao. Cada peca vem com o sitio relativo ao
	tronco, e a frente e -Z.
]]

local Ultra = {}

export type Piece = {
	name: string,
	size: Vector3,
	colour: Color3,
	offset: CFrame, -- relativo ao tronco
	material: Enum.Material?,
}

local SKIN = {
	Color3.fromRGB(234, 196, 160),
	Color3.fromRGB(226, 184, 146),
	Color3.fromRGB(204, 158, 118),
	Color3.fromRGB(168, 120, 84),
	Color3.fromRGB(120, 84, 58),
	Color3.fromRGB(92, 64, 46),
}

local HAIR = {
	Color3.fromRGB(34, 26, 20),
	Color3.fromRGB(62, 42, 28),
	Color3.fromRGB(96, 66, 40),
	Color3.fromRGB(150, 110, 62),
	Color3.fromRGB(200, 170, 110),
}

-- Casacos: quase sempre escuros, como uma claque de preto.
local JACKET = {
	Color3.fromRGB(22, 22, 26),
	Color3.fromRGB(26, 28, 36),
	Color3.fromRGB(30, 32, 44),
	Color3.fromRGB(40, 40, 44),
}

local TROUSERS = {
	Color3.fromRGB(28, 30, 36),
	Color3.fromRGB(44, 52, 72), -- ganga
	Color3.fromRGB(70, 72, 70), -- camuflado cinzento
	Color3.fromRGB(20, 20, 22),
}

local SHOES = {
	Color3.fromRGB(236, 236, 236),
	Color3.fromRGB(24, 24, 24),
	Color3.fromRGB(120, 200, 190),
}

local WHITE = Color3.fromRGB(240, 240, 240)
local BLACK = Color3.fromRGB(16, 16, 18)

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

--[[
	As pecas de um boneco. `arms`: "up" (bracos no ar, na bancada) ou "down"
	(a andar). Com o mesmo `seed` sai sempre o mesmo boneco.
]]
function Ultra.pieces(seed: number, teamColour: Color3, arms: string): { Piece }
	local rng = Random.new(seed)
	local list: { Piece } = {}
	local function add(name: string, size: Vector3, colour: Color3, offset: CFrame, material: Enum.Material?)
		table.insert(list, { name = name, size = size, colour = colour, offset = offset, material = material })
	end

	local skin = pick(rng, SKIN)
	-- Um em cada seis vem com a camisola da claque em vez do casaco preto.
	local jacket = if rng:NextNumber() < 0.17 then teamColour else pick(rng, JACKET)
	local head = CFrame.new(0, 1.5, 0)

	add("Torso", Vector3.new(1.7, 2, 0.9), jacket, CFrame.identity, Enum.Material.Fabric)
	add("Head", Vector3.new(1, 1, 1), skin, head)
	add("Legs", Vector3.new(1.5, 1.7, 0.8), pick(rng, TROUSERS), CFrame.new(0, -1.85, 0), Enum.Material.Fabric)
	add("Tenis", Vector3.new(1.54, 0.3, 0.9), pick(rng, SHOES), CFrame.new(0, -2.6, -0.04))
	-- O emblema pequeno ao peito, da cor da claque.
	add("Emblema", Vector3.new(0.34, 0.34, 0.06), teamColour, CFrame.new(0.42, 0.45, -0.47))

	-- Os bracos: no ar na bancada, caidos a andar. A mao e da cor da pele.
	for _, side in { -1, 1 } do
		local arm = if arms == "up"
			then CFrame.new(1.1 * side, 1, 0) * CFrame.Angles(0, 0, math.rad(-18 * side + rng:NextNumber(-8, 8)))
			else CFrame.new(1.1 * side, 0, 0)
		add(if side < 0 then "ArmL" else "ArmR", Vector3.new(0.5, 1.8, 0.5), jacket, arm, Enum.Material.Fabric)
		local hand = if arms == "up" then CFrame.new(0, 0.85, 0) else CFrame.new(0, -0.85, 0)
		add(if side < 0 then "MaoL" else "MaoR", Vector3.new(0.52, 0.36, 0.52), skin, arm * hand)
	end

	-- A cara: cachecol a tapar (metade deles), oculos escuros (muitos).
	if rng:NextNumber() < 0.5 then
		add("Cachecol", Vector3.new(1.06, 0.38, 1.06), teamColour, head * CFrame.new(0, -0.24, 0), Enum.Material.Fabric)
		add("Risca", Vector3.new(1.08, 0.09, 1.08), WHITE, head * CFrame.new(0, -0.24, 0))
	end
	if rng:NextNumber() < 0.55 then
		add("Oculos", Vector3.new(1.02, 0.2, 0.06), BLACK, head * CFrame.new(0, 0.12, -0.51))
	end

	-- A cabeca: bone, gorro, chapeu de pescador ou so o cabelo.
	local top = rng:NextNumber()
	if top < 0.3 then
		add("Bone", Vector3.new(1.06, 0.32, 1.06), BLACK, head * CFrame.new(0, 0.55, 0))
		add("Pala", Vector3.new(0.9, 0.08, 0.5), BLACK, head * CFrame.new(0, 0.42, -0.72))
	elseif top < 0.45 then
		add("Gorro", Vector3.new(1.08, 0.5, 1.08), if rng:NextNumber() < 0.5 then teamColour else BLACK, head * CFrame.new(0, 0.5, 0), Enum.Material.Fabric)
	elseif top < 0.55 then
		add("Chapeu", Vector3.new(1.4, 0.1, 1.4), if rng:NextNumber() < 0.5 then WHITE else BLACK, head * CFrame.new(0, 0.48, 0), Enum.Material.Fabric)
		add("Copa", Vector3.new(1.04, 0.32, 1.04), if rng:NextNumber() < 0.5 then WHITE else BLACK, head * CFrame.new(0, 0.66, 0), Enum.Material.Fabric)
	else
		local hair = pick(rng, HAIR)
		add("Cabelo", Vector3.new(1.06, 0.26, 1.06), hair, head * CFrame.new(0, 0.56, 0.02))
		add("Nuca", Vector3.new(1.06, 0.62, 0.2), hair, head * CFrame.new(0, 0.26, 0.46))
	end

	return list
end

--[[
	Um nome como o de um jogador do Roblox, para por por cima da cabeca.
	Com o mesmo `seed` sai sempre o mesmo nome.
]]
local STARTS = { "tiago", "rui", "Duarte", "xX", "bruno", "Nuno", "kiko", "Joao", "miguel", "ze", "Pedro", "diogo", "Leo", "andre", "vasco", "Gui", "rafa", "Tomas", "ultra", "Curva", "Capo", "block", "Bairro", "north", "Rafinha", "Goncalo" }
local ENDS = { "_ultra", "Fan", "1912", "07", "_pt", "XD", "_bola", "88", "RBX", "_2009", "Gamer", "_curva", "10", "_tuga", "YT", "_07", "zz", "Pro", "_fc", "99" }

function Ultra.name(seed: number): string
	local rng = Random.new(seed * 7919 + 13)
	local name = pick(rng, STARTS) .. pick(rng, ENDS)
	if rng:NextNumber() < 0.35 then
		name ..= tostring(rng:NextInteger(1, 99))
	end
	return name
end

--[[
	O nome por cima da cabeca, pequeno e so de perto, como o dos jogadores.
]]
function Ultra.nameTag(head: BasePart, seed: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nome"
	gui.Size = UDim2.fromOffset(120, 18)
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = Ultra.name(seed)
	label.Parent = gui
	gui.Parent = head
end

return Ultra
