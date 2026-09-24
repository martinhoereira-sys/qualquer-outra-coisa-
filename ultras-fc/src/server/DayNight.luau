--!strict
--[[
	As horas do dia: manha, tarde, fim de tarde e noite, sempre a andar.

	O servidor adianta o relogio do Lighting, que chega a toda a gente sozinho,
	e muda a luz do ceu, do nevoeiro e do ar com a hora. Quando anoitece
	acendem-se os candeeiros da cidade e os holofotes do estadio; quando
	amanhece apagam-se.

	Luzes a serio (PointLight) so as precisas para se ver: um candeeiro em
	cada tres, e uma dezena por cima do relvado e das bancadas. Os outros
	candeeiros brilham (Neon) mas nao iluminam — cada luz custa em todos os
	ecras.
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
	Os holofotes do estadio: as torres dos cantos acendem-se (brilho, que se ve
	de longe), e umas luzes por cima do relvado e das bancadas fazem a luz a
	serio. As das torres nao chegavam: uma luz do Roblox so ilumina ate 60
	studs, e as torres estao mais longe do que isso do meio do campo.
]]
local function findFloods()
	table.clear(floods)
	table.clear(rigs)
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

	local half = S.pitchLength / 2
	local wide = S.pitchWidth / 2
	local stand = S.standGap + S.rows * S.rowDepth / 2
	local spots = {
		-- Por cima do relvado.
		Vector3.new(-half * 0.6, 44, -wide * 0.45),
		Vector3.new(0, 44, -wide * 0.45),
		Vector3.new(half * 0.6, 44, -wide * 0.45),
		Vector3.new(-half * 0.6, 44, wide * 0.45),
		Vector3.new(0, 44, wide * 0.45),
		Vector3.new(half * 0.6, 44, wide * 0.45),
		-- Por cima das bancadas: os topos das claques e as laterais.
		Vector3.new(-(half + stand), 34, 0),
		Vector3.new(half + stand, 34, 0),
		Vector3.new(0, 34, -(wide + stand)),
		Vector3.new(0, 34, wide + stand),
	}
	for _, at in spots do
		local holder = Instance.new("Part")
		holder.Name = "Holofote"
		holder.Size = Vector3.new(1, 1, 1)
		holder.CFrame = CFrame.new(at)
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.CastShadow = false
		holder.Transparency = 1
		holder.Parent = folder

		local light = Instance.new("PointLight")
		light.Color = FLOOD
		light.Brightness = 1.8
		light.Range = 60
		light.Shadows = false
		light.Enabled = false
		light.Parent = holder
		table.insert(floods, light)
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
		rig.Color = if on then FLOOD else Color3.fromRGB(96, 100, 108)
	end
	for _, light in floods do
		light.Enabled = on
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
	Lighting.ClockTime = D.startHour

	local hoursPerSecond = 24 / (D.dayMinutes * 60)
	local sinceSky = math.huge
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
