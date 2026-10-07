--!strict
--[[
	A cidade a volta, e as duas sedes.

	Isto existe por uma razao: nao se entra num estadio por magia. Apareces na
	sede da tua claque, sais para a rua, e andas ate la — e no caminho que o
	corteo ha-de acontecer.

	A cidade vive no mapa (Workspace.Cidade), feita uma vez pelo CityMap e
	depois mexida a mao no Studio por quem quiser. Aqui le-se o que la estiver:
	- Cidade.Sedes.Sede_<equipa>: cada sede, onde quer que esteja e virada
	  para onde estiver, de qualquer tamanho. A frente (a seta Front do pivo)
	  aponta para a rua: e ai a porta;
	- Spawn_<equipa>: uma peca em qualquer sitio da cidade, se houver, manda
	  mais do que a sede: e ai que se aparece e que o corteo comeca;
	- Cidade.Chegada: onde aparece quem ainda nao escolheu lado;
	- Cidade.Rotas.<equipa>: o caminho de sempre do corteo, pontos 1, 2, 3...
	- Cidade.EstadioArea: so uma marca no Studio de onde o estadio aparece.
	Os marcadores ficam invisiveis quando o jogo arranca. Se nao houver cidade
	no mapa, gera-se uma na hora.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Clubhouse = require(script.Parent:WaitForChild("Clubhouse"))
local CityMap = require(script.Parent:WaitForChild("CityMap"))
local StadiumPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StadiumPlan"))

local City = {}

local spawnPoints: { [string]: Vector3 } = {}
local routes: { [string]: { Vector3 } } = {}
local neutral: Vector3? = nil


local function hide(part: Instance)
	if part:IsA("BasePart") then
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceGui") then
				child:Destroy()
			end
		end
	end
end

--[[
	Onde se chega quando ainda nao se e de lado nenhum: a praca, entre as duas
	sedes. Escolher o lado e ir ate uma delas, nao carregar num botao.
]]
function City.arrivalPoint(): Vector3?
	return neutral
end

function City.spawnPoint(teamId: string): Vector3?
	return spawnPoints[teamId]
end

-- O caminho de sempre do corteo desta claque, a comecar a porta da sede.
function City.route(teamId: string): { Vector3 }
	local list = {}
	local start = spawnPoints[teamId]
	if start then
		table.insert(list, start)
	end
	for _, point in routes[teamId] or {} do
		table.insert(list, point)
	end
	return list
end

--[[
	As mesas de uma sede: os modelos "Desk" a menos de 90 studs da porta.
	Se houver tres, cada uma leva um NPC (Clubhouse.staff), por ordem da
	esquerda para a direita de quem entra: inscricao, loja, lider. Devolve se
	ficou com NPCs.
]]
local function staffDesks(teamId: string, door: Vector3, parent: Instance): boolean
	local desks: { Model } = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d.Name == "Desk" and (d:GetPivot().Position - door).Magnitude < 90 then
			table.insert(desks, d)
		end
	end
	if #desks < 3 then
		return false
	end

	-- Quem entra vai da porta para as mesas; a direita dele e a direita da fila.
	local centre = Vector3.zero
	for _, d in desks do
		centre += d:GetPivot().Position
	end
	centre /= #desks
	local flat = Vector3.new(centre.X - door.X, 0, centre.Z - door.Z)
	local inward = if flat.Magnitude > 0.1 then flat.Unit else -Vector3.zAxis
	local right = inward:Cross(Vector3.yAxis)
	table.sort(desks, function(a, b)
		return a:GetPivot().Position:Dot(right) < b:GetPivot().Position:Dot(right)
	end)

	local folder = Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = parent
	Clubhouse.staff(teamId, { desks[1], desks[2], desks[3] }, inward, folder)
	return true
end

--[[
	WHERE EACH PLACE OF THE MATCH LIVES TODAY. The two places (home, away) are
	taken by the two clubs of the match, and each club has its ground in the
	city (Config.Clubs[...].site). City.place puts the place's things (the
	door of the corteo, the desk, the drum, the bikes, where one appears) at
	the ground of the club that has it now, and works out the way from there to
	the stadium. It runs at the start and again whenever the match changes.
]]
local placeHand: ((string, string?) -> ())? = nil
local handRoutes: { [string]: { Vector3 } } = {}
local placed: { [string]: { Instance } } = {}

-- The streets, read from the blocks of the map: the lines half-way between two blocks.
local function streets(): ({ number }, { number })
	local xs: { { number } }, zs: { { number } } = {}, {}
	local city = workspace:FindFirstChild("Cidade")
	local blocks = city and city:FindFirstChild("Quarteiroes")
	if blocks then
		for _, block in blocks:GetChildren() do
			local floor = block:FindFirstChild("Passeio")
			if floor and floor:IsA("BasePart") then
				table.insert(xs, { floor.Position.X - floor.Size.X / 2, floor.Position.X + floor.Size.X / 2 })
				table.insert(zs, { floor.Position.Z - floor.Size.Z / 2, floor.Position.Z + floor.Size.Z / 2 })
			end
		end
	end
	local function gaps(spans: { { number } }): { number }
		table.sort(spans, function(a, b)
			return a[1] < b[1]
		end)
		local lines: { number } = {}
		local reach = -math.huge
		for _, span in spans do
			if reach > -math.huge and span[1] > reach + 4 then
				table.insert(lines, (reach + span[1]) / 2)
			end
			reach = math.max(reach, span[2])
		end
		return lines
	end
	return gaps(xs), gaps(zs)
end

local function nearest(lines: { number }, value: number): number
	local best, distance = value, math.huge
	for _, line in lines do
		if math.abs(line - value) < distance then
			best, distance = line, math.abs(line - value)
		end
	end
	return best
end

--[[
	The way from a door to the gate of this place's stand, along the streets:
	out to the nearest street, along it to a cross street, along that one to
	the street beside the stadium on the gate's side, and down it to the gate.
	(The gate itself is added by March.)
]]
local function autoRoute(door: Vector3, teamId: string): { Vector3 }
	local xs, zs = streets()
	if #xs == 0 or #zs == 0 then
		return {}
	end
	local gate = StadiumPlan.claqueGate(teamId)
	local side = Config.Teams[teamId].side
	-- The street beside the stadium, on the side of the gate.
	local ring = nearest(xs, gate.X + side * 60)
	local out = nearest(xs, door.X)
	-- The cross street that makes the walk shortest (they all pass outside the stadium).
	local cross, shortest = zs[1], math.huge
	for _, line in zs do
		local length = math.abs(door.Z - line) + math.abs(line - gate.Z)
		if length < shortest then
			cross, shortest = line, length
		end
	end
	local list: { Vector3 } = {}
	local function add(x: number, z: number)
		local last = list[#list]
		if not last or (Vector3.new(x, 3, z) - last).Magnitude > 2 then
			table.insert(list, Vector3.new(x, 3, z))
		end
	end
	add(out, door.Z)
	add(out, cross)
	add(ring, cross)
	add(ring, gate.Z)
	return list
end

--[[
	The way round for the bus of the club in this place: a loop of streets (the
	points are in the middle of them) by its ground and by the stadium's
	players' stop `stop`. Returns the points and where the bus waits (on the
	street nearest the ground).
]]
-- Inside the built sede of `clubId`: the middle of a row of desks at the back of the room, its +Z to the door.
local function insideOf(clubId: string): CFrame?
	local grounds = workspace:FindFirstChild("Recintos")
	local ground = grounds and grounds:FindFirstChild("Recinto_" .. clubId)
	local sede = ground and ground:FindFirstChild("Sede")
	if not sede or not sede:IsA("Model") then
		return nil
	end
	local box, size = sede:GetBoundingBox()
	return CFrame.new(box.Position.X, box.Position.Y - size.Y / 2 + 0.6, box.Position.Z) * box.Rotation * CFrame.new(0, 0, -size.Z * 0.22)
end

-- The desks a hand-made sede already has, near `door`, left to right for whoever comes in.
local function ownDesks(door: Vector3): { Model }
	local desks: { Model } = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d.Name == "Desk" and (d:GetPivot().Position - door).Magnitude < 90 then
			table.insert(desks, d)
		end
	end
	if #desks < 3 then
		return {}
	end
	local centre = Vector3.zero
	for _, d in desks do
		centre += d:GetPivot().Position
	end
	centre /= #desks
	local flat = Vector3.new(centre.X - door.X, 0, centre.Z - door.Z)
	local inward = if flat.Magnitude > 0.1 then flat.Unit else -Vector3.zAxis
	local right = inward:Cross(Vector3.yAxis)
	table.sort(desks, function(a, b)
		return a:GetPivot().Position:Dot(right) < b:GetPivot().Position:Dot(right)
	end)
	return { desks[1], desks[2], desks[3] }
end

function City.dressOthers()
	local old = workspace:FindFirstChild("SedesParadas")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "SedesParadas"
	root.Parent = workspace
	local playing: { [string]: boolean } = {}
	for _, teamId in Config.TeamOrder do
		playing[Config.Teams[teamId].club] = true
	end
	for _, clubId in Config.ClubOrder do
		local club = (Config.Clubs :: any)[clubId]
		local site = club.site
		if playing[clubId] or not site then
			continue
		end
		local frame: CFrame? = nil
		if not site.existing then
			-- A ground built from Config: the same door as when the club plays (City.place).
			local base = CFrame.new(site.x, site.y or 0.7, site.z) * CFrame.Angles(0, math.rad(site.turn or 0), 0)
			local built = workspace:FindFirstChild("Recintos") and workspace.Recintos:FindFirstChild("Recinto_" .. clubId)
			local total = (built and built:GetAttribute("Total")) or 86
			local doorAt = (base * CFrame.new(36, 0, -total / 2 + 21)).Position
			frame = CFrame.lookAt(doorAt, doorAt - base.RightVector)
		else
			-- A sede made by hand: at its sign.
			local marker = if site.marker then workspace:FindFirstChild(site.marker, true) else nil
			if marker and marker:IsA("Model") then
				local pivot = marker:GetPivot()
				local box, size = marker:GetBoundingBox()
				local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
				local forward = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
				local ground = Vector3.new(pivot.Position.X, box.Position.Y - size.Y / 2, pivot.Position.Z)
				frame = CFrame.lookAt(ground, ground - forward)
			end
		end
		if frame then
			local holder = Instance.new("Folder")
			holder.Name = "Sede_" .. clubId
			holder.Parent = root
			-- The people are INSIDE the sede; only the bikes are at the door.
			if site.existing then
				task.spawn(Clubhouse.idle, club, frame, holder, nil, ownDesks(frame.Position))
			else
				task.spawn(Clubhouse.idle, club, frame, holder, insideOf(clubId), nil)
			end
		end
	end
end

function City.busLoop(teamId: string, stop: Vector3): ({ Vector3 }, Vector3?)
	local xs, zs = streets()
	-- The bus waits by the training pitch (that is where the players are), or by the door.
	local door = spawnPoints[teamId]
	local grounds = workspace:FindFirstChild("Recintos")
	local ground = grounds and grounds:FindFirstChild("Recinto_" .. Config.Teams[teamId].club)
	local grass = ground and ground:FindFirstChild("Relva", true)
	if grass and grass:IsA("BasePart") then
		door = grass.Position
	end
	if #xs < 2 or #zs < 2 or not door then
		return {}, nil
	end
	local zStadium = nearest(zs, stop.Z)
	-- The street along the ground (not the stadium's own).
	local zGround, best = zStadium, math.huge
	for _, z in zs do
		if z ~= zStadium and math.abs(z - door.Z) < best then
			zGround, best = z, math.abs(z - door.Z)
		end
	end
	-- Two streets across: the one nearest the ground, and the one nearest the stop (another one).
	local xGround = nearest(xs, door.X)
	local xStop, bestX = xGround, math.huge
	-- (The one just PAST the stop, coming from the ground: the bus has to go by it.)
	for _, x in xs do
		local past = if xGround > stop.X then x < stop.X - 20 else x > stop.X + 20
		if x ~= xGround and past and math.abs(x - stop.X) < bestX then
			xStop, bestX = x, math.abs(x - stop.X)
		end
	end
	local nodes = {
		Vector3.new(xGround, 0, zGround),
		Vector3.new(xGround, 0, zStadium),
		Vector3.new(xStop, 0, zStadium),
		Vector3.new(xStop, 0, zGround),
	}
	return nodes, door
end

function City.place(teamId: string)
	for _, inst in placed[teamId] or {} do
		inst:Destroy()
	end
	placed[teamId] = {}
	local club = Config.Teams[teamId]
	local site = club.site
	if site and not site.existing then
		-- A ground built from Config (SedeBuilder): the door is beside the sede, on the street side.
		local base = CFrame.new(site.x, site.y or 0.7, site.z) * CFrame.Angles(0, math.rad(site.turn or 0), 0)
		-- (The sede is at the north end of the ground, whatever the size of the pitch.)
		local built = workspace:FindFirstChild("Recintos") and workspace.Recintos:FindFirstChild("Recinto_" .. club.club)
		local total = (built and built:GetAttribute("Total")) or 86
		local doorAt = (base * CFrame.new(36, 0, -total / 2 + 21)).Position
		local forward = base.RightVector
		local frame = CFrame.lookAt(doorAt, doorAt - forward)
		local holder = Instance.new("Folder")
		holder.Name = "Sede_" .. teamId .. "_recheio"
		holder.Parent = workspace
		table.insert(placed[teamId], holder)
		spawnPoints[teamId] = doorAt + forward * 4 + Vector3.new(0, 3.5, 0)
		-- The three at their desks, INSIDE the sede: sign up, shop, capo.
		local inside = insideOf(club.club)
		if inside then
			local desks = Clubhouse.desks(inside, holder)
			Clubhouse.equip(teamId, frame, holder, 0, true)
			Clubhouse.staff(teamId, desks, -Vector3.new(inside.ZVector.X, 0, inside.ZVector.Z).Unit, holder)
		else
			Clubhouse.equip(teamId, frame, holder, 0)
		end
		Clubhouse.bikeRack(teamId, frame * CFrame.new(10, 0, 4), holder)
		routes[teamId] = autoRoute(doorAt, teamId)
		return
	end
	-- A sede made by hand: its things are remembered, to take them away when the place moves.
	local markerName = site and site.marker
	local marker = if markerName then workspace:FindFirstChild(markerName, true) else nil
	local before: { [Instance]: boolean } = {}
	if marker then
		for _, child in marker:GetChildren() do
			before[child] = true
		end
	end
	if placeHand then
		placeHand(teamId, markerName)
	end
	if marker then
		for _, child in marker:GetChildren() do
			if not before[child] then
				table.insert(placed[teamId], child)
			end
		end
	end
	-- The hand-made route goes to one stand: it serves only when the club is in that place.
	local hand = if site and site.rota == teamId then handRoutes[teamId] else nil
	local door = spawnPoints[teamId]
	routes[teamId] = if hand and #hand > 0 then hand elseif door then autoRoute(door, teamId) else {}
end

function City.build(_parent: Instance)
	local city = workspace:FindFirstChild("Cidade")
	if not city then
		city = CityMap.generate(workspace)
	end
	assert(city)

	-- So para o Studio: o sitio do estadio sai, o estadio a serio ja esta la.
	local area = city:FindFirstChild("EstadioArea")
	if area then
		area:Destroy()
	end

	--[[
		As sedes: onde estiverem no mapa, feitas por quem for, de qualquer
		tamanho. Uma sede e um Model chamado Sede_<equipa> dentro de
		Cidade.Sedes; a frente dele (a seta Front do pivo) aponta para a rua, e e
		dai que se sai. Se nao houver, fica no sitio de sempre, so com os botoes,
		para o jogo nao parar enquanto se constroi uma nova.
	]]
	local sedes = city:FindFirstChild("Sedes")
	-- A sede made by hand in the map (found by a marker or by its name).
	placeHand = function(teamId: string, markerName: string?)
		local sede = sedes and sedes:FindFirstChild("Sede_" .. teamId)
		-- Uma peca chamada Spawn_<equipa>, em qualquer sitio da cidade: manda
		-- ela. E onde se aparece e de onde sai o corteo; a frente dela (Front)
		-- aponta para a rua. Serve para sedes feitas a mao, com outros nomes.
		-- Tambem serve o nome da sede no mapa (Config.Teams[..].sedeName, ex.
		-- "sede vermelha"), em qualquer sitio do Workspace.
		local named = markerName
		local marker: Instance? = city:FindFirstChild("Spawn_" .. teamId, true)
			or (named and workspace:FindFirstChild(named, true))
		-- Um modelo (uma placa, por ex.) conta pelo seu pivo e pela sua caixa.
		if marker and marker:IsA("Model") then
			local pivot = marker:GetPivot()
			local box, size = marker:GetBoundingBox()
			local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
			local forward = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
			local ground = Vector3.new(pivot.Position.X, box.Position.Y - size.Y / 2, pivot.Position.Z)
			local signFrame = CFrame.lookAt(ground, ground - forward)
			-- Aparece-se um pouco a frente, para nao nascer em cima da placa.
			spawnPoints[teamId] = ground + forward * 5 + Vector3.new(0, 3.5, 0)
			local staffed = staffDesks(teamId, ground, marker)
			Clubhouse.equip(teamId, signFrame, marker, 0, staffed)
			-- As bicicletas ao lado da porta.
			Clubhouse.bikeRack(teamId, signFrame * CFrame.new(10, 0, 4), marker)
			return
		end
		local frame: CFrame
		local front = 17
		local parent: Instance = city
		if marker and marker:IsA("BasePart") then
			local look = Vector3.new(marker.CFrame.LookVector.X, 0, marker.CFrame.LookVector.Z)
			local forward = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
			local ground = Vector3.new(marker.Position.X, marker.Position.Y - marker.Size.Y / 2, marker.Position.Z)
			-- A porta e a peca: os botoes ficam logo atras dela, dentro da sede.
			frame = CFrame.lookAt(ground, ground - forward)
			front = 0
			parent = marker:FindFirstAncestorOfClass("Model") or city
			hide(marker)
			spawnPoints[teamId] = ground + Vector3.new(0, 3.5, 0)
			Clubhouse.equip(teamId, frame, parent, front)
			Clubhouse.bikeRack(teamId, frame * CFrame.new(10, 0, 4), parent)
			return
		elseif sede and sede:IsA("Model") then
			local pivot = sede:GetPivot()
			local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
			local forward = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
			local box, size = sede:GetBoundingBox()
			local ground = Vector3.new(pivot.Position.X, box.Position.Y - size.Y / 2, pivot.Position.Z)
			-- O +Z deste referencial e a frente da sede.
			frame = CFrame.lookAt(ground, ground - forward)
			-- Ate onde vai a sede para a frente: e ai que fica a porta.
			front = 0
			for _, x in { -0.5, 0.5 } do
				for _, z in { -0.5, 0.5 } do
					local corner = (box * CFrame.new(size.X * x, 0, size.Z * z)).Position
					front = math.max(front, Vector3.new(corner.X - ground.X, 0, corner.Z - ground.Z):Dot(forward))
				end
			end
			parent = sede
		else
			frame = CityMap.defaultSede(teamId) or CFrame.new()
			local holder = Instance.new("Folder")
			holder.Name = "Sede_" .. teamId .. "_botoes"
			holder.Parent = city
			parent = holder
			warn("[City] nao ha Cidade.Sedes.Sede_" .. teamId .. " no mapa: a claque usa o sitio de sempre")
		end
		spawnPoints[teamId] = (frame * CFrame.new(0, 3.5, front + 9)).Position
		Clubhouse.equip(teamId, frame, parent, front)
		Clubhouse.bikeRack(teamId, frame * CFrame.new(14, 0, front + 5), parent)
	end

	-- A praca da chegada. (O apito escolhe-se no menu; nao ha cabine na rua.)
	local arrival = city:FindFirstChild("Chegada")
	if arrival and arrival:IsA("BasePart") then
		neutral = Vector3.new(arrival.Position.X, 3.5, arrival.Position.Z)
		hide(arrival)
	end
	local post = city:FindFirstChild("PostoArbitragem")
	if post then
		post:Destroy()
	end

	-- Os caminhos do corteo, pela ordem dos numeros.
	local folder = city:FindFirstChild("Rotas")
	for _, teamId in Config.TeamOrder do
		local route = folder and folder:FindFirstChild(teamId)
		local points: { { index: number, at: Vector3 } } = {}
		if route then
			for _, child in route:GetChildren() do
				local index = tonumber(child.Name)
				if index and child:IsA("BasePart") then
					table.insert(points, { index = index, at = Vector3.new(child.Position.X, 3, child.Position.Z) })
					hide(child)
				end
			end
		end
		table.sort(points, function(a, b)
			return a.index < b.index
		end)
		handRoutes[teamId] = {}
		for _, point in points do
			table.insert(handRoutes[teamId], point.at)
		end
		City.place(teamId)
	end
	--[[
		Os dealers, a vender pirotecnia na rua. Onde houver pecas chamadas
		"Dealer" no mapa (postas a mao, viradas para onde o dealer olha), e ai;
		sem nenhuma, espalham-se junto a uns candeeiros da cidade.
	]]
	local spots: { CFrame } = {}
	for _, d in city:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Dealer" then
			table.insert(spots, CFrame.new(d.Position.X, d.Position.Y - d.Size.Y / 2, d.Position.Z) * d.CFrame.Rotation)
			hide(d)
		end
	end
	if #spots == 0 then
		local lamps: { Model } = {}
		for _, m in city:GetDescendants() do
			if m:IsA("Model") and m.Name == "Candeeiro" and m:FindFirstChild("Poste") and m:FindFirstChild("Luz") then
				table.insert(lamps, m)
			end
		end
		table.sort(lamps, function(a, b)
			local pa, pb = a:GetPivot().Position, b:GetPivot().Position
			return if pa.X == pb.X then pa.Z < pb.Z else pa.X < pb.X
		end)
		local count = math.min(Config.Dealers.count, #lamps)
		for i = 1, count do
			local lamp = lamps[math.floor((i - 0.5) * #lamps / count) + 1]
			local pole = lamp:FindFirstChild("Poste") :: BasePart
			local glow = lamp:FindFirstChild("Luz") :: BasePart
			local toStreet = Vector3.new(glow.Position.X - pole.Position.X, 0, glow.Position.Z - pole.Position.Z)
			local street = if toStreet.Magnitude > 0.1 then toStreet.Unit else Vector3.zAxis
			local along = street:Cross(Vector3.yAxis)
			local ground = Vector3.new(pole.Position.X, pole.Position.Y - pole.Size.Y / 2, pole.Position.Z) + along * 3
			table.insert(spots, CFrame.lookAt(ground, ground + street))
		end
	end
	local dealers = Instance.new("Folder")
	dealers.Name = "Dealers"
	dealers.Parent = city
	for _, spot in spots do
		Clubhouse.dealer(spot, dealers)
	end
end

return City
