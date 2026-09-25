--!strict
--[[
	O dinheiro do jogo (moedas). So se ganha a jogar — ir ao jogo com a
	claque, fazer o corteo, ver a equipa marcar — e so se gasta nos dealers,
	em pirotecnia. Nao ha Robux nenhum aqui.

	Fica guardado entre sessoes (DataStore). No Studio sem acesso as APIs, ou
	se o Roblox falhar, joga-se na mesma com o dinheiro da sessao e nada se
	perde a meio do jogo: so nao fica guardado.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Money = {}

local M = Config.Money

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("UltrasFC_Moedas_v1")
	end)
	if ok then
		store = result
	end
end

local balance: { [Player]: number } = {}
local loaded: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function publish(player: Player)
	player:SetAttribute("Moedas", balance[player] or 0)
end

function Money.get(player: Player): number
	return balance[player] or 0
end

function Money.add(player: Player, amount: number)
	if amount <= 0 or not player.Parent then
		return
	end
	balance[player] = (balance[player] or 0) + math.floor(amount)
	dirty[player] = true
	publish(player)
end

-- Paga, se chegar. Devolve se pagou.
function Money.spend(player: Player, amount: number): boolean
	local have = balance[player] or 0
	if have < amount then
		return false
	end
	balance[player] = have - amount
	dirty[player] = true
	publish(player)
	return true
end

local function load(player: Player)
	local saved: number? = nil
	local s = store
	if s then
		local ok, value = pcall(function()
			return s:GetAsync(key(player))
		end)
		if ok and type(value) == "number" then
			saved = value
		end
	end
	balance[player] = saved or M.start
	loaded[player] = true
	publish(player)
end

local function save(player: Player)
	local s = store
	if not s or not loaded[player] or not dirty[player] then
		return
	end
	local value = balance[player] or 0
	local ok = pcall(function()
		s:SetAsync(key(player), value)
	end)
	if ok then
		dirty[player] = nil
	end
end

function Money.start()
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		balance[player] = nil
		loaded[player] = nil
		dirty[player] = nil
	end)

	-- De minuto a minuto, e ao fechar o servidor.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				save(player)
			end
		end
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)
end

return Money
