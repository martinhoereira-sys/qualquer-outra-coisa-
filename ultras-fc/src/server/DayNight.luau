--!strict
--[[
	As horas do dia: manha, tarde, fim de tarde e noite, sempre a andar.

	O servidor adianta o relogio do Lighting, que chega a toda a gente sozinho,
	e muda a luz do ceu, do nevoeiro e do ar com a hora. Quando anoitece
	acendem-se os candeeiros da cidade e os holofotes do estadio; quando
	amanhece apagam-se.

	Luzes a serio (PointLight) so as precisas para se ver: um candeeiro em
	cada tres, e dezasseis baixas por cima do relvado e das bancadas. Os
	outros candeeiros e algumas janelas brilham (Neon) mas nao iluminam — cada
	luz custa em todos os ecras.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DayNight = {}

local D = Config.DayNight
local S = Config.Stadium

local WARM = Color3.fromRGB(255, 214, 150) -- candeeiro
local FLOOD = Color3.fromRGB(245, 244, 236) -- holofote
local LAMP_OFF = Color3.fromRGB(150, 150, 146)
local WINDOW_LIT = Color3.fromRGB(196, 150, 92) -- uma janela acesa, vista de fora

-- A luz do dia e da noite; entre as duas, mistura-se com a hora.
local DAY = {
	ambient = Color3.fromRGB(138, 134, 126),
	outdoor = Color3.fromRGB(176, 172, 162),
	fog = Color3.fromRGB(214, 212, 204),
	air = Color3.fromRGB(210, 200, 186),
	decay = Color3.fromRGB(128, 122, 116),
	brightness = 3,
}
local NIGHT = {
	ambient = Color3.fromRGB(54, 58, 74),
	outdoor = Color3.fromRGB(70, 76, 100),
	fog = Color3.fromRGB(40, 44, 58),
	air = Color3.fromRGB(56, 62, 84),
	decay = Color3.fromRGB(30, 34, 48),
	brightness = 1.6,
}

--[[
	Quanto e dia a esta hora, de 0 (noite) a 1 (dia). Muda devagar ao nascer e
	ao por do sol, para a luz nao cair de repente.
]]
local function daylight(hour: number): number
	local function ramp(a: number, b: number, t: number): number
		return math.clamp((t - a) / (b - a), 0, 1)
	end
	if hour < 12 then
		return ramp(5, 7.5, hour)
	end
	return 1 - ramp(17, 19.5, hour)
end

--------------------------------------------------------------------------------
-- As luzes
--------------------------------------------------------------------------------

type Lamp = { glow: BasePart, light: PointLight? }
local lamps: { Lamp } = {}
local floods: { PointLight } = {}
local rigs: { BasePart } = {}
local beams: { Beam } = {}
local windows: { BasePart } = {}
local lit: boolean? = nil

-- Os candeeiros da cidade, tal como estiverem no mapa.
local function findLamps()
	table.clear(lamps)
	local city = workspace:FindFirstChild("Cidade")
	if not city then
		return
	end
	local index = 0
	for _, model in city:GetDescendants() do
		if model:IsA("Model") and model.Name == "Candeeiro" then
			local glow = model:FindFirstChild("Luz")
			if glow and glow:IsA("BasePart") then
				index += 1
				local light = glow:FindFirstChildOfClass("PointLight")
				if not light and index % D.lampLightEvery == 0 then
					local made = Instance.new("PointLight")
					made.Color = WARM
					made.Brightness = 1.3
					made.Range = 42
					made.Shadows = false
					made.Enabled = false
					made.Parent = glow
					light = made
				end
				table.insert(lamps, { glow = glow, light = light })
			end
		end
	end
end

--[[
	Os holofotes do estadio. As torres dos cantos acendem-se e deitam um feixe
	de luz sobre o relvado (so aspecto: um Beam, que nao ilumina). A luz a
	serio vem de luzes baixas e fracas, muitas e sobrepostas, para o relvado
	ficar iluminado por igual em vez de a manchas redondas: uma luz do Roblox
	so chega a 60 studs, e as torres estao mais longe do que isso do meio do
	campo.
]]
local function findFloods()
	table.clear(floods)
	table.clear(rigs)
	table.clear(beams)
	local stadium = workspace:FindFirstChild("Stadium")
	if not stadium then
		return
	end
	for _, d in stadium:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Rig" then
			table.insert(rigs, d)
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Holofotes"
	folder.Parent = stadium

	local function holder(at: Vector3): Part
		local p = Instance.new("Part")
		p.Name = "Holofote"
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = CFrame.new(at)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Parent = folder
		return p
	end

	local function light(at: Vector3, brightness: number, range: number)
		local l = Instance.new("PointLight")
		l.Color = FLOOD
		l.Brightness = brightness
		l.Range = range
		l.Shadows = false
		l.Enabled = false
		l.Parent = holder(at)
		table.insert(floods, l)
	end

	local half = S.pitchLength / 2
	local wide = S.pitchWidth / 2
	local stand = S.standGap + S.rows * S.rowDepth / 2

	-- O relvado: uma grelha de 4 por 2, baixa, cada uma a cobrir a vizinha.
	for _, x in { -0.75, -0.25, 0.25, 0.75 } do
		for _, z in { -0.5, 0.5 } do
			light(Vector3.new(x * half, 30, z * wide), 1.1, 60)
		end
	end
	-- As bancadas: dois em cada topo (as claques) e dois em cada lateral.
	for _, side in { -1, 1 } do
		for _, z in { -0.3, 0.3 } do
			light(Vector3.new(side * (half + stand), 24, z * wide), 1, 50)
		end
		for _, x in { -0.45, 0.45 } do
			light(Vector3.new(x * half, 24, side * (wide + stand)), 1, 50)
		end
	end

	-- O feixe de cada torre, ate um pouco antes do meio do campo.
	for _, rig in rigs do
		local from = Instance.new("Attachment")
		from.Parent = rig
		local target = rig.Position:Lerp(Vector3.new(0, 0, 0), 0.7)
		local to = Instance.new("Attachment")
		to.Parent = holder(Vector3.new(target.X, 1, target.Z))
		local beam = Instance.new("Beam")
		beam.Attachment0 = from
		beam.Attachment1 = to
		beam.Color = ColorSequence.new(FLOOD)
		beam.Transparency = NumberSequence.new(0.88, 1)
		beam.Width0 = 8
		beam.Width1 = 40
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Enabled = false
		beam.Parent = rig
		table.insert(beams, beam)
	end
end

--[[
	Janelas acesas a noite: umas quantas, ao calhas mas sempre as mesmas, para
	a cidade parecer habitada. So brilho, nenhuma luz a serio.
]]
local function findWindows()
	table.clear(windows)
	local city = workspace:FindFirstChild("Cidade")
	if not city then
		return
	end
	for _, d in city:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Janelas" or d.Name == "Vidro" or d.Name == "Montra") then
			-- A mesma escolha em todos os servidores: vem da posicao da janela.
			local p = d.Position
			local pick = (math.sin(p.X * 12.9898 + p.Y * 78.233 + p.Z * 37.719) * 43758.5453) % 1
			local share = if d.Name == "Montra" then 0.7 elseif d.Name == "Vidro" then 0.12 else D.windowsLit
			if pick < share then
				d:SetAttribute("DiaCor", d.Color)
				table.insert(windows, d)
			end
		end
	end
end

local function setLights(on: boolean)
	if lit == on then
		return
	end
	lit = on
	for _, lamp in lamps do
		lamp.glow.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		lamp.glow.Color = if on then WARM else LAMP_OFF
		if lamp.light then
			lamp.light.Enabled = on
		end
	end
	for _, rig in rigs do
		rig.Material = if on then Enum.Material.Neon else Enum.Material.Metal
		rig.Color = if on then Color3.fromRGB(235, 234, 226) else Color3.fromRGB(96, 100, 108)
	end
	for _, light in floods do
		light.Enabled = on
	end
	for _, beam in beams do
		beam.Enabled = on
	end
	for _, window in windows do
		local day = window:GetAttribute("DiaCor")
		window.Material = if on then Enum.Material.Neon else Enum.Material.Glass
		window.Color = if on then WINDOW_LIT else (if typeof(day) == "Color3" then day else window.Color)
	end
end

--------------------------------------------------------------------------------

local function applySky(hour: number)
	local t = daylight(hour)
	Lighting.Ambient = NIGHT.ambient:Lerp(DAY.ambient, t)
	Lighting.OutdoorAmbient = NIGHT.outdoor:Lerp(DAY.outdoor, t)
	Lighting.FogColor = NIGHT.fog:Lerp(DAY.fog, t)
	Lighting.Brightness = NIGHT.brightness + (DAY.brightness - NIGHT.brightness) * t
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	if air then
		air.Color = NIGHT.air:Lerp(DAY.air, t)
		air.Decay = NIGHT.decay:Lerp(DAY.decay, t)
	end
	setLights(t < 0.5)
end

-- Arranca o relogio. Chama-se depois de o estadio e a cidade estarem feitos.
function DayNight.start()
	findLamps()
	findFloods()
	findWindows()
	Lighting.ClockTime = D.startHour

	local hoursPerSecond = 24 / (D.dayMinutes * 60)
	local sinceSky = 0 -- a contar desde ja: infinito aqui dava uma hora invalida (noite) no arranque
	RunService.Heartbeat:Connect(function(dt)
		sinceSky += dt
		-- Meio segundo de cada vez chega: o sol anda devagar, e cada mudanca
		-- no Lighting vai pela rede para toda a gente.
		if sinceSky < 0.5 then
			return
		end
		local hour = (Lighting.ClockTime + hoursPerSecond * sinceSky) % 24
		sinceSky = 0
		Lighting.ClockTime = hour
		applySky(hour)
	end)
end

return DayNight
