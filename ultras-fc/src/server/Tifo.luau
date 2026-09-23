--!strict
--[[
	Os tifos.

	Um mosaico de cartolinas por cima do bloco da claque. O lider escolhe o
	desenho e dispara; ha uns segundos de aviso, e depois cada um levanta a
	cartolina do seu lugar. O desenho so aparece inteiro se toda a gente
	levantar: o lugar de quem ficou parado e um buraco que se ve do outro lado
	do campo.

	A bancada a volta dos jogadores levanta sozinha — sem isso, com meia duzia
	de pessoas no servidor, o desenho era so buracos. Mas o que faz o ambiente
	subir a serio sao os jogadores que levantam, e o momento em que o lider
	disparou.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Budget = require(script.Parent:WaitForChild("Budget"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local TifoDesigns = require(Shared:WaitForChild("TifoDesigns"))
local Teams = require(script.Parent:WaitForChild("Teams"))
local Stadium = require(script.Parent:WaitForChild("Stadium"))
local Crowd = require(script.Parent:WaitForChild("Crowd"))

local Tifo = {}

local T = Config.Tifo
local S = Config.Stadium

local INNER_X = S.pitchLength / 2 + S.standGap -- frente dos topos, onde estao as claques
local RAKE = math.sqrt(S.rowHeight ^ 2 + S.rowDepth ^ 2) -- degrau medido ao longo da inclinacao

type Cell = { col: number, row: number } -- fila 1 e a de cima, vista do relvado

type Active = {
	teamId: string,
	name: string,
	grid: { { Color3 } },
	strong: boolean,
	raiseAt: number,
	lowerAt: number,
	holders: { [Player]: Cell },
	lifted: { [Player]: boolean },
	folder: Folder?,
}

local active: { [string]: Active } = {}
local used: { [string]: number } = {}
local kickoffAt = -math.huge
local goalAt: { [string]: number } = {}
local playing = false
local root: Instance? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

-- O desenho em cores, fila a fila, pronto a pintar as cartolinas.
local function gridFor(design: any, teamId: string): { { Color3 } }
	local rows = TifoDesigns.rows(design, teamId)
	local grid = {}
	for r = 1, T.rows do
		grid[r] = {}
		local line = rows[r] or ""
		for c = 1, T.columns do
			grid[r][c] = TifoDesigns.colour(string.sub(line, c, c), teamId)
		end
	end
	return grid
end

--------------------------------------------------------------------------------
-- A grelha em cima da bancada
--------------------------------------------------------------------------------

local function columnWidth(): number
	return Stadium.claqueHalfWidth() * 2 / T.columns
end

--[[
	Onde fica cada cartolina. A coluna 1 e a da esquerda de quem olha do
	relvado, e a fila 1 a de cima. As cartolinas deitam-se na inclinacao da
	bancada: e assim que encostam umas as outras e fazem um plano so, que e o
	que as torna um desenho e nao um monte de quadrados.
]]
local function cellCFrame(teamId: string, cell: Cell): CFrame
	local side = Config.Teams[teamId].side
	local half = Stadium.claqueHalfWidth()

	-- Quem olha do relvado para o topo nascente tem a esquerda para -Z; para o
	-- poente, para +Z.
	local z = -side * (half - (cell.col - 0.5) * columnWidth())

	local standRow = T.firstRow + T.rows - cell.row
	local y = standRow * S.rowHeight + T.liftHeight
	local x = (INNER_X + (standRow - 0.5) * S.rowDepth) * side

	local centre = Vector3.new(x, y, z)
	local up = Vector3.new(S.rowDepth * side, S.rowHeight, 0).Unit
	return CFrame.lookAt(centre, centre + up)
end

local function makeCard(a: Active, cell: Cell)
	local folder = a.folder
	if not folder then
		return
	end

	Budget.take("Tifo")
	local card = Instance.new("Part")
	card.Name = "Card"
	card.Size = Vector3.new(columnWidth() - 0.12, 0.15, RAKE - 0.12)
	card.CFrame = cellCFrame(a.teamId, cell)
	card.Color = a.grid[cell.row][cell.col]
	card.Material = Enum.Material.SmoothPlastic
	card.Anchored = true
	card.CanCollide = false
	card.CanQuery = false
	card.CastShadow = false
	card.TopSurface = Enum.SurfaceType.Smooth
	card.BottomSurface = Enum.SurfaceType.Smooth
	card.Parent = folder
end

-- Em que lugar da grelha esta um jogador, se estiver no bloco da sua claque.
local function cellUnder(teamId: string, position: Vector3): Cell?
	local side = Config.Teams[teamId].side
	if position.X * side <= 0 then
		return nil
	end

	-- O bloco e as duas escadas que lhe servem de entrada.
	local half = Stadium.claqueHalfWidth()
	if math.abs(position.Z) > half + S.gangwayWidth then
		return nil
	end

	local standRow = math.ceil((math.abs(position.X) - INNER_X) / S.rowDepth)
	if standRow < 1 or standRow > S.rows then
		return nil
	end

	local col = math.clamp(math.floor((half + side * position.Z) / columnWidth()) + 1, 1, T.columns)
	local row = math.clamp(T.firstRow + T.rows - standRow, 1, T.rows)
	return { col = col, row = row }
end

-- Dois no mesmo lugar: o segundo fica com o lugar livre mais perto.
local function nearestFree(wanted: Cell, taken: { [string]: boolean }): Cell?
	local best: Cell? = nil
	local bestDistance = math.huge
	for r = 1, T.rows do
		for c = 1, T.columns do
			if not taken[c .. "," .. r] then
				local d = (c - wanted.col) ^ 2 + (r - wanted.row) ^ 2
				if d < bestDistance then
					best, bestDistance = { col = c, row = r }, d
				end
			end
		end
	end
	return best
end

--------------------------------------------------------------------------------
-- O momento
--------------------------------------------------------------------------------

--[[
	O tifo e para o apito inicial ou para logo a seguir a um golo nosso. Conta o
	momento em que o lider dispara: e essa a decisao que lhe cabe.
]]
function Tifo.isMoment(teamId: string): boolean
	local t = now()
	return t - kickoffAt <= T.momentWindow or t - (goalAt[teamId] or -math.huge) <= T.momentWindow
end

function Tifo.markKickoff()
	kickoffAt = now()
end

function Tifo.markGoal(teamId: string)
	goalAt[teamId] = now()
end

function Tifo.setPlaying(isPlaying: boolean)
	playing = isPlaying
end

--------------------------------------------------------------------------------

local function left(teamId: string): number
	return T.perMatch - (used[teamId] or 0)
end

local function broadcast(teamId: string)
	local a = active[teamId]
	Remotes.TifoState:FireAllClients({
		kind = "state",
		teamId = teamId,
		left = left(teamId),
		active = a ~= nil,
		name = a and a.name or nil,
		strong = a and a.strong or nil,
		raiseAt = a and a.raiseAt or nil,
		lowerAt = a and a.lowerAt or nil,
	})
end

local function raise(a: Active)
	if active[a.teamId] ~= a or not root then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Tifo_" .. a.teamId
	folder.Parent = root
	a.folder = folder

	local held: { [string]: boolean } = {}
	for _, cell in a.holders do
		held[cell.col .. "," .. cell.row] = true
	end

	-- A bancada levanta as suas; as dos jogadores so sobem quando eles quiserem.
	-- Com travao: passando do maximo de cartolinas, para e avisa no Output.
	Budget.run("Tifo", function()
		for r = 1, T.rows do
			for c = 1, T.columns do
				if not held[c .. "," .. r] then
					makeCard(a, { col = c, row = r })
				end
			end
		end
		for player, cell in a.holders do
			if a.lifted[player] then
				makeCard(a, cell)
			end
		end
	end)

	Crowd.setTifo(a.teamId, true)
end

local function lower(a: Active)
	if active[a.teamId] ~= a then
		return
	end
	if a.folder then
		Budget.give("Tifo", #a.folder:GetChildren())
		a.folder:Destroy()
	end
	Crowd.setTifo(a.teamId, false)
	active[a.teamId] = nil
	broadcast(a.teamId)
end

--[[
	O lider dispara. Da-se a cada um a cor do seu lugar ja agora, durante o
	aviso, para ter tempo de ver o que lhe calhou antes de levantar.
]]
function Tifo.launch(player: Player, designId: string): boolean
	local teamId = Teams.get(player)
	if not teamId or not Config.Teams[teamId] or not Teams.isLeader(player) then
		return false
	end
	if not playing or active[teamId] or left(teamId) <= 0 then
		return false
	end

	local design = TifoDesigns.byId(designId)
	if not design then
		return false
	end

	local t = now()
	local a: Active = {
		teamId = teamId,
		name = design.name,
		grid = gridFor(design, teamId),
		strong = Tifo.isMoment(teamId),
		raiseAt = t + T.countdown,
		lowerAt = t + T.countdown + T.duration,
		holders = {},
		lifted = {},
		folder = nil,
	}

	local taken: { [string]: boolean } = {}
	for _, other in Players:GetPlayers() do
		if Teams.get(other) == teamId then
			local character = other.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local wanted = hrp and cellUnder(teamId, hrp.Position)
			local cell = wanted and nearestFree(wanted, taken)
			if cell then
				taken[cell.col .. "," .. cell.row] = true
				a.holders[other] = cell
				Remotes.TifoState:FireClient(other, {
					kind = "card",
					teamId = teamId,
					colour = a.grid[cell.row][cell.col],
					raiseAt = a.raiseAt,
					lowerAt = a.lowerAt,
				})
			end
		end
	end

	active[teamId] = a
	used[teamId] = (used[teamId] or 0) + 1
	broadcast(teamId)

	task.delay(T.countdown, raise, a)
	task.delay(T.countdown + T.duration, lower, a)
	return true
end

-- Levantar a cartolina. Antes do tempo fica guardado e sobe com as outras.
function Tifo.lift(player: Player)
	local teamId = Teams.get(player)
	local a = teamId and active[teamId]
	if not a then
		return
	end

	local cell = a.holders[player]
	if not cell or a.lifted[player] then
		return
	end

	a.lifted[player] = true
	if a.folder then
		Budget.run("Tifo", makeCard, a, cell)
	end
end

--[[
	Quanto e que o tifo no ar empurra o ambiente por segundo.

	Metade vem da bancada, que levanta sempre; a outra metade e dos jogadores
	que levantaram. E tudo multiplicado pelo momento: no apito ou depois de um
	golo vale o dobro, a meio do jogo vale metade.
]]
function Tifo.heatFor(teamId: string): number
	local a = active[teamId]
	local t = now()
	if not a or t < a.raiseAt or t > a.lowerAt then
		return 0
	end

	local holders, lifted = 0, 0
	for player in a.holders do
		holders += 1
		if a.lifted[player] then
			lifted += 1
		end
	end
	local share = holders > 0 and lifted / holders or 0

	local timing = a.strong and T.momentMultiplier or T.offMomentMultiplier
	return T.gainPerSecond * timing * (T.crowdShare + (1 - T.crowdShare) * share) * Teams.minorityBonus(teamId)
end

-- Jogo novo, tifos novos.
function Tifo.refill()
	table.clear(used)
	for _, teamId in Config.TeamOrder do
		broadcast(teamId)
	end
end

-- Quem chega a meio tem de saber quantos tifos restam.
function Tifo.sync(player: Player)
	for _, teamId in Config.TeamOrder do
		local a = active[teamId]
		Remotes.TifoState:FireClient(player, {
			kind = "state",
			teamId = teamId,
			left = left(teamId),
			active = a ~= nil,
			name = a and a.name or nil,
			strong = a and a.strong or nil,
			raiseAt = a and a.raiseAt or nil,
			lowerAt = a and a.lowerAt or nil,
		})
	end
end

function Tifo.forget(player: Player)
	for _, a in active do
		a.holders[player] = nil
		a.lifted[player] = nil
	end
end

function Tifo.build(parent: Instance)
	root = parent
end

return Tifo
