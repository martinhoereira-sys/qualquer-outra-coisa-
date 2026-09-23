--!strict
--[[
	O que se ouve.

	A multidao de fundo toca sempre, sobe e desce com o ambiente das bancadas e
	com a distancia ao estadio — e fica abaixo de tudo o resto, para o apito e o
	golo se ouvirem por cima. No corteo ouve-se a festa a volta da faixa.

	Os sons do jogo (apito, pontape, tambor) chegam do servidor pelo nome; o
	golo e o lamento saem do marcador, que toda a gente ja recebe.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))

local player = Players.LocalPlayer

-- A equipa por quem se sofre: a da claque, ou a de quem se joga.
local function mySide(): string?
	local team = player:GetAttribute("Team")
	if type(team) == "string" and Config.Teams[team] then
		return team
	end
	local pitch = player:GetAttribute("PitchTeam")
	return if type(pitch) == "string" and Config.Teams[pitch] then pitch else nil
end

--------------------------------------------------------------------------------
-- Sons que o servidor manda tocar
--------------------------------------------------------------------------------

Remotes.Sound.OnClientEvent:Connect(function(name, at)
	if type(name) ~= "string" then
		return
	end
	Sounds.play(name, if typeof(at) == "Vector3" then at else nil)
end)

--------------------------------------------------------------------------------
-- Golo, lamento, e a festa de quem ganhou
--------------------------------------------------------------------------------

local lastGoalStamp = 0
local lastPhase = ""
local phase = ""

Remotes.MatchState.OnClientEvent:Connect(function(snapshot)
	phase = snapshot.phase

	if snapshot.lastGoal and snapshot.goalStamp > lastGoalStamp then
		-- O primeiro estado que chega a quem entra a meio nao e um golo novo.
		local fresh = lastGoalStamp > 0 or workspace:GetServerTimeNow() - snapshot.goalStamp < 3
		lastGoalStamp = snapshot.goalStamp
		if fresh then
			Sounds.play("golo")
			-- O estadio inteiro ouve a bancada que sofreu; quem sofre ouve-a mais.
			local mine = mySide()
			local suffered = mine ~= nil and mine ~= snapshot.lastGoal
			task.delay(0.6, function()
				Sounds.play("lamento", nil, if suffered then 1 else 0.45)
			end)
		end
	end

	-- De volta a sede depois de ganhar: festa. Quem perdeu volta em silencio.
	if phase == "clubhouse" and lastPhase == "fulltime" then
		local winner = workspace:GetAttribute("LastWinner")
		if winner ~= "" and winner == mySide() then
			Sounds.play("festa_fim")
		end
	end
	lastPhase = phase
end)

--------------------------------------------------------------------------------
-- A multidao de fundo e o corteo
--------------------------------------------------------------------------------

local crowd = Sounds.loop("multidao")
local corteo = Sounds.loop("corteo")
local crowdSpec = Config.Sounds.multidao
local atmosphere = 0 -- 0 a 1, a bancada mais quente

Remotes.Atmosphere.OnClientEvent:Connect(function(levels)
	local top = 0
	for _, value in levels do
		top = math.max(top, value)
	end
	atmosphere = math.clamp(top / Config.Atmosphere.max, 0, 1)
end)

-- 1 perto, 0 longe, a descer entre `near` e `far`.
local function closeness(distance: number, near: number, far: number): number
	return math.clamp(1 - (distance - near) / (far - near), 0, 1)
end

local function bannerDistance(from: Vector3): number
	local stadium = workspace:FindFirstChild("Stadium")
	local march = stadium and stadium:FindFirstChild("March")
	local best = math.huge
	if march then
		for _, banner in march:GetChildren() do
			if banner:IsA("BasePart") then
				best = math.min(best, (banner.Position - from).Magnitude)
			end
		end
	end
	return best
end

if crowd then
	crowd:Play()
end
if corteo then
	corteo:Play()
end

local nextCheck = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextCheck then
		return
	end
	nextCheck = now + 0.2

	local camera = workspace.CurrentCamera
	local at = if camera then camera.CFrame.Position else Vector3.zero

	if crowd and crowdSpec then
		-- O estadio fica na origem; da sede so se ouve ao longe.
		local base = crowdSpec.volume + ((crowdSpec.volumeMax or crowdSpec.volume) - crowdSpec.volume) * atmosphere
		crowd.Volume = base * closeness(at.Magnitude, 260, 650)
	end

	if corteo then
		local near = if phase == "corteo" then closeness(bannerDistance(at), 60, 260) else 0
		corteo.Volume = Sounds.volume("corteo") * near
	end
end)

--[[
	A fila parada a frente da bancada principal: o tambor por cima de tudo,
	sem ninguem ter de bater. E o momento mais alto do dia.
]]
local DRUM_EVERY = 0.5
local nextDrum = 0
RunService.Heartbeat:Connect(function()
	if workspace:GetAttribute("EntranceLine") ~= true then
		return
	end
	local now = os.clock()
	if now >= nextDrum then
		nextDrum = now + DRUM_EVERY
		Sounds.play("tambor", nil, 0.7)
	end
end)
