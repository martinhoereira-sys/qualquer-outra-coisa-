--!strict
--[[
	HOW IT WORKS: one page, in the menu, with what one has to know and the
	game does not say by itself. Short lines, an icon each, no paragraphs
	(Config.Text.rules). A panel in the middle of the screen; it fits a phone
	without scrolling.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UI"))

local player = Players.LocalPlayer
local U = Config.UI
local HALF = U.gap / 2
local W, H = U.canvas.X, U.canvas.Y

-- The button lives in the HUD's MENU (client/Hud takes it there).
local gui = Instance.new("ScreenGui")
gui.Name = "UltrasRegras"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local open = Instance.new("TextButton")
open.Name = "Abrir"
open.Size = UDim2.fromOffset(150, 28)
open.Visible = true
open.Text = Config.Text.hud.howItWorks
open.Parent = gui
local openCorner = Instance.new("UICorner")
openCorner.Parent = open

local screen = Instance.new("ScreenGui")
screen.Name = "UltrasRegrasPainel"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 90
screen.Enabled = false
screen.Parent = player:WaitForChild("PlayerGui")
UI.scale(screen, false, true)

local panel = Instance.new("Frame")
panel.Name = "Painel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(W, H)
panel.BackgroundColor3 = U.ground
panel.BackgroundTransparency = U.groundTransparency
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = screen
UI.corner(panel)

local title = UI.label(panel, Config.Text.hud.howItWorks, "title")
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.fromOffset(U.gap * 1.5, 20)
title.Size = UDim2.fromOffset(W - U.gap * 3 - U.button - U.gap, U.button)

local close = UI.button(panel, "X")
close.Name = "Fechar"
close.AutoLocalize = false
close.Size = UDim2.fromOffset(U.button, U.button)
close.Position = UDim2.fromOffset(W - U.gap * 1.5 - U.button, 20)

-- The lines share the height there is: every one of them in sight at once.
local rules = Config.Text.rules
local top = 20 + U.button + U.gap
local step = math.floor((H - top - 20) / math.max(#rules, 1))
for i, rule in rules do
	local row = UI.panel(panel)
	row.Position = UDim2.fromOffset(U.gap * 1.5, top + (i - 1) * step)
	row.Size = UDim2.fromOffset(W - U.gap * 3, step - HALF)
	local icon = UI.label(row, rule[1], "normal")
	icon.AutoLocalize = false
	icon.Position = UDim2.fromOffset(0, 0)
	icon.Size = UDim2.new(0, 72, 1, 0)
	local words = UI.label(row, rule[2], "small", false, true)
	words.TextXAlignment = Enum.TextXAlignment.Left
	words.Position = UDim2.fromOffset(72, 0)
	words.Size = UDim2.new(1, -72 - U.gap, 1, 0)
end

open.Activated:Connect(function()
	screen.Enabled = not screen.Enabled
end)
close.Activated:Connect(function()
	screen.Enabled = false
end)
