--!strict
--[[
	As COPIAS para animar: ServerStorage.Modelos.

	O jogo constroi tudo no arranque, por isso em modo de edicao nao ha nada
	para ver nem copiar. Isto faz, a partir do MESMO codigo do jogo (Material,
	Rigs, BandeiraoRig), um modelo parado de cada coisa; os que se seguram vem
	com um boneco de teste R15 ja a segura-los.

	SAO SO COPIAS. O jogo nunca le esta pasta: apaga-la nao muda nada.

	Para as fazer outra vez (depois de o codigo mudar), na barra de comandos
	do Studio (View > Command Bar), cola esta linha e carrega Enter:

	  local f=Instance.new("Folder",game.ServerStorage) f.Name="TmpModelos" for _,m in game.ReplicatedStorage.Shared:GetChildren() do m:Clone().Parent=f end local g=game.ServerScriptService.Server.Modelos:Clone() g.Parent=f for _,m in f:GetChildren() do m.Source=m.Source:gsub('ReplicatedStorage:WaitForChild%("Shared"%)','game.ServerStorage.TmpModelos') end require(g).build() f:Destroy()

	(Copia os modulos antes de os usar: assim le sempre o codigo de agora, e
	nao uma versao antiga que o Studio tenha guardado.)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Material = require(Shared:WaitForChild("Material"))
local Rigs = require(Shared:WaitForChild("Rigs"))

local Modelos = {}

-- Um boneco de teste R15, de pe, parado no sitio.
local function dummy(name: string): Model
	local model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	model.Name = name
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	return model
end

-- Uma peca de mao (tocha, lata, vela) soldada a mao direita, como no jogo.
local function holding(name: string, kind: string, colour: Color3): Model
	local model = dummy(name)
	local hand = Material.handOf(model) :: BasePart
	local h = Material.buildHeld(kind, colour)
	h.weld.Part0 = hand
	-- Acesa: de pe, com o braco no ar (a pose que se ve no jogo).
	h.weld.C0 = Material.gripFor(h, Material.stickDirection(Material.RAISED))
	h.model.Parent = model
	return model
end

function Modelos.build(): Folder
	local old = ServerStorage:FindFirstChild("Modelos")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Modelos"
	folder:SetAttribute("Aviso", "Copias para animar. O jogo nao usa esta pasta: pode ser apagada.")

	local teamId = Config.TeamOrder[1]
	local colour = Config.Teams[teamId].color
	local x = 0
	local function place(model: Model, width: number)
		model:PivotTo(CFrame.new(x + width / 2, 5, 0))
		model.Parent = folder
		x += width + 6
	end

	place(holding("Tocha", "tocha", colour), 4)
	place(holding("BombaFumo", "fumo", colour), 4)
	place(holding("VelaRomana", "vela", colour), 4)

	-- O tambor: como a pega do Tool, deitado a tiracolo, soldado a mao.
	local drummer = dummy("Tambor")
	local drumHand = Material.handOf(drummer) :: BasePart
	local drumModel = Instance.new("Model")
	drumModel.Name = "Bombo"
	local handle = Material.drum(drumModel, colour)
	handle.CFrame = drumHand.CFrame * Material.DRUM_GRIP:Inverse()
	for _, p in drumModel:GetChildren() do
		if p:IsA("BasePart") and p ~= handle then
			-- A pele ja vem soldada a pega (WeldConstraint): vai com ela.
			p.CFrame = handle.CFrame * CFrame.new(1.4, 0, 0)
		end
	end
	local drumWeld = Instance.new("Weld")
	drumWeld.Part0 = drumHand
	drumWeld.Part1 = handle
	drumWeld.C0 = Material.DRUM_GRIP:Inverse()
	drumWeld.Parent = handle
	drumModel.Parent = drummer
	place(drummer, 6)

	-- A bandeira grande e a bandeirinha: o rig com juntas, na mao do boneco.
	local flagger = dummy("Bandeira")
	Rigs.flag(flagger, "mastro", teamId)
	place(flagger, 16)
	local small = dummy("Bandeirinha")
	Rigs.flag(small, "bandeirinha", teamId)
	place(small, 6)

	-- O cachecol ao pescoco.
	local scarfed = dummy("Cachecol")
	Material.wearScarf(scarfed, colour)
	place(scarfed, 4)

	-- A faixa: a barra (a peca que o jogo move) com o pano, e dois bonecos nas pontas.
	local faixa = Instance.new("Model")
	faixa.Name = "Faixa"
	local bar = Instance.new("Part")
	bar.Name = "Banner"
	bar.Size = Vector3.new(26, 5, 0.6)
	bar.Transparency = 1
	bar.Anchored = true
	bar.CanCollide = false
	bar.CFrame = CFrame.new(0, 3, 0)
	bar.Parent = faixa
	faixa.PrimaryPart = bar
	Rigs.faixa(faixa, bar, teamId)
	for _, sideSign in { -1, 1 } do
		local holder = dummy("Segura")
		holder:PivotTo(CFrame.new(sideSign * 13.6, 3, 0.9))
		holder.Parent = faixa
	end
	place(faixa, 30)

	folder.Parent = ServerStorage
	return folder
end

return Modelos
