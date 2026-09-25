--!strict
--[[
	A sede da claque, e tudo o que la se faz.

	A sede deixa de ser cenario e passa a ser o inicio do jogo: e la que se
	escolhe o lado, se arranja material e se espera pelos outros. Um ecra a
	perguntar "que equipa?" mal se entra resolvia o mesmo em dois cliques, e
	perdia a unica coisa que faz isto um jogo de claques — ires ter com ela.

	Tudo por ProximityPrompt: e a forma do Roblox de dizer "chega-te aqui e
	carrega", e nao precisa de interface nenhuma.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Budget = require(script.Parent:WaitForChild("Budget"))
local Teams = require(script.Parent:WaitForChild("Teams"))
local Referee = require(script.Parent:WaitForChild("Referee"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Clubhouse = {}

local onStartMarch: ((string) -> ())? = nil
local counters: { [string]: Part } = {}

function Clubhouse.onStartMarch(fn: (string) -> ())
	onStartMarch = fn
end

local function fixture(name: string, size: Vector3, cf: CFrame, colour: Color3, parent: Instance): Part
	Budget.take("Cidade")
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

--[[
	Um letreiro flutuante, visivel atraves de tudo e de qualquer distancia.

	Sem isto, tirar o painel de escolha deixou as pessoas no meio da rua sem
	saberem para onde ir. Um mundo so funciona como menu se os sitios se virem
	de longe.
]]
local function marker(host: BasePart, text: string, colour: Color3, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Marker"
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 1200
	gui.Parent = host

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = colour
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(10, 12, 16)
	label.Parent = gui

	-- Um feixe a subir, para se localizar mesmo com predios pelo meio.
	local beam = Instance.new("Part")
	beam.Name = "Beacon"
	beam.Size = Vector3.new(2, 200, 2)
	beam.CFrame = host.CFrame * CFrame.new(0, 100, 0)
	beam.Color = colour
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.82
	beam.Anchored = true
	beam.CanCollide = false
	beam.CastShadow = false
	beam.Parent = host
end

local function prompt(host: BasePart, action: string, object: string, distance: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.35
	p.MaxActivationDistance = distance
	p.RequiresLineOfSight = false
	p.Parent = host
	return p
end

-- Quantos da claque estao na sede, prontos a sair.
local function readyCount(teamId: string, at: Vector3): number
	local total = 0
	for _, player in Players:GetPlayers() do
		if Teams.get(player) == teamId then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - at).Magnitude <= 40 then
				total += 1
			end
		end
	end
	return total
end

--[[
	Quantos tem de estar prontos para o lider poder sair: os do Config, ou a
	claque inteira se for mais pequena. Uma claque de dois nunca juntava tres.
]]
local function readyNeeded(teamId: string): number
	return math.max(math.min(Config.March.readyNeeded, Teams.count(teamId)), 1)
end

--[[
	Monta uma sede: balcao de inscricao, o tambor no seu suporte, e a porta por
	onde o corteo sai. `pivot` e o centro do chao da sede, com a porta para o
	seu +Z: a sede pode estar em qualquer sitio do mapa, virada para qualquer
	lado, e o recheio vai com ela.
]]
function Clubhouse.equip(teamId: string, pivot: CFrame, parent: Instance, front: number?, staffed: boolean?)
	-- A que distancia do centro fica a frente (a porta): depende do tamanho da sede.
	local reach = front or 17
	local team = Config.Teams[teamId]
	local centre = pivot.Position

	--[[
		Onde fica cada botao. Os blocos sao para quem faz o mapa: se dentro da
		sede houver uma peca com este nome (feita no Studio), o botao vai para
		ela; senao fica no sitio de sempre, preso a uma peca invisivel.
		  Balcao  — "Entrar" na claque
		  Tambor  — "Pegar" no tambor (passa a lider)
		  Porta   — "Sair em corteo"
	]]
	local function spot(name: string, size: Vector3, cf: CFrame): BasePart
		local own = parent:FindFirstChild(name, true)
		if own and own:IsA("BasePart") then
			return own
		end
		local holder = fixture(name, size, cf, team.color, parent)
		holder.Transparency = 1
		holder.CanCollide = false
		holder.CastShadow = false
		return holder
	end

	-- Balcao: e aqui que se entra na claque.
	local desk = spot("Balcao", Vector3.new(10, 3.5, 2.5), pivot * CFrame.new(-12, 1.75, -6))
	local join = prompt(desk, "Entrar", "Claque do " .. team.name, 12)
	-- Com NPCs nas mesas, sao eles que inscrevem e que dao o tambor.
	join.Enabled = not staffed

	-- O letreiro vai no portao, que e o que se ve da rua.

	join.Triggered:Connect(function(player)
		if Teams.get(player) == teamId then
			return
		end
		Teams.assign(player, teamId)
	end)

	-- Tochas e fumos nao se vao buscar: estao na barra desde que se entra na
	-- claque (Gear).

	--[[
		O tambor, no seu suporte. Quem o tira fica lider — e enquanto nao o
		largar mais ninguem pode ser. E dai que vem a autoridade: nao de um
		titulo, de ser o unico a ter o tambor.
	]]
	local stand = spot("Tambor", Vector3.new(3, 3.4, 3), pivot * CFrame.new(0, 1.7, -10))
	local takeDrum = prompt(stand, "Pegar", "Tambor da claque", 10)

	takeDrum.Triggered:Connect(function(player)
		if Teams.get(player) ~= teamId then
			return
		end
		-- Passar a lider poe o tambor na barra (Gear ouve o Teams).
		if Teams.claimLeader(player) then
			takeDrum.Enabled = false
		end
	end)

	-- A porta. So o lider a abre, e so com gente suficiente atras dele.
	local door = spot("Porta", Vector3.new(12, 6, 1.5), pivot * CFrame.new(0, 3, reach))
	local start = prompt(door, "Sair em corteo", "So o lider", 14)
	marker(door, "SEDE  ·  " .. string.upper(team.name), team.color, 22)

	start.Triggered:Connect(function(player)
		if not Teams.isLeader(player) or Teams.get(player) ~= teamId then
			return
		end
		if readyCount(teamId, centre) < readyNeeded(teamId) then
			return
		end
		if onStartMarch then
			onStartMarch(teamId)
		end
	end)

	-- Quadro com a contagem, para se perceber do que se esta a espera.
	local board = fixture("Board", Vector3.new(9, 3, 0.4), pivot * CFrame.new(0, 8, reach - 0.8), Color3.fromRGB(28, 30, 36), parent)
	counters[teamId] = board

	local sign = Instance.new("SurfaceGui")
	sign.Face = Enum.NormalId.Front
	sign.CanvasSize = Vector2.new(600, 200)
	sign.Parent = board

	local text = Instance.new("TextLabel")
	text.Name = "Count"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(240, 240, 240)
	text.Text = "0 / " .. readyNeeded(teamId)
	text.Parent = sign

	task.spawn(function()
		while board.Parent do
			task.wait(1)
			local ready = readyCount(teamId, centre)
			local needed = readyNeeded(teamId)
			local leader = Teams.leader(teamId)
			-- O lider saiu do jogo: o tambor volta ao suporte para outro o pegar.
			takeDrum.Enabled = leader == nil and not staffed
			text.Text = string.format(
				"%d / %d prontos\n%s",
				ready,
				needed,
				leader and ("lider: " .. leader.DisplayName) or "sem lider"
			)
			text.TextColor3 = (ready >= needed and leader)
					and Color3.fromRGB(120, 220, 150)
				or Color3.fromRGB(240, 240, 240)
		end
	end)
end

--------------------------------------------------------------------------------
-- Os NPCs das mesas
--------------------------------------------------------------------------------

local SKIN = Color3.fromRGB(214, 176, 140)

-- O que o NPC diz, no ecra de quem falou com ele.
local function say(player: Player, title: string, lines: { string })
	Remotes.Npc:FireClient(player, { title = title, lines = lines })
end

-- Uma pessoa parada, com o titulo por cima: os NPCs das mesas e os dealers.
local function person(shirt: Color3, name: string, title: string, at: CFrame, parent: Instance): BasePart?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = SKIN
	description.TorsoColor = shirt
	description.LeftArmColor = shirt
	description.RightArmColor = shirt
	description.LeftLegColor = Color3.fromRGB(28, 30, 36)
	description.RightLegColor = Color3.fromRGB(28, 30, 36)
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Clubhouse] NPC nao nasceu:", result)
		return nil
	end
	local model = result :: Model
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	root.Anchored = true
	-- De pe no chao: a anca a altura certa acima do ponto dado.
	model:PivotTo(at * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	model.Parent = parent

	-- O titulo por cima da cabeca, para se saber de longe para que e cada mesa.
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(200, 40)
	tag.StudsOffset = Vector3.new(0, 3.4, 0)
	tag.MaxDistance = 80
	tag.Parent = root
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(245, 245, 245)
	text.TextStrokeTransparency = 0.3
	text.Text = title
	text.Parent = tag
	return root
end

local function staffMember(teamId: string, name: string, title: string, at: CFrame, parent: Instance): BasePart?
	return person(Config.Teams[teamId].color, name, title, at, parent)
end

--[[
	Os dealers: vendem pirotecnia na rua, a troco de moedas do jogo. Quem
	compra e o Main (Remotes.Shop); aqui so ha a pessoa e o botao, e a lista
	de onde estao, para o servidor confirmar que quem compra esta ao pe de um.
]]
local dealers: { BasePart } = {}

function Clubhouse.dealer(at: CFrame, parent: Instance)
	local root = person(Color3.fromRGB(38, 40, 46), "Dealer", "DEALER", at, parent)
	if not root then
		return
	end
	table.insert(dealers, root)
	local p = prompt(root, "Comprar", "Tochas, fumos, velas, estrobos", 10)
	p.Triggered:Connect(function(player)
		Remotes.Shop:FireClient(player, "open")
	end)
end

function Clubhouse.nearDealer(at: Vector3): boolean
	for _, root in dealers do
		if root.Parent and (root.Position - at).Magnitude <= 16 then
			return true
		end
	end
	return false
end

--[[
	As tres mesas da sede, cada uma com o seu NPC atras, virado para quem
	entra. Da esquerda para a direita, para quem entra: inscricao, loja,
	lider. `desks` vem ja por essa ordem; `inward` e o sentido de quem entra.
]]
function Clubhouse.staff(teamId: string, desks: { Model }, inward: Vector3, parent: Instance)
	local team = Config.Teams[teamId]
	local roles = {
		{ id = "inscricao", title = "INSCRICAO" },
		{ id = "loja", title = "LOJA" },
		{ id = "lider", title = "LIDER" },
	}
	for i, desk in desks do
		local role = roles[i]
		if not role then
			break
		end
		local box, size = desk:GetBoundingBox()
		local floor = box.Position.Y - size.Y / 2
		local depth = math.max(math.abs(size.X * inward.X), math.abs(size.Z * inward.Z)) / 2
		local spot = Vector3.new(box.Position.X, floor, box.Position.Z) + inward * (depth + 2.2)
		local at = CFrame.lookAt(spot, spot - inward)
		local root = staffMember(teamId, "NPC_" .. role.id, role.title, at, parent)
		if not root then
			continue
		end

		if role.id == "inscricao" then
			local p = prompt(root, "Entrar na claque", "Claque do " .. team.name, 10)
			p.Triggered:Connect(function(player)
				if Teams.get(player) ~= teamId then
					Teams.assign(player, teamId)
				end
				say(player, "Bem-vindo a claque do " .. team.name, {
					"Na tua barra: 1 tocha, 2 fumo, 3 cachecol (e 4 tambor, se fores lider). Clica para acender.",
					"G animacoes  ·  Ctrl trancar a camara  ·  B pedir ao arbitro  ·  espaco saltar",
					"Antes do jogo sai-se daqui em corteo ate ao estadio, atras da faixa e do lider.",
					"No estadio a claque fica no topo atras da baliza: salta, canta, acende, e empurra a equipa.",
				})
			end)
		elseif role.id == "loja" then
			local p = prompt(root, "Ver a loja", "Tochas, fumos, cachecois, bandeiras", 10)
			p.Triggered:Connect(function(player)
				say(player, "Loja da claque", {
					"A claque da-te a racao de cada jogo: 2 tochas, 1 fumo e 1 estrobo, que ja estao na tua barra.",
					"Mais do que isso, e as velas romanas, compra-se aos dealers na rua, com moedas.",
					"Ganhas moedas a ir aos jogos com a claque, a fazer o corteo e com cada golo da equipa.",
				})
			end)
		else
			local p = prompt(root, "Ser o lider", "Claque do " .. team.name, 10)
			p.Triggered:Connect(function(player)
				if Teams.get(player) ~= teamId then
					say(player, "Lider da claque", { "Primeiro inscreve-te na claque, na mesa da inscricao." })
				elseif Teams.isLeader(player) then
					say(player, "Ja es o lider", {
						"Bate o tambor (4) ao ritmo: a bancada salta mais e o ambiente sobe.",
						"Em breve aqui: desenhar o tifo e marcar encontros para o corteo.",
					})
				elseif Teams.claimLeader(player) then
					say(player, "Es o lider da claque", {
						"Tens o tambor (4): bate ao ritmo para a bancada saltar.",
						"Com gente suficiente na sede, abre o corteo na porta: a faixa vai a tua frente, por onde andares.",
						"Em breve aqui: desenhar o tifo e marcar encontros para o corteo.",
					})
				else
					local leader = Teams.leader(teamId)
					say(player, "A claque ja tem lider", { (if leader then leader.DisplayName else "Alguem") .. " e o lider. Quando sair, o lugar fica livre." })
				end
			end)
		end
	end
end

--[[
	O posto de arbitragem, na praca.

	Fica fora das duas sedes de proposito: quem apita nao e de nenhum lado, e
	tem de se ver isso no sitio onde se pega no apito.
]]
function Clubhouse.refereePost(centre: Vector3, parent: Instance)
	local booth = fixture("RefereePost", Vector3.new(8, 8, 6), CFrame.new(centre.X, 4, centre.Z), Color3.fromRGB(40, 44, 52), parent)

	local sign = Instance.new("SurfaceGui")
	sign.Face = Enum.NormalId.Front
	sign.CanvasSize = Vector2.new(400, 400)
	sign.Parent = booth

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.Text = "ARBITRAGEM"
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(236, 200, 96)
	text.Parent = sign

	marker(booth, "ARBITRAGEM", Color3.fromRGB(236, 200, 96), 14)

	local take = prompt(booth, "Pegar no apito", "Arbitrar o jogo", 12)
	take.Triggered:Connect(function(player)
		Referee.take(player)
	end)
end

return Clubhouse
