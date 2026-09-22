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

local Gear = {}

local KINDS = Config.Gear

-- Contagens por tipo: cada material tem o seu stock e a sua espera.
local remaining: { [Player]: { [string]: number } } = {}
local nextAllowed: { [Player]: { [string]: number } } = {}

type Burning = {
	tool: Tool,
	until_: number,
	teamId: string,
	kind: string,
}

local burning: { [Player]: Burning } = {}
local onDrumHit: ((Player) -> ())? = nil

function Gear.onDrumHit(fn: (Player) -> ())
	onDrumHit = fn
end
local onCountChanged: ((Player, number) -> ())? = nil

function Gear.onCountChanged(fn: (Player, { [string]: number }) -> ())
	onCountChanged = fn
end

function Gear.remaining(player: Player, kind: string): number
	local mine = remaining[player]
	local stock = mine and mine[kind]
	return stock ~= nil and stock or KINDS[kind].perMatch
end

local function spend(player: Player, kind: string)
	remaining[player] = remaining[player] or {}
	remaining[player][kind] = Gear.remaining(player, kind) - 1
end

local function announce(player: Player)
	if onCountChanged then
		onCountChanged(player, {
			tocha = Gear.remaining(player, "tocha"),
			fumo = Gear.remaining(player, "fumo"),
			tambor = Gear.remaining(player, "tambor"),
		})
	end
end

-- Quanto e que o material aceso desta bancada empurra o ambiente por segundo.
function Gear.heatFor(teamId: string): number
	local total = 0
	for _, entry in burning do
		if entry.teamId == teamId then
			total += KINDS[entry.kind].gainPerSecond
		end
	end
	return total
end


--------------------------------------------------------------------------------
-- O objecto
--------------------------------------------------------------------------------

local function buildTool(kind: string, colour: Color3): Tool
	local tool = Instance.new("Tool")
	tool.Name = kind
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	-- Com pega, o Roblox poe sozinho a pose de segurar: o braco sobe e a mao
	-- fecha-se no cabo, sem ser preciso animacao nenhuma.
	tool.Grip = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-20), 0, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.Massless = true
	handle.Material = Enum.Material.SmoothPlastic
	handle.Parent = tool

	if kind == "tambor" then
		handle.Size = Vector3.new(2.6, 2.2, 2.6)
		handle.Shape = Enum.PartType.Cylinder
		handle.Color = Color3.fromRGB(196, 186, 168)
		-- Deitado e a tiracolo, como se leva um bombo.
		tool.Grip = CFrame.new(0, -1.4, 0) * CFrame.Angles(0, 0, math.rad(90))

		local skin = Instance.new("Part")
		skin.Name = "Skin"
		skin.Size = Vector3.new(0.3, 2.3, 2.3)
		skin.Shape = Enum.PartType.Cylinder
		skin.Color = colour
		skin.Material = Enum.Material.SmoothPlastic
		skin.CanCollide = false
		skin.Massless = true
		skin.Parent = tool

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = skin
		weld.Parent = handle
		skin.CFrame = handle.CFrame * CFrame.new(1.4, 0, 0)
	else
		handle.Size = Vector3.new(0.35, 1.8, 0.35)
		handle.Color = Color3.fromRGB(26, 26, 29)

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
	end

	return tool
end

local function ignite(tool: Tool, kind: string, colour: Color3)
	local tip = tool:FindFirstChild("Tip") :: BasePart?
	if not tip then
		return
	end

	tip.Transparency = 0

	--[[
		O fumo e metade do efeito: e ele que se ve do outro lado do estadio e que
		fica preso debaixo da cobertura. Por isso a bomba de fumo nao tem chama
		nenhuma — so fumo, muito mais e mais denso.
	]]
	local smoke = Instance.new("Smoke")
	smoke.Color = colour:Lerp(Color3.new(1, 1, 1), kind == "fumo" and 0.25 or 0.5)
	smoke.Opacity = kind == "fumo" and 0.6 or 0.34
	smoke.RiseVelocity = kind == "fumo" and 6 or 10
	smoke.Size = kind == "fumo" and 18 or 10
	smoke.Parent = tip

	if kind == "tocha" then
		local fire = Instance.new("Fire")
		fire.Heat = 14
		fire.Size = 6
		fire.Color = colour
		fire.SecondaryColor = Color3.fromRGB(255, 238, 196)
		fire.Parent = tip
	end

	local light = Instance.new("PointLight")
	light.Brightness = kind == "tocha" and 7 or 3.5
	light.Range = kind == "tocha" and 38 or 26
	light.Color = colour
	light.Shadows = true
	light.Parent = tip
end

--------------------------------------------------------------------------------

--[[
	Da material novo a mochila, se ainda houver e a espera ja tiver passado.
	Acender e depois: e ao carregar nele com a mao.
]]
function Gear.issue(player: Player, kind: string): boolean
	local spec = KINDS[kind]
	if not spec then
		return false
	end

	local teamId = Teams.get(player)
	if not teamId then
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return false
	end

	-- Um de cada tipo, esteja na mochila ou ja na mao.
	local character = player.Character
	if backpack:FindFirstChild(kind) or (character and character:FindFirstChild(kind)) then
		return false
	end

	local waits = nextAllowed[player]
	if waits and (waits[kind] or 0) > os.clock() then
		return false
	end

	if Gear.remaining(player, kind) <= 0 then
		return false
	end

	local colour = Config.Teams[teamId].color
	local tool = buildTool(kind, colour)
	tool.Parent = backpack

	tool.Activated:Connect(function()
		local current = Teams.get(player)
		if not current then
			return
		end

		-- O tambor bate-se as vezes que forem precisas; o resto acende uma vez.
		if kind == "tambor" then
			if onDrumHit then
				onDrumHit(player)
			end
			return
		end

		if burning[player] then
			return
		end
		if Gear.remaining(player, kind) <= 0 then
			return
		end

		spend(player, kind)
		nextAllowed[player] = nextAllowed[player] or {}
		nextAllowed[player][kind] = os.clock() + spec.cooldown
		burning[player] = {
			tool = tool,
			until_ = os.clock() + spec.duration,
			teamId = current,
			kind = kind,
		}

		ignite(tool, kind, Config.Teams[current].color)
		announce(player)
	end)

	-- O tambor conta como gasto quando sai da mochila: fica para o jogo todo.
	if kind == "tambor" then
		spend(player, kind)
		burning[player] = burning[player]
			or { tool = tool, until_ = math.huge, teamId = teamId, kind = kind }
		announce(player)
	end

	return true
end

--[[
	Enquanto arde, o material balanca na mao. E movimento a serio, sem precisar
	de animacao carregada: mexer o Grip mexe o objecto dentro da mao, e e isso
	que se ve da outra ponta do estadio.
]]
local function sway(entry: Burning, now: number)
	if entry.kind == "tambor" then
		return
	end
	local t = now * 5.5
	entry.tool.Grip = CFrame.new(math.sin(t) * 0.12, -0.4, 0)
		* CFrame.Angles(math.rad(-20) + math.sin(t) * 0.35, math.sin(t * 0.7) * 0.25, math.cos(t) * 0.2)
end

function Gear.start()
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

function Gear.refill()
	for _, player in Players:GetPlayers() do
		remaining[player] = {}
		nextAllowed[player] = {}
		announce(player)
	end
end

function Gear.forget(player: Player)
	remaining[player] = nil
	nextAllowed[player] = nil
	burning[player] = nil
end

return Gear
