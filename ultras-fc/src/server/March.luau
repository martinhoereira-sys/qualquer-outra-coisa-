--!strict
--[[
	O corteo.

	A claque junta-se a porta da sede, sai em bloco e sobe a avenida ate ao
	estadio, a cantar pelo caminho. E a ideia central do jogo inteiro: nao se
	entra num estadio por magia, e a caminhada e a melhor parte.

	Como funciona: uma faixa sai da sede no aquecimento e anda a passo de pessoa
	ate a entrada. Quem a acompanha — quem vai perto dela enquanto ela anda —
	leva a bancada ja quente para o apito inicial. Quem la chega sozinho
	comeca do zero.

	E por isso que vale a pena andar: nao e decoracao, e vantagem.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Teams = require(script.Parent:WaitForChild("Teams"))
local City = require(script.Parent:WaitForChild("City"))

local March = {}

local M = Config.March

type Banner = {
	model: Part,
	waypoints: { Vector3 },
	leg: number,
	teamId: string,
}

local banners: { [string]: Banner } = {}
local credit: { [Player]: number } = {} -- 0 a 1: quanto do percurso acompanhou
local active = false
local root: Folder? = nil

function March.creditFor(player: Player): number
	return credit[player] or 0
end

function March.forget(player: Player)
	credit[player] = nil
end

--[[
	O percurso: sede, avenida, e a porta do topo da claque. Cada sede fica do
	lado do seu topo, por isso os dois corteos descem a avenida cada um para o
	seu lado e nunca se cruzam.
]]
local function routeFor(teamId: string): { Vector3 }
	local start = City.spawnPoint(teamId)
	if not start then
		return {}
	end

	local S = Config.Stadium
	local standDepth = S.rows * S.rowDepth
	local outerZ = S.pitchWidth / 2 + S.standGap + standDepth + 26
	local outerX = S.pitchLength / 2 + S.standGap + standDepth + 26
	local roadZ = outerZ + 70

	-- Por fora da muralha, rente ao topo da claque.
	local side = Config.Teams[teamId].side
	local flank = side * (outerX + 20)

	return {
		start,
		Vector3.new(start.X * 0.55, 3, roadZ), -- desce a rua ate a avenida
		Vector3.new(flank, 3, roadZ), -- segue a avenida ate a esquina do seu topo
		Vector3.new(side * (outerX + 10), 3, 0), -- a porta da claque
	}
end

local function buildBanner(teamId: string, at: Vector3, parent: Instance): Part
	local team = Config.Teams[teamId]

	local banner = Instance.new("Part")
	banner.Name = "Banner_" .. teamId
	banner.Size = Vector3.new(22, 5, 0.6)
	banner.CFrame = CFrame.new(at)
	banner.Color = team.color
	banner.Material = Enum.Material.Fabric
	banner.Anchored = true
	banner.CanCollide = false
	banner.Parent = parent

	local sign = Instance.new("SurfaceGui")
	sign.Face = Enum.NormalId.Back
	sign.CanvasSize = Vector2.new(900, 200)
	sign.Parent = banner

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.Text = team.name
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(245, 245, 245)
	text.Parent = sign

	-- Brilha, para se ver de longe qual e o ponto de encontro.
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 45
	light.Color = team.color
	light.Parent = banner

	return banner
end

--[[
	Prepara o terreno. Nao poe ninguem a andar: o corteo de cada claque so sai
	quando o lider dela mandar, e ate la a faixa nem existe.
]]
function March.arm(parent: Instance)
	March.stop()

	local folder = Instance.new("Folder")
	folder.Name = "March"
	folder.Parent = parent
	root = folder

	table.clear(credit)
	active = true
end

--[[
	O lider mandou sair. A faixa aparece a porta da sede e comeca a andar; quem
	for atras dela ganha credito.
]]
function March.launch(teamId: string): boolean
	if not (active and root) then
		return false
	end
	if banners[teamId] then
		return false
	end

	local waypoints = routeFor(teamId)
	if #waypoints < 2 then
		return false
	end

	banners[teamId] = {
		model = buildBanner(teamId, waypoints[1], root),
		waypoints = waypoints,
		leg = 1,
		teamId = teamId,
	}
	return true
end

function March.stop()
	active = false
	table.clear(banners)
	if root then
		root:Destroy()
		root = nil
	end
end

function March.isActive(): boolean
	return active
end

-- Onde vai a faixa da equipa, para o cliente poder apontar o caminho.
function March.bannerPosition(teamId: string): Vector3?
	local banner = banners[teamId]
	return banner and banner.model.Position or nil
end

function March.step(dt: number)
	if not active then
		return
	end

	for teamId, banner in banners do
		local target = banner.waypoints[banner.leg + 1]
		if not target then
			continue
		end

		local here = banner.model.Position
		local delta = target - here
		if delta.Magnitude <= M.speed * dt then
			banner.leg += 1
			banner.model.CFrame = CFrame.new(target)
		else
			local step = delta.Unit * M.speed * dt
			banner.model.CFrame = CFrame.lookAt(here + step, here + step + delta.Unit)
				* CFrame.Angles(0, math.rad(90), 0)
		end

		-- Quem vai junto a faixa ganha credito, proporcional ao tempo que a
		-- acompanha. Andar ao lado dela e que conta, nao aparecer no fim.
		local legs = #banner.waypoints - 1
		for _, player in Players:GetPlayers() do
			if Teams.get(player) == teamId then
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp and (hrp.Position - banner.model.Position).Magnitude <= M.radius then
					credit[player] = math.min((credit[player] or 0) + dt / (legs * M.legSeconds), 1)
				end
			end
		end
	end
end

return March
