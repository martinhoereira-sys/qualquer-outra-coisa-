--!strict
--[[
	O corteo.

	A claque junta-se a porta da sede, sai em bloco e desce a avenida ate ao
	estadio, a cantar pelo caminho. E a ideia central do jogo inteiro: nao se
	entra num estadio por magia, e a caminhada e a melhor parte.

	Como funciona: quando a fase do corteo comeca, a faixa de cada claque
	aparece parada a porta da sede. O lider da a ordem na porta; se ninguem a
	der, a faixa sai sozinha a meio da fase — um servidor sem lider nao pode
	ficar preso. Quem vai perto dela enquanto anda leva a bancada ja quente para
	o apito inicial; quem la chega sozinho entra na mesma, so sem o bonus.

	Os bonecos que marcham atras da faixa nao vivem aqui: cada ecra desenha-os a
	partir da posicao dela (Corteo.client). Nao pesam nada na rede.
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
	moving: boolean,
	seconds: number, -- quanto demora o percurso todo, a passo da faixa
}

local banners: { [string]: Banner } = {}
local credit: { [Player]: number } = {} -- 0 a 1: quanto do percurso acompanhou
local active = false
local armedAt = 0
local root: Folder? = nil

function March.creditFor(player: Player): number
	return credit[player] or 0
end

function March.forget(player: Player)
	credit[player] = nil
end

--[[
	O percurso: sai-se pela frente da sede, contorna-se o quarteirao por tras,
	desce-se a rua do meio ate a avenida, e segue-se por ela ate a porta do topo
	da claque. Cada sede fica do lado do seu topo, por isso os dois corteos
	descem a avenida cada um para o seu lado e nunca se cruzam.
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

	local side = Config.Teams[teamId].side
	local behind = roadZ + 165 -- por tras dos quarteiroes, onde nao ha predios
	local street = side * 20 -- a rua do meio, cada claque do seu lado
	local flank = side * (outerX + 20) -- por fora da muralha, rente ao topo

	return {
		start,
		Vector3.new(start.X, 3, behind),
		Vector3.new(street, 3, behind),
		Vector3.new(street, 3, roadZ),
		Vector3.new(flank, 3, roadZ),
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
	banner:SetAttribute("Team", teamId)
	banner:SetAttribute("Moving", false)
	banner:SetAttribute("Arrived", false)
	banner.Parent = parent

	-- O nome dos dois lados: le-se a frente de quem vem atras e de quem espera.
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sign = Instance.new("SurfaceGui")
		sign.Face = face
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
	end

	-- Brilha, para se ver de longe qual e o ponto de encontro.
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 45
	light.Color = team.color
	light.Parent = banner

	return banner
end

--[[
	A fase do corteo comecou: as faixas aparecem a porta de cada sede, paradas,
	a espera da ordem de sair.
]]
function March.arm(parent: Instance)
	March.stop()

	local folder = Instance.new("Folder")
	folder.Name = "March"
	folder.Parent = parent
	root = folder

	table.clear(credit)
	active = true
	armedAt = os.clock()

	for _, teamId in Config.TeamOrder do
		local waypoints = routeFor(teamId)
		if #waypoints >= 2 then
			local length = 0
			for i = 2, #waypoints do
				length += (waypoints[i] - waypoints[i - 1]).Magnitude
			end
			banners[teamId] = {
				model = buildBanner(teamId, waypoints[1], folder),
				waypoints = waypoints,
				leg = 1,
				teamId = teamId,
				moving = false,
				seconds = length / M.speed,
			}
		end
	end
end

--[[
	A ordem de sair: do lider, na porta da sede, ou do relogio a meio da fase.
	A faixa comeca a andar; quem for atras dela ganha credito.
]]
function March.launch(teamId: string): boolean
	local banner = banners[teamId]
	if not (active and banner) or banner.moving then
		return false
	end
	banner.moving = true
	banner.model:SetAttribute("Moving", true)
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

	-- Sem ordem do lider, sai-se na mesma a meio da fase.
	if os.clock() - armedAt >= M.autoStartAfter then
		for teamId in banners do
			March.launch(teamId)
		end
	end

	for teamId, banner in banners do
		if not banner.moving then
			continue
		end

		local target = banner.waypoints[banner.leg + 1]
		if not target then
			if not banner.model:GetAttribute("Arrived") then
				banner.model:SetAttribute("Arrived", true)
			end
			continue
		end

		local here = banner.model.Position
		local delta = target - here
		if delta.Magnitude <= M.speed * dt then
			banner.leg += 1
			banner.model.CFrame = CFrame.new(target) * banner.model.CFrame.Rotation
		else
			local step = delta.Unit * M.speed * dt
			banner.model.CFrame = CFrame.lookAt(here + step, here + step + delta.Unit)
				* CFrame.Angles(0, math.rad(90), 0)
		end

		-- Quem vai junto a faixa ganha credito, proporcional ao tempo que a
		-- acompanha. Andar ao lado dela o caminho todo vale o credito todo.
		for _, player in Players:GetPlayers() do
			if Teams.get(player) == teamId then
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp and (hrp.Position - banner.model.Position).Magnitude <= M.radius then
					credit[player] = math.min((credit[player] or 0) + dt / banner.seconds, 1)
				end
			end
		end
	end
end

return March
