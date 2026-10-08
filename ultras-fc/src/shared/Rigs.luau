--!strict
--[[
	Os panos com juntas, para se poderem animar no Animation Editor:

	- BANDEIRA (a grande das claques, no mastro) e BANDEIRINHA: fazem parte do
	  rig da propria personagem. Mao direita -> mastro (Motor6D) -> pano
	  (PanoRig: tiras ao alto, cada uma partida em bocados). Uma animacao feita
	  no boneco de teste (ServerStorage.Modelos) mexe bracos, mastro e pano.
	- FAIXA (a do corteo): rig proprio (AnimationController) preso a barra.
	- BANDEIRAO: rig proprio, preso ao rolo no cimo da curva.

	E daqui que saem o jogo e as copias de ServerStorage.Modelos: os nomes das
	juntas sao sempre os mesmos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pano = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pano"))
local PanoRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PanoRig"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Rigs = {}

export type FlagSpec = {
	name: string, -- o nome do modelo e o prefixo das juntas
	pole: number, -- comprimento do mastro
	thick: number,
	width: number,
	height: number,
	columns: number,
	rows: number,
	design: string, -- o desenho do Pano
	grip: number, -- a que distancia do fundo do mastro fica a mao
	forward: boolean?, -- o mastro sai da mao para a frente (afastado do corpo), nao ao longo do braco
}

-- As medidas de cada bandeira (Gear: "mastro" e "bandeirinha").
Rigs.FLAGS = {
	mastro = { name = "Bandeira", pole = 14, thick = 0.34, width = 9, height = 9, columns = 12, rows = 12, design = "mastro", grip = 0.4 } :: FlagSpec,
	-- The gemellaggio flag: the two emblems side by side, the two clubs' colours behind.
	gemflag = { name = "Gemellaggio", pole = 8, thick = 0.2, width = 6, height = 3.6, columns = 10, rows = 5, design = "gemellaggio", grip = 0.5 } :: FlagSpec,
	bandeirinha = { name = "Bandeirinha", pole = 4.5, thick = 0.14, width = 3.2, height = 2.1, columns = 8, rows = 3, design = "bandeirinha", grip = 0.5 } :: FlagSpec,
}

Rigs.FAIXA = { name = "Faixa", columns = 12, rows = 2 }
Rigs.BANDEIRAO = { name = "Bandeirao", columns = 14, rows = 4 }

local POLE = Color3.fromRGB(70, 60, 48)

local function handOf(character: Model): BasePart?
	return (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
end

--[[
	A bandeira na mao: o mastro (preso a mao por um Motor6D chamado como a
	bandeira) e o pano no cimo dele. Tudo dentro de um modelo com o nome da
	bandeira, dentro da personagem. Devolve o modelo.
]]
function Rigs.flag(character: Model, kind: string, teamId: string, colour: Color3?): Model?
	local spec = Rigs.FLAGS[kind]
	local hand = handOf(character)
	if not spec or not hand then
		return nil
	end
	-- O modelo chama-se "<nome>_Rig": o objecto da barra (Tool) tem o nome
	-- da bandeira, e nao se pode confundir com ele.
	local old = character:FindFirstChild(spec.name .. "_Rig")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = spec.name .. "_Rig"

	local pole = Instance.new("Part")
	pole.Name = spec.name .. "_Mastro"
	pole.Size = Vector3.new(spec.thick, spec.pole, spec.thick)
	pole.Color = POLE
	pole.Material = Enum.Material.Wood
	pole.CanCollide = false
	pole.CanQuery = false
	pole.CanTouch = false
	pole.Massless = true
	pole.Parent = model

	-- A mao segura o mastro perto do fundo; de pe, para cima.
	local joint = Instance.new("Motor6D")
	joint.Name = spec.name .. "_Mastro"
	joint.Part0 = hand
	joint.Part1 = pole
	-- A bandeira grande agarra-se com as duas maos: o mastro sai da mao direita
	-- para a frente (afastado do corpo), e sobra mastro atras dela para a esquerda.
	joint.C0 = CFrame.new(0, -hand.Size.Y / 2, 0) * (if spec.forward then CFrame.Angles(-math.rad(90), 0, 0) else CFrame.identity)
	joint.C1 = CFrame.new(0, -spec.pole / 2 + spec.grip, 0)
	joint.Parent = pole
	pole.CFrame = hand.CFrame * joint.C0 * joint.C1:Inverse()

	local design = Pano.designFor(spec.design, teamId)
	if colour then
		design.colour = colour
	end
	if kind == "gemflag" then
		-- The two clubs: mine and my gemellati (the server said which: "Gemellaggio").
		local owner = game:GetService("Players"):GetPlayerFromCharacter(character)
		local a = owner and (Config.Clubs :: any)[owner:GetAttribute("Clube") or ""]
		local b = owner and (Config.Clubs :: any)[owner:GetAttribute("Gemellaggio") or ""]
		if not a or not b then
			return nil
		end
		design.club = a
		design.club2 = b
		design.colour = a.color
	end
	PanoRig.build(model, pole, {
		name = spec.name,
		columns = spec.columns,
		rows = spec.rows,
		width = spec.width,
		height = spec.height,
		design = design,
		pixels = if kind == "mastro" then 14 else 18,
		maxDistance = if kind == "mastro" then nil else 220,
		-- O canto de cima do pano no cimo do mastro, a sair para o lado.
		attach = CFrame.new(spec.thick / 2, spec.pole / 2 - 0.15, 0),
	})
	model.Parent = character
	return model
end

-- O rig do pano de uma bandeira que a personagem tem na mao (para o mexer).
function Rigs.findFlag(character: Model, kind: string): (PanoRig.Rig?, Motor6D?)
	local spec = Rigs.FLAGS[kind]
	local model = spec and character:FindFirstChild(spec.name .. "_Rig")
	if not spec or not model then
		return nil, nil
	end
	local pole = model:FindFirstChild(spec.name .. "_Mastro")
	local joint = pole and pole:FindFirstChild(spec.name .. "_Mastro")
	local rig = PanoRig.find(model, spec.name, spec.columns, spec.rows, spec.width, spec.height)
	return rig, if joint and joint:IsA("Motor6D") then joint else nil
end

--[[
	A faixa do corteo: o pano com juntas pendurado da barra (`bar`, a peca que
	o servidor move). Dentro de `model` fica tambem o AnimationController, para
	uma animacao "faixapano" a poder mexer.
]]
function Rigs.faixa(model: Model, bar: BasePart, teamId: string): PanoRig.Rig
	local size = bar.Size
	local rig = PanoRig.build(model, bar, {
		name = Rigs.FAIXA.name,
		columns = Rigs.FAIXA.columns,
		rows = Rigs.FAIXA.rows,
		width = size.X,
		height = size.Y,
		design = Pano.designFor("faixa", teamId),
		pixels = 24,
		attach = CFrame.new(-size.X / 2, size.Y / 2, 0),
	})
	if not model:FindFirstChildOfClass("AnimationController") then
		local controller = Instance.new("AnimationController")
		controller.Parent = model
		Instance.new("Animator").Parent = controller
	end
	return rig
end


return Rigs
