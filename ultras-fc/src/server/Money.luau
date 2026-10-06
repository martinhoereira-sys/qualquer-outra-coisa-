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
	-- A club for each thing I am (each one kept between sessions; they may be the same club):
	club: string?, -- the club I am an ULTRA of (its claque is mine)
	second: string?, -- the FIRST club I play for (it comes first for a place in its team)
	second2: string?, -- the SECOND club I play for (a place at kick-off, if one is free)
	referee: string?, -- my club as a REFEREE (I never referee its matches)
	since: number?, -- when I joined my club (os.time)
	cameFrom: string?, -- the rival I left for this club (kept for ever)
	traitor: number?, -- matches left as a traitor (Config.Traitor)
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
	player:SetAttribute("Clube", if p then p.club else nil)
	player:SetAttribute("Clube2", if p then p.second else nil)
	player:SetAttribute("Clube3", if p then p.second2 else nil)
	player:SetAttribute("ClubeArbitro", if p then p.referee else nil)
	player:SetAttribute("ClubeDesde", if p then p.since else nil)
	player:SetAttribute("VeioDe", if p then p.cameFrom else nil)
	player:SetAttribute("Traidor", if p then p.traitor else nil)
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
	if type(value.club) == "string" and (Config.Clubs :: any)[value.club] then
		p.club = value.club
	end
	if type(value.second) == "string" and (Config.Clubs :: any)[value.second] then
		p.second = value.second
	end
	if type(value.second2) == "string" and (Config.Clubs :: any)[value.second2] and value.second2 ~= p.second then
		p.second2 = value.second2
	end
	-- (A referee is of the match, of no club: a club saved for it before is dropped.)
	if p.club and type(value.since) == "number" then
		p.since = value.since
	end
	if type(value.cameFrom) == "string" and (Config.Clubs :: any)[value.cameFrom] then
		p.cameFrom = value.cameFrom
	end
	if type(value.traitor) == "number" and value.traitor > 0 then
		p.traitor = math.floor(value.traitor)
	end
	-- The rival of my club is never one of my clubs.
	if Config.isRival(p.club, p.second) then
		p.second = nil
	end
	if Config.isRival(p.club, p.second2) or Config.isRival(p.second, p.second2) then
		p.second2 = nil
	end
	if Config.isRival(p.club, p.referee) or Config.isRival(p.second, p.referee) or Config.isRival(p.second2, p.referee) then
		p.referee = nil
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
				-- A club chosen in the first seconds, before the saved profile
				-- arrived, is kept too (where the saved one has none).
				if temp.club and not real.club and not Config.isRival(temp.club, real.second) and not Config.isRival(temp.club, real.referee) then
					real.club = temp.club
					real.since = temp.since
					dirty[player] = true
				end
				if temp.second and not real.second and not Config.isRival(temp.second, real.club) and not Config.isRival(temp.second, real.referee) then
					real.second = temp.second
					dirty[player] = true
				end
				if temp.second2 and not real.second2 and temp.second2 ~= real.second and not Config.isRival(temp.second2, real.club) and not Config.isRival(temp.second2, real.second) then
					real.second2 = temp.second2
					dirty[player] = true
				end
				if temp.referee and not real.referee and not Config.isRival(temp.referee, real.club) and not Config.isRival(temp.referee, real.second) then
					real.referee = temp.referee
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
		-- My club, the one I follow, and since when: kept between sessions.
		club = p.club,
		second = p.second,
		second2 = p.second2,
		referee = p.referee,
		since = p.since,
		cameFrom = p.cameFrom,
		traitor = p.traitor,
		version = p.version,
	}
	-- "Nothing to save" is said BEFORE writing: whatever changes while the
	-- write is on its way marks it again, and is saved the next time. (It used
	-- to be cleared after the write, and a choice made meanwhile was lost.)
	dirty[player] = nil
	local ok = retry(function()
		return s:UpdateAsync(key(player), function()
			return snapshot
		end)
	end)
	if not ok and profiles[player] == p then
		dirty[player] = true
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

