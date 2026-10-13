--!strict
--[[
	THE ROUND BUTTONS OF THE PHONE (TIFO, APPEAL, emotes...: the ones Roblox
	makes for ContextActionService) and our panels.

	  - While one of our panels is open (the capo's orders, the menu, the
	    profile, the rules, the choice of club), the round buttons are hidden:
	    they used to sit on top of the panel and cover its buttons.
	  - The word on a round button is never broken in two lines: it is made
	    smaller until it fits in one.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The actions that have a round button.
local ACTIONS = { "Pedir", "Tifo", "Animacoes", "Descer", "Apitar", "SaltarFase", "TrancarCamara" }
-- Our screens that open panels.
local PANELS = { "Lider", "UltrasEscolha", "UltrasMenu", "Perfil", "UltrasRegrasPainel", "UltrasAdmin" }

local function panelOpen(): boolean
	for _, name in PANELS do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") and gui.Enabled then
			for _, child in gui:GetChildren() do
				-- (A panel: something big on the screen, not a small button or a label.)
				if child:IsA("GuiObject") and child.Visible and (child:IsA("Frame") or child:IsA("ScrollingFrame") or child:IsA("CanvasGroup"))
					and child.AbsoluteSize.X > 300 and child.AbsoluteSize.Y > 200 then
					return true
				end
			end
		end
	end
	return false
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local open = panelOpen()
		for _, action in ACTIONS do
			local ok, button = pcall(function()
				return ContextActionService:GetButton(action)
			end)
			if ok and button and button:IsA("GuiObject") then
				if open then
					button.Visible = false
				elseif not button.Visible then
					button.Visible = true
				end
				for _, d in button:GetDescendants() do
					if d:IsA("TextLabel") and d.TextWrapped then
						d.TextWrapped = false
						d.TextScaled = true
					end
				end
			end
		end
	end
end)
