--!strict
--[[
	O que o jogador ve e carrega.

	Rematar: segurar o clique esquerdo (ou F) carrega a forca, largar chuta.
	Passar: um toque no clique direito (ou E). Correr: Shift, enquanto houver
	folego.

	Aqui so ha input e barras. Quem tem a bola, para onde ela vai e se o remate
	conta e tudo decidido no servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local F = Config.Football
local player = Players.LocalPlayer

local TEXT = Color3.fromRGB(232, 234, 237)
local MUTED = Color3.fromRGB(141, 150, 163)
local TRACK = Color3.fromRGB(43, 51, 61)
local BRASS = Color3.fromRGB(217, 164, 65)
local SPENT = Color3.fromRGB(190, 70, 60)

local gui = Instance.new("ScreenGui")
gui.Name = "FootballHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(y: number, width: number, height: number): (Frame, Frame)
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Size = UDim2.fromOffset(width, height)
	track.Position = UDim2.new(0.5, 0, 1, y)
	track.BackgroundColor3 = TRACK
	track.BackgroundTransparency = 0.25
	track.BorderSizePixel = 0
	track.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, height // 2)
	corner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill
	return track, fill
end

local function text(parent: Instance, content: string, size: number, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.Text = content
	l.TextSize = size
	l.TextColor3 = colour
	l.Parent = parent
	return l
end

-- A forca do remate: so aparece enquanto se carrega.
local powerTrack, powerFill = bar(-150, 260, 14)
powerTrack.Visible = false
powerFill.BackgroundColor3 = BRASS

-- O folego, sempre a vista.
local staminaTrack, staminaFill = bar(-122, 200, 6)
staminaFill.BackgroundColor3 = TEXT
local staminaTag = text(staminaTrack, "folego", 11, MUTED)
staminaTag.Font = Enum.Font.Gotham
staminaTag.AnchorPoint = Vector2.new(1, 0.5)
staminaTag.Position = UDim2.new(0, -8, 0.5, 0)

local hint = text(gui, "segurar clique esquerdo  rematar    ·    clique direito  passar    ·    Shift  correr", 12, MUTED)
hint.Font = Enum.Font.Gotham
hint.Size = UDim2.new(1, 0, 0, 16)
hint.Position = UDim2.new(0, 0, 1, -26)

-- "3, 2, 1" antes do apito do pontape de saida.
local countdown = text(gui, "", 64, TEXT)
countdown.Font = Enum.Font.GothamBlack
countdown.AnchorPoint = Vector2.new(0.5, 0.5)
countdown.Position = UDim2.fromScale(0.5, 0.36)
countdown.Size = UDim2.fromOffset(400, 80)
local countdownNote = text(gui, "", 16, MUTED)
countdownNote.AnchorPoint = Vector2.new(0.5, 0.5)
countdownNote.Position = UDim2.new(0.5, 0, 0.36, 50)
countdownNote.Size = UDim2.fromOffset(400, 22)

local function playing(): boolean
	return player:GetAttribute("Team") == "jogador"
end

local function refresh()
	gui.Enabled = playing()
end
player:GetAttributeChangedSignal("Team"):Connect(refresh)
refresh()

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

local chargingSince: number? = nil
local sprinting = false

--[[
	O clique direito e o passe, mas segurar e arrastar o direito e rodar a
	camara no Roblox. Um toque curto e sem arrastar passa; o resto fica para
	a camara.
]]
local rightSince: number? = nil
local rightAt = Vector2.zero
local TAP_TIME = 0.25
local TAP_DRIFT = 6

local function charge(): number
	local since = chargingSince
	if not since then
		return 0
	end
	return math.clamp((os.clock() - since) / F.chargeTime, 0, 1)
end

local function isShootInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not playing() then
		return
	end
	if isShootInput(input) then
		chargingSince = os.clock()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightSince = os.clock()
		rightAt = UserInputService:GetMouseLocation()
	elseif input.KeyCode == Enum.KeyCode.E then
		Remotes.Football:FireServer("pass")
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprinting = true
		Remotes.Football:FireServer("sprint", true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not playing() then
		return
	end
	if isShootInput(input) and chargingSince then
		Remotes.Football:FireServer("shoot", charge())
		chargingSince = nil
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and rightSince then
		local quick = os.clock() - rightSince <= TAP_TIME
		local still = (UserInputService:GetMouseLocation() - rightAt).Magnitude <= TAP_DRIFT
		rightSince = nil
		if quick and still then
			Remotes.Football:FireServer("pass")
		end
	elseif (input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift) and sprinting then
		sprinting = false
		Remotes.Football:FireServer("sprint", false)
	end
end)

--------------------------------------------------------------------------------
-- Barras
--------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		return
	end

	local power = charge()
	powerTrack.Visible = chargingSince ~= nil
	powerFill.Size = UDim2.fromScale(math.max(power, 0.02), 1)
	powerFill.BackgroundColor3 = BRASS:Lerp(SPENT, math.max(power - 0.75, 0) * 4)

	local stamina = player:GetAttribute("Stamina")
	local fraction = if type(stamina) == "number" then stamina else 1
	staminaFill.Size = UDim2.fromScale(fraction, 1)
	staminaFill.BackgroundColor3 = if player:GetAttribute("Exhausted") then SPENT else TEXT

	local at = workspace:GetAttribute("KickoffAt")
	local left = if type(at) == "number" then at - workspace:GetServerTimeNow() else -1
	if left > 0 then
		countdown.Text = tostring(math.ceil(left))
		local teamId = workspace:GetAttribute("KickoffTeam")
		local team = Config.Teams[if type(teamId) == "string" then teamId else ""]
		countdownNote.Text = if team then "pontape de saida  ·  " .. team.name else "pontape de saida"
	elseif left > -0.8 then
		countdown.Text = "APITO"
		countdownNote.Text = ""
	else
		countdown.Text = ""
		countdownNote.Text = ""
	end
end)
