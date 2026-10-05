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
local TXT = Config.Text.lider
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

-- O que cada lider ja deu neste jogo, e quantas vezes mandou acender.
local given: { [Player]: number } = {}
local lit: { [Player]: number } = {}
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

-- Quantas vezes pode mandar ACENDER num jogo: cresce com o nivel.
function Lider.lightBudget(player: Player): number
	local level = if deps then deps.level(player) else 1
	local t = math.clamp((level - 1) / math.max(Config.Progress.maxLevel - 1, 1), 0, 1)
	return math.floor(L.lights.base + (L.lights.max - L.lights.base) * t + 0.5)
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
	-- Small and only from close, like every floating label (Config.Labels).
	gui.Size = UDim2.fromScale(Config.Labels.width * 0.7, Config.Labels.height * 1.6)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = Config.Labels.distance
	gui.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 0.72, 0)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.Text = TXT.capo
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

-- `club`: another claque's farda (the admin bar); by default the player's own.
function Lider.dress(player: Player, club: any?)
	local character = player.Character
	local teamId = Teams.get(player)
	local claque = club or (if teamId then Config.Teams[teamId] else nil)
	if not character or not claque or character:FindFirstChild("Farda") then
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
		shell("Cachecol", head, band, CFrame.new(0, -s.Y * 0.2, 0), claque.color, folder)
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
	formar = TXT.theCapoCalledFormUp,
	saltar = TXT.theCapoCalledJump,
	acender = TXT.theCapoCalledLightUp,
	farda = TXT.theCapoCalledUniformOn,
	agachar = TXT.theCapoCalledCrouchEverybody,
	bracos = TXT.theCapoCalledSwayYour,
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
			-- Uma ordem do lider: andar so a pausa (Poses.client), nao a acaba.
			player:SetAttribute("EmoteUntil", workspace:GetServerTimeNow() + L.jumpSeconds)
			task.delay(L.jumpSeconds, function()
				if player:GetAttribute("Emote") == "saltar" then
					player:SetAttribute("Emote", nil)
				end
			end)
		end
	elseif order == "agachar" or order == "bracos" then
		if not player:GetAttribute("Riding") then
			local emote = if order == "agachar" then "agachado" else "balancar"
			player:SetAttribute("Emote", emote)
			player:SetAttribute("EmoteUntil", workspace:GetServerTimeNow() + L.jumpSeconds)
			task.delay(L.jumpSeconds, function()
				if player:GetAttribute("Emote") == emote then
					player:SetAttribute("Emote", nil)
				end
			end)
		end
	elseif order == "acender" then
		task.spawn(function()
			local lit = Gear.lightNow(player)
			if not lit then
				Remotes.Lider:FireClient(player, { kind = "aviso", text = TXT.youHaveNoFlaresOr })
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
		tell(leader, TXT.thatPersonIsNotIn)
		return
	end
	-- A bandeira do mastro nao se gasta: e so uma, e muda de mao.
	if kind == "mastro" then
		Gear.setMastro(teamId, target)
		Remotes.Lider:FireClient(target, { kind = "aviso", text = TXT.theCapoPickedYouTo })
		tell(leader, target.DisplayName .. TXT.nowWavesThePoleFlag)
		return
	end
	if left(leader) <= 0 then
		tell(leader, TXT.youHaveGivenAllYou)
		return
	end
	given[leader] = (given[leader] or 0) + 1
	local names = { tocha = TXT.aFlare, fumo = TXT.aSmoke, bandeira = TXT.theBigFlag, faixa = TXT.theBanner }
	if kind == "faixa" then
		March.grantHold(target)
	else
		Gear.give(target, kind, 1)
		Gear.sync(target)
	end
	Remotes.Lider:FireClient(target, { kind = "aviso", text = TXT.theCapoGaveYou .. names[kind] .. "!" })
	tell(leader, TXT.youGave .. names[kind] .. TXT.to .. target.DisplayName .. ".")
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
			local song = L.canticos[index] :: any
			if index >= 1 and song and (song.club == nil or song.club == Config.Teams[teamId].club) then
				folder:SetAttribute("Musica_" .. teamId, index .. ":" .. workspace:GetServerTimeNow())
				notice(teamId, TXT.theCapoPutOn .. L.canticos[index].name, nil)
				tell(player, TXT.playing .. L.canticos[index].name)
			else
				folder:SetAttribute("Musica_" .. teamId, nil)
				tell(player, TXT.musicStopped)
			end
		end
		return
	end

	-- ACENDER tem o seu proprio limite: poucas vezes por jogo, conforme o nivel.
	if order == "acender" then
		local used = lit[player] or 0
		if used >= Lider.lightBudget(player) then
			tell(player, TXT.youHaveCalledLightUp .. used .. TXT.timesThisMatchLevelUp)
			return
		end
		local key = teamId .. ":acender"
		if os.clock() < (nextOrder[key] or 0) then
			tell(player, TXT.theFlaresAreStillBurning)
			return
		end
		nextOrder[key] = os.clock() + L.lightCooldown
		lit[player] = used + 1
		botOrder(teamId, "Acender", L.lightSeconds)
		invite(player, teamId, "acender")
		local rest = Lider.lightBudget(player) - lit[player]
		tell(player, TXT.flaresUp .. rest .. (if rest == 1 then TXT.moreTime else TXT.moreTimes))
		return
	end

	if not ready(teamId, order) then
		tell(player, TXT.waitAFewSecondsBefore)
		return
	end

	if order == "formar" then
		if not March.isActive() then
			tell(player, TXT.youOnlyFormUpBefore)
			return
		end
		if not March.form(teamId) then
			tell(player, TXT.theUltrasHaveAlreadyFormed)
			return
		end
		formSlot[teamId] = 0
		invite(player, teamId, "formar")
		tell(player, TXT.theUltrasAreFormingUp)
	elseif order == "marchar" then
		if not March.launch(teamId) then
			tell(player, TXT.theCorteoHasAlreadyLeft)
			return
		end
		notice(teamId, TXT.theCorteoIsAboutTo, player)
		tell(player, TXT.theCorteoLeavesAfterThe)
	elseif order == "saltar" then
		botOrder(teamId, "Saltar", L.jumpSeconds)
		invite(player, teamId, "saltar")
		tell(player, TXT.theUltrasJump)
	elseif order == "agachar" or order == "bracos" then
		-- As coreografias: a bancada inteira ao mesmo tempo, ao ritmo do tambor.
		botOrder(teamId, if order == "agachar" then "Agachar" else "Bracos", L.jumpSeconds)
		invite(player, teamId, order)
		tell(player, if order == "agachar" then TXT.theUltrasCrouch else TXT.theUltrasSwayTheirArms)
	elseif order == "farda" then
		botOrder(teamId, "Farda", nil)
		invite(player, teamId, "farda")
		Lider.dress(player)
		tell(player, TXT.theUltrasPutTheUniform)
	end
end

--------------------------------------------------------------------------------

-- Dia de jogo novo: o material volta a contar do zero, e as fardas saem.
function Lider.newMatch()
	table.clear(given)
	table.clear(lit)
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
		lit[player] = nil
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
