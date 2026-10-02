--!strict
--[[
	Os multibancos da cidade (os modelos com "ATM" no nome, postos no mapa):
	chega-se, carrega-se em TXT.atm, e abre-se o ecra (Banco.client) com
	o saldo e para enviar Escudos a outra pessoa que esteja no jogo.

	Tudo validado aqui: ao pe de um multibanco, a outra pessoa no jogo, o
	valor inteiro e dentro do limite, o saldo a serio (Money.transfer), e uma
	espera curta entre envios. Cada um fica a saber: quem envia e quem recebe.
]]

local Players = game:GetService("Players")
local TXT = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")).Text.bank
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Money = require(script.Parent:WaitForChild("Money"))

local Bank = {}

local MAX_SEND = 1000 -- por envio
local COOLDOWN = 4 -- segundos entre envios
local REACH = 14 -- a que distancia do multibanco se pode usar

local machines: { BasePart } = {}
local seen: { [Instance]: boolean } = {}
local lastSend: { [Player]: number } = {}

local function isMachine(inst: Instance): boolean
	return inst:IsA("Model") and string.find(string.upper(inst.Name), "ATM") ~= nil
end

local function addMachine(model: Model)
	if seen[model] then
		return
	end
	seen[model] = true
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end
	table.insert(machines, anchor)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = TXT.atm
	prompt.ActionText = TXT.atm
	prompt.ObjectText = TXT.sendMoney
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		Remotes.Banco:FireClient(player, { kind = "abrir" })
	end)
end

local function nearMachine(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, m in machines do
		if m.Parent and (m.Position - root.Position).Magnitude <= REACH then
			return true
		end
	end
	return false
end

local function reply(player: Player, ok: boolean, message: string)
	Remotes.Banco:FireClient(player, { kind = "resposta", ok = ok, message = message })
end

function Bank.start()
	for _, d in workspace:GetDescendants() do
		if isMachine(d) then
			addMachine(d :: Model)
		end
	end
	workspace.DescendantAdded:Connect(function(d)
		if isMachine(d) then
			task.defer(addMachine, d :: Model)
		end
	end)

	Remotes.Banco.OnServerEvent:Connect(function(player, action, targetId, amount)
		if action ~= "enviar" then
			return
		end
		if type(targetId) ~= "number" or type(amount) ~= "number" or amount ~= amount then
			return
		end
		local value = math.floor(amount)
		if not nearMachine(player) then
			reply(player, false, TXT.youHaveToBeNext)
			return
		end
		local now = os.clock()
		if now - (lastSend[player] or -math.huge) < COOLDOWN then
			reply(player, false, TXT.waitAFewSecondsBefore)
			return
		end
		if value < 1 or value > MAX_SEND then
			reply(player, false, TXT.youCanSendFrom1 .. MAX_SEND .. TXT.atATime)
			return
		end
		local target = Players:GetPlayerByUserId(targetId)
		if not target or target == player then
			reply(player, false, TXT.thatPersonIsNoLonger)
			return
		end
		lastSend[player] = now
		if Money.transfer(player, target, value) then
			reply(player, true, TXT.youSent .. value .. TXT.to .. target.DisplayName .. ".")
			Remotes.Banco:FireClient(target, { kind = "recebido", amount = value, from = player.DisplayName })
		else
			reply(player, false, TXT.youDoNotHaveEnough)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSend[player] = nil
	end)
end

return Bank
