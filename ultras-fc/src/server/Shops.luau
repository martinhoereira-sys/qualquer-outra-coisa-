--!strict
--[[
	As lojas da cidade: entrar e assaltar a caixa.

	As lojas sao modelos do mapa (a LojaConveniencia e as copias dela, onde
	quer que se ponham); aqui nao se constroi nada, so se da vida ao que la
	esta:

	- A porta automatica: um modelo "Door" com duas folhas de vidro, "Engine1"
	  e "Engine2". Chega alguem perto e as folhas abrem-se para os lados;
	  sai e fecham. (A porta veio do Toolbox com um script que foi tirado; esta
	  faz o mesmo sem codigo de fora.)
	- A caixa: cada "CashRegister" tem um botao para a assaltar (segurar uns
	  segundos). Da moedas, e fica vazia uns minutos.

	Tudo o que se copiar no Studio (mais lojas, mais caixas) funciona sozinho,
	pelo nome.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Money = require(script.Parent:WaitForChild("Money"))

local Shops = {}

local DOOR_REACH = 10 -- a esta distancia (do centro da porta) abre
local DOOR_TIME = 0.45
local ROB_HOLD = 3 -- segundos a segurar o botao
local ROB_MIN, ROB_MAX = 15, 35 -- moedas
local ROB_EMPTY = 300 -- segundos ate a caixa voltar a ter dinheiro

type Door = {
	centre: Vector3,
	leaves: { { part: BasePart, closed: CFrame, open: CFrame } },
	isOpen: boolean,
}

local doors: { Door } = {}
local seen: { [Instance]: boolean } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function addDoor(model: Model)
	local a = model:FindFirstChild("Engine1")
	local b = model:FindFirstChild("Engine2")
	if seen[model] or not a or not b or not a:IsA("BasePart") or not b:IsA("BasePart") then
		return
	end
	seen[model] = true
	local axis = flat(a.Position - b.Position)
	if axis.Magnitude < 0.1 then
		return
	end
	axis = axis.Unit
	-- Cada folha corre para o seu lado a largura dela.
	local function leaf(p: BasePart, sign: number)
		local along = math.max(math.abs(p.CFrame.RightVector:Dot(axis)) * p.Size.X, math.abs(p.CFrame.LookVector:Dot(axis)) * p.Size.Z)
		return { part = p, closed = p.CFrame, open = p.CFrame + axis * sign * (along * 0.95) }
	end
	table.insert(doors, {
		centre = (a.Position + b.Position) / 2,
		leaves = { leaf(a, 1), leaf(b, -1) },
		isOpen = false,
	})
end

local function addRegister(register: Instance)
	if seen[register] then
		return
	end
	local anchor = if register:IsA("BasePart") then register elseif register:IsA("Model") then (register.PrimaryPart or register:FindFirstChildWhichIsA("BasePart", true)) else nil
	if not anchor then
		return
	end
	seen[register] = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Assaltar"
	prompt.ActionText = "Assaltar a caixa"
	prompt.ObjectText = "Caixa"
	prompt.HoldDuration = ROB_HOLD
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		local role = player:GetAttribute("Team")
		if not prompt.Enabled or role == "jogador" or role == "arbitro" or player:GetAttribute("Riding") then
			return
		end
		local amount = math.random(ROB_MIN, ROB_MAX)
		Money.add(player, amount)
		prompt.Enabled = false
		Remotes.Npc:FireClient(player, {
			title = "Caixa assaltada",
			lines = {
				"Levaste " .. amount .. " moedas.",
				"Esta caixa fica vazia uns minutos. Ha mais lojas na cidade.",
			},
		})
		task.delay(ROB_EMPTY, function()
			if prompt.Parent then
				prompt.Enabled = true
			end
		end)
	end)
end

local function consider(d: Instance)
	if d:IsA("Model") and d.Name == "Door" then
		-- As pecas podem ainda estar a chegar (copias): espera um instante.
		task.defer(addDoor, d)
	elseif d.Name == "CashRegister" and (d:IsA("Model") or d:IsA("BasePart")) then
		task.defer(addRegister, d)
	end
end

local function setDoor(door: Door, open: boolean)
	door.isOpen = open
	local info = TweenInfo.new(DOOR_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, leaf in door.leaves do
		if leaf.part.Parent then
			TweenService:Create(leaf.part, info, { CFrame = if open then leaf.open else leaf.closed }):Play()
		end
	end
end

function Shops.start()
	for _, d in workspace:GetDescendants() do
		consider(d)
	end
	workspace.DescendantAdded:Connect(consider)

	task.spawn(function()
		while true do
			task.wait(0.2)
			if #doors == 0 then
				continue
			end
			local roots: { Vector3 } = {}
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					table.insert(roots, root.Position)
				end
			end
			for _, door in doors do
				local near = false
				for _, at in roots do
					if (at - door.centre).Magnitude < DOOR_REACH then
						near = true
						break
					end
				end
				if near ~= door.isOpen then
					setDoor(door, near)
				end
			end
		end
	end)
end

return Shops
