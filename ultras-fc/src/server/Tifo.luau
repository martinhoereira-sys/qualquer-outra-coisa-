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
local Crowd = require(script.Parent:WaitForChild("Crowd"))

local Tifo = {}

local T = Config.Tifo
local S = Config.Stadium

local Plan = require(Shared:WaitForChild("StadiumPlan"))
local RAKE = math.sqrt(S.rowHeight ^ 2 + S.rowDepth ^ 2) -- degrau medido ao longo da inclinacao

type Cell = { col: number, row: number } -- fila 1 e a de cima, vista do relvado

type Active = {
	teamId: string,
	name: string,
	grid: { { Color3 } },
	lines: { string }, -- o desenho, na resolucao dele (a tela pinta-o todo)
	strong: boolean,
	raiseAt: number,
	lowerAt: number,
	holders: { [Player]: Cell },
	lifted: { [Player]: boolean },
	folder: Folder?,
	message: string?, -- uma frase por cima do mosaico, em letras gigantes
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
		for c = 1, T.columns do
			grid[r][c] = TifoDesigns.colour(TifoDesigns.sample(rows, r, c, T.rows, T.columns), teamId)
		end
	end
	return grid
end

--------------------------------------------------------------------------------
-- A grelha em cima da curva da claque
--------------------------------------------------------------------------------

--[[
	A grelha vai de ponta a ponta da curva da claque (StadiumPlan), nas filas
	do meio. Em t (0 a 1 ao longo da curva), a coluna 1 e a da esquerda de
	quem olha do relvado — que na curva e a ponta t = 1 — e a fila 1 a de cima.
]]
local T_FROM, T_TO = 0.07, 0.93

local function tOfColumn(col: number): number
	return T_TO - (col - 0.5) / T.columns * (T_TO - T_FROM)
end

-- Largura de uma cartolina nesta fila da bancada (a curva abre para tras).
local function cardWidth(standRow: number): number
	return (T_TO - T_FROM) / T.columns * (math.pi / 2) * Plan.rowRadius(standRow)
end

--[[
	Onde fica cada cartolina: deitada na inclinacao da bancada, a altura das
	maos levantadas. E assim que encostam umas as outras e fazem um plano so,
	que e o que as torna um desenho e nao um monte de quadrados.
]]
local function cellCFrame(teamId: string, cell: Cell): CFrame
	local cx, cz = Plan.claqueCorner(teamId)
	local standRow = T.firstRow + T.rows - cell.row
	local t = tOfColumn(cell.col)
	local centre = Plan.curvePoint(cx, cz, t, Plan.rowRadius(standRow), standRow * S.rowHeight + T.liftHeight)
	local out = Plan.dir(cx, cz, t)
	local up = (out * S.rowDepth + Vector3.new(0, S.rowHeight, 0)).Unit
	return CFrame.lookAt(centre, centre + up)
end

-- Em que lugar da grelha esta um jogador, se estiver na curva da sua claque.
local function cellUnder(teamId: string, position: Vector3): Cell?
	local standRow, t = Plan.inClaque(teamId, position)
	if not standRow or not t then
		return nil
	end
	local col = math.clamp(math.floor((T_TO - t) / (T_TO - T_FROM) * T.columns) + 1, 1, T.columns)
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

	--[[
		A tela: um papel pintado estendido por cima da claque, de ponta a ponta
		da curva, que ondula ao vento (cada ecra fa-la ondular: TifoWave.client).

		Na curva nao ha um plano so: a tela e feita de tiras ao alto, uma por
		coluna, cada uma virada para o relvado com o "cima" pela bancada acima.
		O desenho e a frase pintam-se por cima de todas, cada tira com o seu
		pedaco, e de la de baixo leem-se como uma tela so.
	]]
	local team = Config.Teams[a.teamId]
	local lines = a.lines
	local designRows = #lines
	local designCols = if designRows > 0 then #lines[1] else 0
	local text = if a.message then string.gsub(a.message, "%%TEAM%%", string.upper(team.name)) else nil
	local height = RAKE * T.rows + 0.6
	local PW = 100 -- pixeis de cada tira na largura
	local STRIPS = T.columns

	Budget.run("Tifo", function()
		for strip = 1, STRIPS do
			Budget.take("Tifo")
			local top = cellCFrame(a.teamId, { col = strip, row = 1 })
			local bottom = cellCFrame(a.teamId, { col = strip, row = T.rows })
			local width = cardWidth(T.firstRow + T.rows // 2) + 0.35 -- um pouco sobrepostas
			local normal = top.UpVector -- para fora da bancada, para o campo
			local upslope = top.LookVector -- pela bancada acima
			local viewerRight = upslope:Cross(normal)

			local tela = Instance.new("Part")
			tela.Name = "Tela"
			tela.Size = Vector3.new(width, height, 0.08)
			tela.CFrame = CFrame.fromMatrix((top.Position + bottom.Position) / 2 + normal * 0.3, -viewerRight, upslope, -normal)
			tela.Color = team.color
			tela.Material = Enum.Material.Fabric
			tela.Anchored = true
			tela.CanCollide = false
			tela.CanQuery = false
			tela.CastShadow = false
			tela:SetAttribute("Strip", strip)
			tela.Parent = folder

			local PH = math.floor(PW * height / width)
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			gui.CanvasSize = Vector2.new(PW, PH)
			gui.LightInfluence = 0.4
			gui.ClipsDescendants = true
			gui.Parent = tela

			-- O desenho: as colunas do desenho que caem nesta tira, em riscos
			-- verticais da mesma cor (menos pecas do que um quadrado por pixel).
			if designCols > 0 then
				local total = PW * STRIPS
				local colW = total / designCols
				local rowH = PH / designRows
				local fromCol = math.floor((strip - 1) * designCols / STRIPS) + 1
				local toCol = math.ceil(strip * designCols / STRIPS)
				for c = fromCol, toCol do
					local r = 1
					while r <= designRows do
						local code = string.sub(lines[r], c, c)
						local run = 1
						while r + run <= designRows and string.sub(lines[r + run], c, c) == code do
							run += 1
						end
						if code ~= "E" and code ~= "" then
							local cell = Instance.new("Frame")
							cell.BorderSizePixel = 0
							cell.BackgroundColor3 = TifoDesigns.colour(code, a.teamId)
							cell.Position = UDim2.fromOffset((c - 1) * colW - (strip - 1) * PW, (r - 1) * rowH)
							cell.Size = UDim2.fromOffset(colW + 1, run * rowH + 1)
							cell.Parent = gui
						end
						r += run
					end
				end
			end

			-- A frase, em letras gigantes por cima do desenho.
			if text then
				local total = PW * STRIPS
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromOffset(total * 0.94, PH * 0.9)
				label.Position = UDim2.fromOffset(-(strip - 1) * PW + total * 0.03, PH * 0.05)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamBlack
				label.TextScaled = true
				label.TextWrapped = true
				label.TextColor3 = Color3.fromRGB(245, 245, 240)
				label.TextStrokeTransparency = 0.2
				label.TextStrokeColor3 = Color3.fromRGB(20, 20, 24)
				label.Text = text
				label.ZIndex = 2
				label.Parent = gui
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
		lines = TifoDesigns.rows(design, teamId),
		strong = Tifo.isMoment(teamId),
		raiseAt = t + T.countdown,
		lowerAt = t + T.countdown + T.duration,
		holders = {},
		lifted = {},
		folder = nil,
		message = design.message,
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
