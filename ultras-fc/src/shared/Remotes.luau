--!strict
--[[
	Cria (no servidor) e encontra (no cliente) os RemoteEvents.

	Ter isto num sitio so evita WaitForChild espalhado por todo o lado e faz
	falhar cedo se um nome for mal escrito.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"PickTeam", -- cliente -> servidor: escolhi esta equipa
	"Chant", -- cliente -> servidor: cantei agora
	"Atmosphere", -- servidor -> clientes: as barras das duas bancadas
	"MatchState", -- servidor -> clientes: fase, relogio, resultado
	"Flare", -- cliente -> servidor: acender tocha
	"FlareCount", -- servidor -> cliente: quantas lhe restam
}

local folder: Folder

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes = {}
for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
