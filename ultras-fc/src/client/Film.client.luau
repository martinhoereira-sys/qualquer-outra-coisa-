--!strict
--[[
	O enquadramento de filme: os cantos e as bordas do ecra um pouco mais
	escuros (vinheta), como numa camara de cinema. Por baixo da interface,
	subtil: nota-se o ar, nao se ve o efeito.
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Filme"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -10
gui.Parent = player:WaitForChild("PlayerGui")

-- Uma banda preta numa borda, a desvanecer para o meio do ecra.
local function edge(size: UDim2, position: UDim2, rotation: number)
	local band = Instance.new("Frame")
	band.Size = size
	band.Position = position
	band.BackgroundColor3 = Color3.new(0, 0, 0)
	band.BorderSizePixel = 0
	band.Active = false
	band.Parent = gui
	local fade = Instance.new("UIGradient")
	fade.Rotation = rotation
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = band
end

edge(UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), 90) -- cima
edge(UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78), -90) -- baixo
edge(UDim2.fromScale(0.18, 1), UDim2.fromScale(0, 0), 0) -- esquerda
edge(UDim2.fromScale(0.18, 1), UDim2.fromScale(0.82, 0), 180) -- direita
