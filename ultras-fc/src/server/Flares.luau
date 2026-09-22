--!strict
--[[
	Tochas.

	A imagem da coisa toda: bancada as escuras e um ponto de luz a arder no meio
	dela. Por isso o servidor e que as acende — uma tocha que so quem a acendeu
	visse nao servia de nada. Todos tem de as ver.

	Sao poucas e duram pouco de proposito. Se cada um pudesse ter sempre uma
	acesa, deixava de ser um momento e passava a ser o fundo do ecra.

	Vivem na mochila como objecto, nao numa tecla solta: pegar nela, levanta-la e
	ve-la na mao e metade do gesto.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Teams = require(script.Parent:WaitForChild("Teams"))

local Flares = {}

local F = Config.Flares

local remaining: { [Player]: number } = {}
local nextAllowed: { [Player]: number } = {}

type Burning = {
	tool: Tool,
	until_: number,
	teamId: string,
}

local burning: { [Player]: Burning } = {}
local onCountChanged: ((Player, number) -> ())? = nil

function Flares.onCountChanged(fn: (Player, number) -> ())
	onCountChanged = fn
end

function Flares.remaining(player: Player): number
	return remaining[player] or F.perMatch
end

local function announce(player: Player)
	if onCountChanged then
		onCountChanged(player, Flares.remaining(player))
	end
end

function Flares.countFor(teamId: string): number
	local total = 0
	for _, entry in burning do
		if entry.teamId == teamId then
			total += 1
		end
	end
	return total
end

--------------------------------------------------------------------------------
-- O objecto
--------------------------------------------------------------------------------

local function buildTool(colour: Color3): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Tocha"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	-- Com pega, o Roblox poe sozinho a pose de segurar: o braco sobe e a mao
	-- fecha-se no cabo, sem ser preciso animacao nenhuma.
	tool.Grip = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-20), 0, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 1.8, 0.35)
	handle.Color = Color3.fromRGB(26, 26, 29)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.4, 0.35, 0.4)
	tip.Color = colour
	tip.Material = Enum.Material.Neon
	tip.CanCollide = false
	tip.Massless = true
	tip.CastShadow = false
	tip.Transparency = 1 -- so acende quando for acesa
	tip.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = tip
	weld.Parent = handle
	tip.CFrame = handle.CFrame * CFrame.new(0, 1.05, 0)

	return tool
end

local function ignite(tool: Tool, colour: Color3)
	local tip = tool:FindFirstChild("Tip") :: BasePart?
	if not tip then
		return
	end

	tip.Transparency = 0

	local fire = Instance.new("Fire")
	fire.Heat = 14
	fire.Size = 6
	fire.Color = colour
	fire.SecondaryColor = Color3.fromRGB(255, 238, 196)
	fire.Parent = tip

	-- O fumo e metade do efeito: e ele que se ve do outro lado do estadio e que
	-- fica preso debaixo da cobertura da bancada.
	local smoke = Instance.new("Smoke")
	smoke.Color = colour:Lerp(Color3.new(1, 1, 1), 0.5)
	smoke.Opacity = 0.34
	smoke.RiseVelocity = 10
	smoke.Size = 10
	smoke.Parent = tip

	local light = Instance.new("PointLight")
	light.Brightness = 7
	light.Range = 38
	light.Color = colour
	light.Shadows = true
	light.Parent = tip
end

--------------------------------------------------------------------------------

--[[
	Da uma tocha nova a mochila, se ainda houver e a espera ja tiver passado.
	Acender e depois: e ao carregar nela com a mao.
]]
function Flares.issue(player: Player): boolean
	local teamId = Teams.get(player)
	if not teamId then
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return false
	end

	-- Uma de cada vez, esteja na mochila ou ja na mao.
	if backpack:FindFirstChild("Tocha") then
		return false
	end
	local character = player.Character
	if character and character:FindFirstChild("Tocha") then
		return false
	end

	if (nextAllowed[player] or 0) > os.clock() then
		return false
	end

	local left = remaining[player] or F.perMatch
	if left <= 0 then
		return false
	end

	local tool = buildTool(Config.Teams[teamId].color)
	tool.Parent = backpack

	tool.Activated:Connect(function()
		if burning[player] then
			return
		end

		local current = Teams.get(player)
		if not current then
			return
		end

		local stock = remaining[player] or F.perMatch
		if stock <= 0 then
			return
		end

		remaining[player] = stock - 1
		nextAllowed[player] = os.clock() + F.cooldown
		burning[player] = { tool = tool, until_ = os.clock() + F.duration, teamId = current }

		ignite(tool, Config.Teams[current].color)
		announce(player)
	end)

	return true
end

--[[
	Enquanto arde, a tocha balanca na mao. E movimento a serio, sem precisar de
	animacao carregada: mexer o Grip mexe o objecto dentro da mao, e e isso que
	se ve da outra ponta do estadio.
]]
local function sway(entry: Burning, now: number)
	local t = now * 5.5
	entry.tool.Grip = CFrame.new(math.sin(t) * 0.12, -0.4, 0)
		* CFrame.Angles(math.rad(-20) + math.sin(t) * 0.35, math.sin(t * 0.7) * 0.25, math.cos(t) * 0.2)
end

function Flares.start()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, entry in burning do
			if now >= entry.until_ then
				burning[player] = nil
				if entry.tool.Parent then
					entry.tool:Destroy()
				end
			else
				sway(entry, now)
			end
		end
	end)
end

function Flares.refill()
	for _, player in Players:GetPlayers() do
		remaining[player] = F.perMatch
		announce(player)
	end
end

function Flares.forget(player: Player)
	remaining[player] = nil
	nextAllowed[player] = nil
	burning[player] = nil
end

return Flares
