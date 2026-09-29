--!strict
--[[
	O pano liso: uma malha so (EditableMesh), dobrada ponto a ponto pela
	simulacao (PanoSim). Sem placas nem dobras em bico: parece tecido.

	So existe no ecra de cada um (e assim que o EditableMesh funciona). O rig
	com juntas (PanoRig) continua la, invisivel: e o mesmo pano para quem
	anima no Animation Editor, e e o que se ve se este nao se puder criar
	(um telemovel sem memoria, por exemplo).

	O desenho (cor, moldura, emblema, sigla) e pintado numa imagem
	(EditableImage) e posto por cima, dos dois lados, a ler bem de ambos.
]]

local AssetService = game:GetService("AssetService")

local PanoMesh = {}

export type Design = { kind: string, colour: Color3, short: string? }

export type Cloth = {
	part: MeshPart,
	mesh: EditableMesh,
	front: { number },
	back: { number },
	center: Vector3, -- o centro da caixa da malha (a MeshPart fica ai)
	cols: number,
	rows: number,
}

local WHITE = Color3.fromRGB(246, 246, 246)
local DARK = Color3.fromRGB(18, 18, 22)

-- Letras de blocos 4x6 (como as do tifo), para a sigla da claque.
local GLYPHS: { [string]: { string } } = {
	A = { ".##.", "#..#", "#..#", "####", "#..#", "#..#" },
	B = { "###.", "#..#", "###.", "#..#", "#..#", "###." },
	C = { ".###", "#...", "#...", "#...", "#...", ".###" },
	D = { "###.", "#..#", "#..#", "#..#", "#..#", "###." },
	E = { "####", "#...", "###.", "#...", "#...", "####" },
	F = { "####", "#...", "###.", "#...", "#...", "#..." },
	G = { ".###", "#...", "#...", "#.##", "#..#", ".###" },
	H = { "#..#", "#..#", "####", "#..#", "#..#", "#..#" },
	I = { "###.", ".#..", ".#..", ".#..", ".#..", "###." },
	L = { "#...", "#...", "#...", "#...", "#...", "####" },
	M = { "#..#", "####", "####", "#..#", "#..#", "#..#" },
	N = { "#..#", "##.#", "####", "#.##", "#..#", "#..#" },
	O = { ".##.", "#..#", "#..#", "#..#", "#..#", ".##." },
	P = { "###.", "#..#", "###.", "#...", "#...", "#..." },
	R = { "###.", "#..#", "###.", "#.#.", "#..#", "#..#" },
	S = { ".###", "#...", ".##.", "...#", "...#", "###." },
	T = { "####", ".#..", ".#..", ".#..", ".#..", ".#.." },
	U = { "#..#", "#..#", "#..#", "#..#", "#..#", ".##." },
	V = { "#..#", "#..#", "#..#", "#..#", ".##.", ".#.." },
}

local function rect(img: EditableImage, x: number, y: number, w: number, h: number, colour: Color3)
	img:DrawRectangle(Vector2.new(math.floor(x), math.floor(y)), Vector2.new(math.max(1, math.floor(w)), math.max(1, math.floor(h))), colour, 0, Enum.ImageCombineType.Overwrite)
end

-- A sigla em letras de blocos, centrada em (cx, cy), cada bloco `cell` pixeis.
local function word(img: EditableImage, text: string, cx: number, cy: number, cell: number, colour: Color3)
	local letters = math.min(#text, 4)
	local width = letters * 5 * cell - cell
	local x0 = cx - width / 2
	local y0 = cy - 3 * cell
	for n = 1, letters do
		local glyph = GLYPHS[string.upper(string.sub(text, n, n))]
		if glyph then
			for row, line in glyph do
				for col = 1, 4 do
					if string.sub(line, col, col) == "#" then
						rect(img, x0 + (n - 1) * 5 * cell + (col - 1) * cell, y0 + (row - 1) * cell, cell, cell, colour)
					end
				end
			end
		end
	end
end

-- O desenho da bandeira, pintado numa imagem 3:2.
local function paint(design: Design): EditableImage
	-- A bandeira grande e quadrada (2 x 2 m); a bandeirinha 3:2.
	local W, H = if design.kind == "mastro" then 200 else 240, if design.kind == "mastro" then 200 else 160
	local img = AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })
	local c = design.colour
	rect(img, 0, 0, W, H, c)
	if design.kind == "mastro" then
		-- Moldura branca, emblema redondo ao meio com a sigla.
		local t = 7
		rect(img, 9, 9, W - 18, t, WHITE)
		rect(img, 9, H - 9 - t, W - 18, t, WHITE)
		rect(img, 9, 9, t, H - 18, WHITE)
		rect(img, W - 9 - t, 9, t, H - 18, WHITE)
		img:DrawCircle(Vector2.new(W / 2, H / 2), 50, DARK, 0, Enum.ImageCombineType.Overwrite)
		img:DrawCircle(Vector2.new(W / 2, H / 2), 44, WHITE, 0, Enum.ImageCombineType.Overwrite)
		word(img, design.short or "", W / 2, H / 2, 5, c)
	else
		-- A bandeirinha: cor, branco, cor; a sigla na faixa branca.
		rect(img, 0, H / 3, W, H / 3, WHITE)
		word(img, design.short or "", W / 2, H / 2, 6, c)
	end
	return img
