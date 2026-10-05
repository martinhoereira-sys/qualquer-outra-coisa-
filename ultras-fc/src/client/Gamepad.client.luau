--!strict
--[[
	Playing with a gamepad (PlayStation / Xbox): the menus without a mouse.

	Roblox moves a selection from button to button with the stick or the D-pad
	once something is selected. This puts the selection on the first button of
	whatever screen of ours is open (the club menu, the capo's orders, the
	table...), so no action needs a mouse or a keyboard. With no screen open
	the selection is let go, so the stick moves the character again.

	The other gamepad buttons are bound where each action lives:
	  R2 shoot · L2 shoot with curve · L1 sprint · X dive / whistle (Football, Hud)
	  D-pad up emotes · D-pad left appeal · D-pad right tifo · Y join the capo's order
	  the gear bar: L1 / R1 change what is held (Roblox's own bar), R2 uses it
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The screens that take the selection when they are open: the gui, and the frame to look at.
local SCREENS = {
	{ "UltrasHud", "Escolha" }, -- the club and role menu
	{ "UltrasLiga", "Painel" },
	{ "UltrasAdmin", "Bar" },
}

local function firstButton(root: Instance): GuiButton?
	local best: GuiButton? = nil
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.Visible and d.Active and d.AbsoluteSize.X > 0 then
			-- visible all the way up
			local shown = true
			local parent = d.Parent
			while parent and parent ~= root.Parent do
				if parent:IsA("GuiObject") and not parent.Visible then
					shown = false
					break
				end
				parent = parent.Parent
			end
			if shown and (not best or d.AbsolutePosition.Y < best.AbsolutePosition.Y - 4 or (math.abs(d.AbsolutePosition.Y - best.AbsolutePosition.Y) <= 4 and d.AbsolutePosition.X < best.AbsolutePosition.X)) then
				best = d
			end
		end
	end
	return best
end

local function openScreen(): Instance?
	for _, entry in SCREENS do
		local gui = playerGui:FindFirstChild(entry[1])
		if gui and gui:IsA("ScreenGui") and gui.Enabled then
			local root: Instance? = if entry[2] then gui:FindFirstChild(entry[2] :: string, true) else nil
			if entry[2] == nil then
				-- a panel that is shown or hidden
				for _, child in gui:GetChildren() do
					if child:IsA("Frame") and child.Visible then
						root = child
					end
				end
			end
			if root and root:IsA("GuiObject") and root.Visible then
				local shown = true
				local parent = root.Parent
				while parent and parent ~= gui do
					if parent:IsA("GuiObject") and not parent.Visible then
						shown = false
						break
					end
					parent = parent.Parent
				end
				if shown then
					return root
				end
			end
		end
	end
	return nil
end

task.spawn(function()
	while true do
		task.wait(0.3)
		if UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:find("Gamepad") then
			local screen = openScreen()
			local selected = GuiService.SelectedObject
			if screen then
				if not selected or not selected:IsDescendantOf(screen) then
					GuiService.SelectedObject = firstButton(screen)
				end
			elseif selected and selected:IsDescendantOf(playerGui) then
				GuiService.SelectedObject = nil
			end
		end
	end
end)
