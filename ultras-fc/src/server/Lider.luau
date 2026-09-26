--!strict
--[[
	O LIDER (o capo).

	Na vida real e o tipo de costas para o campo, virado para a claque, a
	dirigir toda a gente. Aqui:

	- Por cima dele le-se LIDER na cor da claque, de longe (e atraves das
	  paredes): quem chega novo encontra-o sem perguntar a ninguem.
	- So ele tem as ordens (Lider.client mostra os botoes; aqui confirma-se
	  sempre que e mesmo o lider): FORMAR, MARCHAR, SALTAR, ACENDER, BANDEIRAO,
	  MUSICA, DAR MATERIAL e FARDA.

	A REGRA QUE NAO SE QUEBRA: o lider nunca obriga ninguem. Os bonecos
	obedecem sempre (atributos na pasta Workspace.Stadium, que cada ecra le);
	as pessoas recebem um aviso ("O lider mandou saltar — carrega E para
	entrar") e decidem. Quem ignora, fica como esta. O lider organiza, nao
	manda.

	O material que da e limitado por jogo e cresce com o nivel de adepto dele
	(Config.Lider.give): e isso que faz o nivel de lider valer alguma coisa.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Teams = require(script.Parent:WaitForChild("Teams"))
local Gear = require(script.Parent:WaitForChild("Gear"))
local March = require(script.Parent:WaitForChild("March"))

local L = Config.Lider

local Lider = {}

export type Deps = {
	level: (Player) -> number, -- o nivel de adepto
	phase: () -> string,
}

local deps: Deps? = nil
local bandeiraoHook: ((string) -> (boolean, string?))? = nil

-- O que cada lider ja deu neste jogo.
local given: { [Player]: number } = {}
-- Quando cada ordem pode voltar a ser dada, por claque.
local nextOrder: { [string]: number } = {}
-- Os avisos em aberto: quem foi convidado para qual ordem, e ate quando.
type Invite = { order: string, teamId: string, untilAt: number, taken: { [Player]: boolean } }
local invites: { [number]: Invite } = {}
local nextInviteId = 0

-- O bandeirao (etapa seguinte) regista-se aqui.
function Lider.setBandeirao(fn: (string) -> (boolean, string?))
	bandeiraoHook = fn
end

-- Quanto pode dar um lider deste nivel, num jogo.
function Lider.budget(player: Player): number
	local level = if deps then deps.level(player) else 1
	local t = math.clamp((level - 1) / math.max(Config.Progress.maxLevel - 1, 1), 0, 1)
	return math.floor(L.give.base + (L.give.max - L.give.base) * t + 0.5)
end

local function left(player: Player): number
	return math.max(Lider.budget(player) - (given[player] or 0), 0)
end

local function stadium(): Instance?
	return workspace:FindFirstChild("Stadium")
end

local function tell(player: Player, text: string, extra: { [string]: any }?)
	local data: { [string]: any } = { kind = "resposta", text = text, left = left(player), budget = Lider.budget(player) }
	if extra then
		for k, v in extra do
			data[k] = v
		end
	end
	Remotes.Lider:FireClient(player, data)
end

--------------------------------------------------------------------------------
-- O letreiro LIDER por cima da cabeca
--------------------------------------------------------------------------------

local function sign(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("LiderSinal")
	local teamId = Teams.get(player)
	if not Teams.isLeader(player) or not teamId then
		if old then
			old:Destroy()
		end
		return
	end
	if old then
		return
	end
	local colour = Config.Teams[teamId].color
	local gui = Instance.new("BillboardGui")
	gui.Name = "LiderSinal"
	-- Em pixeis: le-se do mesmo tamanho perto ou do outro lado do estadio.
	gui.Size = UDim2.fromOffset(150, 52)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 1500
	gui.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 0.72, 0)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.Text = "LÍDER"
	text.TextColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.15)
	text.TextStrokeColor3 = Color3.fromRGB(10, 10, 12)
	text.TextStrokeTransparency = 0
	text.Parent = gui
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Position = UDim2.fromScale(0, 0.68)
	arrow.Size = UDim2.fromScale(1, 0.32)
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextScaled = true
	arrow.Text = "▼"
	arrow.TextColor3 = text.TextColor3
	arrow.TextStrokeTransparency = 0
	arrow.Parent = gui
	gui.Parent = head
end

--------------------------------------------------------------------------------
-- A farda: casaco escuro por cima do corpo e o cachecol da claque na cara
--------------------------------------------------------------------------------

local JACKET_PARTS = {
	"UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
	"Torso", "Left Arm", "Right Arm",
}

local function shell(name: string, body: BasePart, size: Vector3, offset: CFrame, colour: Color3, parent: Instance)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.Fabric
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = body.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = body
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	p.Parent = parent
end

function Lider.dress(player: Player)
	local character = player.Character
	local teamId = Teams.get(player)
	if not character or not teamId or character:FindFirstChild("Farda") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Farda"
	for _, name in JACKET_PARTS do
		local body = character:FindFirstChild(name)
		if body and body:IsA("BasePart") then
			shell("Casaco", body, body.Size + Vector3.new(0.12, 0.06, 0.12), CFrame.identity, L.farda, folder)
		end
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local s = head.Size
		local band = Vector3.new(s.X * 1.08, s.Y * 0.32, s.Z * 1.08)
		shell("Cachecol", head, band, CFrame.new(0, -s.Y * 0.2, 0), Config.Teams[teamId].color, folder)
		shell("Risca", head, band * Vector3.new(1.01, 0.25, 1.01), CFrame.new(0, -s.Y * 0.2, 0), Color3.fromRGB(240, 240, 240), folder)
	end
	folder.Parent = character
	player:SetAttribute("Farda", true)
end

function Lider.undress(player: Player)
	player:SetAttribute("Farda", nil)
	local character = player.Character
	local farda = character and character:FindFirstChild("Farda")
	if farda then
		farda:Destroy()
	end
end

--------------------------------------------------------------------------------
-- Os avisos a claque (as pessoas decidem)
--------------------------------------------------------------------------------

local TEXTS = {
	formar = "O líder mandou FORMAR à porta da sede",
	saltar = "O líder mandou SALTAR",
	acender = "O líder mandou ACENDER as tochas",
	farda = "O líder mandou vestir a FARDA",
}

local function invite(leader: Player, teamId: string, order: string)
	nextInviteId += 1
	local id = nextInviteId
	invites[id] = { order = order, teamId = teamId, untilAt = os.clock() + L.inviteSeconds + 2, taken = {} }
	for _, player in Players:GetPlayers() do
		if player ~= leader and Teams.get(player) == teamId then
			Remotes.Lider:FireClient(player, { kind = "convite", id = id, order = order, text = TEXTS[order] or order })
		end
	end
	-- O proprio lider entra logo (foi ele que mandou).
	return id
end

local function notice(teamId: string, text: string, except: Player?)
	for _, player in Players:GetPlayers() do
		if player ~= except and Teams.get(player) == teamId then
			Remotes.Lider:FireClient(player, { kind = "aviso", text = text })
		end
	end
end

-- Um lugar na formatura para quem aceitou: as primeiras filas, atras da faixa.
local formSlot: { [string]: number } = {}
local function slotFor(teamId: string): Vector3?
	local folder = stadium() and (stadium() :: Instance):FindFirstChild("March")
	local banner = folder and folder:FindFirstChild("Banner_" .. teamId)
	if not banner or not banner:IsA("BasePart") then
		return nil
	end
	local n = formSlot[teamId] or 0
	formSlot[teamId] = n + 1
	local columns = Config.March.columns
	local spacing = banner.Size.X / columns
	local column = n % columns
	local row = n // columns
	-- Entre os bonecos: meio passo ao lado de cada lugar deles.
	local side = (column - (columns - 1) / 2) * spacing + spacing / 2
	return (banner.CFrame * CFrame.new(side, 0, 3 + row * 2.6 + 1.3)).Position
end

local function accept(player: Player, id: number)
	local entry = invites[id]
	if not entry or os.clock() > entry.untilAt or entry.taken[player] or Teams.get(player) ~= entry.teamId then
		return
	end
	entry.taken[player] = true
	local order = entry.order
	if order == "formar" then
		local spot = slotFor(entry.teamId)
		if spot then
			Remotes.Lider:FireClient(player, { kind = "ir", at = spot })
		end
	elseif order == "saltar" then
		if not player:GetAttribute("Riding") then
			player:SetAttribute("Emote", "saltar")
			task.delay(L.jumpSeconds, function()
				if player:GetAttribute("Emote") == "saltar" then
					player:SetAttribute("Emote", nil)
				end
			end)
		end
	elseif order == "acender" then
		task.spawn(function()
			local lit = Gear.lightNow(player)
			if not lit then
				Remotes.Lider:FireClient(player, { kind = "aviso", text = "Não tens tochas nem fumo: compra a um dealer." })
			end
		end)
	elseif order == "farda" then
		Lider.dress(player)
	end
end

--------------------------------------------------------------------------------
-- As ordens
--------------------------------------------------------------------------------

-- Os bonecos obedecem sempre: a claque le isto na pasta do estadio.
local function botOrder(teamId: string, name: string, seconds: number?)
	local folder = stadium()
	if folder then
		if seconds then
			folder:SetAttribute(name .. "_" .. teamId, workspace:GetServerTimeNow() + seconds)
		else
			folder:SetAttribute(name .. "_" .. teamId, true)
		end
	end
end

local function ready(teamId: string, order: string): boolean
	local key = teamId .. ":" .. order
	local now = os.clock()
	if now < (nextOrder[key] or 0) then
		return false
	end
	nextOrder[key] = now + L.cooldown
	return true
end

local function give(leader: Player, teamId: string, targetId: any, kind: any)
	if type(targetId) ~= "number" or type(kind) ~= "string" or not table.find(L.giveKinds, kind) then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target or Teams.get(target) ~= teamId then
		tell(leader, "Essa pessoa não é da claque.")
		return
	end
	if left(leader) <= 0 then
		tell(leader, "Já deste tudo o que podias neste jogo. Sobe de nível para dares mais.")
		return
	end
	given[leader] = (given[leader] or 0) + 1
	local names = { tocha = "uma tocha", fumo = "um fumo", bandeira = "a bandeira grande", faixa = "a faixa" }
	if kind == "faixa" then
		March.grantHold(target)
	else
		Gear.give(target, kind, 1)
		Gear.sync(target)
	end
	Remotes.Lider:FireClient(target, { kind = "aviso", text = "O líder deu-te " .. names[kind] .. "!" })
	tell(leader, "Deste " .. names[kind] .. " a " .. target.DisplayName .. ".")
end

local function onOrder(player: Player, order: any, a: any, b: any)
	local teamId = Teams.get(player)
	if type(order) ~= "string" or not teamId then
		return
	end
	if order == "aceitar" then
		if type(a) == "number" then
			accept(player, a)
		end
		return
	end
	if order == "pedir" then
		tell(player, "", { kind = "estado" })
		return
	end
	-- Daqui para baixo so o lider.
	if not Teams.isLeader(player) then
		return
	end

	if order == "dar" then
		give(player, teamId, a, b)
		return
	end
	if order == "musica" then
		local index = if type(a) == "number" then math.floor(a) else 0
		local folder = stadium()
		if folder then
			if index >= 1 and L.canticos[index] then
				folder:SetAttribute("Musica_" .. teamId, index .. ":" .. workspace:GetServerTimeNow())
				notice(teamId, "O líder pôs a tocar: " .. L.canticos[index].name, nil)
				tell(player, "A tocar: " .. L.canticos[index].name)
			else
				folder:SetAttribute("Musica_" .. teamId, nil)
				tell(player, "Música parada.")
			end
		end
		return
	end

	if not ready(teamId, order) then
		tell(player, "Espera uns segundos antes de repetir a ordem.")
		return
	end

	if order == "formar" then
		if not March.isActive() then
			tell(player, "Só se forma antes do cortejo, à porta da sede.")
			return
		end
		if not March.form(teamId) then
			tell(player, "A claque já formou (ou já saiu).")
			return
		end
		formSlot[teamId] = 0
		invite(player, teamId, "formar")
		tell(player, "A claque está a formar.")
	elseif order == "marchar" then
		if not March.launch(teamId) then
			tell(player, "O cortejo já saiu (ou ainda não é hora).")
			return
		end
		notice(teamId, "O cortejo vai arrancar: vai atrás da faixa!", player)
		tell(player, "O cortejo arranca depois da formatura.")
	elseif order == "saltar" then
		botOrder(teamId, "Saltar", L.jumpSeconds)
		invite(player, teamId, "saltar")
		tell(player, "A claque salta.")
	elseif order == "acender" then
		botOrder(teamId, "Acender", L.lightSeconds)
		invite(player, teamId, "acender")
		tell(player, "Tochas no ar!")
	elseif order == "farda" then
		botOrder(teamId, "Farda", nil)
		invite(player, teamId, "farda")
		Lider.dress(player)
		tell(player, "A claque veste a farda.")
	elseif order == "bandeirao" then
		local hook = bandeiraoHook
		if not hook then
			tell(player, "O bandeirão ainda não está pronto.")
			return
		end
		local ok, why = hook(teamId)
		tell(player, if ok then "O bandeirão está a descer!" else (why or "Agora não dá."))
	end
end

--------------------------------------------------------------------------------

-- Dia de jogo novo: o material volta a contar do zero, e as fardas saem.
function Lider.newMatch()
	table.clear(given)
	local folder = stadium()
	for _, player in Players:GetPlayers() do
		Lider.undress(player)
	end
	if folder then
		for _, teamId in Config.TeamOrder do
			folder:SetAttribute("Farda_" .. teamId, nil)
			folder:SetAttribute("Musica_" .. teamId, nil)
		end
	end
end

function Lider.start(d: Deps)
	deps = d
	Remotes.Lider.OnServerEvent:Connect(onOrder)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			task.wait(0.5)
			sign(player)
			-- A farda aguenta o jogo todo: volta ao renascer.
			if player:GetAttribute("Farda") then
				player:SetAttribute("Farda", nil)
				Lider.dress(player)
			end
		end)
		player:GetAttributeChangedSignal("Leader"):Connect(function()
			sign(player)
		end)
		player:GetAttributeChangedSignal("Team"):Connect(function()
			sign(player)
		end)
		sign(player)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		given[player] = nil
	end)

	-- Os avisos velhos saem.
	task.spawn(function()
		while true do
			task.wait(10)
			local now = os.clock()
			for id, entry in invites do
				if now > entry.untilAt then
					invites[id] = nil
				end
			end
		end
	end)
end

return Lider
