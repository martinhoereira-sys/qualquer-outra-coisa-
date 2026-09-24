--!strict
--[[
	Trancar a camara (o "shift lock"), no Ctrl.

	O do Roblox vive no Shift, e o Shift aqui e correr: os dois juntos
	trancavam a camara a cada sprint. Este faz o mesmo noutra tecla — o rato
	preso ao centro, o boneco sempre virado para onde a camara olha, e a
	camara um pouco ao lado do ombro, para se ver a frente.

	Serve a toda a gente: a quem joga para apontar o chuto com a camara, e a
	quem esta na bancada para olhar a volta.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local SHOULDER = Vector3.new(1.75, 0, 0)

local locked = false

local function humanoidAndRoot(): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function setLocked(on: boolean)
	locked = on
	local humanoid = humanoidAndRoot()
	if humanoid then
		humanoid.AutoRotate = not on
		humanoid.CameraOffset = if on then SHOULDER else Vector3.zero
	end
	if not on then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

ContextActionService:BindAction("TrancarCamara", function(_, state)
	if state == Enum.UserInputState.Begin then
		setLocked(not locked)
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl)

-- Um corpo novo comeca destrancado, como o do Roblox.
player.CharacterAdded:Connect(function()
	setLocked(false)
end)

-- Depois da camara do Roblox, senao ela desfazia isto a cada frame.
RunService:BindToRenderStep("TrancarCamara", Enum.RenderPriority.Camera.Value + 1, function()
	if not locked then
		return
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	local humanoid, root = humanoidAndRoot()
	local camera = workspace.CurrentCamera
	-- Caido ou sentado, o corpo nao se vira.
	if not humanoid or not root or not camera or humanoid.PlatformStand or humanoid.Sit then
		return
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	end
end)
