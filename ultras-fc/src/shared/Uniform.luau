--!strict
--[[
	The kits, built from parts (no textures, no uploaded images).

	A kit comes from Config.Clubs[...].kits (pattern, colours). `Uniform.wear`
	dresses any R15 character with it: shirt with sleeves, shorts, socks, the
	number on the back and on the chest, and the name over the number.

	How it is made: the body takes the base colours (shirt on the torso, skin
	on arms and legs), and thin shells are welded over it:
	  - sleeves on the upper arms, shorts over the hips and thighs, socks on
	    the lower legs;
	  - "hoops": horizontal bands round the torso and the sleeves;
	  - "stripes": vertical bars down the torso;
	  - "sash": one diagonal band, front and back;
	  - trim: a collar and cuffs in a third colour.
	Everything goes in a folder called "Kit" inside the character, so taking
	the kit off is destroying that folder.

	The four clubs must be told apart from a stand away: plain red, green and
	white HOOPS with yellow, green and white vertical STRIPES, white with ONE
	red sash. The patterns are big on purpose.
]]

local Emblem = require(script.Parent:WaitForChild("Emblem"))

local Uniform = {}

export type Kit = {
	pattern: string, -- "plain" | "hoops" | "stripes" | "sash"
	shirt: Color3,
	second: Color3?,
	trim: Color3?,
	shorts: Color3,
	socks: Color3,
	sockTop: Color3?,
	thin: boolean?, -- thin hoops
	sleeves: Color3?, -- sleeves in another colour
}

export type Extras = {
	club: any?, -- the club: its emblem goes on the chest
	number: number?,
	name: string?,
	skin: Color3?, -- arms and legs (default: the colour of the head)
}

local FOLDER = "Kit"
local PAD = 0.06 -- how far a shell sits outside the body

