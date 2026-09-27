--!strict
--[[
	O bandeirao, neste ecra.

	Quando o lider da a ordem (atributo "Bandeirao_<equipa>" da pasta Stadium,
	com a hora do servidor), monta-se o rig do bandeirao (BandeiraoRig) e ele
	desce do rolo, no cimo da curva, de cima para baixo, por cima das cabecas.
	Tapa o bloco inteiro, ondula, fica `hold` segundos e volta a enrolar.

	Com a animacao "bandeirao" feita (Config.Animations), e ela que mexe o
	pano; sem ela, o jogo desdobra-o fila a fila (BandeiraoRig.pose).

	O desenho e o emblema da claque. O pano e um pouco translucido: as tochas
	acesas por baixo veem-se a brilhar atraves dele.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BP = require(Shared:WaitForChild("BandeiraoPlan"))
local BandeiraoRig = require(Shared:WaitForChild("BandeiraoRig"))
local Animacoes = require(Shared:WaitForChild("Animacoes"))

local B = Config.Lider.bandeirao
local TOTAL = B.unroll + B.hold + B.rollup
local AWAY = CFrame.new(0, -600, 0)

type Show = {
	teamId: string,
	start: number,
	model: Model,
	rig: BandeiraoRig.Rig,
	roll: { BasePart },
	anim: AnimationTrack?,
}

local shows: { [string]: Show } = {}

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
		if show.anim then
			show.anim:Stop()
		end
		show.model:Destroy()
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
	local model = Instance.new("Model")
	model.Name = "Bandeirao_" .. teamId
	local rig = BandeiraoRig.build(model, teamId)
	-- Comeca enrolado.
	BandeiraoRig.pose(rig, 0, 0)

	local roll: { BasePart } = {}
	for i = 1, BP.ROLL_PIECES do
		local p = Instance.new("Part")
		p.Name = "Rolo"
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(4, BP.ROLL_THICK, BP.ROLL_THICK)
		p.Color = if i % 2 == 0 then team.color else Color3.fromRGB(236, 236, 232)
		p.Material = Enum.Material.Fabric
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = AWAY
		p.Parent = model
		table.insert(roll, p)
	end
	model.Parent = workspace

	local anim: AnimationTrack? = nil
	if Animacoes.has("bandeirao") then
		local controller = model:FindFirstChildOfClass("AnimationController")
		local animator = controller and controller:FindFirstChildOfClass("Animator")
		anim = animator and Animacoes.track(animator, "bandeirao")
		if anim then
			BandeiraoRig.pose(rig, BP.rows, 0) -- tudo a vista; a animacao manda
			anim.Looped = false
			Animacoes.play(anim, "bandeirao")
		end
	end

	shows[teamId] = { teamId = teamId, start = start, model = model, rig = rig, roll = roll, anim = anim }
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
		progress = progress * progress * (3 - 2 * progress)

		if not show.anim then
			BandeiraoRig.pose(show.rig, progress * show.rig.rows, t)
		end

		-- O rolo vai a frente do pano: desce com ele e volta a subir.
		local s = BP.sAt(math.clamp(progress * BP.rows, 0, BP.rows))
		for i, pieceAt in BP.roll(teamId, s, BP.ROLL_PIECES) do
			local p = show.roll[i]
			if p then
				p.Size = Vector3.new(pieceAt.length, BP.ROLL_THICK * (1 - 0.55 * progress), BP.ROLL_THICK * (1 - 0.55 * progress))
				table.insert(parts, p)
				table.insert(frames, pieceAt.cf)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
