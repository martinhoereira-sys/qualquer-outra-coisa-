--!strict
--[[
	The tifo's sheet as CLOTH, on this screen.

	The server lays the sheet out flat (one part called "Tela", in
	Workspace.Stadium, with what is drawn on it in its attributes). Here it
	becomes one smooth cloth (the same mesh as the pole flag: shared/PanoMesh),
	painted with the same drawing, and it ripples from side to side like a
	cloth held up by a whole stand. Still ONE sheet: no strips, no pieces.

	If the cloth cannot be made (a phone short of memory), the flat sheet
	stays as it is. Looks only: nothing is sent.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PanoMesh = require(Shared:WaitForChild("PanoMesh"))
local TifoDesigns = require(Shared:WaitForChild("TifoDesigns"))

local W = Config.TifoCloth

type Sheet = { part: BasePart, cloth: PanoMesh.Cloth, corner: CFrame, width: number, height: number, points: { Vector3 } }

local sheets: { [BasePart]: Sheet } = {}

-- The drawing of the sheet, painted on an image (what the flat sheet has on its SurfaceGui).
local function paint(tela: BasePart, teamId: string): EditableImage
	local tools = PanoMesh.tools
	local pw = W.pixels
	local ph = math.max(16, math.floor(pw * tela.Size.Y / tela.Size.X))
	local img = AssetService:CreateEditableImage({ Size = Vector2.new(pw, ph) })
	local team = Config.Teams[teamId]
	tools.rect(img, 0, 0, pw, ph, team.color)
	local lines = string.split(tostring(tela:GetAttribute("Lines") or ""), "\n")
	if tela:GetAttribute("Emblem") == true and (team :: any).emblem then
		-- The club's emblem itself, whole, in the middle.
		tools.stamp(img, teamId, pw / 2, ph / 2, math.floor(ph * 0.9))
	elseif #lines > 0 and #lines[1] > 0 then
		local rows, cols = #lines, #lines[1]
		local cw, rh = pw / cols, ph / rows
		for r = 1, rows do
			for c = 1, cols do
				local code = string.sub(lines[r], c, c)
				if code ~= "E" and code ~= "" then
					tools.rect(img, math.floor((c - 1) * cw), math.floor((r - 1) * rh), math.ceil(cw), math.ceil(rh), TifoDesigns.colour(code, teamId))
				end
			end
		end
	end
	local message = tela:GetAttribute("Message")
	if type(message) == "string" and message ~= "" then
		-- The words in block letters, as wide as the sheet lets them be.
		local cell = math.max(2, math.floor(pw * 0.9 / (#message * 5)))
		tools.word(img, string.upper(message), pw / 2, ph / 2, cell, Color3.fromRGB(245, 245, 240))
	end
	-- The cloth shows an image the other way round: it is painted mirrored, to read right.
	local w, h = pw, ph
	local pixels = img:ReadPixelsBuffer(Vector2.zero, Vector2.new(w, h))
	local turned = buffer.create(buffer.len(pixels))
	for y = 0, h - 1 do
		local line = y * w
		for x = 0, w - 1 do
			buffer.writeu32(turned, (line + (w - 1 - x)) * 4, buffer.readu32(pixels, (line + x) * 4))
		end
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), turned)
	return img
end

local function adopt(d: Instance)
	if not d:IsA("BasePart") or d.Name ~= "Tela" or sheets[d] then
		return
	end
	local teamId = d:GetAttribute("Team")
	if type(teamId) ~= "string" or not Config.Teams[teamId] then
		return
	end
	local width, height = d.Size.X, d.Size.Y
	local ok, image = pcall(paint, d, teamId)
	local cloth = if ok then PanoMesh.sheet(W.columns, W.rows, width, height, image, workspace) else nil
	if not cloth then
		return -- the flat sheet stays
	end
	-- The cloth takes the flat sheet's place.
	d.Transparency = 1
	for _, child in d:GetChildren() do
		if child:IsA("SurfaceGui") then
			child.Enabled = false
		end
	end
	-- The top corner of the sheet, with the drawing reading right from the pitch.
	local corner = d.CFrame * CFrame.Angles(0, if W.flip then math.pi else 0, 0) * CFrame.new(-width / 2, height / 2, 0)
	sheets[d] = { part = d, cloth = cloth, corner = corner, width = width, height = height, points = {} }
	d.AncestryChanged:Connect(function()
		if not d:IsDescendantOf(workspace) then
			local sheet = sheets[d]
			sheets[d] = nil
			if sheet then
				PanoMesh.destroy(sheet.cloth)
			end
		end
	end)
end

local stadium = workspace:WaitForChild("Stadium")
for _, d in stadium:GetDescendants() do
	adopt(d)
end
stadium.DescendantAdded:Connect(function(d)
	-- (Its attributes are set right after it is made.)
	task.defer(adopt, d)
end)

local last = 0
RunService.RenderStepped:Connect(function()
	if next(sheets) == nil then
		return
	end
	local t = os.clock()
	if t - last < 1 / W.rate then
		return
	end
	last = t
	for _, sheet in sheets do
		local cols, rows = sheet.cloth.cols, sheet.cloth.rows
		local points = sheet.points
		local corner = sheet.corner
		for j = 0, rows do
			local v = j / rows
			for i = 0, cols do
				local u = i / cols
				-- Waves running along the sheet, a slower swell up and down it,
				-- and a little flutter: cloth held up by many hands.
				local z = math.sin(u * W.waves * math.pi * 2 - t * W.speed) * W.amplitude
					+ math.sin(v * math.pi * 1.5 + t * W.speed * 0.6 + u * 3) * W.amplitude * 0.5
					+ math.sin((u + v) * 11 + t * W.speed * 2.3) * W.amplitude * 0.15
				points[j * (cols + 1) + i + 1] = corner:PointToWorldSpace(Vector3.new(u * sheet.width, -v * sheet.height, z))
			end
		end
		PanoMesh.update(sheet.cloth, corner, points)
	end
end)
