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
	"Atmosphere", -- servidor -> clientes: as barras das duas bancadas
	"MatchState", -- servidor -> clientes: fase, relogio, resultado
	"Gear", -- cliente -> servidor: pedir material (tocha, fumo, tambor)
	"GearCount", -- servidor -> cliente: quanto lhe resta de cada
	"Incident", -- servidor -> arbitro: ha um lance para decidir
	"Decide", -- arbitro -> servidor: a decisao
	"Pressure", -- adepto -> servidor: pedir ao arbitro
	"RefState", -- servidor -> todos: quem apita, suspeicao, ultima decisao
	"Tifo", -- cliente -> servidor: o lider dispara um tifo, ou alguem levanta a cartolina
	"TifoState", -- servidor -> clientes: tifo no ar, e a cartolina de cada um
	"Football", -- jogador -> servidor: sprint, e o chuto (forca, efeito, altura)
	"Sound", -- servidor -> clientes: toca este som (pelo nome do Config.Sounds), e onde
	"Celebrate", -- servidor -> quem marcou: corre para a tua claque
	"Admin", -- admin -> servidor: saltar de fase
	"Escort", -- servidor -> quem sai do tunel: este e o teu caminho ate a fila
	"Home", -- cliente -> servidor: leva-me a minha sede
	"Emote", -- cliente -> servidor: a animacao de adepto que escolhi ("" para parar)
	"Npc", -- servidor -> cliente: o que um NPC da sede te diz (titulo e linhas)
	"Shop", -- dealer: servidor -> cliente "open"; cliente -> servidor "buy", material
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