-- My club (one only) and the second club I follow. `nil` clears the second.
function Money.setClub(player: Player, clubId: string)
	local p = profiles[player]
	if not p or not (Config.Clubs :: any)[clubId] then
		return
	end
	if p.club ~= clubId or not p.since then
		p.since = os.time()
	end
	p.club = clubId
	if Config.isRival(clubId, p.second) then
		p.second = nil
	end
	if Config.isRival(clubId, p.second2) then
		p.second2 = nil
	end
	if Config.isRival(clubId, p.referee) then
		p.referee = nil
	end
	dirty[player] = true
	publish(player)
	-- A club is not left waiting for the next minute's save: it is written now.
	task.spawn(save, player)
end

function Money.setSecond(player: Player, clubId: string?)
	local p = profiles[player]
	if not p or (clubId ~= nil and (not (Config.Clubs :: any)[clubId] or Config.isRival(clubId, p.club) or Config.isRival(clubId, p.referee) or Config.isRival(clubId, p.second2))) then
		return
	end
	p.second = clubId
	if p.second2 == clubId then
		p.second2 = nil -- (it has become the first)
	end
	dirty[player] = true
	publish(player)
	-- A club is not left waiting for the next minute's save: it is written now.
	task.spawn(save, player)
end

-- I have just left `from` for its rival: a traitor for Config.Traitor.matches matches.
function Money.markTraitor(player: Player, from: string)
	local p = profiles[player]
	if not p then
		return
	end
	p.cameFrom = from
	p.traitor = Config.Traitor.matches
	dirty[player] = true
	publish(player)
	-- A club is not left waiting for the next minute's save: it is written now.
	task.spawn(save, player)
end

-- A match I was at has ended: one less as a traitor.
function Money.traitorTick(player: Player)
	local p = profiles[player]
	if not p or not p.traitor then
		return
	end
	p.traitor = if p.traitor > 1 then p.traitor - 1 else nil
	dirty[player] = true
	publish(player)
end

-- The second club I play for (nil takes it away). Never the same as the first, never a rival of one of mine.
function Money.setSecond2(player: Player, clubId: string?)
	local p = profiles[player]
	if not p then
		return
	end
	if clubId ~= nil and (not (Config.Clubs :: any)[clubId] or clubId == p.second or Config.isRival(clubId, p.club) or Config.isRival(clubId, p.second) or Config.isRival(clubId, p.referee)) then
		return
	end
	p.second2 = clubId
	dirty[player] = true
	publish(player)
	-- A club is not left waiting for the next minute's save: it is written now.
	task.spawn(save, player)
end

function Money.second2Of(player: Player): string?
	local p = profiles[player]
	return if p then p.second2 else nil
end

-- My club as a referee.
function Money.setReferee(player: Player, clubId: string)
	local p = profiles[player]
	if not p or not (Config.Clubs :: any)[clubId] or Config.isRival(clubId, p.club) or Config.isRival(clubId, p.second) or Config.isRival(clubId, p.second2) then
		return
	end
	p.referee = clubId
	dirty[player] = true
	publish(player)
	-- A club is not left waiting for the next minute's save: it is written now.
	task.spawn(save, player)
end

function Money.refereeOf(player: Player): string?
	local p = profiles[player]
	return if p then p.referee else nil
end

function Money.clubOf(player: Player): (string?, string?)
	local p = profiles[player]
	return if p then p.club else nil, if p then p.second else nil
end

--[[
	ERASE MY PROFILE (an admin, on their own account only: who may call this
	is Main's business). Everything that is this player's goes from the
	DataStore: clubs, roles, levels, money, the traitor's mark. The player is
	left as if they had never joined. Nobody else, no table and no season is
	touched. Returns false if the DataStore refused.
]]
function Money.wipe(player: Player): boolean
	local s = store
	if s then
		local ok = retry(function()
			s:RemoveAsync(key(player))
			return true
		end)
		if not ok then
			return false
		end
		-- The coins of the old save too (a first join would bring them back).
		local old = oldStore
		if old then
			pcall(function()
				old:RemoveAsync(key(player))
			end)
		end
	end
	profiles[player] = newProfile(M.start)
	loaded[player] = true
	dirty[player] = true -- saved as a new profile
	publish(player)
	-- A club is not left waiting for the next minute's save: it is written now.
	task.spawn(save, player)
	return true
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
