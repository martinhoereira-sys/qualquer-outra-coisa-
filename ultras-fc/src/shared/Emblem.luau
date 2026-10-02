--!strict
--[[
	The club emblems, drawn with shapes and text (no images).

	Each emblem has its own SHAPE, so the four are told apart from far away
	even before the colours are read:
	  shield   Águias do Norte   classic shield, diagonal band, a star on top
	  circle   Leões             round badge, horizontal hoops, a ring round it
	  diamond  Verdes de Triana  a square stood on its corner, vertical stripes
	  block    Blancos de Nervión  a tall rounded rectangle split in two halves
	The letters go in the middle and the founding year underneath.

	These are our own designs: simple geometry and initials, not copies of
	any real club's crest.

	`Emblem.draw(parent, club, opts)` fills `parent` (any GuiObject; best
	square). Two ways of drawing:
	  full    with the pattern inside the shape (uses CanvasGroup to cut it to
	          the shape): chest, scoreboard, admin bar;
	  simple  solid shapes only, no cutting: for cloth that is sliced in
	          strips (faixas), where dozens of copies are drawn.
	The data comes from Config.Clubs[...].emblem.
]]

local Emblem = {}

export type Options = {
	simple: boolean?,
	year: boolean?, -- write the founding year underneath (default true)
}

local DARK = Color3.fromRGB(24, 24, 28)

local function frame(parent: Instance, colour: Color3, size: UDim2, position: UDim2): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.Size = size
	f.Position = position
	f.Parent = parent
	return f
end

