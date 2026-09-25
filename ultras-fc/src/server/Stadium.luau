--!strict
--[[
	O estadio.

	O edificio vive no mapa (Workspace.Estadio), feito uma vez pelo
	StadiumBuilder e depois mexido a mao no Studio se for preciso; se o mapa nao
	o tiver, constroi-se ao arrancar. Aqui fica o que o jogo precisa dele: a
	luz do fim de tarde, o tunel e o balneario, e onde aparece cada claque.
	A planta (medidas, curvas das claques) e o StadiumPlan.

	O que e do jogo e muda (adeptos, tifo, corteo) vai para Workspace.Stadium,
	que se refaz a cada arranque.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Budget = require(script.Parent:WaitForChild("Budget"))
local City = require(script.Parent:WaitForChild("City"))
local StadiumBuilder = require(script.Parent:WaitForChild("StadiumBuilder"))
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StadiumPlan"))

local Stadium = {}

local S = Config.Stadium

local INNER_Z = S.pitchWidth / 2 + S.standGap -- frente das bancadas laterais
local MAIN_SIDE = Plan.mainSide -- a bancada principal (tunel, balneario, camarotes)

--------------------------------------------------------------------------------
-- Fim de tarde
--------------------------------------------------------------------------------

local function setAfternoon()
	--[[
		Sol ainda alto mas ja a cair, como as cinco da tarde.

		A latitude conta tanto como a hora: com 41 graus o sol do fim de tarde
		mergulha logo abaixo do horizonte e o que se via era noite. Perto do
		equador mantem-se alto, e ai a hora le-se como tarde e nao como noite.
	]]
	Lighting.ClockTime = 16.6
	Lighting.GeographicLatitude = 8
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(138, 134, 126)
	Lighting.OutdoorAmbient = Color3.fromRGB(176, 172, 162)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 2600
	Lighting.FogColor = Color3.fromRGB(214, 212, 204)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(216, 196, 168)
	atmosphere.Decay = Color3.fromRGB(136, 118, 100)
	atmosphere.Glare = 0.45
	atmosphere.Haze = 1.5
	atmosphere.Parent = Lighting

	-- Um bloom discreto, so para o sol rasante ter peso.
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.25
	bloom.Parent = Lighting

	--[[
		O ar de filme: cores quentes e um pouco lavadas, contraste suave, como
		pelicula antiga. E o que tira o aspeto de plastico de cores vivas do
		Roblox e da ao jogo o ar de uma cidade velha ao fim da tarde.
	]]
	local grade = Lighting:FindFirstChild("Filme") or Instance.new("ColorCorrectionEffect")
	grade.Name = "Filme"
	grade.Brightness = 0.02
	grade.Contrast = 0.2
	grade.Saturation = -0.3
	grade.TintColor = Color3.fromRGB(255, 234, 208)
	grade.Parent = Lighting

	-- Raios de sol discretos a atravessar a bruma.
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Spread = 0.7
	rays.Parent = Lighting

	-- Ao longe, um pouco desfocado, como numa lente de cinema. O perto fica nitido.
	local focus = Lighting:FindFirstChildOfClass("DepthOfFieldEffect") or Instance.new("DepthOfFieldEffect")
	focus.FarIntensity = 0.14
	focus.NearIntensity = 0
	focus.FocusDistance = 60
	focus.InFocusRadius = 90
	focus.Parent = Lighting

	-- Nuvens a serio no ceu, em vez do azul liso.
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.62
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(246, 238, 226)
	clouds.Parent = workspace.Terrain
end

--------------------------------------------------------------------------------
-- O tunel e o balneario (por baixo do bloco do meio da principal)
--------------------------------------------------------------------------------

local tunnelGate: BasePart? = nil

-- Abre ou fecha a grade da boca do tunel.
function Stadium.setTunnelOpen(open: boolean)
	local gate = tunnelGate
	if gate then
		gate.CanCollide = not open
		gate.Transparency = if open then 1 else 0.35
	end
end

--[[
	Onde cada um espera no balneario: cada equipa na sua metade, em duas filas
	de lugares; o arbitro ao meio, junto a porta do tunel.
]]
function Stadium.lockerSpot(teamId: string?, slot: number): Vector3
	local z = MAIN_SIDE
	local roomFront = INNER_Z + 5 * S.rowDepth
	if not teamId then
		return Vector3.new(0, 0, z * (roomFront + 2.5))
	end
	local s = Config.Teams[teamId].side
	local column = (slot - 1) % 3
	local line = (slot - 1) // 3
	return Vector3.new(s * (4 + column * 3.5), 0, z * (roomFront + 7 + line * 4))
end

-- O caminho do balneario ao relvado, por uma das tres faixas do tunel.
function Stadium.tunnelPath(lane: number): { Vector3 }
	local z = MAIN_SIDE
	local roomFront = INNER_Z + 5 * S.rowDepth
	return {
		Vector3.new(lane, 0, z * (roomFront + 1.5)),
		Vector3.new(lane, 0, z * (INNER_Z + 2)),
		Vector3.new(lane, 0, z * (S.pitchWidth / 2 - 4)),
	}
end

-- O lado da bancada principal, a do tunel: -1.
function Stadium.mainSide(): number
	return MAIN_SIDE
end

-- (Do estadio antigo: a meia largura do bloco da claque. As claques agora
-- estao nas curvas; quem precisa da forma delas usa o StadiumPlan.)
function Stadium.claqueHalfWidth(): number
	return S.claqueBlockWidth / 2
end

local spawnPoints: { [string]: Vector3 } = {}

function Stadium.spawnPoint(teamId: string): Vector3?
	return spawnPoints[teamId]
end

function Stadium.build()
	if not S.build then
		return
	end

	-- O Baseplate do place novo estende-se ate ao horizonte e e nele que se cai.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	setAfternoon()

	-- O edificio: o do mapa, ou feito agora se o mapa nao o tiver.
	local building = workspace:FindFirstChild("Estadio") or StadiumBuilder.build(workspace)
	tunnelGate = building:FindFirstChild("TunnelGate", true) :: BasePart?

	-- A pasta do que e do jogo e muda (adeptos, tifo, corteo, bola).
	local existing = workspace:FindFirstChild("Stadium")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Stadium"
	root.Parent = workspace

	-- Cada claque aparece a meio da sua curva, um pouco ao lado do vomitorio.
	for _, teamId in Config.TeamOrder do
		spawnPoints[teamId] = Plan.claqueSeat(teamId, 5, 0.32) + Vector3.new(0, 3, 0)
	end

	Budget.run("Cidade", City.build, root)
end

return Stadium
