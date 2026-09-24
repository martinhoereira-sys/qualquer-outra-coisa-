--!strict
--[[
	A cidade a volta, e as duas sedes.

	Isto existe por uma razao: nao se entra num estadio por magia. Apareces na
	sede da tua claque, sais para a rua, e andas ate la — e no caminho que o
	corteo ha-de acontecer.

	A cidade vive no mapa (Workspace.Cidade), feita uma vez pelo CityMap e
	depois mexida a mao no Studio por quem quiser. Aqui le-se o que la estiver:
	- Cidade.Sedes.Sede_<equipa>: cada sede, onde quer que esteja e virada
	  para onde estiver. A porta e o lado +Z do modelo;
	- Cidade.Chegada: onde aparece quem ainda nao escolheu lado;
	- Cidade.PostoArbitragem: onde fica a cabine do arbitro;
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

-- A porta de uma sede, no chao a frente dela: e ai que se aparece e que o corteo comeca.
local SEDE_FRONT = 17 + 9

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

	-- As sedes: onde estiverem no mapa, e o Clubhouse poe-lhes o recheio.
	local sedes = city:FindFirstChild("Sedes")
	for _, teamId in Config.TeamOrder do
		local sede = sedes and sedes:FindFirstChild("Sede_" .. teamId)
		if sede and sede:IsA("Model") then
			local pivot = sede:GetPivot()
			-- O pivo e o chao da sede (a peca Base); o recheio assenta no passeio.
			local flat = CFrame.new(pivot.Position.X, pivot.Position.Y - 0.5, pivot.Position.Z) * pivot.Rotation
			spawnPoints[teamId] = (flat * CFrame.new(0, 3.5, SEDE_FRONT)).Position
			Clubhouse.equip(teamId, flat, sede)
		else
			warn("[City] falta a sede de " .. teamId .. " no mapa (Cidade.Sedes.Sede_" .. teamId .. ")")
		end
	end

	-- A praca da chegada e o posto do arbitro.
	local arrival = city:FindFirstChild("Chegada")
	if arrival and arrival:IsA("BasePart") then
		neutral = Vector3.new(arrival.Position.X, 3.5, arrival.Position.Z)
		hide(arrival)
	end
	local post = city:FindFirstChild("PostoArbitragem")
	if post and post:IsA("BasePart") then
		Clubhouse.refereePost(Vector3.new(post.Position.X, 0, post.Position.Z), city)
		hide(post)
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
