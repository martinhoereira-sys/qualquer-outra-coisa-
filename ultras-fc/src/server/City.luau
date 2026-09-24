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
	for _, teamId in Config.TeamOrder do
		local sede = sedes and sedes:FindFirstChild("Sede_" .. teamId)
		-- Uma peca chamada Spawn_<equipa>, em qualquer sitio da cidade: manda
		-- ela. E onde se aparece e de onde sai o corteo; a frente dela (Front)
		-- aponta para a rua. Serve para sedes feitas a mao, com outros nomes.
		-- Tambem serve o nome da sede no mapa (Config.Teams[..].sedeName, ex.
		-- "sede vermelha"), em qualquer sitio do Workspace.
		local named = Config.Teams[teamId].sedeName
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
			continue
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
			continue
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
		routes[teamId] = {}
		for _, point in points do
			table.insert(routes[teamId], point.at)
		end
	end
end

return City
