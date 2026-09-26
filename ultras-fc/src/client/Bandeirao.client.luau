--!strict
--[[
	O bandeirao, neste ecra.

	Quando o lider da a ordem (atributo "Bandeirao_<equipa>" da pasta Stadium,
	com a hora do servidor), o pano desenrola-se do rolo, no cimo da curva,
	de cima para baixo, por cima das cabecas: fila a fila, cada bocado dobra
	para baixo a partir da beira de cima, e o rolo vai descendo a frente dele.
	Tapa o bloco inteiro, ondula como se a claque o empurrasse por baixo, fica
	`hold` segundos e volta a enrolar.

	O desenho e o emblema da claque (TifoDesigns), pintado nos bocados. O pano
	e um pouco translucido: as tochas acesas por baixo veem-se a brilhar
	atraves dele.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BP = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BandeiraoPlan"))
local TifoDesigns = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TifoDesigns"))

local B = Config.Lider.bandeirao
local TOTAL = B.unroll + B.hold + B.rollup
local AWAY = CFrame.new(0, -600, 0)

type Panel = { part: BasePart, c: number, j: number, h: number, top: CFrame }
type Show = {
	teamId: string,
	start: number,
	folder: Folder,
	panels: { Panel },
	roll: { BasePart },
}

local shows: { [string]: Show } = {}

local function piece(name: string, size: Vector3, colour: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.Fabric
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = AWAY
	p.Parent = parent
	return p
end

-- O rolo do mapa (Workspace.Estadio) esconde-se enquanto o pano esta fora.
local function showMapRoll(teamId: string, on: boolean)
	local estadio = workspace:FindFirstChild("Estadio")
	local roll = estadio and estadio:FindFirstChild("Bandeirao_" .. teamId)
	if roll then
		for _, part in roll:GetChildren() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = if on then 0 else 1
			end
		end
	end
end

local function finish(teamId: string)
	local show = shows[teamId]
	if show then
		show.folder:Destroy()
		shows[teamId] = nil
	end
	showMapRoll(teamId, true)
end

local function build(teamId: string, start: number)
	finish(teamId)
	local team = Config.Teams[teamId]
	if not team then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Bandeirao_" .. teamId
	local lines = TifoDesigns.rows({ emblem = true }, teamId)
	local panels: { Panel } = {}
	for j = 1, BP.rows do
		for c = 1, BP.columns do
			local tl = BP.point(teamId, BP.tAt(c - 1), BP.sAt(j - 1))
			local tr = BP.point(teamId, BP.tAt(c), BP.sAt(j - 1))
			local bl = BP.point(teamId, BP.tAt(c - 1), BP.sAt(j))
			local br = BP.point(teamId, BP.tAt(c), BP.sAt(j))
			local topMid = (tl + tr) / 2
			local down = (bl + br) / 2 - topMid
			local across = tr - tl
			local x = across.Unit
			local y = -down.Unit
			local code = TifoDesigns.sample(lines, j, c, BP.rows, BP.columns)
			local part = piece("Pano", Vector3.new(across.Magnitude * 1.08, down.Magnitude * 1.1, 0.1), TifoDesigns.colour(code, teamId), folder)
			-- Um pouco translucido: a luz das tochas por baixo passa.
			part.Transparency = 0.14
			table.insert(panels, { part = part, c = c, j = j, h = down.Magnitude, top = CFrame.fromMatrix(topMid, x, y) })
		end
	end
	local roll: { BasePart } = {}
	for i = 1, BP.ROLL_PIECES do
		local p = piece("Rolo", Vector3.new(4, BP.ROLL_THICK, BP.ROLL_THICK), if i % 2 == 0 then team.color else Color3.fromRGB(236, 236, 232), folder)
		p.Shape = Enum.PartType.Cylinder
		table.insert(roll, p)
	end
	folder.Parent = workspace
	shows[teamId] = { teamId = teamId, start = start, folder = folder, panels = panels, roll = roll }
	showMapRoll(teamId, false)
end

local function check(stadium: Instance, teamId: string)
	local start = stadium:GetAttribute("Bandeirao_" .. teamId)
	if type(start) == "number" and workspace:GetServerTimeNow() - start < TOTAL then
		local show = shows[teamId]
		if not show or show.start ~= start then
			build(teamId, start)
		end
	end
end

local stadium = workspace:WaitForChild("Stadium")
for _, teamId in Config.TeamOrder do
	stadium:GetAttributeChangedSignal("Bandeirao_" .. teamId):Connect(function()
		check(stadium, teamId)
	end)
	check(stadium, teamId)
end

local parts: { BasePart } = {}
local frames: { CFrame } = {}

RunService.RenderStepped:Connect(function()
	if next(shows) == nil then
		return
	end
	local serverNow = workspace:GetServerTimeNow()
	local t = os.clock()
	table.clear(parts)
	table.clear(frames)
	for teamId, show in shows do
		local e = serverNow - show.start
		if e >= TOTAL or e < -1 then
			finish(teamId)
			continue
		end
		-- Quanto do pano esta em baixo: 0 enrolado, 1 todo aberto.
		local progress = if e < B.unroll
			then math.max(e, 0) / B.unroll
			elseif e < B.unroll + B.hold then 1
			else 1 - (e - B.unroll - B.hold) / B.rollup
		-- Com uma curva suave: comeca devagar, acelera, e poisa.
		progress = progress * progress * (3 - 2 * progress)
		local front = progress * BP.rows

		for _, panel in show.panels do
			local k = math.clamp(front - (panel.j - 1), 0, 1)
			table.insert(parts, panel.part)
			if k <= 0 then
				table.insert(frames, AWAY)
			else
				-- Ainda a desenrolar: dobrado para tras sobre a beira de cima.
				local fold = (1 - k) * 2.8
				-- Aberto: a claque empurra-o por baixo, e ele ondula.
				local wave = k * (math.sin(t * 2.1 + panel.c * 0.45 + panel.j * 0.7) * 0.35 + math.sin(t * 3.3 + panel.c * 0.9 - panel.j * 0.4) * 0.12)
				table.insert(frames, panel.top * CFrame.new(0, 0, wave) * CFrame.Angles(fold, 0, 0) * CFrame.new(0, -panel.h / 2, 0))
			end
		end

		-- O rolo vai a frente do pano: desce com ele e volta a subir.
		local s = BP.sAt(math.clamp(front, 0, BP.rows))
		for i, pieceAt in BP.roll(teamId, s, BP.ROLL_PIECES) do
			local p = show.roll[i]
			if p then
				p.Size = Vector3.new(pieceAt.length, BP.ROLL_THICK * (1 - 0.55 * progress), BP.ROLL_THICK * (1 - 0.55 * progress))
				table.insert(parts, p)
				table.insert(frames, pieceAt.cf * CFrame.Angles(t * 3 * (if e < B.unroll then 1 else -1), 0, 0))
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
