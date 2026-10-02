--!strict
--[[
	The club emblems, drawn with shapes (no images, no letters).

	Each club has one strong SYMBOL inside its own outline, so the four are
	told apart from far away:
	  Aguias do Norte      a white eagle, wings open, on a red shield
	  Leoes                a lion on its hind legs, yellow mane, on a green disc
	  Verdes de Triana     a bridge of two arches, on a green diamond
	  Blancos de Nervion   a wide red star, on a white block

	These are our own designs, made of simple solid shapes: not copies of any
	real club's crest.

	The drawing lives in Config.Clubs[...].emblem, as a list of shapes in a
	square box (0..1 across and down):
	  { centreX, centreY, width, height, rotation (degrees), round (0..0.5), colour key }
	`round` is the corner radius as a share of the shorter side (0.5 on a
	square is a circle). Shapes are laid one over the other, in order. The
	colour keys are in `emblem.colours`.

	The same list is drawn two ways, so the symbol is the same everywhere:
	  Emblem.draw     with Frames, on any GuiObject (chest, scoreboard, menu,
	                  faixa, scarf, flags made of strips)
	  Emblem.colourAt the colour at a point, for painting it on an image (the
	                  smooth cloth of the pole flag)
]]

local Emblem = {}

export type Options = {
	simple: boolean?, -- kept for old callers: the drawing is the same
	year: boolean?, -- write the founding year underneath (default true)
}

-- Fills `parent` (best square) with the club's emblem.
function Emblem.draw(parent: GuiObject, club: any, options: Options?): Frame
	local o: Options = options or {}
	local e = club.emblem
	local showYear = o.year ~= false

	local box = Instance.new("Frame")
	box.Name = "Emblema"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.fromScale(0.5, 0)
	box.Size = UDim2.fromScale(1, if showYear then 0.8 else 1)
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.Parent = box
	box.Parent = parent

	for index, shape in e.shapes do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = e.colours[shape[7]]
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(shape[1], shape[2])
		f.Size = UDim2.fromScale(shape[3], shape[4])
		f.Rotation = shape[5]
		f.ZIndex = index
		if shape[6] > 0 then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(shape[6], 0)
			corner.Parent = f
		end
		f.Parent = box
	end

	if showYear then
		local year = Instance.new("TextLabel")
		year.Name = "Ano"
		year.BackgroundTransparency = 1
		year.Size = UDim2.fromScale(1, 0.2)
		year.Position = UDim2.fromScale(0, 0.8)
		year.Font = Enum.Font.GothamBlack
		year.TextScaled = true
		year.TextColor3 = Color3.fromRGB(245, 245, 245)
		year.TextStrokeTransparency = 0.3
		year.Text = tostring(club.founded)
		year.Parent = parent
	end
	return box
end

-- The colour of the emblem at (u, v) in its box (0..1), or nil outside it.
function Emblem.colourAt(club: any, u: number, v: number): Color3?
	local e = club.emblem
	local shapes = e.shapes
	for index = #shapes, 1, -1 do
		local s = shapes[index]
		local dx, dy = u - s[1], v - s[2]
		if s[5] ~= 0 then
			local a = -math.rad(s[5])
			local cos, sin = math.cos(a), math.sin(a)
			dx, dy = dx * cos - dy * sin, dx * sin + dy * cos
		end
		local halfW, halfH = s[3] / 2, s[4] / 2
		local r = s[6] * math.min(s[3], s[4])
		local qx, qy = math.abs(dx) - halfW + r, math.abs(dy) - halfH + r
		local outside = math.sqrt(math.max(qx, 0) ^ 2 + math.max(qy, 0) ^ 2) + math.min(math.max(qx, qy), 0) - r
		if outside <= 0 then
			return e.colours[s[7]]
		end
	end
	return nil
end

return Emblem
