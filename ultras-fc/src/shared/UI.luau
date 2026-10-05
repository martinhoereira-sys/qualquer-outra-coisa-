--!strict
--[[
	The pieces every screen is made of, in the one look of Config.UI:

	  UI.scale(gui)                     the canvas: the screen shrinks with the phone
	  UI.label(parent, text, size)      "title", "normal" or "small"; white
	  UI.panel(parent)                  a dark card
	  UI.button(parent, text, icon?)    a button of the one height, icon and word
	  UI.outline(thing, colour)         the club's colour, as a line round it
	  UI.corner(thing)

	Dark ground, white text. A club's colour is only ever a line. Nothing here
	knows what a screen is for.
]]

local Config = require(script.Parent:WaitForChild("Config"))

local UI = {}

local U = Config.UI

export type Size = "title" | "normal" | "small"

local FONTS: { [string]: Enum.Font } = {
	title = Enum.Font.GothamBlack,
	normal = Enum.Font.GothamBold,
	small = Enum.Font.GothamMedium,
}

-- The screen is drawn on the canvas and shrinks with the screen.
-- `hud`: something that stays on the screen during the match (it does not grow on a big screen).
-- `panel`: a window opened during the game (it does not take the whole of a big screen).
function UI.scale(gui: Instance, hud: boolean?, panel: boolean?): UIScale
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function fit()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else U.canvas
		scale.Scale = math.clamp(math.min(size.X / U.canvas.X, size.Y / U.canvas.Y), U.minScale, if hud then U.hudMaxScale elseif panel then U.panelMaxScale else U.maxScale)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	return scale
end

function UI.corner(thing: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, U.corner)
	c.Parent = thing
end

function UI.outline(thing: Instance, colour: Color3, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Thickness = thickness or U.line
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = thing
	return stroke
end

-- `dim`: secondary text. `fit`: the letter may shrink to stay on one line (names).
function UI.label(parent: Instance, text: string, size: Size, dim: boolean?, fit: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONTS[size]
	l.Text = text
	l.TextSize = (U :: any)[size]
	l.TextColor3 = U.text
	l.TextTransparency = if dim then U.dim else 0
	l.Size = UDim2.new(1, 0, 0, (U :: any)[size] + 6)
	if fit then
		l.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = (U :: any)[size]
		limit.MinTextSize = 12
		limit.Parent = l
	end
	l.Parent = parent
	return l
end

function UI.panel(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = U.panel
	f.BackgroundTransparency = U.panelTransparency
	f.BorderSizePixel = 0
	f.Parent = parent
	UI.corner(f)
	return f
end

-- A card that is pressed (a club, an item): a panel that is a button.
function UI.card(parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = U.panel
	b.BackgroundTransparency = U.panelTransparency
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Text = ""
	b.Parent = parent
	UI.corner(b)
	return b
end

--[[
	A button: always the one height, the icon and the word on the left, and
	(if given) a small note on the right (a level, a count).
]]
function UI.button(parent: Instance, text: string, icon: string?, note: string?): TextButton
	local b = UI.card(parent)
	b.Size = UDim2.new(1, 0, 0, U.button)
	local word = UI.label(b, if icon then icon .. "  " .. text else text, "normal", false, true)
	word.Name = "Palavra"
	word.Font = Enum.Font.GothamBlack
	word.AnchorPoint = Vector2.new(0, 0.5)
	word.Position = UDim2.new(0, U.gap, 0.5, 0)
	word.Size = UDim2.new(1, -U.gap * 2, 0, U.normal + 6)
	if note then
		word.TextXAlignment = Enum.TextXAlignment.Left
		word.Size = UDim2.new(0.68, -U.gap, 0, U.normal + 6)
		local right = UI.label(b, note, "small", true, true)
		right.Name = "Nota"
		right.AnchorPoint = Vector2.new(1, 0.5)
		right.Position = UDim2.new(1, -U.gap, 0.5, 0)
		right.Size = UDim2.new(0.32, -U.gap, 0, U.small + 6)
		right.TextXAlignment = Enum.TextXAlignment.Right
	end
	return b
end

return UI