local function shell(name: string, body: BasePart, size: Vector3, offset: CFrame, colour: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.Fabric
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = body.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = body
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	p.Parent = parent
	return p
end

-- A band round a body part, `height` tall, centred at `y` (in the part's space).
local function band(name: string, body: BasePart, y: number, height: number, colour: Color3, parent: Instance, pad: number?)
	local extra = pad or PAD
	return shell(name, body, Vector3.new(body.Size.X + extra * 2, height, body.Size.Z + extra * 2), CFrame.new(0, y, 0), colour, parent)
end

local function part(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

-- Dark ink on light shirts, white on the rest.
local function inkFor(colour: Color3): Color3
	local light = colour.R * 0.3 + colour.G * 0.59 + colour.B * 0.11
	return if light > 0.7 then Color3.fromRGB(24, 24, 28) else Color3.fromRGB(248, 248, 248)
end

local function label(plate: BasePart, face: Enum.NormalId, text: string, colour: Color3, size: UDim2, position: UDim2)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Texto"
	gui.AutoLocalize = false -- names and numbers: never translated
	gui.Face = face
	gui.CanvasSize = Vector2.new(200, 200)
	gui.LightInfluence = 0.6
	gui.Parent = plate
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = position
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = colour
	t.Text = text
	t.Parent = gui
end

-- Takes the kit off (the body colours stay as they are).
function Uniform.strip(model: Model)
	-- What the ultra's hood was hiding comes back.
	for _, d in model:GetDescendants() do
		local hidden = d:GetAttribute("Escondido")
		if d:IsA("BasePart") and type(hidden) == "number" then
			d.Transparency = hidden
			d:SetAttribute("Escondido", nil)
		end
	end
	local old = model:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
end

--[[
	Dresses `model` with `kit`. Returns the kit folder.
]]
function Uniform.wear(model: Model, kit: Kit, extras: Extras?): Folder
	Uniform.strip(model)
	local e: Extras = extras or {}
	local folder = Instance.new("Folder")
	folder.Name = FOLDER

	local torso = part(model, "UpperTorso")
	local hips = part(model, "LowerTorso")
	local head = part(model, "Head")
	local second = kit.second or kit.shirt
	local skin = e.skin or (if head then head.Color else Color3.fromRGB(226, 190, 152))

	-- The base colours: shirt on the torso, skin on arms and legs.
	local colours = model:FindFirstChildOfClass("BodyColors")
	if not colours then
		colours = Instance.new("BodyColors")
		colours.Parent = model
	end
	local bc = colours :: BodyColors
	bc.TorsoColor3 = kit.shirt
	bc.LeftArmColor3 = skin
	bc.RightArmColor3 = skin
	bc.LeftLegColor3 = skin
	bc.RightLegColor3 = skin

	if torso then
		local w, h, d = torso.Size.X, torso.Size.Y, torso.Size.Z
		if kit.pattern == "hoops" then
			-- Six bands down the chest, every other one in the second colour.
			local each = h / 6
			for i = 1, 6, 2 do
				band("Argola", torso, h / 2 - (i + 0.5) * each, if kit.thin then each * 0.32 else each, second, folder)
			end
		elseif kit.pattern == "stripes" then
			-- Six bars across the chest, every other one in the second colour.
			local each = w / 6
			for i = 1, 6, 2 do
				shell("Risca", torso, Vector3.new(each, h + 0.02, d + PAD * 2), CFrame.new(-w / 2 + (i + 0.5) * each, 0, 0), second, folder)
			end
		elseif kit.pattern == "halves" then
			-- Two vertical halves: the wearer's right side in the second colour.
			shell("Metade", torso, Vector3.new(w / 2, h + 0.02, d + PAD * 2), CFrame.new(w / 4, 0, 0), second, folder)
		elseif kit.pattern == "sash" then
			-- One diagonal band from the left shoulder to the right hip, front and back.
			local angle = math.atan2(w - 0.5, h)
			local length = math.sqrt((w - 0.5) ^ 2 + h ^ 2) * 0.98
			for _, side in { -1, 1 } do
				shell(
					"Faixa",
					torso,
					Vector3.new(0.46, length, 0.04),
					CFrame.new(0, 0, side * (d / 2 + 0.03)) * CFrame.Angles(0, 0, -side * angle),
					second,
					folder
				)
			end
		end
		-- The collar.
		if kit.trim then
			band("Gola", torso, h / 2 - 0.07, 0.14, kit.trim, folder, PAD + 0.03)
		end
	end

	-- Sleeves (with the pattern's bands on hooped shirts) and cuffs.
	for _, name in { "LeftUpperArm", "RightUpperArm" } do
		local arm = part(model, name)
		if arm then
			local h = arm.Size.Y
			band("Manga", arm, 0, h + 0.02, if kit.sleeves then kit.sleeves elseif kit.pattern == "halves" and name == "RightUpperArm" then second else kit.shirt, folder)
			if kit.pattern == "hoops" then
				local tall = if kit.thin then h * 0.07 else h * 0.2
				band("Argola", arm, h * 0.2, tall, second, folder, PAD + 0.01)
				band("Argola", arm, -h * 0.2, tall, second, folder, PAD + 0.01)
			end
			if kit.trim then
				band("Punho", arm, -h / 2 + 0.07, 0.14, kit.trim, folder, PAD + 0.03)
			end
		end
	end

	-- Shorts: the hips and most of the thighs.
	if hips then
		band("Calcoes", hips, 0, hips.Size.Y + 0.02, kit.shorts, folder)
	end
	for _, name in { "LeftUpperLeg", "RightUpperLeg" } do
		local leg = part(model, name)
		if leg then
			local h = leg.Size.Y
			band("Calcoes", leg, h * 0.15, h * 0.72, kit.shorts, folder)
		end
	end

	-- Socks, with a band at the top.
	for _, name in { "LeftLowerLeg", "RightLowerLeg" } do
		local leg = part(model, name)
		if leg then
			local h = leg.Size.Y
			band("Meia", leg, -h * 0.08, h * 0.86, kit.socks, folder)
			if kit.sockTop then
				band("MeiaTopo", leg, h * 0.28, h * 0.16, kit.sockTop, folder, PAD + 0.02)
			end
		end
	end

	--[[
		The number and the name. They go on thin plates just outside the shirt
		(the bands would hide anything written on the torso itself). On
		patterned shirts the back plate is a solid panel, like real hooped kits.
	]]
	if torso and e.number then
		local w, h, d = torso.Size.X, torso.Size.Y, torso.Size.Z
		local patterned = (kit.pattern == "hoops" or kit.pattern == "stripes" or kit.pattern == "halves") and not kit.thin
		local ink = inkFor(kit.shirt)
		local back = shell("Costas", torso, Vector3.new(w * 0.62, h * 0.78, 0.03), CFrame.new(0, -h * 0.02, d / 2 + 0.1), kit.shirt, folder)
		back.Transparency = 1
		if patterned then
			-- A small solid panel just behind the number, so the pattern still shows around it.
			shell("Painel", torso, Vector3.new(w * 0.38, h * 0.46, 0.03), CFrame.new(0, -h * 0.17, d / 2 + 0.08), kit.shirt, folder)
		end
		label(back, Enum.NormalId.Back, tostring(e.number), ink, UDim2.fromScale(0.9, 0.66), UDim2.fromScale(0.05, 0.32))
		if e.name then
			label(back, Enum.NormalId.Back, string.upper(e.name), ink, UDim2.fromScale(0.96, 0.22), UDim2.fromScale(0.02, 0.06))
		end
		-- The small number on the chest (the emblem goes on the other side).
		local front = shell("Peito", torso, Vector3.new(w * 0.26, h * 0.26, 0.03), CFrame.new(w * 0.24, h * 0.2, -(d / 2 + 0.085)), kit.shirt, folder)
		front.Transparency = if patterned then 0 else 1
		label(front, Enum.NormalId.Front, tostring(e.number), ink, UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.05))
	end

	-- The club emblem on the chest (the wearer's left, over the heart).
	if torso and e.club and e.club.emblem then
		local w, h, d = torso.Size.X, torso.Size.Y, torso.Size.Z
		local plate = shell("Emblema", torso, Vector3.new(w * 0.3, w * 0.3, 0.03), CFrame.new(-w * 0.24, h * 0.2, -(d / 2 + 0.1)), kit.shirt, folder)
		plate.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Emblema"
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(120, 120)
		gui.LightInfluence = 0.7
		gui.Parent = plate
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Parent = gui
		Emblem.draw(holder, e.club, { year = false })
	end

	folder.Parent = model
	return folder
end

--[[
	THE ULTRA'S OUTFIT: what everyone in a claque wears, never on the pitch.
	The same cut for every club, read from the club (Config.Clubs).

	It is BLACK from head to foot: hood, long sleeves, gloves, trousers. The club's colour
	shows in two places only: the scarf round the neck (the claque's material:
	Gear / Material.wearScarf) and the mask over mouth and nose (`mask`). The
	claque's name goes across the chest in white, and the club's symbol small
	on the back, in white too. From the pitch a curva is a black block with a
	line of colour at the neck.
]]
local ULTRA_BLACK = Color3.fromRGB(18, 18, 21)
local ULTRA_WHITE = Color3.fromRGB(245, 245, 245)

function Uniform.ultra(model: Model, club: any): Folder
	Uniform.strip(model)
	for _, child in model:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	local head = part(model, "Head")
	local skin = if head then head.Color else Color3.fromRGB(226, 190, 152)

	local colours = model:FindFirstChildOfClass("BodyColors")
	if not colours then
		colours = Instance.new("BodyColors")
		colours.Parent = model
	end
	local bc = colours :: BodyColors
	bc.TorsoColor3 = ULTRA_BLACK
	bc.LeftArmColor3 = skin
	bc.RightArmColor3 = skin
	bc.LeftLegColor3 = ULTRA_BLACK
	bc.RightLegColor3 = ULTRA_BLACK

	local torso = part(model, "UpperTorso")
	if torso then
		local w, h, d = torso.Size.X, torso.Size.Y, torso.Size.Z
		band("Camisola", torso, 0, h + 0.02, ULTRA_BLACK, folder)
		-- The claque's name across the chest, in white.
		local chest = shell("Peito", torso, Vector3.new(w * 0.96, h * 0.34, 0.03), CFrame.new(0, h * 0.08, -(d / 2 + 0.09)), ULTRA_BLACK, folder)
		chest.Transparency = 1
		label(chest, Enum.NormalId.Front, string.upper(club.claque), ULTRA_WHITE, UDim2.fromScale(0.96, 0.9), UDim2.fromScale(0.02, 0.05))
		local texts = chest:FindFirstChild("Texto") :: SurfaceGui?
		if texts then
			texts.CanvasSize = Vector2.new(400, 120)
		end
		-- The club's symbol, small and white, on the back.
		if club.emblem then
			local plate = shell("Emblema", torso, Vector3.new(w * 0.36, w * 0.36, 0.03), CFrame.new(0, h * 0.12, d / 2 + 0.1), ULTRA_BLACK, folder)
			plate.Transparency = 1
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Emblema"
			gui.Face = Enum.NormalId.Back
			gui.CanvasSize = Vector2.new(120, 120)
			gui.LightInfluence = 0.7
			gui.Parent = plate
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromScale(1, 1)
			holder.Parent = gui
			Emblem.draw(holder, club, { year = false, mono = ULTRA_WHITE, ground = ULTRA_BLACK })
		end
	end
	local hips = part(model, "LowerTorso")
	if hips then
		band("Calcas", hips, 0, hips.Size.Y + 0.02, ULTRA_BLACK, folder)
	end
	for _, name in { "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" } do
		local arm = part(model, name)
		if arm then
			band("Manga", arm, 0, arm.Size.Y + 0.02, ULTRA_BLACK, folder)
		end
	end
	for _, name in { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" } do
		local leg = part(model, name)
		if leg then
			band("Calcas", leg, 0, leg.Size.Y + 0.02, ULTRA_BLACK, folder)
		end
	end
	-- The black hood: over the hair and anything worn on the head, so the block
	-- stays black. Only the face is out. (Taking the outfit off shows them again.)
	for _, child in model:GetChildren() do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") and handle.Transparency < 1 then
				handle:SetAttribute("Escondido", handle.Transparency)
				handle.Transparency = 1
			end
		end
	end
	if head then
		local s = head.Size
		-- The hood: the top down to just over the eyes, the back, and the two
		-- sides coming forward past the cheeks, with a small peak over the brow.
		shell("Capuz", head, Vector3.new(s.X + 0.18, s.Y * 0.36, s.Z + 0.18), CFrame.new(0, s.Y * 0.36, 0), ULTRA_BLACK, folder)
		shell("Capuz", head, Vector3.new(s.X + 0.18, s.Y + 0.12, s.Z * 0.55), CFrame.new(0, 0, s.Z * 0.32), ULTRA_BLACK, folder)
		for _, side in { -1, 1 } do
			shell("Capuz", head, Vector3.new(0.2, s.Y + 0.12, s.Z * 0.92), CFrame.new(side * (s.X / 2 + 0.01), 0, s.Z * 0.1), ULTRA_BLACK, folder)
		end
		shell("Capuz", head, Vector3.new(s.X + 0.18, 0.1, 0.16), CFrame.new(0, s.Y * 0.2, -(s.Z / 2 + 0.1)), ULTRA_BLACK, folder)
		-- The mask, in the club's colour: over the mouth and the nose, up to under
		-- the eyes. With the hood, only the eyes are left out.
		shell("Mascara", head, Vector3.new(s.X + 0.06, s.Y * 0.3, s.Z + 0.1), CFrame.new(0, -s.Y * 0.35, -0.02), club.mask or club.color, folder)
	end
	-- Dark glasses over the eyes.
	if head then
		local s = head.Size
		local glasses = shell("Oculos", head, Vector3.new(s.X * 0.8, s.Y * 0.17, 0.08), CFrame.new(0, s.Y * 0.07, -(s.Z / 2 + 0.03)), Color3.fromRGB(8, 8, 10), folder)
		glasses.Material = Enum.Material.SmoothPlastic
		glasses.Reflectance = 0.15
	end
	-- Black gloves: no skin showing.
	for _, name in { "LeftHand", "RightHand" } do
		local hand = part(model, name)
		if hand then
			band("Luva", hand, 0, hand.Size.Y + 0.04, ULTRA_BLACK, folder, PAD + 0.01)
		end
	end

	folder.Parent = model
	return folder
end

-- The goalkeeper: plain, in a colour neither club of the match wears.
function Uniform.keeperKit(colour: Color3): Kit
	return {
		pattern = "plain",
		shirt = colour,
		second = colour,
		trim = Color3.fromRGB(24, 24, 28),
		shorts = Color3.fromRGB(24, 24, 28),
		socks = colour,
	}
end

return Uniform
