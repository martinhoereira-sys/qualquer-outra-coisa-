--!strict
--[[
	Tochas.

	A imagem da coisa toda: bancada as escuras e um ponto de luz a arder no meio
	dela. Por isso o servidor e que as acende — uma tocha que so quem a acendeu
	visse nao servia de nada. Todos tem de as ver.

	Sao poucas e duram pouco de proposito. Se cada um pudesse ter sempre uma
	acesa, deixava de ser um momento e passava a ser o fundo do ecra.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Teams = require(script.Parent:WaitForChild("Teams"))

local Flares = {}

local F = Config.Flares

local remaining: { [Player]: number } = {}
local nextAllowed: { [Player]: number } = {}
local burning: { [Player]: true } = {}

function Flares.remaining(player: Player): number
	return remaining[player] or F.perMatch
end

function Flares.refill()
	for _, player in Players:GetPlayers() do
		remaining[player] = F.perMatch
	end
end

function Flares.forget(player: Player)
	remaining[player] = nil
	nextAllowed[player] = nil
	burning[player] = nil
end

-- Quantas estao acesas nesta bancada, que e o que o ambiente le.
function Flares.countFor(teamId: string): number
	local total = 0
	for player in burning do
		if Teams.get(player) == teamId then
			total += 1
		end
	end
	return total
end

--[[
	A mao direita em R15 ou R6. Se nenhuma existir — avatares estranhos, corpo
	ainda a montar — vale o tronco: uma tocha presa ao peito e esquisita, mas
	carregar em F e nao acontecer nada e pior.
]]
local function findHand(character: Model): BasePart?
	return (
		character:FindFirstChild("RightHand")
		or character:FindFirstChild("Right Arm")
		or character:FindFirstChild("HumanoidRootPart")
	) :: BasePart?
end

local function buildFlare(colour: Color3): Part
	local handle = Instance.new("Part")
	handle.Name = "Flare"
	handle.Size = Vector3.new(0.3, 1.5, 0.3)
	handle.Color = Color3.fromRGB(28, 28, 30)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true

	-- A ponta acesa. Neon porque o brilho tem de se ver do outro lado do estadio.
	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.34, 0.3, 0.34)
	tip.Color = colour
	tip.Material = Enum.Material.Neon
	tip.CanCollide = false
	tip.Massless = true
	tip.CastShadow = false
	tip.Parent = handle

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = tip
	weld.Parent = handle
	tip.CFrame = handle.CFrame * CFrame.new(0, 0.9, 0)

	local fire = Instance.new("Fire")
	fire.Heat = 12
	fire.Size = 5
	fire.Color = colour
	fire.SecondaryColor = Color3.fromRGB(255, 236, 190)
	fire.Parent = tip

	-- O fumo e metade do efeito: e ele que se ve de longe e que fica preso
	-- debaixo da cobertura da bancada.
	local smoke = Instance.new("Smoke")
	smoke.Color = colour:Lerp(Color3.new(1, 1, 1), 0.45)
	smoke.Opacity = 0.32
	smoke.RiseVelocity = 9
	smoke.Size = 9
	smoke.Parent = tip

	local light = Instance.new("PointLight")
	light.Brightness = 6
	light.Range = 34
	light.Color = colour
	light.Shadows = true
	light.Parent = tip

	return handle
end

--[[
	Acende uma tocha na mao do jogador. Devolve false quando nao ha, quando a
	espera ainda nao passou, ou quando ja tem uma a arder.
]]
function Flares.light(player: Player): boolean
	local teamId = Teams.get(player)
	if not teamId then
		return false
	end

	if burning[player] then
		return false
	end

	local now = os.clock()
	if (nextAllowed[player] or 0) > now then
		return false
	end

	local left = remaining[player] or F.perMatch
	if left <= 0 then
		return false
	end

	local character = player.Character
	local hand = character and findHand(character)
	if not hand then
		return false
	end

	remaining[player] = left - 1
	nextAllowed[player] = now + F.duration + F.cooldown
	burning[player] = true

	local flare = buildFlare(Config.Teams[teamId].color)
	flare.CFrame = hand.CFrame * CFrame.new(0, -0.8, 0)
	flare.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = flare
	weld.Parent = flare

	task.delay(F.duration, function()
		burning[player] = nil
		if flare.Parent then
			flare:Destroy()
		end
	end)

	return true
end

return Flares
