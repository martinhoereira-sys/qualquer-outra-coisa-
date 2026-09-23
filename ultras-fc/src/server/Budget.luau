--!strict
--[[
	O travao das pecas.

	Cada parte do jogo que cria pecas tem um maximo (Config.Performance). Se o
	passar, para de construir e escreve no Output — um ciclo que se enganasse
	nas contas e criasse pecas sem fim pendurava o Studio, e num telemovel
	fechava o jogo. Mais vale um estadio a meio e um aviso do que isso.

	Como se usa:
		Budget.run("Cidade", City.build, root) -- corre a construcao com travao
		Budget.take("Cidade") -- dentro de cada helper que cria uma peca

	Quando `take` passa do maximo, a construcao inteira dessa parte para ali
	mesmo, por muitos ciclos encaixados que haja. As pecas que vem e vao durante
	o jogo (cartolinas, bonecos) devolvem-se com `give` quando saem.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Budget = {}

local LIMITS = Config.Performance.maxParts

-- O sinal de paragem. Uma tabela so nossa, para nao se confundir com um erro a
-- serio, que continua a subir como qualquer outro.
local STOP = table.freeze({})

local counts: { [string]: number } = {}
local warned: { [string]: boolean } = {}

local function limitFor(section: string): number
	return LIMITS[section] or LIMITS.default
end

-- Reserva `amount` pecas; devolve false (e avisa uma vez) se passar do maximo.
function Budget.try(section: string, amount: number?): boolean
	local n = (counts[section] or 0) + (amount or 1)
	if n > limitFor(section) then
		if not warned[section] then
			warned[section] = true
			warn(string.format(
				"[Ultras FC] %s chegou ao maximo de %d pecas (Config.Performance). Parei de construir.",
				section,
				limitFor(section)
			))
		end
		return false
	end
	counts[section] = n
	return true
end

-- Igual, mas para a construcao ali mesmo se passar do maximo. So dentro de `run`.
function Budget.take(section: string, amount: number?)
	if not Budget.try(section, amount) then
		error(STOP, 0)
	end
end

-- Pecas que sairam do jogo: cartolinas recolhidas, bonecos que deram o lugar.
function Budget.give(section: string, amount: number)
	counts[section] = math.max((counts[section] or 0) - amount, 0)
end

-- Corre uma construcao com travao. Devolve false se tiver parado a meio.
function Budget.run(section: string, fn: (...any) -> (), ...: any): boolean
	local ok, err = pcall(fn, ...)
	if ok then
		return true
	end
	if err == STOP then
		return false
	end
	error(err, 0)
end

function Budget.count(section: string): number
	return counts[section] or 0
end

-- Quantas pecas ha em cada parte, para o Output.
function Budget.report()
	local names = {}
	for section in counts do
		table.insert(names, section)
	end
	table.sort(names)

	local total = 0
	local lines = {}
	for _, section in names do
		total += counts[section]
		table.insert(lines, string.format("%s %d/%d", section, counts[section], limitFor(section)))
	end
	print(string.format("[Ultras FC] Pecas: %s  (total %d)", table.concat(lines, ", "), total))
end

-- Pecas dentro de um modelo, para contar um boneco inteiro de uma vez.
function Budget.partsIn(model: Instance): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return Budget
