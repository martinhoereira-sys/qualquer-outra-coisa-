--!strict
--[[
	O perfil de cada pessoa, guardado entre sessoes: os Escudos (o dinheiro do
	jogo), o XP dos tres caminhos (adepto, jogador, arbitro), as escolhas
	(numero da camisola, posicao, botas) e a recompensa diaria.

	Continua a chamar-se Money porque o resto do jogo (loja, caixas) ja fala
	com ele: Money.get / add / spend sao os Escudos.

	Nada disto se perde:
	- carrega-se com tentativas (e espera a crescer entre elas);
	- se nao carregar, joga-se com um perfil provisorio que NUNCA se grava por
	  cima do verdadeiro; continua-se a tentar, e quando o verdadeiro chega
	  soma-se-lhe o que se ganhou entretanto;
	- grava-se ao sair, ao fechar o servidor e de minuto a minuto, sempre com
	  UpdateAsync e tentativas.

	Quem ja tinha moedas (a loja antiga, UltrasFC_Moedas_v1) comeca com elas.
	No Studio sem acesso as APIs joga-se na mesma, so nao fica guardado.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Money = {}

local M = Config.Money

export type Profile = {
	escudos: number,
	xp: { adepto: number, jogador: number, arbitro: number },
	prefs: { number: number?, position: string?, boots: number? },
	daily: { day: number, streak: number },
	version: number,
}

local function newProfile(escudos: number): Profile
	return {
		escudos = escudos,
		xp = { adepto = 0, jogador = 0, arbitro = 0 },
		prefs = {},
		daily = { day = 0, streak = 0 },
		version = 1,
	}
end

local function getStore(name: string): DataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	return if ok then result else nil
end

local store = getStore("UltrasFC_Perfil_v1")
local oldStore = getStore("UltrasFC_Moedas_v1")

local profiles: { [Player]: Profile } = {}
local loaded: { [Player]: boolean } = {} -- o verdadeiro chegou (pode-se gravar)
local dirty: { [Player]: boolean } = {}
local onChanged: ((Player) -> ())? = nil
local onLoaded: ((Player) -> ())? = nil

local function key(player: Player): string
	return "u_" .. player.UserId
end

-- Os admins (Config.Admins) tem escudos sem fim, para testar a loja.
local function unlimited(player: Player): boolean
	return table.find(Config.Admins, player.UserId) ~= nil
end

local function publish(player: Player)
	local p = profiles[player]
	player:SetAttribute("Moedas", if p then p.escudos else 0)
	player:SetAttribute("MoedasInfinitas", if unlimited(player) then true else nil)
	if onChanged then
		onChanged(player)
	end
end

-- Uma chamada a DataStore, com tentativas e espera a crescer (1, 2, 4 s).
local function retry<T>(fn: () -> T): (boolean, T?)
	local wait = 1
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(string.format("[Ultras FC] DataStore falhou (tentativa %d): %s", attempt, tostring(result)))
		if attempt < 3 then
			task.wait(wait)
			wait *= 2
		end
	end
	return false, nil
end

-- Le um perfil guardado, completando o que faltar (versoes antigas).
local function fromSaved(value: any): Profile?
	if type(value) ~= "table" then
		return nil
	end
	local p = newProfile(if type(value.escudos) == "number" then value.escudos else M.start)
	if type(value.xp) == "table" then
		for _, path in { "adepto", "jogador", "arbitro" } do
			local v = value.xp[path]
			if type(v) == "number" then
				(p.xp :: any)[path] = math.max(0, math.floor(v))
			end
		end
	end
	if type(value.prefs) == "table" then
		p.prefs.number = if type(value.prefs.number) == "number" then value.prefs.number else nil
		p.prefs.position = if type(value.prefs.position) == "string" then value.prefs.position else nil
		p.prefs.boots = if type(value.prefs.boots) == "number" then value.prefs.boots else nil
	end
	if type(value.daily) == "table" and type(value.daily.day) == "number" and type(value.daily.streak) == "number" then
		p.daily = { day = value.daily.day, streak = value.daily.streak }
	end
	return p
end

--[[
	Carrega. Sem DataStore (Studio sem API), fica o provisorio e nao se grava.
	Se a DataStore existir mas falhar, continua a tentar de 30 em 30 s.
]]
local function load(player: Player)
	-- O provisorio: comeca a zero, para nao se gastar o que ainda nao se sabe se ha.
	profiles[player] = newProfile(0)
	publish(player)
	local s = store
	if not s then
		profiles[player] = newProfile(M.start)
		-- Sem DataStore (Studio sem API): joga-se com este, so nao se grava.
		loaded[player] = true
		publish(player)
		if onLoaded then
			onLoaded(player)
		end
		return
	end
	while player.Parent do
		local ok, value = retry(function()
			return s:GetAsync(key(player))
		end)
		if ok then
			local saved = fromSaved(value)
			if not saved then
				-- Primeira vez com o perfil novo: traz as moedas antigas, se houver.
				local start = M.start
				local old = oldStore
				if old then
					local okOld, coins = retry(function()
						return old:GetAsync(key(player))
					end)
					if okOld and type(coins) == "number" then
						start = coins
					end
				end
				saved = newProfile(start)
				dirty[player] = true
			end
			-- O que se ganhou com o provisorio soma-se ao verdadeiro.
			local temp = profiles[player]
			local real = saved :: Profile
			if temp then
				real.escudos += math.max(temp.escudos, 0)
				real.xp.adepto += temp.xp.adepto
				real.xp.jogador += temp.xp.jogador
				real.xp.arbitro += temp.xp.arbitro
				if temp.escudos ~= 0 or temp.xp.adepto + temp.xp.jogador + temp.xp.arbitro > 0 then
					dirty[player] = true
				end
			end
			profiles[player] = real
			loaded[player] = true
			publish(player)
			if onLoaded then
				onLoaded(player)
			end
			return
		end
		warn("[Ultras FC] Perfil de " .. player.Name .. " nao carregou; a jogar com um provisorio, volto a tentar.")
		task.wait(30)
	end
end

-- Grava (so se o verdadeiro foi carregado e ha mudancas).
local function save(player: Player)
	local s = store
	local p = profiles[player]
	if not s or not p or not loaded[player] or not dirty[player] then
		return
	end
	local snapshot = {
		escudos = p.escudos,
		xp = { adepto = p.xp.adepto, jogador = p.xp.jogador, arbitro = p.xp.arbitro },
		prefs = { number = p.prefs.number, position = p.prefs.position, boots = p.prefs.boots },
		daily = { day = p.daily.day, streak = p.daily.streak },
		version = p.version,
	}
	local ok = retry(function()
		return s:UpdateAsync(key(player), function()
			return snapshot
		end)
	end)
	if ok then
		dirty[player] = nil
	end
end

--------------------------------------------------------------------------------
-- Escudos
--------------------------------------------------------------------------------

function Money.get(player: Player): number
	local p = profiles[player]
	return if p then p.escudos else 0
end

function Money.add(player: Player, amount: number)
	local p = profiles[player]
	if amount <= 0 or not p or not player.Parent then
		return
	end
	p.escudos += math.floor(amount)
	dirty[player] = true
	publish(player)
end

-- Paga, se chegar. Devolve se pagou.
function Money.spend(player: Player, amount: number): boolean
	if unlimited(player) then
		return true
	end
	local p = profiles[player]
	if not p or p.escudos < amount then
		return false
	end
	p.escudos -= amount
	dirty[player] = true
	publish(player)
	return true
end

--[[
	Enviar Escudos a outra pessoa (os multibancos). Conta sempre o saldo a
	serio, mesmo para quem tem moedas sem fim: senao um admin fabricava
	dinheiro para os outros. Os dois perfis tem de estar carregados, para nada
	se perder a meio.
]]
function Money.transfer(from: Player, to: Player, amount: number): boolean
	local a, b = profiles[from], profiles[to]
	amount = math.floor(amount)
	if from == to or amount <= 0 or not a or not b or not loaded[from] or not loaded[to] then
		return false
	end
	if a.escudos < amount then
		return false
	end
	a.escudos -= amount
	b.escudos += amount
	dirty[from] = true
	dirty[to] = true
	publish(from)
	publish(to)
	return true
end

--------------------------------------------------------------------------------
-- O resto do perfil (o Progress e quem mexe no XP)
--------------------------------------------------------------------------------

function Money.profile(player: Player): Profile?
	return profiles[player]
end

function Money.isLoaded(player: Player): boolean
	return loaded[player] == true
end

function Money.addXP(player: Player, path: string, amount: number)
	local p = profiles[player]
	if not p or amount <= 0 then
		return
	end
	local xp = p.xp :: any
	if type(xp[path]) ~= "number" then
		return
	end
	xp[path] += math.floor(amount)
	dirty[player] = true
	publish(player)
end

function Money.setPref(player: Player, name: string, value: any)
	local p = profiles[player]
	if not p then
		return
	end
	(p.prefs :: any)[name] = value
	dirty[player] = true
	publish(player)
end

function Money.setDaily(player: Player, day: number, streak: number)
	local p = profiles[player]
	if not p then
		return
	end
	p.daily = { day = day, streak = streak }
	dirty[player] = true
end

function Money.onChanged(fn: (Player) -> ())
	onChanged = fn
end

function Money.onLoaded(fn: (Player) -> ())
	onLoaded = fn
end

function Money.start()
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		loaded[player] = nil
		dirty[player] = nil
	end)

	-- De minuto a minuto, e ao fechar o servidor (todos ao mesmo tempo).
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return Money