end

--[[
	Cria o pano liso para uma simulacao de `cols` x `rows` quadrados, de
	`width` x `height` studs. Devolve nil se nao se puder (e fica o rig).
]]
function PanoMesh.new(cols: number, rows: number, width: number, height: number, design: Design, parent: Instance): Cloth?
	local ok, result = pcall(function(): Cloth
		local mesh = AssetService:CreateEditableMesh()
		local front: { number } = {}
		local back: { number } = {}
		local frontNormals: { number } = {}
		local backNormals: { number } = {}
		local uvFront: { number } = {}
		local uvBack: { number } = {}
		for j = 0, rows do
			for i = 0, cols do
				local p = Vector3.new(i / cols * width, -j / rows * height, 0)
				local k = j * (cols + 1) + i + 1
				front[k] = mesh:AddVertex(p)
				back[k] = mesh:AddVertex(p)
				frontNormals[k] = mesh:AddNormal() -- calculada sozinha a cada mexida
				backNormals[k] = mesh:AddNormal()
				uvFront[k] = mesh:AddUV(Vector2.new(1 - i / cols, j / rows))
				-- Do outro lado le-se ao contrario: espelha-se, para se ler bem.
				uvBack[k] = mesh:AddUV(Vector2.new(i / cols, j / rows))
			end
		end
		-- Dois pontos soltos que so alargam a caixa da malha: o pano pode
		-- ondular para longe sem o Roblox deixar de o desenhar.
		local lo = Vector3.new(-width, height, -width)
		local hi = Vector3.new(width * 2, -height * 2, width)
		mesh:AddVertex(lo)
		mesh:AddVertex(hi)

		local function face(ids: { number }, normals: { number }, uvs: { number }, a: number, b: number, c: number)
			local f = mesh:AddTriangle(ids[a], ids[b], ids[c])
			mesh:SetFaceNormals(f, { normals[a], normals[b], normals[c] })
			mesh:SetFaceUVs(f, { uvs[a], uvs[b], uvs[c] })
		end
		for j = 0, rows - 1 do
			for i = 0, cols - 1 do
				local a = j * (cols + 1) + i + 1
				local b = a + 1
				local c = a + cols + 1
				local d = c + 1
				-- Frente e verso (voltas ao contrario).
				face(front, frontNormals, uvFront, a, c, b)
				face(front, frontNormals, uvFront, b, c, d)
				face(back, backNormals, uvBack, a, b, c)
				face(back, backNormals, uvBack, b, d, c)
			end
		end

		local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
		part.Name = "PanoLiso"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Fabric
		part.TextureContent = Content.fromObject(paint(design))
		part.Parent = parent
		return {
			part = part,
			mesh = mesh,
			front = front,
			back = back,
			center = (lo + hi) / 2,
			cols = cols,
			rows = rows,
		}
	end)
	if not ok then
		warn("[Ultras FC] Pano liso nao disponivel (fica o de tiras): " .. tostring(result))
		return nil
	end
	return result
end

--[[
	Poe o pano nos pontos da simulacao. `corner` e o canto do pano no mastro
	(o sitio de onde se mediram os pontos ao criar).
]]
function PanoMesh.update(cloth: Cloth, corner: CFrame, points: { Vector3 })
	-- A malha desenha os pontos tal como sao dados, a partir da MeshPart: a
	-- MeshPart fica no canto do pano e os pontos sao relativos a ele.
	cloth.part.CFrame = corner
	local mesh = cloth.mesh
	for k, world in points do
		local id = cloth.front[k]
		if id then
			local p = corner:PointToObjectSpace(world)
			mesh:SetPosition(id, p)
			mesh:SetPosition(cloth.back[k], p)
		end
	end
end

function PanoMesh.destroy(cloth: Cloth)
	cloth.part:Destroy()
	pcall(function()
		cloth.mesh:Destroy()
	end)
end

return PanoMesh