local function round(parent: Instance, scale: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

local function stroke(parent: Instance, colour: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function text(parent: Instance, value: string, colour: Color3, size: UDim2, position: UDim2, z: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = position
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = colour
	t.Text = value
	t.ZIndex = z
	t.Parent = parent
	return t
end

-- The pattern inside the shape, filling `canvas`.
local function field(canvas: Instance, e: any)
	if e.field == "hoops" then
		for i = 0, 4 do
			if i % 2 == 1 then
				frame(canvas, e.second, UDim2.fromScale(1, 0.2), UDim2.fromScale(0, i * 0.2))
			end
		end
	elseif e.field == "stripes" then
		for i = 0, 4 do
			if i % 2 == 1 then
				frame(canvas, e.second, UDim2.fromScale(0.2, 1), UDim2.fromScale(i * 0.2, 0))
			end
		end
	elseif e.field == "halves" then
		frame(canvas, e.second, UDim2.fromScale(0.5, 1), UDim2.fromScale(0.5, 0))
	elseif e.field == "band" then
		-- A diagonal band from top left to bottom right.
		local band = frame(canvas, e.second, UDim2.fromScale(1.3, 0.26), UDim2.fromScale(0.5, 0.5))
		band.AnchorPoint = Vector2.new(0.5, 0.5)
		band.Rotation = 40
	end
end

-- A masked area (cut to a rounded shape), with the pattern inside.
local function masked(parent: Instance, e: any, size: UDim2, position: UDim2, corner: number, rotation: number?): CanvasGroup
	local group = Instance.new("CanvasGroup")
	group.BorderSizePixel = 0
	group.BackgroundColor3 = e.main
	group.Size = size
	group.Position = position
	group.Rotation = rotation or 0
	group.Parent = parent
	round(group, corner)
	return group
end

function Emblem.draw(parent: GuiObject, club: any, options: Options?)
	local o: Options = options or {}
	local e = club.emblem
	local showYear = o.year ~= false
	-- The shape takes the top of the box; the year goes underneath.
	local box = Instance.new("Frame")
	box.Name = "Emblema"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, if showYear then 0.8 else 1)
	box.Parent = parent
	local ink = e.ink or DARK
	local outline = e.ring or DARK

	if e.shape == "circle" then
		if o.simple then
			local disc = frame(box, e.main, UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.07, 0.07))
			round(disc, 0.5)
			stroke(disc, outline, 3)
			local mid = frame(disc, e.second, UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.35))
			mid.ZIndex = 2
		else
			local disc = masked(box, e, UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.07, 0.07), 0.5)
			field(disc, e)
			stroke(disc, outline, 4)
		end
		-- The letter on a small plate so it reads over the hoops.
		local plate = frame(box, e.second, UDim2.fromScale(0.4, 0.4), UDim2.fromScale(0.3, 0.3))
		plate.ZIndex = 3
		round(plate, 0.5)
		stroke(plate, outline, 2)
		text(box, e.letters, ink, UDim2.fromScale(0.34, 0.34), UDim2.fromScale(0.33, 0.33), 4)
	elseif e.shape == "diamond" then
		-- A square stood on its corner. The stripes are upright bars kept inside
		-- it (a rotated CanvasGroup does not draw on a SurfaceGui, so no cutting).
		local d = frame(box, e.main, UDim2.fromScale(0.64, 0.64), UDim2.fromScale(0.5, 0.5))
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Rotation = 45
		stroke(d, outline, 3)
		for _, bar in { { 0, 0.78 }, { -0.2, 0.4 }, { 0.2, 0.4 } } do
			local b = frame(box, e.second, UDim2.fromScale(0.1, bar[2]), UDim2.fromScale(0.5 + bar[1], 0.5))
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.ZIndex = 2
		end
		local plate = frame(box, e.second, UDim2.fromScale(0.46, 0.3), UDim2.fromScale(0.27, 0.35))
		plate.ZIndex = 3
		round(plate, 0.2)
		stroke(plate, outline, 2)
		text(box, e.letters, ink, UDim2.fromScale(0.42, 0.26), UDim2.fromScale(0.29, 0.37), 4)
	elseif e.shape == "block" then
		if o.simple then
			local b = frame(box, e.main, UDim2.fromScale(0.58, 0.9), UDim2.fromScale(0.21, 0.05))
			round(b, 0.16)
			stroke(b, outline, 3)
			local half = frame(box, e.second, UDim2.fromScale(0.25, 0.7), UDim2.fromScale(0.5, 0.15))
			half.ZIndex = 2
		else
			local b = masked(box, e, UDim2.fromScale(0.58, 0.9), UDim2.fromScale(0.21, 0.05), 0.16)
			field(b, e)
			stroke(b, outline, 3)
		end
		local plate = frame(box, e.main, UDim2.fromScale(0.46, 0.28), UDim2.fromScale(0.27, 0.36))
		plate.ZIndex = 3
		round(plate, 0.2)
		stroke(plate, outline, 2)
		text(box, e.letters, ink, UDim2.fromScale(0.42, 0.24), UDim2.fromScale(0.29, 0.38), 4)
	else
		-- The shield: a square top and a round bottom.
		if o.simple then
			frame(box, e.main, UDim2.fromScale(0.7, 0.5), UDim2.fromScale(0.15, 0.08))
			local bottom = frame(box, e.main, UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.15, 0.26))
			round(bottom, 0.5)
			local band = frame(box, e.second, UDim2.fromScale(0.7, 0.14), UDim2.fromScale(0.15, 0.44))
			band.ZIndex = 2
		else
			-- (A CanvasGroup, because a rotated band is not cut by a plain frame.)
			local top = masked(box, e, UDim2.fromScale(0.7, 0.5), UDim2.fromScale(0.15, 0.08), 0)
			local topCanvas = Instance.new("Frame")
			topCanvas.BackgroundTransparency = 1
			topCanvas.Size = UDim2.fromScale(1, 1.76) -- the whole shield (0.88 of the box), seen through the top half
			topCanvas.Parent = top
			field(topCanvas, e)
			local bottom = masked(box, e, UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.15, 0.26), 0.5)
			local bottomCanvas = Instance.new("Frame")
			bottomCanvas.BackgroundTransparency = 1
			bottomCanvas.Size = UDim2.fromScale(1, 1.257)
			bottomCanvas.Position = UDim2.fromScale(0, -0.257)
			bottomCanvas.Parent = bottom
			field(bottomCanvas, e)
		end
		text(box, e.letters, ink, UDim2.fromScale(0.4, 0.4), UDim2.fromScale(0.3, 0.3), 4).TextStrokeTransparency = 0.4
		if e.star then
			text(box, "★", e.second, UDim2.fromScale(0.2, 0.2), UDim2.fromScale(0.4, 0.09), 4)
		end
	end

	if showYear then
		local year = text(parent, tostring(club.founded), DARK, UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.8), 4)
		year.Name = "Ano"
		year.TextColor3 = Color3.fromRGB(245, 245, 245)
		year.TextStrokeTransparency = 0.3
	end
	return box
end

return Emblem
