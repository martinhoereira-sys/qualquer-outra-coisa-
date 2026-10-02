--!strict
--[[
	THE CLUB GROUNDS: one per club, in its bairro. A ground is the club's
	corner of the city:
	  - the sede: a small building in the club's colours, with the emblem and
	    the claque's name at the entrance;
	  - the training pitch beside it: grass, two goals, a fence in the club's
	    colours, the emblem at one end.

	Built ONCE as a model and repeated from Config: the sede is a copy of the
	one made by hand in the map (kept in ServerStorage.SedeModelo), a little
	smaller, with the walls and the roof recoloured for each club; the pitch is
	made here. Where each ground goes is `site` in Config.Clubs. A new club in
	Config with a `site` gets its ground by itself (SedeBuilder.buildAll).

	Run in Edit, like the stadium: the grounds are saved in the map
	(Workspace.Recintos.Recinto_<club>). Building one again replaces it. Only
	the generic houses (Predio) of the block that are in the way are removed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Emblem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Emblem"))

local SedeBuilder = {}

local SCALE = 0.7 -- the sede is a little smaller than the hand-made one
-- The training pitch: as big as the block lets it be, up to this (the stadium's
-- own pitch does not fit in a city block).
local PITCH_MAX = Vector3.new(110, 0.4, 64)
local MARGIN = 5 -- pavement left round the ground
local GAP = 6 -- between the sede and the pitch

-- The walls: black, white or dark grey, so the grounds look alike but not the same.
local WALLS = {
	{ colour = Color3.fromRGB(30, 30, 34), material = Enum.Material.Brick },
	{ colour = Color3.fromRGB(232, 230, 224), material = Enum.Material.Brick },
	{ colour = Color3.fromRGB(74, 76, 82), material = Enum.Material.Concrete },
}
local OLD_WALL = Color3.fromRGB(86, 36, 36)
local OLD_ROOF = Color3.fromRGB(117, 0, 0)
local WHITE = Color3.fromRGB(240, 240, 236)

local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.12
end

local function part(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A board with the club's emblem on `face`.
local function emblemBoard(club: any, size: number, cf: CFrame, face: Enum.NormalId, parent: Instance)
	local board = part("Emblema", Vector3.new(size, size, 0.3), cf, Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Emblema"
	gui.Face = face
	gui.CanvasSize = Vector2.new(300, 300)
	gui.LightInfluence = 1
	gui.Parent = board
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.9, 0.9)
	holder.Position = UDim2.fromScale(0.05, 0.05)
	holder.Parent = gui
	Emblem.draw(holder, club, { year = false })
end

local function sign(text: string, size: Vector3, cf: CFrame, ground: Color3, ink: Color3, parent: Instance)
	local board = part("Letreiro", size, cf, ground, Enum.Material.SmoothPlastic, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Texto"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(size.X * 30, size.Y * 30)
	gui.LightInfluence = 1
	gui.AutoLocalize = false -- a proper name: never translated
	gui.Parent = board
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(0.94, 0.8)
	l.Position = UDim2.fromScale(0.03, 0.1)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = ink
	l.Text = text
	l.Parent = gui
end

local function inkFor(colour: Color3): Color3
	return if colour.R * 0.3 + colour.G * 0.59 + colour.B * 0.11 > 0.7 then Color3.fromRGB(24, 24, 28) else WHITE
end

-- The sede: the hand-made model, smaller, in this club's colours. Its door side faces -Z of `at`.
local function sede(club: any, index: number, at: CFrame, parent: Instance): (Model?, Vector3)
	local template = ServerStorage:FindFirstChild("SedeModelo")
	if not template or not template:IsA("Model") then
		warn("[Ultras FC] SedeBuilder: ServerStorage.SedeModelo is missing")
		return nil, Vector3.zero
	end
	local model = template:Clone()
	model.Name = "Sede"
	model:ScaleTo(SCALE)
	local wall = WALLS[(index - 1) % #WALLS + 1]
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			if near(d.Color, OLD_ROOF) then
				d.Color = club.color
			elseif near(d.Color, OLD_WALL) then
				if d.Size.Y < 2 then
					-- floor and ceiling slabs
					d.Color = Color3.fromRGB(58, 60, 66)
					d.Material = Enum.Material.Concrete
				else
					d.Color = wall.colour
					d.Material = wall.material
				end
			end
		end
	end
	local _, size = model:GetBoundingBox()
	model:PivotTo(at * CFrame.new(0, size.Y / 2, 0))
	model.Parent = parent
	return model, size
end

local function pitch(club: any, at: CFrame, parent: Instance, PITCH: Vector3)
	local folder = Instance.new("Model")
	folder.Name = "Campo"
	local w, d = PITCH.X, PITCH.Z
	part("Relva", PITCH, at * CFrame.new(0, 0.2, 0), Color3.fromRGB(70, 130, 66), Enum.Material.Grass, folder)
	-- The lines.
	local LINE = Color3.fromRGB(236, 236, 232)
	for _, z in { -d / 2 + 1, d / 2 - 1 } do
		part("Linha", Vector3.new(w - 2, 0.06, 0.4), at * CFrame.new(0, 0.44, z), LINE, Enum.Material.SmoothPlastic, folder).CanCollide = false
	end
	for _, x in { -w / 2 + 1, 0, w / 2 - 1 } do
		part("Linha", Vector3.new(0.4, 0.06, d - 2), at * CFrame.new(x, 0.44, 0), LINE, Enum.Material.SmoothPlastic, folder).CanCollide = false
	end
	-- Two goals.
	for _, side in { -1, 1 } do
		local x = side * (w / 2 - 1)
		for _, z in { -4, 4 } do
			part("Poste", Vector3.new(0.4, 4.4, 0.4), at * CFrame.new(x, 2.6, z), WHITE, Enum.Material.Metal, folder)
		end
		part("Trave", Vector3.new(0.4, 0.4, 8.4), at * CFrame.new(x, 4.8, 0), WHITE, Enum.Material.Metal, folder)
		local net = part("Rede", Vector3.new(0.2, 4.4, 8), at * CFrame.new(x + side * 1.6, 2.6, 0), WHITE, Enum.Material.Fabric, folder)
		net.Transparency = 0.6
	end
	-- The fence, in the club's colours: posts and two rails, open in the middle of the side that faces the sede.
	local colour: Color3 = club.color
	local second: Color3 = club.accent or club.second
	local function run(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		local mid = (from + to) / 2
		local cf = at * CFrame.lookAt(mid, to)
		part("Vedacao", Vector3.new(0.3, 0.3, length), cf * CFrame.new(0, 3.2, 0), colour, Enum.Material.Metal, folder)
		part("Vedacao", Vector3.new(0.3, 0.3, length), cf * CFrame.new(0, 1.8, 0), second, Enum.Material.Metal, folder)
		local posts = math.max(1, math.floor(length / 7))
		for i = 0, posts do
			local p = from:Lerp(to, i / posts)
			part("Poste", Vector3.new(0.4, 3.2, 0.4), at * CFrame.new(p.X, 1.8, p.Z), colour, Enum.Material.Metal, folder)
		end
	end
	local hw, hd = w / 2 + 2, d / 2 + 2
	run(Vector3.new(-hw, 0, hd), Vector3.new(hw, 0, hd))
	run(Vector3.new(-hw, 0, -hd), Vector3.new(-5, 0, -hd))
	run(Vector3.new(5, 0, -hd), Vector3.new(hw, 0, -hd))
	run(Vector3.new(-hw, 0, -hd), Vector3.new(-hw, 0, hd))
	run(Vector3.new(hw, 0, -hd), Vector3.new(hw, 0, hd))
	-- The emblem at one end.
	emblemBoard(club, 7, at * CFrame.new(hw, 5.5, 0) * CFrame.Angles(0, math.rad(90), 0), Enum.NormalId.Front, folder)
	folder.Parent = parent
end

-- Takes the generic houses (Predio) of the blocks out of the way of the ground.
local function clear(centre: CFrame, size: Vector3): number
	local removed = 0
	local city = workspace:FindFirstChild("Cidade")
	local blocks = city and city:FindFirstChild("Quarteiroes")
	if not blocks then
		return 0
	end
	local params = OverlapParams.new()
	params.FilterDescendantsInstances = { blocks }
	params.FilterType = Enum.RaycastFilterType.Include
	local gone: { [Instance]: boolean } = {}
	for _, hit in workspace:GetPartBoundsInBox(centre * CFrame.new(0, 30, 0), Vector3.new(size.X, 80, size.Z), params) do
		local top: Instance = hit
		while top.Parent and not string.match(top.Parent.Name, "^Quarteirao_") do
			top = top.Parent
		end
		if top.Name == "Predio" and not gone[top] then
			gone[top] = true
			top:Destroy()
			removed += 1
		end
	end
	return removed
end

--[[
	Builds (or builds again) the ground of `clubId`. Returns how many generic
	houses were removed. `site` in Config: { x, z, turn (degrees, optional) }.
]]
function SedeBuilder.build(clubId: string): number
	local club = (Config.Clubs :: any)[clubId]
	local site = club and club.site
	if not site or site.existing then
		return 0
	end
	local index = table.find(Config.ClubOrder, clubId) or 1
	local root = workspace:FindFirstChild("Recintos")
	if not root then
		root = Instance.new("Folder")
		root.Name = "Recintos"
		root.Parent = workspace
	end
	local old = root:FindFirstChild("Recinto_" .. clubId)
	if old then
		old:Destroy()
	end
	local ground = Instance.new("Model")
	ground.Name = "Recinto_" .. clubId
	local y = site.y or 0.7 -- on top of the pavement of the block
	local base = CFrame.new(site.x, y, site.z) * CFrame.Angles(0, math.rad(site.turn or 0), 0)

	-- How big the pitch can be here: what is left of the block beside the sede.
	local sedeDepth = 60 * SCALE
	local PITCH = PITCH_MAX
	local city = workspace:FindFirstChild("Cidade")
	local blocks = city and city:FindFirstChild("Quarteiroes")
	local block = blocks and site.block and blocks:FindFirstChild("Quarteirao_" .. site.block)
	local floor = block and block:FindFirstChild("Passeio")
	if floor and floor:IsA("BasePart") then
		local roomX = floor.Size.X - MARGIN * 2
		local roomZ = math.min(floor.Size.Z, 140) - MARGIN * 2 - sedeDepth - GAP - 4
		PITCH = Vector3.new(math.clamp(roomX - 4, 40, site.maxWidth or PITCH_MAX.X), PITCH_MAX.Y, math.clamp(roomZ, 30, PITCH_MAX.Z))
	end
	-- The sede in the north half of the site, the pitch in the south half.
	local total = sedeDepth + GAP + PITCH.Z + 4
	local removed = clear(base, Vector3.new(math.max(80 * SCALE, PITCH.X + 4) + 4, 0, total + 4))
	local model, size = sede(club, index, base * CFrame.new(0, 0, -total / 2 + sedeDepth / 2), ground)
	if model then
		-- Over the door (the side that looks at the pitch): the emblem and the claque's name.
		local front = base * CFrame.new(0, 0, -total / 2 + sedeDepth + 0.4)
		emblemBoard(club, 6, front * CFrame.new(0, size.Y * 0.62, 0) * CFrame.Angles(0, math.pi, 0), Enum.NormalId.Front, ground)
		sign(club.claque, Vector3.new(22, 3, 0.3), front * CFrame.new(0, size.Y * 0.62 - 5.2, 0) * CFrame.Angles(0, math.pi, 0), club.color, inkFor(club.color), ground)
		sign(club.nameUpper, Vector3.new(22, 2, 0.3), front * CFrame.new(0, size.Y * 0.62 + 4.6, 0) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(20, 20, 24), WHITE, ground)
	end
	pitch(club, base * CFrame.new(0, 0, total / 2 - PITCH.Z / 2 - 2), ground, PITCH)
	ground:SetAttribute("Total", total)
	ground.Parent = root
	return removed
end

function SedeBuilder.buildAll(): number
	local removed = 0
	for _, clubId in Config.ClubOrder do
		removed += SedeBuilder.build(clubId)
	end
	return removed
end

return SedeBuilder
